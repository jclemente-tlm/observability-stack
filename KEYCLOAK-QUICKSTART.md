# 🔐 Keycloak - Guía Rápida de Configuración

Esta es una guía visual simplificada para configurar Keycloak. Para detalles completos, ver **KEYCLOAK-SETUP.md**.

---

## ⚡ Quick Start (20 minutos)

### Paso 1: Acceder a Keycloak

```bash
# Verificar que Keycloak está corriendo
make health

# Abrir Keycloak UI
make keycloak-ui
```

**O manualmente:**

- URL: <http://localhost:8090>
- Username: `admin`
- Password: `admin`

---

### Paso 2: Crear Realm "observability"

#### 2.1 Click en el dropdown superior izquierdo

```
┌─────────────────────────────────┐
│  master ▼                       │  ← Click aquí
├─────────────────────────────────┤
│  [ Create Realm ]               │  ← Luego aquí
└─────────────────────────────────┘
```

#### 2.2 Completar formulario

```
Realm name: observability
Enabled: [x] ON
```

#### 2.3 Click "Create"

✅ **Verificar:** En el dropdown superior ahora debe decir "observability"

---

### Paso 3: Crear Client "agent-pe"

#### 3.1 Menú lateral → Clients

```
┌─────────────────┐
│ Realm settings  │
│ Clients         │  ← Click aquí
│ Client scopes   │
│ Roles           │
│ Users           │
└─────────────────┘
```

#### 3.2 Click botón "Create client"

#### 3.3 General Settings

```
Client type:     OpenID Connect
Client ID:       agent-pe
Name:            Agent Peru
Description:     Service account for Peru tenant agent
```

Click **"Next"**

#### 3.4 Capability config

```
Client authentication:  [x] ON
Authorization:          [ ] OFF

Authentication flow:
  [x] Service accounts roles  ← Solo este habilitado
  [ ] Standard flow
  [ ] Direct access grants
  [ ] Implicit flow
  [ ] OAuth 2.0 Device Authorization Grant
  [ ] OIDC CIBA Grant
```

Click **"Save"**

✅ **Verificar:** El client `agent-pe` aparece en la lista de clients

---

### Paso 4: Agregar Mapper "tenant_id"

#### 4.1 En el client `agent-pe` → Tab "Client scopes"

```
┌────────────────────────────────────────┐
│ Settings | Client scopes | ...        │
│                           ↑            │
│                       Click aquí       │
└────────────────────────────────────────┘
```

#### 4.2 Click en scope dedicado `agent-pe-dedicated`

```
Client scopes:
  agent-pe-dedicated    ← Click aquí
  email
  profile
  ...
```

#### 4.3 Tab "Mappers" → Click "Add mapper" → "By configuration"

#### 4.4 Seleccionar "Hardcoded claim"

#### 4.5 Configurar el mapper

```
Name:              tenant-id-claim
Mapper Type:       Hardcoded claim
Token Claim Name:  tenant_id
Claim value:       tenant-pe
Claim JSON Type:   String

Add to ID token:       [x] ON
Add to access token:   [x] ON
Add to userinfo:       [x] ON
```

Click **"Save"**

✅ **Verificar:** En la lista de mappers aparece `tenant-id-claim`

---

### Paso 5: Obtener Client Secret

#### 5.1 En el client `agent-pe` → Tab "Credentials"

```
┌────────────────────────────────────────┐
│ Settings | Credentials | ...          │
│                ↑                       │
│            Click aquí                  │
└────────────────────────────────────────┘
```

#### 5.2 Copiar el "Client secret"

```
Client Authenticator: Client Id and Secret
Client secret: a1b2c3d4-e5f6-7890-abcd-ef1234567890
                ↑
            Copiar este valor
```

📋 **Guardar este secret** para configurar el agent

---

### Paso 6: Repetir para otros tenants

Crear dos clients más siguiendo los mismos pasos:

#### Client: agent-mx

```
Client ID:    agent-mx
Name:         Agent Mexico
Claim value:  tenant-mx    ← Cambiar esto
```

#### Client: agent-co

```
Client ID:    agent-co
Name:         Agent Colombia
Claim value:  tenant-co    ← Cambiar esto
```

📋 **Guardar los 3 client secrets:**

```
agent-pe: <secret-1>
agent-mx: <secret-2>
agent-co: <secret-3>
```

---

## 🧪 Testing de Keycloak

### Test 1: Verificar Realm

```bash
make test-keycloak
```

**Output esperado:**

```
✅ Keycloak is healthy
✅ Realm 'observability' exists
```

### Test 2: Obtener Token de agent-pe

Primero, configurar el agent:

```bash
cd agent
nano .env
```

Agregar al final:

```env
KEYCLOAK_URL=http://172.17.0.1:8090
KEYCLOAK_REALM=observability
KEYCLOAK_CLIENT_ID=agent-pe
KEYCLOAK_CLIENT_SECRET=<pegar_secret_de_paso_5>
```

Guardar y ejecutar:

```bash
./get-token.sh
```

**Output esperado:**

