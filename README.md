# Observability Stack - Arquitectura Multi-Tenant Simplificada

Stack de observabilidad empresarial con aislamiento inteligente por tipo de señal: logs por país, métricas por ambiente, traces por sistema.

## 🎯 Características

- ✅ **Aislamiento por tipo de señal**: Logs→País, Metrics→Ambiente, Traces→Sistema
- ✅ **Autenticación híbrida**: JWT (Keycloak) para externos + API-Key para internos
- ✅ **Sin intermediarios**: Agents → Envoy → Backends directo
- ✅ **Multitenancy nativo**: Loki, Mimir y Tempo con tenants independientes
- ✅ **OTLP completo**: Soporte nativo para OpenTelemetry Protocol
- ✅ **Escalabilidad**: Arquitectura distribuida para múltiples países y ambientes

## 🏗️ Arquitectura

```
┌────────────────────────────────────────────────────────────┐
│  AGENTS (distribuidos por país/ambiente/sistema)          │
│                                                            │
│  Agent PE-PROD-Ecommerce   Agent MX-QA-Payments          │
│  country=PE                country=MX                     │
│  environment=prod          environment=qa                 │
│  system=ecommerce          system=payments                │
│  auth=JWT (externo)        auth=API-Key (interno)         │
└─────────────┬──────────────────────┬───────────────────────┘
              │                      │
              │  OTLP + Headers      │
              │  X-Country           │
              │  X-Environment       │
              │  X-System            │
              └──────────┬───────────┘
                         ▼
            ┌────────────────────────┐
            │   ENVOY GATEWAY        │
            │                        │
            │  jwt_authn filter      │ ← Valida JWT con Keycloak
            │  lua filter            │ ← Extrae headers, enruta
            │                        │
            │  Routing inteligente:  │
            │  • Logs   → X-Scope-OrgID: talma-{country}     │
            │  • Metrics→ X-Scope-OrgID: talma-{environment} │
            │  • Traces → X-Scope-OrgID: {system}-{environment} │
            └───────────┬────────────┘
                        │
            ┌───────────┼────────────┐
            ▼           ▼            ▼
      ┌─────────┐ ┌─────────┐ ┌──────────┐
      │  Loki   │ │  Mimir  │ │  Tempo   │
      │         │ │         │ │          │
      │ talma-  │ │ talma-  │ │ ecommerce│
      │   pe    │ │   dev   │ │   -prod  │
      │   mx    │ │   qa    │ │ payments │
      │   co    │ │   prod  │ │   -prod  │
      └─────────┘ └─────────┘ └──────────┘
           ▲           ▲            ▲
           └───────────┴────────────┘
                       │
                ┌──────▼──────┐
                │   Grafana   │
                │ 3+3+N DSs   │
                └─────────────┘
```

## 📊 Patrón de Aislamiento

### 1. Logs → Por PAÍS 🌍

**Razón**: Compliance legal (GDPR, LGPD), auditoría por jurisdicción

- `talma-pe` - Logs de Perú
- `talma-mx` - Logs de México
- `talma-co` - Logs de Colombia

**Labels adicionales**: `country_code`, `environment`, `system_name`

### 2. Métricas → Por AMBIENTE 🔧

**Razón**: Infraestructura compartida, alertas globales por ambiente

- `talma-dev` - Métricas de desarrollo
- `talma-qa` - Métricas de QA
- `talma-prod` - Métricas de producción

**Labels adicionales**: `country_code`, `system_name`

### 3. Traces → Por SISTEMA 🔗

**Razón**: Seguimiento de transacciones distribuidas, debugging

- `ecommerce-prod` - Traces del sistema e-commerce
- `payments-prod` - Traces del sistema de pagos
- `logistics-qa` - Traces de logística en QA

**Labels adicionales**: `country_code`, `environment`

## 🚀 Quick Start

### 1. Iniciar el Server Central

```bash
cd server
cp .env.example .env
# Editar .env si es necesario

docker compose up -d
```

**Servicios disponibles:**

- Grafana: <http://localhost:3000> (auto-login)
- Envoy Admin: <http://localhost:9901>
- Keycloak: <http://localhost:8090> (admin/admin)
- Mimir: <http://localhost:9009>
- Loki: <http://localhost:3100>
- Tempo: <http://localhost:3200>

### 2. Configurar Agent

```bash
cd agent
cp .env.example .env

# Editar .env con la configuración del agent
cat > .env <<EOF
COMPOSE_PROJECT_NAME=agent-pe-prod-ecommerce
COUNTRY_CODE=PE
ENVIRONMENT=prod
SYSTEM_NAME=ecommerce
COLLECTOR_NAME=agent-pe-prod-ecommerce
GATEWAY_OTLP_ENDPOINT=envoy.talma.com:4317
AUTH_MODE=jwt
KEYCLOAK_CLIENT_ID=agent-pe-prod
KEYCLOAK_CLIENT_SECRET=<secret>
EOF

docker compose up -d
```

## 🔐 Autenticación

### Para Agents Externos (otros países)

Usa JWT de Keycloak:

```bash
# Obtener token
curl -X POST http://keycloak:8090/realms/observability/protocol/openid-connect/token \
  -d "client_id=agent-pe-prod" \
  -d "client_secret=<secret>" \
  -d "grant_type=client_credentials"

# El agent enviará el token en cada request
# Envoy lo valida automáticamente
```

### Para Agents Internos (misma red)

Usa API Key simple:

```bash
# En .env del agent
AUTH_MODE=apikey
API_KEY=<tu-api-key-segura>

# El agent enviará: X-API-Key: <tu-api-key-segura>
```

## 📝 Variables de Entorno

