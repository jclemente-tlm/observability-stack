.PHONY: start down restart logs shell build status stop test clean-images help detect-gateway \
        start-gateway start-agent stop-gateway stop-agent logs-gateway logs-agent \
        test-keycloak get-token test-auth-service test-envoy keycloak-ui grafana-ui \
        health check-tenants

DOCKER_COMPOSE ?= docker compose

# Detectar IP del gateway de Docker
DOCKER_GATEWAY := $(shell bash scripts/get-docker-gateway.sh 2>/dev/null || echo "172.17.0.1")

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
	@echo "🚀 Observability Stack - Multi-Tenant"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════"
	@echo "  Quick Start Commands"
	@echo "═══════════════════════════════════════════════════════════"
	@echo ""
	@echo "  make start-gateway       Iniciar gateway (Grafana, Keycloak, Envoy, etc)"
	@echo "  make start-agent         Iniciar agent"
	@echo "  make stop-gateway        Detener gateway"
	@echo "  make stop-agent          Detener agent"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════"
	@echo "  Keycloak & Authentication"
	@echo "═══════════════════════════════════════════════════════════"
	@echo ""
	@echo "  make keycloak-ui         Abrir Keycloak UI (http://localhost:8090)"
	@echo "  make test-keycloak       Test de conectividad a Keycloak"
	@echo "  make get-token           Obtener JWT token del agent"
	@echo "  make test-auth-service   Test del servicio de autenticación"
	@echo "  make test-envoy          Test del routing de Envoy"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════"
	@echo "  Monitoring & Logs"
	@echo "═══════════════════════════════════════════════════════════"
	@echo ""
	@echo "  make grafana-ui          Abrir Grafana UI (http://localhost:3000)"
	@echo "  make logs-gateway        Ver logs del gateway"
	@echo "  make logs-agent          Ver logs del agent"
	@echo "  make logs SERVICE=<name> Ver logs de un servicio específico"
	@echo "  make health              Verificar health de todos los servicios"
	@echo "  make status              Ver status de contenedores"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════"
	@echo "  Multi-Tenant Testing"
	@echo "═══════════════════════════════════════════════════════════"
	@echo ""
	@echo "  make check-tenants       Verificar aislamiento de tenants"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════"
	@echo "  Advanced Commands"
	@echo "═══════════════════════════════════════════════════════════"
	@echo ""
	@echo "  make start TARGET=<gateway|agent> ENV=<local|nonprod|prod>"
	@echo "  make down TARGET=<gateway|agent>"
	@echo "  make restart SERVICE=<name> TARGET=<gateway|agent>"
	@echo "  make shell SERVICE=<name> TARGET=<gateway|agent>"
	@echo "  make build TARGET=<gateway|agent>"
	@echo "  make detect-gateway      Mostrar IP del Docker gateway"
	@echo ""
	@echo "  stop-gateway        - detiene gateway"
	@echo "  start-gateway-nonprod - inicia gateway (nonprod)"
	@echo "  start-gateway-prod  - inicia gateway (prod)"
	@echo "  start-agent         - inicia agent (local)"
	@echo "  stop-agent          - detiene agent"
	@echo "  start-agent-nonprod - inicia agent (nonprod)"
	@echo "  start-agent-prod    - inicia agent (prod)"
	@echo "  run-test            - ejecuta tests"
	@echo "  stop-test           - detiene tests"
	@echo "  start-all           - inicia gateway + agent"
	@echo "  stop-all            - detiene todo el stack"
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

# ============================================================================
# Alias convenientes para targets y entornos comunes
# ============================================================================

# Gateway
.PHONY: start-gateway stop-gateway start-gateway-nonprod start-gateway-prod
start-gateway:
	@$(MAKE) start TARGET=gateway ENV=local

stop-gateway:
	@$(MAKE) stop TARGET=gateway ENV=local

start-gateway-nonprod:
	@$(MAKE) start TARGET=gateway ENV=nonprod

start-gateway-prod:
	@$(MAKE) start TARGET=gateway ENV=prod

# Agent
.PHONY: start-agent stop-agent start-agent-nonprod start-agent-prod
start-agent:
	@$(MAKE) start TARGET=agent ENV=local

stop-agent:
	@$(MAKE) stop TARGET=agent ENV=local

start-agent-nonprod:
	@$(MAKE) start TARGET=agent ENV=nonprod

