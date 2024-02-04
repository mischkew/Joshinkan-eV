.PHONY: all
all: watch

SYSTEM_NAME = $(shell uname -s)

ifneq (,$(wildcard .env))
	include .env
endif

ifndef SMTP_USER
$(error Variable SMTP_USER is not set. Check .env or define environment variable)
endif
ifndef SMTP_PASSWORD
$(error Variable SMTP_PASSWORD is not set. Check .env or define environment variable)
endif
ifndef DOMAIN
$(error Variable DOMAIN is not set. Check .env or define environment variable)
endif
ifndef SSL_CERT
$(error Variable SSL_CERT is not set. Check .env or define environment variable)
endif
ifndef SSL_KEY
$(error Variable SSL_KEY is not set. Check .env or define environment variable)
endif


#
# General
#

.PHONY: clean
clean:
	rm -rf ./build

.PHONY: build
build: build-frontend install-backend

.PHONY: watch
watch:
	@echo "Call `make watch-frontend` and `make watch-backend` in two separate shells."

.PHONY: stop
stop: stop-nginx

# Shows whether a local backend instance are already running
.PHONY: status
status: status-nginx

.PHONE: test
test: test-backend

#
# Frontend
#

# GNU sed is required for shell substitution. Use brew to install it on OSX if
# it is not present.
GSED_PATH = $(shell which gsed)

# NOTE(sven): Install gnu-sed on OSX as otherwise shell command substitution is
# not supported, which we need for templating.
ifeq ($(SYSTEM_NAME), Darwin)
ifeq (,$(GSED_PATH))
	brew install gnu-sed
endif
endif

.PHONY: assets
assets:
	mkdir -p build/web
	cp -r web/images web/stylesheets web/javascripts web/fonts build/web

.PHONY: start-nginx
start-nginx:
	$(MAKE) stop-nginx
	echo "Starting nginx"
	mkdir -p logs
	nginx -p ./ -c build/nginx.conf

.PHONY: stop-nginx
stop-nginx:
	@(nginx -s stop -p ./build -c nginx.conf >& /dev/null && echo "nginx stopped") || \
		echo "nginx not running"

.PHONY: reload-nginx
reload-nginx: .should-reload

.should-reload: nginx.tpl.conf .env $(wildcard *.pem)
	@echo "reload nginx";
	nginx -s reload -p ./ -c build/nginx.conf
	@touch $@

.PHONY: status-nginx
status-nginx:
	@if [ -f build/nginx.pid ]; then \
		(ps -p $$(cat build/nginx.pid) >& /dev/null && echo "nginx running") || echo "nginx not running"; \
	else \
		echo "nginx not running"; \
	fi

.PHONY: certs
dev-certs:
	@if [ -f "localhost+2.pem" ] && [ -f "localhost+2-key.pem" ]; then \
		echo "Development certificates already created. Exiting."; \
		exit 1; \
	fi

	@if [ ! "$$(command -v mkcert)" ]; then \
	 	echo "mkcert is not installed. Refer to the README."; \
	 	exit 1; \
	fi

	mkcert localhost 127.0.0.1 ::1
	@if [ ! -f "localhost+2.pem" ] || [ ! -f "localhost+2-key.pem" ]; then \
	 	echo "Unexpected mkcert local certificate names."; \
	 	exit 1; \
	fi

build/nginx.conf: nginx.tpl.conf .env $(SSL_KEY) $(SSL_CERT) mime.types ./load-env.sh
	mkdir -p build
	cp $(SSL_KEY) build/
	cp $(SSL_CERT) build/
	cp mime.types build/
	source ./load-env.sh .env && \
  ./web/scripts/include.sh $< > $@

.PHONY: logs-error
logs-error:
	tail -f logs/error.log

.PHONY: logs-access
logs-access:
	tail -f logs/access.log

.PHONY: build-frontend
build-frontend: assets $(addprefix build/,$(wildcard web/*.html)) build/nginx.conf

build/web/%.html: \
	web/%.html \
	$(wildcard web/templates/*.html) \
	$(wildcard web/components/*.html) \
	$(wildcard web/stylesheets/*.css) \
	$(wildcard web/scripts/*.sh)

	@echo "Building $< to $@"
	@mkdir -p $$(dirname $@)
	./web/scripts/include.sh $< > $@ || (rm $@ && exit 1)

.PHONY: watch-frontend
watch-frontend:
	$(MAKE) build-frontend
	@if [ "$$($(MAKE) status-nginx)" = "nginx not running" ]; then \
		$(MAKE) start-nginx --silent; \
	fi

	@echo "Starting to watch for frontend changes."
	@echo "Edit files and:"
	@echo "  - the frontend will rebuild"
	@echo "  - the nginx config will reload"
	@echo "... if required."
	@echo

	@while true; do \
		$(MAKE) build-frontend --silent; \
		$(MAKE) reload-nginx --silent; \
		sleep 1; \
	done

#
# Backend
#

.PHONY: install-backend
install-backend: build/install.log
build/install.log: server/setup.py
	@echo "Installing backend for development"
	mkdir -p build
	pip install -e 'server[dev]' | tee build/install.log

.PHONY: watch-backend
watch-backend: install-backend
	@echo "Starting to watch for backend changes."
	@echo "Edit files and:"
	@echo "  - the backend will reload"
	@echo "... if required."

	source ./load-env.sh .env && \
	joshinkand-dev

.PHONY: test-backend
test-backend: install-backend
	cd "server" && pytest -x --ff -v

#
# Deployment
#


.PHONY: ssh
ssh:
	ssh ec2-user@3.70.140.207 # TODO: test.joshinkan.de

.PHONY: upload
upload:
	./zip-pack.sh
	scp joshinkan.zip ec2-user@3.70.140.207:~/
	ssh ec2-user@3.70.140.207 sudo mv '~/joshinkan.zip' /opt
	ssh ec2-user@3.70.140.207 < ./zip-unpack.sh

.PHONY: deploy
deploy:
	gcloud app deploy --quiet
