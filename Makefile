.PHONY: help build build-and-push \
	clean-images tests-run clean \
	start start-prod start-minimal stop restart redeploy deps status clean-volumes \
	logs shell clean-dangling-images
#######################################################################
#######################################################################

# Comandos y rutas
DOCKER_COMPOSE_CMD ?= docker compose
GATEWAY_DIR := gateway
AGENT_DIR := agent
TESTS_DIR := tests

# Opcional: nombre de proyecto para evitar colisiones (ej: OBSERVABILITY)
COMPOSE_PROJECT_NAME ?=

# Compose files usados desde cada carpeta (relativos a la carpeta)
GATEWAY_FILES := -f docker-compose.yml
GATEWAY_FILES_PROD := -f docker-compose.yml -f docker-compose.prod.yml
GATEWAY_FILES_TEST := -f docker-compose-tests.yml

AGENT_FILES := -f docker-compose.yml
AGENT_FILES_PROD := -f docker-compose.yml -f docker-compose.prod.yml
AGENT_FILES_TEST := -f docker-compose-tests.yml

# Agrupación de todos los targets .PHONY
#######################################################################

help:
	@printf "Uso:\n\n"
	@printf "  make start        Inicia los contenedores (detached)\n"
	@printf "  make start-prod   Inicia los contenedores (PROD)\n"
	@printf "  make down         Para y elimina los contenedores\n"
	@printf "  make logs         Muestra logs de un servicio: SERVICE=nombre\n"
	@printf "  make ps           Lista contenedores\n"
	@printf "  make restart      Reinicia (down -> start o solo servicio)\n"
	@printf "  make redeploy     Reconstruye y reinicia servicio\n"
	@printf "  make exec         Ejecuta comando en un servicio en ejecución: SERVICE=name CMD='comando'\n"
	@printf "  make shell        Abre shell en un servicio: SERVICE=name SHELL=/bin/bash\n"
	@printf "  make build        Construye imágenes\n"
	@printf "  make status       Muestra servicios activos\n"
	@printf "  make clean-volumes Elimina volúmenes de docker usados por la demo\n"
	@printf "  make clean-dangling-images Elimina imágenes dangling de docker\n"
	@printf "  make deps         Verifica dependencias necesarias (docker, buildx)\n\n"
	@printf "Variables de entorno:\n  SERVICE - nombre del servicio para logs, shell, restart, redeploy\n"

# Dependencias
deps:
	@command -v docker >/dev/null 2>&1 || { echo "Falta docker"; exit 1; }
	@echo "Dependencias OK"

start:
	cd $(GATEWAY_DIR) && \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) up --force-recreate --remove-orphans --detach
	@echo ""
	@echo "Contenedores iniciados."

start-prod:
	cd $(GATEWAY_DIR) && \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES_PROD) up --force-recreate --remove-orphans --detach
	@echo ""
	@echo "Contenedores iniciados."

start-minimal:
	cd $(GATEWAY_DIR) && \
	$(DOCKER_COMPOSE_CMD) -f docker-compose.minimal.yml up --force-recreate --remove-orphans --detach
	@echo ""
	@echo "Contenedores iniciados en modo minimal."

stop:
	cd $(GATEWAY_DIR) && \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) down --remove-orphans --volumes 
	cd $(GATEWAY_DIR) && \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES_PROD) down --remove-orphans --volumes
	cd $(TESTS_DIR) && \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES_TEST) down --remove-orphans --volumes
	@echo ""
	@echo "Contenedores detenidos."

status:
	cd $(GATEWAY_DIR) && \
	$(DOCKER_COMPOSE_CMD) ps

# Logs & shell (requieren SERVICE)
logs:
	if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; \
		exit 1; \
	fi; \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) logs -f $(SERVICE)

shell:
	if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; \
		exit 1; \
	fi; \
	SHELL_CMD=$(if [ -z "$(SHELL)" ]; then echo "/bin/bash"; else echo "$(SHELL)"; fi); \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) exec $(SERVICE) $$SHELL_CMD

# Build
build:
	cd $(GATEWAY_DIR) && \
	$(DOCKER_COMPOSE_CMD) build $(DOCKER_COMPOSE_BUILD_ARGS)
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) build $(DOCKER_COMPOSE_BUILD_ARGS)

build-and-push:
	cd $(GATEWAY_DIR) && \
	$(DOCKER_COMPOSE_CMD) build $(DOCKER_COMPOSE_BUILD_ARGS) --push
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) build $(DOCKER_COMPOSE_BUILD_ARGS) --push

# Redeploy single service
redeploy:
	@set -e
	if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; \
		exit 1; \
	fi; \
	cd $(GATEWAY_DIR) && \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) build $(DOCKER_COMPOSE_BUILD_ARGS) $(SERVICE); \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) stop $(SERVICE); \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) rm --force $(SERVICE); \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) create $(SERVICE); \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) start $(SERVICE);

restart:
	@set -e
	if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; \
		exit 1; \
	fi; \
	cd $(GATEWAY_DIR) && \
	if [ -n "$(SERVICE)" ]; then \
		$(DOCKER_COMPOSE_CMD) stop $(SERVICE); \
		$(DOCKER_COMPOSE_CMD) rm --force $(SERVICE); \
		$(DOCKER_COMPOSE_CMD) create $(SERVICE); \
		$(DOCKER_COMPOSE_CMD) start $(SERVICE); \
	else \
		$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) down --remove-orphans; \
		$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES) up --force-recreate --remove-orphans --detach; \
	fi

# Tests
tests-run:
	cd $(TESTS_DIR) && \
	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES_TEST) run trace-testing
# 	$(DOCKER_COMPOSE_CMD) $(GATEWAY_FILES_TEST) run order-tests

# Utilities
clean-dangling-images:
	@docker image prune -f

clean-volumes:
	@docker volume rm grafana_data loki_data mimir_data || true

clean-images:
	@docker rmi $(shell docker images --filter=reference="ghcr.io/open-telemetry/demo:latest-*" -q); \
    if [ $$? -ne 0 ]; \
    then \
    	echo; \
        echo "Error al eliminar una o más imágenes de contenedores."; \
        echo "Verifica que los contenedores no esten ejecutandose con: make stop"; \
        false; \
    fi

clean:
	rm -rf ./src/{checkout,product-catalog}/genproto/oteldemo/
	rm -rf ./src/recommendation/{demo_pb2,demo_pb2_grpc}.py
	rm -rf ./src/frontend/protos/demo.ts








