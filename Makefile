.PHONY: all
all: watch

SYSTEM_NAME = $(shell uname -s)

ifndef ENVIRONMENT
ENVIRONMENT=local
endif

ifneq ($(ENVIRONMENT),$(filter $(ENVIRONMENT),production testing local current-deployment))
$(error Variable ENVIRONMENT must be either production, testing, local or current-deployment)
endif

include .env.$(ENVIRONMENT)

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
ifndef BUILD_DIR
$(error Variable BUILD_DIR is not set. Check .env or define environment variable)
endif
ifndef LOGS_DIR
$(error Variable LOGS_DIR is not set. Check .env or define environment variable)
endif

# Checks if the currently used environment is local. Otherwise exits.
require-local:
	@if [ "${ENVIRONMENT}" != "local" ]; then \
	  echo "Environment 'local' is required. The current environment is '${ENVIRONMENT}'."; \
	  exit 1; \
	fi


#
# General
#

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

.PHONY: build
build: build-frontend install-backend

.PHONY: watch
watch: | require-local
	@echo "Call `make watch-frontend` and `make watch-backend` in two separate shells."

.PHONY: stop | require-local
stop: stop-nginx

# Shows whether a local backend instance are already running
.PHONY: status
status: status-nginx | require-local

.PHONE: test
test: test-backend | require-local

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
	mkdir -p $(BUILD_DIR)/web
	cp -r web/images web/stylesheets web/javascripts web/fonts $(BUILD_DIR)/web

.PHONY: start-nginx
start-nginx: | require-local
	$(MAKE) stop-nginx
	echo "Starting nginx"
	mkdir -p logs
	nginx -p ./ -c $(BUILD_DIR)/nginx.conf

.PHONY: stop-nginx
stop-nginx: | require-local
	@(nginx -s stop -p $(BUILD_DIR) -c nginx.conf >& /dev/null && echo "nginx stopped") || \
		echo "nginx not running"

.PHONY: reload-nginx
reload-nginx: .should-reload | require-local

.should-reload: nginx.tpl.conf .env.$(ENVIRONMENT) $(wildcard *.pem) | require-local
	@echo "reload nginx";
	nginx -s reload -p ./ -c $(BUILD_DIR)/nginx.conf
	@touch $@

.PHONY: status-nginx
status-nginx: | require-local
	@if [ -f $(BUILD_DIR)/nginx.pid ]; then \
		(ps -p $$(cat $(BUILD_DIR)/nginx.pid) >& /dev/null && echo "nginx running") || echo "nginx not running"; \
	else \
		echo "nginx not running"; \
	fi

.PHONY: certs
dev-certs: | require-local
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

$(BUILD_DIR)/nginx.conf: nginx.tpl.conf .env.$(ENVIRONMENT) mime.types ./load-env.sh
	mkdir -p $(BUILD_DIR)
  # NOTE(sven): We force usage of bash here as on different oses Make uses
  # different shells which don't support a full feature set
	/bin/bash -c \
		"ENVIRONMENT=$(ENVIRONMENT) source ./load-env.sh; ./web/scripts/include.sh $< > $@"

$(BUILD_DIR)/nginx-host.conf: nginx-host.tpl.conf .env.$(ENVIRONMENT) ./load-env.sh
	mkdir -p $(BUILD_DIR)
	cp mime.types $(BUILD_DIR)
  # NOTE(sven): We force usage of bash here as on different oses Make uses
  # different shells which don't support a full feature set
	/bin/bash -c \
		"ENVIRONMENT=$(ENVIRONMENT) source ./load-env.sh; ./web/scripts/include.sh $< > $@"

.PHONY: build-frontend
build-frontend: assets $(addprefix $(BUILD_DIR)/,$(wildcard web/*.html)) $(BUILD_DIR)/nginx.conf $(BUILD_DIR)/nginx-host.conf

$(BUILD_DIR)/web/%.html: \
	web/%.html \
	$(wildcard web/templates/*.html) \
	$(wildcard web/components/*.html) \
	$(wildcard web/stylesheets/*.css) \
	$(wildcard web/scripts/*.sh)

	@echo "Building $< to $@"
	@mkdir -p $$(dirname $@)
	./web/scripts/include.sh $< > $@ || (rm $@ && exit 1)

.PHONY: watch-frontend
watch-frontend: | require-local
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
install-backend: $(BUILD_DIR)/install.log
$(BUILD_DIR)/install.log: server/setup.py
	mkdir -p $(BUILD_DIR)
ifeq ($(ENVIRONMENT),current-deployment)
	@echo "Installing backend"
	pip install './server' | tee $(BUILD_DIR)/install.log
else
	@echo "Installing backend for development"
	pip install -e 'server[dev]' | tee $(BUILD_DIR)/install.log
endif

.PHONY: watch-backend
watch-backend: install-backend | require-local
	@echo "Starting to watch for backend changes."
	@echo "Edit files and:"
	@echo "  - the backend will reload"
	@echo "... if required."

	source ./load-env.sh .env.$(ENVIRONMENT) && \
	joshinkand-dev

.PHONY: test-backend
test-backend: install-backend | require-local
	cd "server" && pytest -x --ff -v

#
# Deployment
#

# -tt: Force pseudo-terminal allocation. This can be used to execute arbitrary
# -screen-based programs on a remote machine.
run_remote = ssh -tt ubuntu@$(DOMAIN) $1

print-env:
	@echo;
	@echo "Using environment ${ENVIRONMENT}";
	@echo "Domain: $(DOMAIN)";
	@echo;

# Solution: https://stackoverflow.com/a/47839479/3154357
request-confirmation: print-env
	@echo "Do you want to continue? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo


.PHONY: ssh
ssh:
	ssh ubuntu@$(DOMAIN)

.PHONY: upload
upload: | request-confirmation
	./zip-pack.sh joshinkan.zip $(ENVIRONMENT)
	scp joshinkan.zip zip-unpack.sh ubuntu@$(DOMAIN):~/
	$(call run_remote, "./zip-unpack.sh joshinkan.zip")

.PHONY: bootstrap
bootstrap: | request-confirmation
	$(call run_remote, "cd joshinkan && ./bootstrap.sh")

# gcloud app deploy --quiet
.PHONY: deploy
deploy: | request-confirmation
	$(call run_remote, "cd joshinkan && ./deploy.sh")

.PHONY: log
log:
	$(call run_remote, "systemctl status nginx joshinkan")

.PHONY: log-nginx
log-nginx:
	$(call run_remote, "journalctl -xeu nginx")

.PHONY: log-server
log-server:
	$(call run_remote, "journalctl -xeu joshinkan")
