# Observability Stack - Multi-Tenant con Autenticación JWT

Stack de observabilidad basado en Grafana Alloy, Mimir, Loki y Tempo con soporte multi-tenant nativo y autenticación JWT vía Keycloak.

## 📋 Características

- ✅ **Multi-tenancy nativo**: Aislamiento completo por tenant (PE, MX, CO)
- ✅ **Autenticación JWT**: Keycloak + Envoy ext_authz
- ✅ **Gateway centralizado**: Arquitectura hub-and-spoke con Grafana Alloy
- ✅ **OTLP nativo**: Soporte completo para OpenTelemetry Protocol
- ✅ **Correlación automática**: Traces ↔ Logs ↔ Metrics
- ✅ **Escalabilidad horizontal**: Diseñado para múltiples agents distribuidos

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                      TENANT AGENTS                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Alloy Agent  │  │ Alloy Agent  │  │ Alloy Agent  │      │
│  │  (tenant-pe) │  │  (tenant-mx) │  │  (tenant-co) │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │ JWT (tenant_id)  │                 │              │
└─────────┼──────────────────┼─────────────────┼──────────────┘
          │                  │                 │
          ▼                  ▼                 ▼
    ┌────────────────────────────────────────────────┐
    │           Envoy Proxy (Port 4317/4318)         │
    │  ┌──────────────────────────────────────────┐  │
    │  │  ext_authz → Auth Service → Keycloak     │  │
    │  │  Extrae tenant_id del JWT                │  │
    │  │  Agrega X-Scope-OrgID header             │  │
    │  └──────────────────────────────────────────┘  │
    └────────────────────┬───────────────────────────┘
                         │
                         ▼
          ┌──────────────────────────────┐
          │  Alloy Gateway (14317/14318) │
          │  - Procesamiento              │
          │  - Enriquecimiento            │
          │  - Batching                   │
          └──────────┬───────────────────┘
                     │
        ┏━━━━━━━━━━━━┻━━━━━━━━━━━━┓
        ▼            ▼             ▼
   ┌────────┐  ┌────────┐   ┌────────┐
   │ Mimir  │  │  Loki  │   │ Tempo  │
   │(Metrics│  │ (Logs) │   │(Traces)│
   └────────┘  └────────┘   └────────┘
        │            │             │
        └────────────┴─────────────┘
                     │
              ┌──────▼──────┐
              │   Grafana   │
              │ (13 DS x 3) │
              └─────────────┘
```

## 🚀 Quick Start

### 1. Iniciar el Gateway

```bash
cd gateway
docker compose up -d
```

**Servicios disponibles:**
- Grafana: http://localhost:3000 (auto-login)
- Keycloak: http://localhost:8090 (admin/admin)
- Envoy Admin: http://localhost:9901
- Alloy Gateway UI: http://localhost:5000

### 2. Configurar Keycloak

Ver guía detallada: **[KEYCLOAK-SETUP.md](./KEYCLOAK-SETUP.md)**

Pasos rápidos:
1. Acceder a http://localhost:8090 (admin/admin)
2. Crear realm `observability`
3. Crear service account clients: `agent-pe`, `agent-mx`, `agent-co`
4. Agregar mapper `tenant_id` a cada client
5. Obtener client secrets

### 3. Configurar y iniciar Agent

```bash
cd agent

# Editar .env con las credenciales de Keycloak
cat > .env <<EOF
TENANT_ID=tenant-pe
KEYCLOAK_URL=http://172.17.0.1:8090
KEYCLOAK_REALM=observability
KEYCLOAK_CLIENT_ID=agent-pe
KEYCLOAK_CLIENT_SECRET=<obtener_de_keycloak>
GATEWAY_OTLP_ENDPOINT=http://172.17.0.1:4317
EOF

# Iniciar agent
docker compose up -d
```

### 4. Verificar funcionamiento

```bash
# Obtener token JWT
cd agent
./get-token.sh

# Ver logs del agent
docker logs observability-agent --tail 50

# Ver logs del gateway
docker logs -f observability-alloy-gateway

# Verificar en Grafana
# http://localhost:3000 → Explore → Datasource: loki
# Query: {service_name="alloy-agent"}
```

## 📚 Documentación

- **[README-MULTI-TENANT.md](./README-MULTI-TENANT.md)**: Arquitectura multi-tenant, datasources, labels estándar
- **[KEYCLOAK-SETUP.md](./KEYCLOAK-SETUP.md)**: Configuración paso a paso de Keycloak y JWT
- **[notas.txt](./notas.txt)**: Notas de desarrollo y troubleshooting

## 🎯 Casos de Uso

### Caso 1: Múltiples regiones geográficas
Cada región (PE, MX, CO) tiene su propio tenant. Los datos se aíslan automáticamente por el header `X-Scope-OrgID` extraído del JWT.

### Caso 2: Ambientes por cliente
Cada cliente tiene su propio tenant. Facilita billing, reporting y compliance.

### Caso 3: Multi-cluster Kubernetes
Cada cluster tiene un agent con su tenant_id. Vista unificada en Grafana con datasources dedicados por cluster.

## 🔐 Seguridad

### Flujo de Autenticación

1. **Agent obtiene JWT** de Keycloak (OAuth2 Client Credentials)
2. **Agent envía OTLP** con header `Authorization: Bearer <JWT>`
3. **Envoy valida JWT** vía ext_authz filter llamando al auth-service
4. **Auth service** valida firma con Keycloak JWKS y extrae `tenant_id`
5. **Envoy agrega header** `X-Scope-OrgID: tenant-xxx`
6. **Gateway y backends** usan el header para aislamiento multi-tenant

### Características de Seguridad

- ✅ JWT con firma RSA256 (validado contra Keycloak JWKS)
- ✅ Token expiration (default: 5 minutos)
- ✅ Service accounts (no usuarios humanos)
- ✅ Aislamiento por tenant en Mimir/Loki/Tempo
- ⏸️ mTLS entre componentes (roadmap)
- ⏸️ Rate limiting por tenant (roadmap)

## 📊 Datasources en Grafana

### Por Tenant

Cada tenant tiene 3 datasources:

**tenant-pe (default):**
- `mimir` - Métricas de Perú
- `loki` - Logs de Perú
- `tempo` - Traces de Perú

**tenant-mx:**
- `mimir-mx` - Métricas de México
- `loki-mx` - Logs de México
- `tempo-mx` - Traces de México

**tenant-co:**
- `mimir-co` - Métricas de Colombia
- `loki-co` - Logs de Colombia
- `tempo-co` - Traces de Colombia

### Vistas de Administración

- `mimir-all` - Todas las métricas (sin filtro de tenant)
- `loki-all` - Todos los logs
- `tempo-all` - Todos los traces

## 🏷️ Labels Estándar

Toda la telemetría incluye automáticamente:

```yaml
tenant_id: tenant-pe          # Identificador de tenant
collector: alloy              # Tipo de collector
collector_name: agent-pe-default  # Nombre del collector
collector_instance: host123   # Instancia específica
collector_country: PE         # Código de país
service.name: alloy-agent     # Nombre del servicio
```

## 🔧 Componentes

| Componente | Puerto | Descripción |
|------------|--------|-------------|
| Envoy Proxy | 4317 (gRPC), 4318 (HTTP) | Entry point OTLP + Auth |
| Alloy Gateway | 14317 (gRPC), 14318 (HTTP) | Procesamiento central |
| Alloy Agent | 24317 (gRPC), 24318 (HTTP) | Recolección distribuida |
| Keycloak | 8090 | Identity Provider |
| Auth Service | 8000 | Validación JWT |
| Grafana | 3000 | Visualización |
| Mimir | 9009 | Métricas (TSDB) |
| Loki | 3100 | Logs |
| Tempo | 3200 | Traces |

## 📝 Comandos Útiles

### Logs

```bash
# Ver logs del gateway
docker logs -f observability-alloy-gateway

# Ver logs del agent
docker logs -f observability-agent

# Ver logs de Envoy
docker logs -f observability-envoy

# Ver logs del auth service
docker logs -f observability-auth-service

# Ver logs de Keycloak
docker logs -f observability-keycloak
```

### Testing

```bash
# Obtener token JWT
cd agent && ./get-token.sh

# Test del auth service
TOKEN="<token>"
curl -X POST http://localhost:8000/authz \
  -H "Authorization: Bearer $TOKEN" \
  -v

# Enviar métrica de prueba vía Envoy
curl -X POST http://localhost:4318/v1/metrics \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"resourceMetrics":[...]}'

# Verificar métricas en Mimir
curl "http://localhost:9009/prometheus/api/v1/label/__name__/values" \
  -H "X-Scope-OrgID: tenant-pe"
```

### Diagnóstico

```bash
# Estado de contenedores
docker ps

# Healthchecks
docker ps --format "table {{.Names}}\t{{.Status}}"

# Estadísticas de Envoy
curl http://localhost:9901/stats | grep tenant

# UI de Alloy Gateway
open http://localhost:5000
```

## 🐛 Troubleshooting

### Logs no llegan del agent

1. Verificar conectividad: `docker logs observability-agent | grep error`
2. Verificar token JWT: `cd agent && ./get-token.sh`
3. Verificar Envoy: `docker logs observability-envoy --tail 20`
4. Verificar variable DOCKER_GATEWAY_IP en agent

### Token JWT inválido

1. Verificar que Keycloak está corriendo: `docker ps | grep keycloak`
2. Verificar configuración del mapper en Keycloak
3. Verificar client secret en `.env`
4. Ver logs del auth-service: `docker logs observability-auth-service`

### Métricas no aparecen en datasource específico

1. Verificar que el JWT incluye el `tenant_id` correcto
2. Verificar header `X-Scope-OrgID` en logs de Envoy
3. Usar datasource `*-all` para ver todos los tenants
4. Verificar que Mimir está recibiendo datos: `curl http://localhost:9009/prometheus/api/v1/label/__name__/values -H "X-Scope-OrgID: tenant-pe"`

Ver guía completa: **[README-MULTI-TENANT.md](./README-MULTI-TENANT.md#troubleshooting)**

## 🗺️ Roadmap

### Fase 1 ✅ (Completada)
- [x] Arquitectura gateway-centric
- [x] Multi-tenancy con Envoy + ext_authz
- [x] Keycloak + Auth Service
- [x] 13 datasources configurados

### Fase 2 ⏸️ (En progreso)
- [ ] Configuración de Keycloak realm
- [ ] Configuración de service account clients
- [ ] Token refresh automático en agents
- [ ] Testing end-to-end con JWT

### Fase 3 (Futuro)
- [ ] Grafana SSO con Keycloak
- [ ] Rate limiting por tenant
- [ ] mTLS entre componentes
- [ ] Dashboards específicos por tenant
- [ ] Alerting rules multi-tenant

### Fase 4 (Producción)
- [ ] High Availability (HA)
- [ ] Disaster Recovery
- [ ] Backup automatizado
- [ ] Monitoring del stack
- [ ] Compliance y auditoría

## 🤝 Contribuir

### Agregar un nuevo tenant

Ver guía: **[README-MULTI-TENANT.md](./README-MULTI-TENANT.md#agregar-nuevo-tenant)**

Pasos básicos:
1. Crear client en Keycloak (`agent-xx`)
2. Agregar mapper con `tenant_id: tenant-xx`
3. Agregar 3 datasources en Grafana (mimir-xx, loki-xx, tempo-xx)
4. Configurar nuevo agent con el client secret

### Reportar issues

Por favor incluir:
- Logs relevantes (agent, gateway, envoy, auth-service)
- Configuración de `.env`
- Output del comando `./get-token.sh`
- Versión de los componentes

## 📄 Licencia

Proyecto interno de Talma.

## 📞 Contacto

Equipo de Observabilidad - Talma DevOps

---

**Última actualización:** Enero 2025
**Stack version:** v1.0.0
