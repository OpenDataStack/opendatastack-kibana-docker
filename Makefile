SHELL=/bin/bash
ELASTIC_REGISTRY ?= ''

export PATH := ./bin:./venv/bin:$(PATH)

# Determine the version to build. Override by setting ELASTIC_VERSION env var.
ELASTIC_VERSION := $(shell ./bin/elastic-version)

ifdef STAGING_BUILD_NUM
  VERSION_TAG=$(ELASTIC_VERSION)-${STAGING_BUILD_NUM}
else
  VERSION_TAG=$(ELASTIC_VERSION)
endif

PYTHON ?= $(shell command -v python3.5 || command -v python3.6)

# Build different images tagged as :version-<flavor>
IMAGE_FLAVORS ?= opendatastack

# Which image flavor will additionally receive the plain `:version` tag
DEFAULT_IMAGE_FLAVOR ?= opendatastack

IMAGE_TAG ?= $(ELASTIC_REGISTRY)opendatastack/kibana

FIGLET := pyfiglet -w 160 -f puffy

all: build test

test: lint docker-compose
	$(foreach FLAVOR, $(IMAGE_FLAVORS), \
	  $(FIGLET) "test: $(FLAVOR)"; \
	  ./bin/pytest tests --image-flavor=$(FLAVOR); \
	)

lint: venv
	  flake8 tests

build: dockerfile
	docker pull centos:7
	$(foreach FLAVOR, $(IMAGE_FLAVORS), \
	  $(FIGLET) "build: $(FLAVOR)"; \
	  docker build --no-cache -t $(IMAGE_TAG)-$(FLAVOR):$(VERSION_TAG) \
	    -f build/kibana/Dockerfile-$(FLAVOR) build/kibana; \
	  if [[ $(FLAVOR) == $(DEFAULT_IMAGE_FLAVOR) ]]; then \
	    docker tag $(IMAGE_TAG)-$(FLAVOR):$(VERSION_TAG) $(IMAGE_TAG):$(VERSION_TAG); \
	  fi; \
	)

# Push the image to the dedicated push endpoint at "push.docker.elastic.co"
push: test
	$(foreach FLAVOR, $(IMAGE_FLAVORS), \
	  docker push $(IMAGE_TAG)-$(FLAVOR):$(VERSION_TAG); \
	  docker rmi $(IMAGE_TAG)-$(FLAVOR):$(VERSION_TAG); \
	)
	# Also push the default version, with no suffix like '-oss' or '-x-pack'
	docker push $(IMAGE_TAG):$(VERSION_TAG);
	docker rmi $(IMAGE_TAG):$(VERSION_TAG);

clean-test:
	$(TEST_COMPOSE) down
	$(TEST_COMPOSE) rm --force

venv: requirements.txt
	test -d venv || virtualenv --python=$(PYTHON) venv
	pip install -r requirements.txt
	touch venv

# Generate the Dockerfiles from Jinja2 templates.
dockerfile: venv templates/Dockerfile.j2
	$(foreach FLAVOR, $(IMAGE_FLAVORS), \
	  jinja2 \
	    -D image_flavor='$(FLAVOR)' \
	    -D elastic_version='$(ELASTIC_VERSION)' \
	    templates/Dockerfile.j2 > build/kibana/Dockerfile-$(FLAVOR); \
	)

# Generate docker-compose files from Jinja2 templates.
docker-compose: venv
	$(foreach FLAVOR, $(IMAGE_FLAVORS), \
	  jinja2 \
	    -D version_tag='$(VERSION_TAG)' \
	    -D image_flavor='$(FLAVOR)' \
	   templates/docker-compose.yml.j2 > docker-compose-$(FLAVOR).yml; \
	)
	ln -sf docker-compose-$(DEFAULT_IMAGE_FLAVOR).yml docker-compose.yml

.PHONY: build clean flake8 push pytest test dockerfile docker-compose
