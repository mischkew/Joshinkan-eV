.PHONY: all assets build sed start stop reload logs-error logs-access
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

build: assets $(subst src,build,$(wildcard src/*.html))

assets:
	mkdir -p build
	cp -r src/images src/stylesheets src/javascripts src/fonts build/


clean:
	rm -rf ./build

watch:
	while true; do $(MAKE) --silent; sleep 1; done


build/%.html: src/%.html $(wildcard src/templates/*.html) | sed
	@echo "Building $< to $@"
	@mkdir -p $$(dirname $@)
	./src/scripts/include.sh $< > $@ || (rm $@ && exit 1)


start: build
	mkdir -p logs
	nginx -p ./ -c nginx.conf

stop:
	nginx -s stop

reload: build
	nginx -s reload

logs-error:
	tail -f logs/error.log

logs-access:
	tail -f logs/access.log

deploy:
	gcloud app deploy --quiet
