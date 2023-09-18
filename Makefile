.PHONY: all assets build sed start stop reload logs-error logs-access server server-deps start-server stop-server
all: build

# GNU sed is required for shell substitution. Use brew to install it on OSX if
# it is not present.
SYSTEM_NAME = $(shell uname -s)
GSED_PATH = $(shell which gsed)

# NOTE(sven): Install gnu-sed on OSX as otherwise shell command substitution is
# not supported, which we need for templating.
sed:
ifeq ($(SYSTEM_NAME), Darwin)
ifeq (,$(GSED_PATH))
	brew install gnu-sed
endif
endif

# NOTE(sven): Install fcgi and spawn-fcgi to support the nginx connection to the
# backend.
server-deps:
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

build: assets $(subst web,build/web,$(wildcard web/*.html)) build/server/server

assets:
	mkdir -p build/web
	cp -r web/images web/stylesheets web/javascripts web/fonts build/web

SWIFT_FILES = $(shell find server -type f -not -path "*.build*" "(" -name "*.swift" -or -name "*.modulemap" -or -name "*.h" ")")
build/server/server: $(SWIFT_FILES)
	echo $^
	$(MAKE) server-deps
	mkdir -p build/server
	swift build --package-path server
	cp $$(swift build --package-path server --show-bin-path)/server ./build/server/server

clean:
	rm -rf ./build

watch:
	while true; do \
		$(MAKE) build/server/server --question || \
			$(MAKE) start-server --silent || \
			$(MAKE) start-server --touch; \
		$(MAKE) build --silent; \
		$(MAKE) reload --silent; \
		sleep 1; \
	done


build/web/%.html: web/%.html $(wildcard web/templates/*.html) $(wildcard web/components/*.html) | sed
	@echo "Building $< to $@"
	@mkdir -p $$(dirname $@)
	./web/scripts/include.sh $< > $@ || (rm $@ && exit 1)

start-server: build/server/server
	$(MAKE) stop-server
	spawn-fcgi \
    -d build/server \
    -p 5000 \
    -P fcgi.pid \
    -- server

stop-server:
	@if [ -f fcgi.pid ] && [ -n "$$(cat fcgi.pid)" ] ; then \
		(kill $$(cat fcgi.pid) || echo "no such process") && \
		rm fcgi.pid && \
		echo "server stopped"; \
	else \
		echo "server not running"; \
	fi

start: build start-server
	mkdir -p logs
	nginx -p ./ -c nginx.conf

stop: stop-server
	@(nginx -s stop >& /dev/null && echo "nginx stopped") || echo "nginx not running"

reload: nginx.conf
	nginx -s reload -p ./ -c nginx.conf

logs-error:
	tail -f logs/error.log

logs-access:
	tail -f logs/access.log

deploy:
	gcloud app deploy --quiet
