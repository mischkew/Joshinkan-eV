#! /bin/bash

# NOTE(sven): Stop on errors and log the shell commands executed to
# stdout. Useful for debugging when running the bootstrap script via the make
# pipeline.
set -ex

if [ ! -f .env.current-deployment ]; then
  echo ".env.current-deployment file not found. 'MAKE upload' executed?"
  exit 1
fi
source .env.current-deployment

function test_environment() {
  if [ -z "$(eval echo \$$1)" ]; then
    echo "Error: Environment variable $1 not set."
    exit 1
  fi
}

test_environment DOMAIN
test_environment SMTP_USER
test_environment SSL_CERT
test_environment SSL_KEY

# NOTE(sven): We add the ubuntu user to the docker group. All ssh-ed users will
# need to use sudo.
USER=ubuntu

# Security upgrades
sudo apt update
sudo apt upgrade --yes

# Install dependencies
sudo apt install nginx python3 python3.10-venv unzip make --yes
sudo snap install --classic certbot
sudo ln -f -s /snap/bin/certbot /usr/bin/certbot

# create virtual environment for python
python3 -m venv venv

# create a self signed certificate so our nginx server can start without
# errors. Certificates will be updated by certbot
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout $SSL_KEY \
     -out $SSL_CERT \
     -subj "/C=DE/ST=Denial/L=Berlin/O=Dis/CN=$DOMAIN"

# add the www-data (nginx default) user to our group
sudo usermod --append --groups $USER www-data

# backend system configuration
cat <<EOF > joshinkan.service
[Unit]
Description=Joshinkan Backend - Gunicorn
After=network.target

[Service]
User=ubuntu
Group=ubuntu
Environment="ENVIRONMENT=current-deployment"
WorkingDirectory=/home/ubuntu/joshinkan/
ExecStart=/bin/bash -c /home/ubuntu/joshinkan/server-entrypoint.sh

[Install]
WantedBy=multi-user.target
EOF
sudo cp joshinkan.service /etc/systemd/system/joshinkan.service

sudo systemctl daemon-reload
sudo systemctl enable joshinkan # we don't start yet, need to deploy first

# now we deploy the server once so that the webroot is available for certbot setup
./deploy.sh

# After this, manually ssh into the server and execute `sudo certbot` to obtain
# the initial certificates
sudo certbot certonly \
     -n \
     --agree-tos \
     --email "$SMTP_USER" \
     --no-eff-email \
     --force-renewal \
     --webroot \
     --webroot-path "$BUILD_DIR/web/" \
     --domains "$DOMAIN"
ln -sf /etc/letsencrypt/live/$DOMAIN/fullchain.pem "$SSL_CERT"
ln -sf /etc/letsencrypt/live/$DOMAIN/privkey.pem "$SSL_KEY"
sudo systemctl reload nginx

# Setup certbot auto-renew
cat << EOF > nginx-reload.sh
#! /bin/bash
systemctl reload nginx
EOF
sudo chmod a+x nginx-reload.sh
sudo mv nginx-reload.sh "/etc/letsencrypt/renewal-hooks/post/nginx-reload.sh"

# and reboot to make any apt upgrade changes active
sudo reboot
