# Guía de Configuración de Keycloak para Multi-Tenancy

## Contexto

Este documento explica paso a paso cómo configurar Keycloak para la autenticación JWT en el stack de observabilidad multi-tenant.

## Arquitectura de Autenticación

```
Agent → Keycloak (obtiene JWT con tenant_id)
  ↓
Agent → Envoy (envía OTLP + JWT en header)
  ↓
Envoy → Auth Service (valida JWT)
  ↓
Auth Service → Keycloak JWKS (valida firma)
  ↓
Auth Service → Envoy (retorna X-Scope-OrgID: tenant-xxx)
  ↓
Envoy → Alloy Gateway (forwarding con tenant header)
  ↓
Alloy Gateway → Mimir/Loki/Tempo (con X-Scope-OrgID)
```

## Acceso a Keycloak

### 1. URL y Credenciales

```
URL: http://localhost:8090
Username: admin
Password: admin
```

**Nota:** El puerto es 8090 (no 8080) para evitar conflictos con otros servicios.

### 2. Verificar que Keycloak está funcionando

```bash
# Verificar contenedor
docker ps | grep keycloak

# Ver logs
docker logs observability-keycloak --tail 50

# Test de conectividad
curl http://localhost:8090/health
```

## Configuración del Realm

### 1. Crear Realm "observability"

1. En la interfaz web, hacer clic en el dropdown superior izquierdo donde dice **"master"**
2. Click en botón **"Create Realm"**
3. En el formulario:
   - **Realm name:** `observability`
   - **Enabled:** ON
4. Click **"Create"**

### 2. Configurar opciones del Realm (opcional)

En **Realm settings**:

- **Display name:** "Observability Stack"
- **HTML display name:** `<b>Observability</b> Stack`
- **Frontend URL:** Dejar vacío para desarrollo
- **Require SSL:** External requests (default)

En **Tokens** tab:

- **Access Token Lifespan:** 5 minutos (default, ajustar según necesidad)
- **Client Login Timeout:** 5 minutos

## Configuración de Clients (Service Accounts)

### ¿Por qué Service Accounts?

Los agents son servicios automatizados, no usuarios interactivos. Keycloak soporta **Service Account** authentication (OAuth2 Client Credentials flow), donde un client puede obtener un token sin usuario humano.

### 1. Crear Client "agent-pe"

#### Paso 1: Información básica

1. En el realm `observability`, ir a **Clients** (menú izquierdo)
2. Click en **"Create client"**
3. En el formulario **"General Settings"**:
   - **Client type:** OpenID Connect
   - **Client ID:** `agent-pe`
   - **Name:** `Agent Peru`
   - **Description:** `Service account for Peru tenant agent`
   - **Always display in console:** OFF
4. Click **"Next"**

#### Paso 2: Capability config

En **"Capability config"**:

- **Client authentication:** ON (confidential client)
- **Authorization:** OFF (no necesitamos fine-grained authorization)
- **Authentication flow:**
  - ✅ **Service accounts roles** (habilitar)
  - ❌ Standard flow (deshabilitar)
  - ❌ Direct access grants (deshabilitar)
  - ❌ Implicit flow (deshabilitar)
  - ❌ OAuth 2.0 Device Authorization Grant (deshabilitar)
  - ❌ OIDC CIBA Grant (deshabilitar)

**Importante:** Solo debe estar habilitado "Service accounts roles".

4. Click **"Next"**

#### Paso 3: Login settings

En **"Login settings"** (opcional, dejar vacíos para service accounts):

- **Root URL:** (vacío)
- **Home URL:** (vacío)
- **Valid redirect URIs:** (vacío)
- **Valid post logout redirect URIs:** (vacío)
- **Web origins:** (vacío)

5. Click **"Save"**

### 2. Configurar Mapper para tenant_id

Ahora debemos agregar el atributo `tenant_id` al JWT token.

#### Paso 1: Ir a Client Scopes

