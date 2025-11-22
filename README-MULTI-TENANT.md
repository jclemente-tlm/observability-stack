# Multi-Tenant Observability Stack

## Arquitectura

```
Agent (tenant-mx, tenant-pe, tenant-co...)
  ↓ OTLP con tenant_id como resource attribute
Envoy Proxy (puerto 4317/4318)
  ├─ Extrae tenant_id del payload
  ├─ Agrega header X-Scope-OrgID
  ↓
Alloy Gateway (puerto 14317/14318 interno)
  ├─ Procesa y enriquece telemetría
  ↓
Mimir/Loki/Tempo (multi-tenant)
```

## Componentes

- **Envoy Proxy**: Routing inteligente por tenant
- **Alloy Gateway**: Procesamiento y enriquecimiento
- **Alloy Agent**: Recolección distribuida
- **Keycloak**: Identity & Access Management (preparado, opcional)
- **Grafana**: Visualización multi-tenant
- **Mimir**: Métricas (Prometheus-compatible)
- **Loki**: Logs
- **Tempo**: Traces

## Quick Start

### 1. Iniciar Gateway

```bash
cd gateway
docker compose up -d
```

**Servicios disponibles:**

- Grafana: <http://localhost:3000> (auto-login)
- Keycloak: <http://localhost:8080> (admin/admin)
- Envoy Admin: <http://localhost:9901>
- Mimir: <http://localhost:9009>
- Loki: <http://localhost:3100>
- Tempo: <http://localhost:3200>

### 2. Iniciar Agent

```bash
cd agent
docker compose up -d
```

### 3. Verificar en Grafana

1. Ir a <http://localhost:3000>
2. Explore → Seleccionar datasource `loki-mx` o `loki-pe`
3. Query: `{collector="agent"}` o `{collector="gateway"}`

## Agregar Nuevo Tenant

### 1. Variables de Entorno

Crear/editar `agent/.env`:

```env
TENANT_ID=tenant-co                    # tenant-pe, tenant-mx, tenant-co
COUNTRY_CODE=CO                        # PE, MX, CO
COLLECTOR_NAME=agent-co-central
LOG_LEVEL=info
```

### 2. Datasources en Grafana

Los datasources ya están configurados:

- `mimir-co`, `loki-co`, `tempo-co` → Para tenant-co
- `mimir-mx`, `loki-mx`, `tempo-mx` → Para tenant-mx
- `mimir`, `loki`, `tempo` → Para tenant-pe

### 3. Deploy

```bash
cd agent
docker compose up -d
```

**¡Listo!** Envoy automáticamente:

1. Lee el `tenant_id` del payload OTLP
2. Agrega header `X-Scope-OrgID: tenant-co`
3. Routea a Mimir/Loki/Tempo con tenant correcto

## Keycloak Setup (Autenticación JWT)

### 1. Acceder a Keycloak

```bash
# Abrir en navegador
http://localhost:8090

# Credenciales
Username: admin
Password: admin
```

### 2. Crear Realm "observability"

1. Hacer clic en el dropdown superior izquierdo (master)
2. Click en "Create Realm"
3. Realm name: `observability`
4. Enabled: `ON`
5. Click "Create"

### 3. Crear Service Account Clients para Agents

Para cada tenant (PE, MX, CO), crear un client:

#### Client: agent-pe

1. En el realm `observability`, ir a "Clients" → "Create client"
2. Configuración:

   ```
   Client type: OpenID Connect
   Client ID: agent-pe
   Name: Agent Peru
   ```

3. Click "Next"
4. Capability config:

   ```
   Client authentication: ON
   Authorization: OFF
   Authentication flow:
     ☑ Service accounts roles
     ☐ Standard flow
     ☐ Direct access grants
   ```

5. Click "Save"

#### Agregar Mapper "tenant_id" (Hardcoded Claim)

1. En el client `agent-pe`, ir a "Client scopes" tab
2. Click en el scope `agent-pe-dedicated`
3. Click "Add mapper" → "By configuration" → **"Hardcoded claim"**
4. Configuración del mapper:

   ```
   Name: tenant-id-claim
   Mapper Type: Hardcoded claim
   Token Claim Name: tenant_id
   Claim value: tenant-pe
   Claim JSON Type: String
   Add to ID token: ON
   Add to access token: ON
   Add to userinfo: ON
   ```

5. Click "Save"

✅ **¡Listo!** El mapper inyectará automáticamente `tenant_id: "tenant-pe"` en todos los tokens.

**Nota:** Usamos "Hardcoded claim" porque el valor es fijo por client. No necesitas configurar atributos adicionales en el service account user.

#### Repetir para agent-mx y agent-co

Crear clients `agent-mx` y `agent-co` con los mismos pasos, cambiando:

- agent-mx: tenant_id = `tenant-mx`
- agent-co: tenant_id = `tenant-co`

### 4. Obtener Client Secret

Para cada client (agent-pe, agent-mx, agent-co):

1. Ir a "Clients" → seleccionar el client
2. Ir a tab "Credentials"
3. Copiar "Client Secret"
4. Guardar para configurar los agents

### 5. Test del Auth Service

**Paso 1: Obtener token de Keycloak**

```bash
# Obtener token de Keycloak (reemplazar <CLIENT_SECRET>)
TOKEN=$(curl -X POST "http://localhost:8090/realms/observability/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=agent-pe" \
  -d "client_secret=<CLIENT_SECRET>" | jq -r '.access_token')

# Verificar que el token se obtuvo
echo "Token obtenido: ${TOKEN:0:50}..."
```

**Paso 2: Decodificar el JWT para verificar tenant_id**

