.PHONY: help build build-and-push \
	clean-images run-tests run-tracetesting clean \
	start start-minimal stop restart redeploy deps status clean-volumes \
	logs shell clean-dangling-images
#######################################################################
#######################################################################

DOCKER_COMPOSE_CMD ?= docker compose
DOCKER_COMPOSE_ENV=--env-file central/.env --env-file central/.env.override
DOCKER_COMPOSE_BUILD_ARGS=
FILES ?= -f ./central/docker-compose.yml
FILES_TEST ?= -f ./tests/docker-compose-tests.yml

# Agrupación de todos los targets .PHONY
#######################################################################

help:
	@printf "Uso:\n\n"
	@printf "  make start        Inicia los contenedores (detached)\n"
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

logs:
	if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; \
		exit 1; \
	fi; \
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) logs -f $(SERVICE)

shell:
	if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; \
		exit 1; \
	fi; \
	SHELL_CMD=$(if [ -z "$(SHELL)" ]; then echo "/bin/bash"; else echo "$(SHELL)"; fi); \
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) exec $(SERVICE) $$SHELL_CMD

clean-dangling-images:
	@docker image prune -f

deps:
	@command -v docker >/dev/null 2>&1 || { echo "Falta docker"; exit 1; }
	@echo "Dependencias OK"

status:
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) ps

clean-volumes:
	@docker volume rm grafana_data loki_data mimir_data || true

build:
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) build $(DOCKER_COMPOSE_BUILD_ARGS)
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) build $(DOCKER_COMPOSE_BUILD_ARGS)

build-and-push:
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) build $(DOCKER_COMPOSE_BUILD_ARGS) --push
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) build $(DOCKER_COMPOSE_BUILD_ARGS) --push

clean-images:
	@docker rmi $(shell docker images --filter=reference="ghcr.io/open-telemetry/demo:latest-*" -q); \
    if [ $$? -ne 0 ]; \
    then \
    	echo; \
        echo "Error al eliminar una o más imágenes de contenedores."; \
        echo "Verifica que los contenedores no esten ejecutandose con: make stop"; \
        false; \
    fi

run-tests:
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES_TEST) run frontendTests
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES_TEST) run traceBasedTests

run-tracetesting:
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES_TEST) run traceBasedTests ${SERVICES_TO_TEST}

clean:
	rm -rf ./src/{checkout,product-catalog}/genproto/oteldemo/
	rm -rf ./src/recommendation/{demo_pb2,demo_pb2_grpc}.py
	rm -rf ./src/frontend/protos/demo.ts

start:
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) up --force-recreate --remove-orphans --detach
	@echo ""
	@echo "Contenedores iniciados."

start-minimal:
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) -f docker-compose.minimal.yml up --force-recreate --remove-orphans --detach
	@echo ""
	@echo "Contenedores iniciados en modo minimal."

stop:
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) down --remove-orphans --volumes
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES_TEST) down --remove-orphans --volumes
	@echo ""
	@echo "Contenedores detenidos."

restart:
	@set -e
	if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; \
		exit 1; \
	fi; \
	if [ -n "$(SERVICE)" ]; then \
		$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) stop $(SERVICE); \
		$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) rm --force $(SERVICE); \
		$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) create $(SERVICE); \
		$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) start $(SERVICE); \
	else \
		$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) down --remove-orphans; \
		$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) up --force-recreate --remove-orphans --detach; \
	fi

redeploy:
	@set -e
	if [ -z "$(SERVICE)" ]; then \
		echo "Por favor indica SERVICE=[nombre]"; \
		exit 1; \
	fi; \
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) build $(DOCKER_COMPOSE_BUILD_ARGS) $(SERVICE); \
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) stop $(SERVICE); \
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) rm --force $(SERVICE); \
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) create $(SERVICE); \
	$(DOCKER_COMPOSE_CMD) $(DOCKER_COMPOSE_ENV) $(FILES) start $(SERVICE);