1. En el client `agent-pe`, ir al tab **"Client scopes"**
2. Buscar el scope **`agent-pe-dedicated`** (scope dedicado del client)
3. Click en `agent-pe-dedicated`

#### Paso 2: Agregar Mapper

1. Click en **"Add mapper"** → **"By configuration"**
2. Seleccionar **"Hardcoded claim"** (recomendado)

##### Configuración del Mapper (Hardcoded Claim)

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

**¿Por qué Hardcoded Claim?**
- ✅ Más simple: no requiere configurar atributos en el service account user
- ✅ Explícito: el valor está directamente en la configuración del mapper
- ✅ Recomendado para service accounts con tenant fijo

3. Click **"Save"**

✅ **¡Listo!** El mapper inyectará automáticamente `tenant_id: "tenant-pe"` en todos los tokens de este client.

**Nota:** Si necesitas una configuración más flexible donde el tenant_id pueda cambiar sin modificar el mapper, consulta la sección "Configuración Avanzada" al final de este documento.

### 3. Repetir para agent-mx y agent-co

Crear los clients `agent-mx` y `agent-co` siguiendo los mismos pasos, cambiando solo el valor del claim:

- **agent-mx:** Claim value = `tenant-mx`
- **agent-co:** Claim value = `tenant-co`

### 4. Obtener Client Secret

1. Volver al client `agent-pe`
2. Ir al tab **"Credentials"**
3. Copiar el **Client secret** (lo necesitarás para configurar el agent)

Ejemplo:

```
Client Secret: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

⚠️ **Importante:** Guardar este secret en un lugar seguro. Se usará en el `.env` del agent.

### 5. Repetir para otros tenants

Crear los clients `agent-mx` y `agent-co` siguiendo los mismos pasos, cambiando:

**agent-mx:**

- Client ID: `agent-mx`
- Name: `Agent Mexico`
- tenant_id: `tenant-mx`

**agent-co:**

- Client ID: `agent-co`
- Name: `Agent Colombia`
- tenant_id: `tenant-co`

## Testing

### 1. Obtener token con curl

```bash
# Reemplazar <CLIENT_SECRET> con el secret real
curl -X POST "http://localhost:8090/realms/observability/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=agent-pe" \
  -d "client_secret=<CLIENT_SECRET>"
```

Respuesta esperada:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI...",
  "expires_in": 300,
  "refresh_expires_in": 0,
  "token_type": "Bearer",
  "not-before-policy": 0,
  "scope": "profile email"
}
```

### 2. Decodificar el JWT

```bash
TOKEN="<access_token>"
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq
```

Debe incluir el claim `tenant_id`:

```json
{
  "exp": 1234567890,
  "iat": 1234567590,
  "iss": "http://localhost:8090/realms/observability",
  "aud": "account",
  "sub": "12345678-90ab-cdef-1234-567890abcdef",
  "typ": "Bearer",
  "azp": "agent-pe",
  "tenant_id": "tenant-pe",    ← ¡Importante!
  "scope": "profile email",
  "clientId": "agent-pe",
  "client_id": "agent-pe"
}
```

### 3. Probar con Auth Service

```bash
TOKEN="<access_token>"

curl -v -X POST http://localhost:8000/authz \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

Debe retornar HTTP 200 con headers:

```
X-Scope-OrgID: tenant-pe
X-User-Id: service-account-agent-pe
X-User-Email: (vacío para service accounts)
```

### 4. Test end-to-end con Envoy

```bash
TOKEN="<access_token>"

# Enviar métrica de prueba a través de Envoy
curl -X POST http://localhost:4318/v1/metrics \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "test_metric",
          "gauge": {
            "dataPoints": [{
              "asDouble": 42.0,
              "timeUnixNano": "1234567890000000000"
            }]
          }
        }]
      }]
    }]
  }'
```

Verificar en logs de Envoy:

```bash
docker logs observability-envoy --tail 20
```

Debe mostrar:

```
[info] [ext_authz] Authorization succeeded. Added header: x-scope-orgid: tenant-pe
```

## Configuración del Agent

### 1. Actualizar .env

Editar `agent/.env`:

```env
# Tenant Configuration
TENANT_ID=tenant-pe
COUNTRY_CODE=PE
COLLECTOR_NAME=agent-pe-default

