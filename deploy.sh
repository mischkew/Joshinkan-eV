#! /bin/bash

set -ex

source ~/venv/bin/activate
export ENVIRONMENT=current-deployment

make clean
make build

source ./load-env.sh
sudo ln -sf $BUILD_DIR/nginx-host.conf /etc/nginx/sites-enabled/joshinkan.conf
sudo rm -f /etc/nginx/sites-enabled/default # disable the default server

mkdir -p $LOGS_DIR
sudo systemctl restart nginx
sudo systemctl restart joshinkan
