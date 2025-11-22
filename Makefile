.PHONY: start down restart logs shell build status stop test clean-images help

DOCKER_COMPOSE ?= docker compose

# Carpetas
TARGET ?= gateway
BASE_DIR := $(TARGET)

# Environments
ENV ?= local

# Compose files per env
ifeq ($(ENV),local)
  COMPOSE_FILES := -f docker-compose.yml
  ENV_FILE := --env-file .env
endif

ifeq ($(ENV),nonprod)
  COMPOSE_FILES := -f docker-compose.yml -f docker-compose.nonprod.yml
  ENV_FILE := --env-file .env.nonprod
endif

ifeq ($(ENV),prod)
  COMPOSE_FILES := -f docker-compose.yml -f docker-compose.prod.yml
  ENV_FILE := --env-file .env.prod
endif

help:
	@echo ""
	@echo "Usage:"
	@echo "  make start TARGET=gateway ENV=nonprod"
	@echo "  make down TARGET=agent ENV=prod"
	@echo "  make restart SERVICE=name TARGET=gateway ENV=local"
	@echo ""
	@echo "Targets:"
	@echo "  start       - start stack"
	@echo "  down        - stop stack (NO volumes removed)"
	@echo "  stop        - stop + remove volumes"
	@echo "  restart     - restart a service or full stack"
	@echo "  logs        - logs for SERVICE="
	@echo "  shell       - exec into container"
	@echo "  status      - compose ps"
	@echo "  build       - build images"
	@echo ""

start:
	cd $(BASE_DIR) && \
	$(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) up -d --remove-orphans

down:
	cd $(BASE_DIR) && \
	$(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) down --remove-orphans

stop:
	cd $(BASE_DIR) && \
	$(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) down --remove-orphans --volumes

restart:
ifeq ($(SERVICE),)
	cd $(BASE_DIR) && \
	$(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) down && \
	$(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) up -d
else
	cd $(BASE_DIR) && \
	$(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) restart $(SERVICE)
endif

test:
	cd tests && \
	$(DOCKER_COMPOSE) -f docker-compose.tests.yml $(ENV_FILE) run  --build --rm orders-testing

logs:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Provide SERVICE=name"; exit 1; fi
	cd $(BASE_DIR) && \
	$(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) logs -f $(SERVICE)

shell:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Provide SERVICE=name"; exit 1; fi
	cd $(BASE_DIR) && \
	$(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) exec $(SERVICE) /bin/sh

status:
	cd $(BASE_DIR) && \
	$(DOCKER_COMPOSE) ps

build:
	cd $(BASE_DIR) && \
	$(DOCKER_COMPOSE) $(COMPOSE_FILES) build


clean-images:
	@docker rmi $(shell docker images --filter=reference="observability*" -q);