```
🔐 Obteniendo token JWT de Keycloak...
   URL: http://172.17.0.1:8090
   Realm: observability
   Client: agent-pe

✅ Token obtenido exitosamente
   Expira en: 300 segundos

📋 Información del token:
{
  "exp": 1234567890,
  "iat": 1234567590,
  "iss": "http://localhost:8090/realms/observability",
  "azp": "agent-pe",
  "tenant_id": "tenant-pe",    ← ¡Importante!
  "clientId": "agent-pe"
}

🏢 Tenant ID: tenant-pe
💾 Token guardado en: /tmp/keycloak-token.txt
```

✅ **Verificar:** El campo `tenant_id` debe ser `tenant-pe`

### Test 3: Validar con Auth Service

```bash
make test-auth-service
```

**Output esperado:**

```
🧪 Testing auth service...
✅ Auth service is healthy

Testing JWT validation...
{
  "headers": {
    "x-scope-orgid": "tenant-pe",
    "x-user-id": "service-account-agent-pe"
  }
}
```

✅ **Verificar:** El header `x-scope-orgid` debe tener el valor `tenant-pe`

---

## ✅ Checklist de Configuración

Marca cada paso al completarlo:

### En Keycloak UI

- [ ] Acceso a <http://localhost:8090> (admin/admin)
- [ ] Realm "observability" creado
- [ ] Client "agent-pe" creado con service account
- [ ] Mapper "tenant-id-claim" agregado (tenant-pe)
- [ ] Client secret de agent-pe copiado
- [ ] Client "agent-mx" creado con mapper (tenant-mx)
- [ ] Client secret de agent-mx copiado
- [ ] Client "agent-co" creado con mapper (tenant-co)
- [ ] Client secret de agent-co copiado

### En Agent

- [ ] Archivo `agent/.env` actualizado con:
  - [ ] KEYCLOAK_URL
  - [ ] KEYCLOAK_REALM
  - [ ] KEYCLOAK_CLIENT_ID
  - [ ] KEYCLOAK_CLIENT_SECRET

### Testing

- [ ] `make test-keycloak` pasa
- [ ] `./agent/get-token.sh` obtiene token con tenant_id
- [ ] `make test-auth-service` retorna x-scope-orgid correcto
- [ ] Agent reiniciado: `make stop-agent && make start-agent`
- [ ] Logs visibles en Grafana (datasource loki-pe)

---

## 🐛 Troubleshooting

### Error: "Realm not found"

**Causa:** El realm "observability" no existe o estás en el realm "master"

**Solución:**

1. Verificar dropdown superior izquierdo (debe decir "observability")
2. Si dice "master", crear el realm "observability"

### Error: "Invalid client credentials"

**Causa:** El client secret es incorrecto o el client no existe

**Solución:**

1. Ir a Clients → agent-pe → Credentials
2. Copiar el secret nuevamente
3. Actualizar `agent/.env` con el secret correcto
4. Reiniciar agent: `make stop-agent && make start-agent`

### Token no incluye tenant_id

**Causa:** El mapper no está configurado o está en el scope incorrecto

**Solución:**

1. Ir a Clients → agent-pe → Client scopes
2. Click en `agent-pe-dedicated` (no "agent-pe")
3. Verificar que el mapper existe
4. Verificar que "Add to access token" está ON
5. Obtener nuevo token: `./agent/get-token.sh`

### "Connection refused" al obtener token

**Causa:** Keycloak no está accesible desde el host

**Solución:**

1. Verificar que Keycloak está corriendo: `docker ps | grep keycloak`
2. Verificar puerto: debe ser 8090 (no 8080)
3. Test: `curl http://localhost:8090/health`
4. Si usa Docker Desktop en Windows/Mac: usar `host.docker.internal` en lugar de `172.17.0.1`

---

## 📋 Resumen de Valores

Para referencia rápida:

```yaml
Keycloak:
  URL: http://localhost:8090
  Admin user: admin
  Admin password: admin
  Realm: observability

Clients:
  agent-pe:
    Client ID: agent-pe
    Tenant ID: tenant-pe
    Secret: <obtener de Keycloak UI>

  agent-mx:
    Client ID: agent-mx
    Tenant ID: tenant-mx
    Secret: <obtener de Keycloak UI>

  agent-co:
    Client ID: agent-co
    Tenant ID: tenant-co
    Secret: <obtener de Keycloak UI>

Agent .env:
  KEYCLOAK_URL: http://172.17.0.1:8090
  KEYCLOAK_REALM: observability
  KEYCLOAK_CLIENT_ID: agent-pe
  KEYCLOAK_CLIENT_SECRET: <obtener de Keycloak UI>
```

---

## 🎯 Siguiente Paso

Una vez completada esta configuración:

```bash
# Verificar configuración completa
make health
make test-keycloak
make get-token
make test-auth-service

# Si todo pasa ✅
make grafana-ui
# Explorer → Datasource: loki → Query: {service_name="alloy-agent"}
```

¡Deberías ver logs del agent con el tenant correcto! 🎉

---

**Tiempo estimado:** 20 minutos
**Dificultad:** Fácil (solo UI clicks)
**Documentación completa:** KEYCLOAK-SETUP.md