```bash
# Decodificar payload del JWT
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq

# Deberías ver algo como:
# {
#   "tenant_id": "tenant-pe",    ← Verificar que existe
#   "azp": "agent-pe",
#   "clientId": "agent-pe",
#   ...
# }
```

**Paso 3: Probar auth service con el token**

```bash
# Probar auth service (debe retornar header X-Scope-OrgID)
curl -v -X POST http://localhost:8000/authz \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# Respuesta esperada (HTTP 200):
# {
#   "result": {
#     "allowed": true,
#     "headers": {
#       "x-scope-orgid": "tenant-pe",
#       "x-user-id": "service-account-agent-pe",
#       "x-user-email": "unknown"
#     }
#   }
# }
```

**Troubleshooting:**

- **Error "HTTP 405 Method Not Allowed"** al obtener token:
  - Verificar URL de Keycloak: debe ser `http://localhost:8090` (no 8080)
  - Verificar que el realm "observability" existe
  - Verificar que el client "agent-pe" existe

- **Token vacío o error al obtener**:

  ```bash
  # Ver el error completo
  curl -X POST "http://localhost:8090/realms/observability/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "client_id=agent-pe" \
    -d "client_secret=<CLIENT_SECRET>" | jq
  ```

- **Auth service retorna tenant por defecto** en lugar del correcto:
  - Verificar que el mapper "tenant-id-claim" está configurado
  - Verificar que el token incluye el claim `tenant_id`

**Usar el script automatizado:**

```bash
# Más fácil: usar el script que viene incluido
cd agent
./get-token.sh
```

### 6. Configurar Agents para usar JWT

Actualizar `agent/.env`:

```env
TENANT_ID=tenant-pe
KEYCLOAK_URL=http://<DOCKER_GATEWAY_IP>:8090
KEYCLOAK_REALM=observability
KEYCLOAK_CLIENT_ID=agent-pe
KEYCLOAK_CLIENT_SECRET=<SECRET_FROM_STEP_4>
```

Crear script `agent/get-token.sh`:

```bash
#!/bin/bash
KEYCLOAK_URL=${KEYCLOAK_URL:-http://localhost:8090}
REALM=${KEYCLOAK_REALM:-observability}
CLIENT_ID=${KEYCLOAK_CLIENT_ID}
CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET}

TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" | jq -r '.access_token')

echo "Authorization: Bearer $TOKEN"
```

**Nota:** En producción, los agents deberían refrescar el token automáticamente antes de expirar (típicamente cada 5 minutos).

## Estructura de Tenants

### tenant-pe (Perú)

- Datasources: mimir, loki, tempo
- Collector: gateway-pe-central, agent-pe-default
- Country Code: PE

### tenant-mx (México)

- Datasources: mimir-mx, loki-mx, tempo-mx
- Collector: agent-mx-default
- Country Code: MX

### tenant-co (Colombia)

- Datasources: mimir-co, loki-co, tempo-co
- Collector: agent-co-default
- Country Code: CO

### admin (All tenants)

- Datasources: mimir-all, loki-all, tempo-all
- Vista global para administradores

## Labels Estándar

Toda la telemetría incluye:

```yaml
tenant_id: tenant-pe / tenant-mx / tenant-co
collector: gateway / agent
collector_name: gateway-pe-central / agent-mx-default
collector_instance: <hostname>
collector_country: PE / MX / CO
service.name: alloy-gateway / alloy-agent / <app-name>
```

## Troubleshooting

### Ver logs de Envoy

```bash
docker logs observability-envoy --tail 50
```

### Verificar routing

```bash
curl http://localhost:9901/stats | grep tenant
```

### Test manual con curl

```bash
# Enviar métrica de prueba
curl -X POST http://localhost:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -d '{"resource_attributes": {"tenant_id": "tenant-mx"}}'
```

### Verificar tenant en Loki

```bash
curl "http://localhost:3100/loki/api/v1/label/tenant_id/values" \
  -H "X-Scope-OrgID: tenant-mx"
```

## Próximos Pasos

### Fase 1 (Completada)

- ✅ Envoy proxy con ext_authz filter
- ✅ Auth service para validación JWT
- ✅ Keycloak instalado y funcionando
- ✅ Datasources multi-tenant configurados
- ✅ Arquitectura gateway-centric mantenida

### Fase 2 (Implementación Actual)

- ⏸️ Configurar realm "observability" en Keycloak
- ⏸️ Crear service account clients (agent-pe, agent-mx, agent-co)
- ⏸️ Agregar custom claim "tenant_id" en JWT
- ⏸️ Actualizar agents para obtener JWT tokens
- ⏸️ Testing end-to-end multi-tenant con JWT

### Fase 3 (Futuro)

- [ ] Configurar Grafana OAuth con Keycloak
- [ ] Rate limiting por tenant en Envoy
- [ ] mTLS entre componentes
- [ ] Dashboards específicos por tenant
- [ ] Alerting rules por tenant
- [ ] Recording rules para service graphs

### Fase 4 (Producción)

- [ ] High Availability (HA) para todos los componentes
- [ ] Backup y restore automatizado
- [ ] Disaster recovery plan
- [ ] Export de métricas a cloud providers
- [ ] Compliance y auditoría

## Monitoring del Stack

Dashboard de Alloy Gateway: <http://localhost:5000>

- Métricas del gateway
- Estado de los exporters
- Queue size, drop rate

Envoy Admin: <http://localhost:9901>

- Stats y métricas de routing
- Health checks
- Circuit breakers

## Contacto y Soporte

Para agregar nuevos tenants o preguntas, contactar al equipo de observabilidad.