### Agent

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `COUNTRY_CODE` | Código del país | `PE`, `MX`, `CO` |
| `ENVIRONMENT` | Ambiente de ejecución | `dev`, `qa`, `prod` |
| `SYSTEM_NAME` | Nombre del sistema | `ecommerce`, `payments`, `logistics` |
| `GATEWAY_OTLP_ENDPOINT` | Endpoint del gateway | `envoy.talma.com:4317` |
| `AUTH_MODE` | Modo de autenticación | `jwt` o `apikey` |
| `KEYCLOAK_CLIENT_ID` | Client ID (si jwt) | `agent-pe-prod` |
| `API_KEY` | API Key (si apikey) | `<key-segura>` |

### Server

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `KEYCLOAK_ADMIN` | Usuario admin de Keycloak | `admin` |
| `KEYCLOAK_ADMIN_PASSWORD` | Password admin | `admin` |

## 📦 Componentes

### Server Central

#### Envoy Gateway

- **Puerto**: 4317 (gRPC), 4318 (HTTP)
- **Función**: Entry point OTLP, auth JWT, routing multi-tenant
- **Filters**: `jwt_authn` + `lua` para X-Scope-OrgID

#### Loki (Logs)

- **Puerto**: 3100 (HTTP), 9096 (gRPC), 4317 (OTLP)
- **Tenants**: `talma-pe`, `talma-mx`, `talma-co`
- **Retention**: 744h (31 días)

#### Mimir (Metrics)

- **Puerto**: 9009 (HTTP), 9095 (gRPC), 4317/4318 (OTLP)
- **Tenants**: `talma-dev`, `talma-qa`, `talma-prod`
- **Overrides**: Límites por tenant en `overrides.yaml`

#### Tempo (Traces)

- **Puerto**: 3200 (HTTP), 4317/4318 (OTLP)
- **Tenants**: `{system}-{environment}` (ej: `ecommerce-prod`)
- **Features**: Service graphs, span metrics

#### Grafana

- **Puerto**: 3000
- **Datasources**:
  - Logs: loki-pe, loki-mx, loki-co
  - Metrics: mimir-dev, mimir-qa, mimir-prod
  - Traces: tempo-{system}-{env}

#### Keycloak

- **Puerto**: 8090
- **Realm**: `observability`
- **Función**: Emisor de JWT tokens para agents externos

### Agents (distribuidos)

#### Grafana Alloy

- **Puerto**: 4317/4318 (OTLP receiver)
- **Función**: Recolección, procesamiento, enriquecimiento
- **Exporta a**: Envoy Gateway central

#### Node Exporter

- **Puerto**: 9100
- **Función**: Métricas de host (CPU, memoria, disco, red)

#### cAdvisor

- **Puerto**: 8080
- **Función**: Métricas de contenedores Docker

## 🔍 Consultas

### Logs (por país)

```logql
# Logs de Perú
{country_code="PE"} |= "error"

# Logs de un sistema específico en México
{country_code="MX", system_name="payments"} |= "transaction"
```

### Métricas (por ambiente)

```promql
# CPU de producción (todos los países)
node_cpu_seconds_total{environment="prod"}

# Métricas de un país específico en QA
up{environment="qa", country_code="MX"}
```

### Traces (por sistema)

```
# En Grafana, seleccionar datasource: tempo-ecommerce-prod
# Buscar por service.name, http.status_code, etc.
```

## 🛠️ Deployment

### Escenario 1: Agent en Perú (Producción)

```bash
cd agent
cat > .env <<EOF
COUNTRY_CODE=PE
ENVIRONMENT=prod
SYSTEM_NAME=ecommerce
GATEWAY_OTLP_ENDPOINT=envoy.talma.com:4317
AUTH_MODE=jwt
KEYCLOAK_CLIENT_ID=agent-pe-prod
KEYCLOAK_CLIENT_SECRET=<secret>
EOF
docker compose up -d
```

### Escenario 2: Agent en México (QA)

```bash
cd agent
cat > .env <<EOF
COUNTRY_CODE=MX
ENVIRONMENT=qa
SYSTEM_NAME=payments
GATEWAY_OTLP_ENDPOINT=172.17.0.1:4317
AUTH_MODE=apikey
API_KEY=<key-interna>
EOF
docker compose up -d
```

## 🎓 Mejores Prácticas

1. **Logs por país**: Mantiene compliance legal y facilita auditorías
2. **Métricas por ambiente**: Optimiza costos, un backend por ambiente
3. **Traces por sistema**: Permite seguimiento completo de transacciones
4. **JWT para externos**: Seguridad robusta, auditable, revocable
5. **API-Key para internos**: Simplicidad, baja latencia
6. **Labels consistentes**: Siempre incluir `country_code`, `environment`, `system_name`

## 📚 Documentación Adicional

- **KEYCLOAK-SETUP.md**: Configuración de clientes y tokens
- **ESTADO-ACTUAL.md**: Estado del proyecto y próximos pasos
- **Envoy Admin**: <http://localhost:9901> para debugging

## 🐛 Troubleshooting

### Agent no envía datos

```bash
# Verificar conectividad a Envoy
curl -v http://envoy-host:4317

# Ver logs del agent
docker compose logs -f alloy-agent

# Verificar headers en Envoy
curl http://localhost:9901/stats | grep jwt
```

### Datos no aparecen en Grafana

```bash
# Verificar tenant en datasource
# Logs: debe coincidir con talma-{COUNTRY_CODE}
# Metrics: debe coincidir con talma-{ENVIRONMENT}

# Verificar labels
# En Grafana Explore, revisar que existan labels:
# country_code, environment, system_name
```

### JWT inválido

```bash
# Obtener nuevo token
./scripts/get-token.sh

# Verificar JWKS de Keycloak
curl http://keycloak:8080/realms/observability/protocol/openid-connect/certs
```

## 📄 Licencia

MIT