# Keycloak Configuration
KEYCLOAK_URL=http://172.17.0.1:8090
KEYCLOAK_REALM=observability
KEYCLOAK_CLIENT_ID=agent-pe
KEYCLOAK_CLIENT_SECRET=a1b2c3d4-e5f6-7890-abcd-ef1234567890

# Gateway Configuration
GATEWAY_OTLP_ENDPOINT=http://172.17.0.1:4317
LOG_LEVEL=info
```

### 2. Usar script get-token.sh

```bash
cd agent
./get-token.sh
```

Esto genera el token y lo guarda en `/tmp/keycloak-token.txt`.

### 3. Integración con Alloy (Futuro)

Actualmente Grafana Alloy no soporta nativamente OAuth2 client credentials flow. Opciones:

#### Opción A: Script externo + Variable de entorno

```bash
# Pre-start script
export BEARER_TOKEN=$(./get-token.sh | tail -1)
docker compose up -d
```

Luego en `config.alloy`:

```hcl
otelcol.exporter.otlp "gateway_otlp" {
  client {
    endpoint = env("GATEWAY_OTLP_ENDPOINT")
    headers  = {
      "Authorization" = "Bearer ${env("BEARER_TOKEN")}",
    }
  }
}
```

**Problema:** El token expira cada 5 minutos.

#### Opción B: Sidecar token refresher

Crear un sidecar container que:

1. Obtiene token de Keycloak
2. Lo guarda en un volumen compartido
3. Lo refresca automáticamente cada 4 minutos

```yaml
# docker-compose.yml
services:
  token-refresher:
    image: curlimages/curl:latest
    volumes:
      - ./get-token.sh:/app/get-token.sh
      - token-volume:/tokens
    environment:
      - KEYCLOAK_URL=${KEYCLOAK_URL}
      - KEYCLOAK_REALM=${KEYCLOAK_REALM}
      - KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID}
      - KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET}
    command: >
      sh -c "while true; do
        /app/get-token.sh > /tokens/bearer.txt
        sleep 240
      done"

  alloy-agent:
    # ... config existente
    volumes:
      - token-volume:/tokens:ro
    # Luego leer token desde /tokens/bearer.txt
