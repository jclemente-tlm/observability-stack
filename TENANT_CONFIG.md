# Configuración de Tenant ID por País

Este stack de observabilidad soporta multi-tenancy dinámico basado en el país de despliegue.

## Variables de Tenant

### Agent (despliegue remoto)

- **TENANT_ID**: Identificador del tenant (tenant-pe, tenant-mx, tenant-co)
- **LOCAL_COUNTRY**: Código del país (PE, MX, CO)

El agent y sus servicios (node-exporter, cadvisor) usan el mismo TENANT_ID.

### Gateway (despliegue central)

- **TENANT_ID**: Por defecto `tenant-pe`

El gateway y sus servicios (node-exporter, cadvisor) usan el mismo TENANT_ID del gateway.

### Aplicaciones

Las aplicaciones envían `tenant_id` según su ubicación mediante el atributo OTLP:

```
OTEL_RESOURCE_ATTRIBUTES=...,tenant_id=${TENANT_ID},service.country=${LOCAL_COUNTRY}
```

## Despliegue por País

### Perú (PE)

```bash
# Agent
cd agent
cp .env.pe .env  # o usar .env actual
docker compose up -d

# Tests
cd ../tests
# .env tiene TENANT_ID=tenant-pe
docker compose -f docker-compose.tests.yml up -d
```

### México (MX)

```bash
# Agent
cd agent
cp .env.mx .env
docker compose up -d

# Tests
cd ../tests
# Modificar .env con TENANT_ID=tenant-mx, LOCAL_COUNTRY=MX
docker compose -f docker-compose.tests.yml up -d
```

### Colombia (CO)

```bash
# Agent
cd agent
cp .env.co .env
docker compose up -d

# Tests
cd ../tests
# Modificar .env con TENANT_ID=tenant-co, LOCAL_COUNTRY=CO
docker compose -f docker-compose.tests.yml up -d
```

## Consultas en Grafana

Todas las métricas, logs y trazas van al tenant del gateway (tenant-pe por defecto).
Dentro del tenant, se usa el label/atributo `tenant_id` para filtrar por origen:

```promql
# Métricas de un tenant específico
up{tenant_id="tenant-pe"}
node_cpu_seconds_total{tenant_id="tenant-mx"}
container_memory_usage_bytes{tenant_id="tenant-co"}
```

```logql
# Logs de un tenant específico
{tenant_id="tenant-pe"}
{tenant_id="tenant-mx", service_name="orders-service"}
```

Para consultar datos en Grafana, usar el header:

```http
X-Scope-OrgID: tenant-pe
```

## Estructura de Tenants

```text
┌─────────────────────────────────────────────┐
│ Componente          → tenant_id             │
├─────────────────────────────────────────────┤
│ Agent PE            → tenant-pe              │
│ ├─ node-exporter    → tenant-pe              │
│ └─ cadvisor         → tenant-pe              │
│                                              │
│ Gateway             → tenant-pe              │
│ ├─ node-exporter    → tenant-pe              │
│ ├─ cadvisor         → tenant-pe              │
│ └─ alloy metrics    → tenant-pe              │
│                                              │
│ Apps (orders/notif) → tenant-pe (según .env)│
└─────────────────────────────────────────────┘
```

**Todos los datos se almacenan en el tenant del gateway (tenant-pe) de los backends (Mimir, Loki, Tempo) con `tenant_id` como label/atributo para identificar el origen (agent, gateway, aplicaciones).**
