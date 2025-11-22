.PHONY: start down restart logs shell build status stop test clean-images help detect-gateway

DOCKER_COMPOSE ?= docker compose

# Detectar IP del gateway de Docker
DOCKER_GATEWAY := $(shell bash scripts/get-docker-gateway.sh)

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
	@echo "  start         - start stack"
	@echo "  down          - stop stack (NO volumes removed)"
	@echo "  stop          - stop + remove volumes"
	@echo "  restart       - restart a service or full stack"
	@echo "  logs          - logs for SERVICE="
	@echo "  shell         - exec into container"
	@echo "  status        - compose ps"
	@echo "  build         - build images"
	@echo "  detect-gateway- show detected Docker gateway IP"
	@echo ""

detect-gateway:
	@echo "Detected Docker Gateway IP: $(DOCKER_GATEWAY)"
	@echo "This IP will be used for cross-network communication."

start: detect-gateway
	@echo "Using Docker Gateway IP: $(DOCKER_GATEWAY)"
	@cd $(BASE_DIR) && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) up -d --remove-orphans

down:
	@cd $(BASE_DIR) && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) down --remove-orphans

stop:
	@cd $(BASE_DIR) && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) down --remove-orphans --volumes

restart: detect-gateway
ifeq ($(SERVICE),)
	@echo "Using Docker Gateway IP: $(DOCKER_GATEWAY)"
	@cd $(BASE_DIR) && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) down && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) up -d
else
	@cd $(BASE_DIR) && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) restart $(SERVICE)
endif

test: detect-gateway
	@echo "Using Docker Gateway IP: $(DOCKER_GATEWAY)"
	@cd tests && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) -f docker-compose.tests.yml $(ENV_FILE) run --rm orders-testing

logs:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Provide SERVICE=name"; exit 1; fi
	@cd $(BASE_DIR) && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) logs -f $(SERVICE)

shell:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Provide SERVICE=name"; exit 1; fi
	@cd $(BASE_DIR) && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) $(COMPOSE_FILES) $(ENV_FILE) exec $(SERVICE) /bin/sh

status:
	@cd $(BASE_DIR) && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) ps

build: detect-gateway
	@echo "Using Docker Gateway IP: $(DOCKER_GATEWAY)"
	@cd $(BASE_DIR) && \
	DOCKER_GATEWAY_IP=$(DOCKER_GATEWAY) $(DOCKER_COMPOSE) $(COMPOSE_FILES) build


clean-images:
	@docker rmi $(shell docker images --filter=reference="observability*" -q);