start-agent-prod:
	@$(MAKE) start TARGET=agent ENV=prod

# ============================================================================
# Keycloak & Authentication
# ============================================================================

.PHONY: keycloak-ui test-keycloak get-token test-auth-service test-envoy

keycloak-ui:
	@echo "🔐 Abriendo Keycloak UI..."
	@echo "URL: http://localhost:8090"
	@echo "Username: admin"
	@echo "Password: admin"
	@echo ""
	@which xdg-open > /dev/null && xdg-open http://localhost:8090 || \
	 which open > /dev/null && open http://localhost:8090 || \
	 echo "Por favor abre http://localhost:8090 en tu navegador"

test-keycloak:
	@echo "🧪 Testing Keycloak connectivity..."
	@curl -sf http://localhost:8090/health > /dev/null && \
	 echo "✅ Keycloak is healthy" || \
	 echo "❌ Keycloak is not responding"
	@echo ""
	@echo "Testing realm endpoint..."
	@curl -sf http://localhost:8090/realms/observability > /dev/null && \
	 echo "✅ Realm 'observability' exists" || \
	 echo "⚠️  Realm 'observability' not found - please configure it"

show-keycloak-secrets:
	@echo "🔑 Obteniendo client secrets de Keycloak..."
	@echo ""
	@if ! curl -sf http://localhost:8090/health > /dev/null; then \
		echo "❌ Keycloak no está accesible"; \
		exit 1; \
	fi
	@echo "Obteniendo token de administrador..."
	@TOKEN=$$(curl -s -X POST "http://localhost:8090/realms/master/protocol/openid-connect/token" \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-d "username=admin" \
		-d "password=admin" \
		-d "grant_type=password" \
		-d "client_id=admin-cli" | jq -r '.access_token'); \
	if [ "$$TOKEN" = "null" ] || [ -z "$$TOKEN" ]; then \
		echo "❌ No se pudo obtener token de administrador"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "📋 Client Secrets:"; \
	echo ""; \
	for CLIENT_ID in agent-pe agent-mx agent-co; do \
		echo "  🔐 $$CLIENT_ID:"; \
		INTERNAL_ID=$$(curl -s "http://localhost:8090/admin/realms/observability/clients" \
			-H "Authorization: Bearer $$TOKEN" | \
			jq -r ".[] | select(.clientId==\"$$CLIENT_ID\") | .id"); \
		if [ -z "$$INTERNAL_ID" ]; then \
			echo "     ❌ Client no encontrado"; \
			continue; \
		fi; \
		SECRET=$$(curl -s "http://localhost:8090/admin/realms/observability/clients/$$INTERNAL_ID/client-secret" \
			-H "Authorization: Bearer $$TOKEN" | jq -r '.value'); \
		echo "     Secret: $$SECRET"; \
		echo ""; \
	done

get-token:
	@if [ ! -f agent/.env ]; then \
		echo "❌ agent/.env not found"; \
		echo "Please configure agent/.env with Keycloak credentials"; \
		exit 1; \
	fi
	@echo "🔑 Obtaining JWT token..."
	@cd agent && ./get-token.sh

test-auth-service:
	@echo "🧪 Testing auth service..."
	@curl -sf http://localhost:8000/health > /dev/null && \
	 echo "✅ Auth service is healthy" || \
	 echo "❌ Auth service is not responding"
	@echo ""
	@if [ -f /tmp/keycloak-token.txt ]; then \
		echo "Testing JWT validation..."; \
		TOKEN=$$(cat /tmp/keycloak-token.txt); \
		curl -s -X POST http://localhost:8000/authz \
		  -H "Authorization: Bearer $$TOKEN" \
		  -H "Content-Type: application/json" | jq; \
	else \
		echo "⚠️  No token found. Run 'make get-token' first"; \
	fi

test-envoy:
	@echo "🧪 Testing Envoy proxy..."
	@curl -sf http://localhost:9901/ready > /dev/null && \
	 echo "✅ Envoy is ready" || \
	 echo "❌ Envoy is not responding"
	@echo ""
	@echo "Envoy stats (tenant routing):"
	@curl -s http://localhost:9901/stats | grep -i tenant || echo "No tenant stats found"

# ============================================================================
# Monitoring & Logs
# ============================================================================

