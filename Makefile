.PHONY: all
all: watch

SYSTEM_NAME = $(shell uname -s)

ifneq (,$(wildcard .env))
	include .env
endif

ifndef SMTP_EMAIL
$(error Variable SMTP_EMAIL is not set. Check .env or define environment variable)
endif
ifndef SMTP_PASSWORD
$(error Variable SMTP_PASSWORD is not set. Check .env or define environment variable)
endif
ifndef DOMAIN
$(error Variable DOMAIN is not set. Check .env or define environment variable)
endif


#
# General
#

.PHONY: clean
clean:
	swift package clean --package-path server
	rm -rf ./build

.PHONY: build
build: build-frontend build-backend

.PHONY: watch
watch:
	@if [ "$$($(MAKE) status-backend)" = "backend not running" ]; then \
		$(MAKE) start-backend --silent; \
	fi
	@if [ "$$($(MAKE) status-nginx)" = "nginx not running" ]; then \
		$(MAKE) start-nginx --silent; \
	fi

	@echo "Starting to watch for frontend and backend changes."
	@echo "Edit files and:"
	@echo "  - the frontend will rebuild"
	@echo "  - the backend will rebuild"
	@echo "  - the nginx config will reload"
	@echo "  - the backend fcgi server will restart"
	@echo "... if required."

	@while true; do \
		$(MAKE) build-backend --question || \
			$(MAKE) start-backend --silent || \
			$(MAKE) start-backend --touch; \
		$(MAKE) build-frontend --silent; \
		$(MAKE) reload-nginx --silent; \
		sleep 1; \
	done

.PHONY: start
start: build start-backend start-nginx

.PHONY: stop
stop: stop-backend stop-nginx

# Shows whether a local frontend/ backend instance are already running
.PHONY: status
status: status-backend status-nginx

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
.PHONY: frontend-dependencies
frontend-dependencies:
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
	nginx -p ./ -c nginx.conf

.PHONY: stop-nginx
stop-nginx:
	@(nginx -s stop -p ./ -c nginx.conf >& /dev/null && echo "nginx stopped") || \
		echo "nginx not running"

.PHONY: reload-nginx
reload-nginx: .should-reload

.should-reload: nginx.conf $(wildcard *.pem)
	@echo "reload nginx";
	nginx -s reload -p ./ -c nginx.conf
	@touch $@

.PHONY: status-nginx
status-nginx:
	@if [ -f nginx.pid ]; then \
		(ps -p $$(cat nginx.pid) >& /dev/null && echo "nginx running") || echo "nginx not running"; \
	else \
		echo "nginx not running"; \
	fi

.PHONY: logs-error
logs-error:
	tail -f logs/error.log

.PHONY: logs-access
logs-access:
	tail -f logs/access.log

.PHONY: build-frontend
build-frontend: assets $(subst web,build/web,$(wildcard web/*.html))

build/web/%.html: web/%.html $(wildcard web/templates/*.html) $(wildcard web/components/*.html) $(wildcard web/stylesheets/*.css)
	$(MAKE) frontend-dependencies
	@echo "Building $< to $@"
	@mkdir -p $$(dirname $@)
	./web/scripts/include.sh $< > $@ || (rm $@ && exit 1)

#
# Backend
#

.PHONY: test-backend
test-backend:
	cd server && USE_LINEBREAK=1 swift test

.PHONY: build-backend
build-backend: build/server/server


ifdef SMTP_CC
SMTP_CC_CMD=$(addprefix --cc ,$(SMTP_CC))
endif
ifdef SMTP_BCC
SMTP_BCC_CMD=$(addprefix --bcc ,$(SMTP_BCC))
endif
ifdef SMTP_REPLY_TO
SMTP_REPLY_TO_CMD=--reply-to $(SMTP_REPLY_TO)
endif

.PHONY: start-backend
start-backend: build/server/server
	$(MAKE) stop-backend
	echo "Starting backend"
	spawn-fcgi \
    -d build/server \
    -p 5000 \
    -P fcgi.pid \
    -- server \
      --email $(SMTP_EMAIL) \
      --password $(SMTP_PASSWORD) \
			$(SMTP_CC_CMD) \
      $(SMTP_BCC_CMD) \
			$(SMTP_REPLY_TO_CMD) \
      --domain $(DOMAIN)

.PHONY: stop-backend
stop-backend:
	@if [ -f fcgi.pid ] && [ -n "$$(cat fcgi.pid)" ] ; then \
		(kill $$(cat fcgi.pid) || echo "no such process") && \
		rm fcgi.pid && \
		echo "backend stopped"; \
	else \
		echo "backend not running"; \
	fi

.PHONY: status-backend
status-backend:
	@if [ -f fcgi.pid ]; then \
		(ps -p $$(cat fcgi.pid) >& /dev/null && echo "backend running") || echo "backend not running"; \
	else \
		echo "backend not running"; \
	fi

# NOTE(sven): Install fcgi and spawn-fcgi to support the nginx connection to the
# backend.
.PHONY: backend-dependencies
backend-dependencies:
ifeq ($(SYSTEM_NAME), Darwin)
	@if [ ! -d $$(brew --prefix fcgi) ]; then \
    brew install fcgi; \
	fi
	@if [ ! -d $$(brew --prefix spawn-fcgi) ]; then \
    brew install spawn-fcgi; \
	fi
else
  echo "Deps only installed for OSX" && exit 1
endif

SWIFT_FILES_CMD = find server -type f -not -path "*.build*" "(" -name "*.swift" -or -name "*.modulemap" -or -name "*.h" -or -name "*Package.resolved" ")"
SWIFT_FILES = $(shell $(SWIFT_FILES_CMD))
.PHONY: debug-build-dependencies
debug-build-dependencies:
	$(SWIFT_FILES_CMD)
	@echo
	@echo $(SWIFT_FILES)

build/server/server: $(SWIFT_FILES)
	@echo $^
	$(MAKE) backend-dependencies
	mkdir -p build/server
	swift build --package-path server
	cp $$(swift build --package-path server --show-bin-path)/Joshinkan ./build/server/server

#
# Deployment
#

.PHONY: deploy
deploy:
	gcloud app deploy --quiet