```

#### Opción C: Envoy sidecar (recomendado para producción)

En lugar de que el agent maneje el JWT, poner un Envoy local que:

1. Intercepta requests OTLP
2. Agrega el JWT automáticamente
3. Envía al Envoy gateway

```
Agent → Envoy Local (agrega JWT) → Envoy Gateway (valida JWT) → Alloy
```

## Troubleshooting

### Error: "Client not found"

**Causa:** El client_id no existe o está en el realm incorrecto.

**Solución:** Verificar que estés en el realm `observability` (no `master`).

### Error: "Invalid client credentials"

**Causa:** El client_secret es incorrecto.

**Solución:**

1. Ir a Clients → agent-pe → Credentials tab
2. Regenerar secret si es necesario
3. Actualizar `.env` con el nuevo secret

### Error: "Client authentication with signed JWT is not enabled"

**Causa:** El client no tiene "Client authentication: ON".

**Solución:**

1. Ir a Clients → agent-pe → Settings tab
2. En "Capability config", activar "Client authentication: ON"
3. Save

### Token no incluye tenant_id

**Causa:** El mapper no está configurado correctamente.

**Solución:**

1. Verificar que el mapper existe en el client scope dedicado
2. Verificar que el mapper tiene "Add to access token: ON"
3. Regenerar token y verificar de nuevo

### Auth service retorna 401

**Causa:** El token no es válido o Keycloak no está accesible desde el auth service.

**Solución:**

1. Verificar que Keycloak está corriendo: `docker ps | grep keycloak`
2. Verificar network: auth-service y keycloak deben estar en la misma red Docker
3. Ver logs: `docker logs observability-auth-service --tail 50`
4. Verificar KEYCLOAK_URL en auth-service incluye el puerto correcto (8090)

### Envoy no agrega X-Scope-OrgID

**Causa:** El ext_authz filter no está recibiendo el header del auth service.

**Solución:**

1. Ver logs de Envoy: `docker logs observability-envoy --tail 50`
2. Ver logs de auth-service: `docker logs observability-auth-service --tail 50`
3. Verificar que auth-service está retornando el header correctamente
4. Verificar que Envoy tiene configurado `allowed_upstream_headers` con `x-scope-orgid`

## Seguridad

### En Desarrollo

- ✅ Client secrets en `.env` (no commitear a git)
- ✅ Keycloak usa PostgreSQL (no H2 en memoria)
- ⚠️ Keycloak sin SSL (usar solo en localhost)
- ⚠️ Credenciales default (admin/admin)

### En Producción

- [ ] Cambiar credenciales de admin de Keycloak
- [ ] Habilitar SSL/TLS para Keycloak
- [ ] Usar secrets management (Vault, Kubernetes secrets, etc.)
- [ ] Habilitar mTLS entre componentes
- [ ] Configurar rate limiting en Keycloak
- [ ] Auditoría de eventos de autenticación
- [ ] Rotación periódica de client secrets

## Referencias

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OAuth2 Client Credentials Flow](https://oauth.net/2/grant-types/client-credentials/)
- [Envoy ext_authz Filter](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/filters/http/ext_authz/v3/ext_authz.proto)
- [OpenTelemetry Authentication](https://opentelemetry.io/docs/specs/otel/protocol/exporter/#authentication)

---

## Configuración Avanzada: User Attribute Mapper

Esta sección es **opcional** y solo necesaria si quieres que el `tenant_id` sea configurable sin modificar el mapper.

### ¿Cuándo usar User Attribute en lugar de Hardcoded Claim?

**Hardcoded Claim (recomendado):**
- ✅ Client fijo = tenant fijo
- ✅ Más simple de configurar
- ✅ Ideal para service accounts

**User Attribute (avanzado):**
- 🔄 Necesitas cambiar el tenant_id dinámicamente
- 🔄 Múltiples service accounts con diferentes tenants bajo el mismo client
- 🔄 Integración con sistemas externos que proveen atributos

### Configuración con User Attribute

Si decides usar User Attribute mapper:

#### 1. Crear el Mapper

En el client scope dedicado (`agent-pe-dedicated`):

```
Name: tenant-id-attribute
Mapper Type: User Attribute
User Attribute: tenant_id
Token Claim Name: tenant_id
Claim JSON Type: String
Add to ID token: ON
Add to access token: ON
Add to userinfo: ON
Multivalued: OFF
```

#### 2. Configurar el Atributo en el Service Account User

1. En el client `agent-pe`, ir al tab **"Service account roles"**
2. En la parte superior verás: _"To manage detail and group mappings, click on the username **service-account-agent-pe**"_
3. Click en el link **service-account-agent-pe**
4. Se abrirá la página del usuario del service account
5. Ir al tab **"Attributes"**
6. Click **"Add an attribute"**
7. Configurar:
   - **Key:** `tenant_id`
   - **Value:** `tenant-pe`
8. Click **"Save"**

✅ Ahora el mapper leerá el atributo `tenant_id` del usuario y lo incluirá en el JWT.

**Nota:** Esta configuración es más compleja. Solo úsala si realmente necesitas la flexibilidad.

---

## Próximos Pasos

Una vez completada la configuración de Keycloak:

1. ✅ Verificar que los tokens JWT incluyen `tenant_id`
2. ✅ Probar el flujo completo: Agent → Envoy → Auth Service → Keycloak
3. ⏸️ Implementar token refresh automático en los agents
4. ⏸️ Configurar Grafana OAuth con Keycloak para SSO
5. ⏸️ Agregar rate limiting por tenant en Envoy
6. ⏸️ Implementar RBAC basado en roles de Keycloak
