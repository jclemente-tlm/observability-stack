# Makefile (mejorado) -----------------------------------------------------

.PHONY: help start start-prod start-minimal stop restart redeploy \
	clean-volumes build build-and-push ps logs shell status deps \
	clean-dangling-images tests-up tests-down

# Comandos y rutas
DOCKER_COMPOSE_CMD ?= docker compose
CENTRAL_DIR := central
AGENT_DIR := agent
TESTS_DIR := tests

# Opcional: nombre de proyecto para evitar colisiones (ej: OBSERVABILITY)
COMPOSE_PROJECT_NAME ?=

# Compose files usados desde cada carpeta (relativos a la carpeta)
FILES := -f docker-compose.yml
FILES_PROD := -f docker-compose.prod.yml
FILES_TEST := -f docker-compose-tests.yml

# Helper para ejecutar docker-compose dentro de una carpeta
define dc
	@if [ -n "$(COMPOSE_PROJECT_NAME)" ]; then \
		export COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME); \
	fi; \
	cd $(1) && $(DOCKER_COMPOSE_CMD) $(2)
endef

help:
	@printf "Uso:\n\n"
	@printf "  make start               Inicia central (dev)\n"
	@printf "  make start-prod          Inicia central con overrides de prod\n"
	@printf "  make start-minimal       Inicia central minimal (usa docker-compose.minimal.yml)\n"
	@printf "  make stop                Para y elimina contenedores (central + tests)\n"
	@printf "  make ps                  Muestra contenedores (central)\n"
	@printf "  make logs SERVICE=name   Sigue logs\n"
	@printf "  make shell SERVICE=name  Abre shell en servicio\n"
	@printf "  make build               Construye imágenes (central)\n"
	@printf "  make build-and-push      Build y push\n"
	@printf "  make tests-up            Ejecuta compose de tests\n"
	@printf "  make clean-volumes       Elimina volúmenes locales de demo\n"
	@printf "  make deps                Verifica dependencias\n"

# Dependencias
deps:
	@command -v docker >/dev/null 2>&1 || { echo "Falta docker"; exit 1; }
	@echo "Dependencias OK"

# Central (dev)
start:
	@echo "Starting central (dev) from $(CENTRAL_DIR)/"
	$(call dc,$(CENTRAL_DIR),$(FILES) up --force-recreate --remove-orphans --detach)
	@echo "Contenedores iniciados."

# Central (prod overrides)
start-prod:
	@echo "Starting central (prod) from $(CENTRAL_DIR)/"
	$(call dc,$(CENTRAL_DIR),$(FILES) $(FILES_PROD) up --force-recreate --remove-orphans --detach)
	@echo "Contenedores iniciados (prod overrides)."

start-minimal:
	@echo "Starting central (minimal) from $(CENTRAL_DIR)/"
	$(call dc,$(CENTRAL_DIR),-f docker-compose.minimal.yml up --force-recreate --remove-orphans --detach)
	@echo "Contenedores iniciados en modo minimal."

stop:
	@echo "Stopping central and tests..."
	$(call dc,$(CENTRAL_DIR),$(FILES) down --remove-orphans --volumes)
	$(call dc,$(TESTS_DIR),$(FILES_TEST) down --remove-orphans --volumes)
	@echo "Contenedores detenidos."

ps:
	$(call dc,$(CENTRAL_DIR),$(FILES) ps)

# Logs & shell (requieren SERVICE)
logs:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; exit 1; \
	fi; \
	$(call dc,$(CENTRAL_DIR),$(FILES) logs -f $(SERVICE))

shell:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; exit 1; \
	fi; \
	SHELL_CMD=$(if [ -z "$(SHELL)" ]; then echo "/bin/bash"; else echo "$(SHELL)"; fi); \
	$(call dc,$(CENTRAL_DIR),$(FILES) exec $(SERVICE) $$SHELL_CMD)

status:
	$(call dc,$(CENTRAL_DIR),$(FILES) ps)

# Build
build:
	@echo "Building images (central)..."
	$(call dc,$(CENTRAL_DIR),$(FILES) build)

build-and-push:
	@echo "Building and pushing images (central)..."
	$(call dc,$(CENTRAL_DIR),$(FILES) build --push)

# Redeploy single service
redeploy:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; exit 1; \
	fi; \
	$(call dc,$(CENTRAL_DIR),$(FILES) build $(SERVICE)); \
	$(call dc,$(CENTRAL_DIR),$(FILES) stop $(SERVICE)); \
	$(call dc,$(CENTRAL_DIR),$(FILES) rm --force $(SERVICE)); \
	$(call dc,$(CENTRAL_DIR),$(FILES) up -d --no-deps --force-recreate $(SERVICE))

# Tests
tests-up:
	@echo "Starting tests compose..."
	$(call dc,$(TESTS_DIR),$(FILES_TEST) up --build --abort-on-container-exit)

tests-down:
	@echo "Stopping tests compose..."
	$(call dc,$(TESTS_DIR),$(FILES_TEST) down --remove-orphans --volumes)

# Utilities
clean-volumes:
	@docker volume rm grafana_data loki_data mimir_data || true

clean-dangling-images:
	@docker image prune -f

# fin --------------------------------------------------------------------