.PHONY: grafana-ui logs-gateway logs-agent logs-envoy logs-auth health

grafana-ui:
	@echo "📊 Abriendo Grafana UI..."
	@echo "URL: http://localhost:3000"
	@echo "Auto-login enabled"
	@echo ""
	@which xdg-open > /dev/null && xdg-open http://localhost:3000 || \
	 which open > /dev/null && open http://localhost:3000 || \
	 echo "Por favor abre http://localhost:3000 en tu navegador"

logs-gateway:
	@docker logs -f observability-alloy-gateway

logs-agent:
	@docker logs -f observability-agent

logs-envoy:
	@docker logs -f observability-envoy --tail 50

logs-auth:
	@docker logs -f observability-auth-service --tail 50

health:
	@echo "🏥 Checking health of all services..."
	@echo ""
	@echo "Gateway Stack:"
	@docker ps --filter "name=observability-" --format "table {{.Names}}\t{{.Status}}" | grep -v agent || true
	@echo ""
	@echo "Agent Stack:"
	@docker ps --filter "name=observability-agent" --format "table {{.Names}}\t{{.Status}}" || true
	@echo ""
	@echo "Component Health Checks:"
	@echo -n "  Keycloak:      "; curl -sf http://localhost:8090/health > /dev/null && echo "✅" || echo "❌"
	@echo -n "  Auth Service:  "; curl -sf http://localhost:8000/health > /dev/null && echo "✅" || echo "❌"
	@echo -n "  Envoy:         "; curl -sf http://localhost:9901/ready > /dev/null && echo "✅" || echo "❌"
	@echo -n "  Grafana:       "; curl -sf http://localhost:3000/api/health > /dev/null && echo "✅" || echo "❌"
	@echo -n "  Mimir:         "; curl -sf http://localhost:9009/ready > /dev/null && echo "✅" || echo "❌"
	@echo -n "  Loki:          "; curl -sf http://localhost:3100/ready > /dev/null && echo "✅" || echo "❌"
	@echo -n "  Tempo:         "; curl -sf http://localhost:3200/ready > /dev/null && echo "✅" || echo "❌"

# ============================================================================
# Multi-Tenant Testing
# ============================================================================

.PHONY: check-tenants

check-tenants:
	@echo "🏢 Checking tenant isolation..."
	@echo ""
	@echo "Available tenants in Mimir:"
	@curl -s "http://localhost:9009/prometheus/api/v1/label/tenant_id/values" | jq -r '.data[]' || echo "No tenants found"
	@echo ""
	@echo "Available tenants in Loki:"
	@curl -s "http://localhost:3100/loki/api/v1/label/tenant_id/values" | jq -r '.data[]' || echo "No tenants found"
	@echo ""
	@echo "Per-tenant data check:"
	@for tenant in tenant-pe tenant-mx tenant-co; do \
		echo ""; \
		echo "Checking $$tenant:"; \
		echo -n "  Mimir metrics: "; \
		COUNT=$$(curl -s "http://localhost:9009/prometheus/api/v1/label/__name__/values" \
		  -H "X-Scope-OrgID: $$tenant" | jq -r '.data | length'); \
		echo "$$COUNT series"; \
		echo -n "  Loki logs: "; \
		curl -s "http://localhost:3100/loki/api/v1/label/tenant_id/values" \
		  -H "X-Scope-OrgID: $$tenant" | jq -r '.data[]' | grep -q "$$tenant" && echo "✅" || echo "⚠️ "; \
	done

stop-agent:
	@$(MAKE) stop TARGET=agent ENV=local

start-agent-nonprod:
	@$(MAKE) start TARGET=agent ENV=nonprod

start-agent-prod:
	@$(MAKE) start TARGET=agent ENV=prod

# Tests
.PHONY: run-test stop-test
run-test:
	@$(MAKE) test ENV=local

stop-test:
	@$(MAKE) stop TARGET=tests ENV=local

# Comandos completos
.PHONY: start-all stop-all
start-all:
	@echo "Starting complete observability stack..."
	@$(MAKE) start-gateway
	@sleep 5
	@$(MAKE) start-agent
	@echo "Stack started successfully!"

stop-all:
	@echo "Stopping complete observability stack..."
	@$(MAKE) stop-agent
	@$(MAKE) stop-gateway
	@$(MAKE) stop-test
	@echo "Stack stopped successfully!"
