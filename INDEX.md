# 📚 Documentación - Observability Stack Multi-Tenant

Índice completo de la documentación del proyecto.

---

## 🚀 Inicio Rápido

### Para nuevos usuarios

1. **[README.md](./README.md)** - Empieza aquí
   - Visión general del proyecto
   - Arquitectura completa
   - Quick Start Guide
   - Comandos básicos

2. **[RESUMEN-EJECUTIVO.md](./RESUMEN-EJECUTIVO.md)** - Resumen del estado actual
   - ¿Qué se ha completado?
   - ¿Qué falta por hacer?
   - Próximos pasos
   - 5 minutos de lectura

3. **[KEYCLOAK-QUICKSTART.md](./KEYCLOAK-QUICKSTART.md)** - Configuración rápida
   - Guía visual paso a paso
   - 20 minutos para completar
   - Checklist incluida

### Para empezar a trabajar

```bash
# Ver comandos disponibles
make help

# Verificar estado
make health

# Iniciar gateway
make start-gateway

# Iniciar agent
make start-agent
```

---

## 📖 Documentación por Tema

### 🏗️ Arquitectura

| Documento | Descripción | Audiencia |
|-----------|-------------|-----------|
| **[README.md](./README.md)** | Arquitectura general, componentes, flujo de datos | Todos |
| **[README-MULTI-TENANT.md](./README-MULTI-TENANT.md)** | Arquitectura multi-tenant, datasources, labels | Desarrolladores |
| **[ESTADO-ACTUAL.md](./ESTADO-ACTUAL.md)** | Estado detallado del proyecto, flujos técnicos | DevOps, Arquitectos |

### 🔐 Autenticación y Seguridad

| Documento | Descripción | Tiempo |
|-----------|-------------|--------|
| **[KEYCLOAK-QUICKSTART.md](./KEYCLOAK-QUICKSTART.md)** | Guía rápida con pasos visuales | 20 min |
| **[KEYCLOAK-SETUP.md](./KEYCLOAK-SETUP.md)** | Guía completa con troubleshooting | 45 min |
| `gateway/auth-service/auth_service.py` | Código del servicio de autenticación | - |

### 🛠️ Operación y Mantenimiento

| Recurso | Descripción | Uso |
|---------|-------------|-----|
| **[Makefile](./Makefile)** | 30+ comandos útiles | `make help` |
| `agent/get-token.sh` | Obtener JWT tokens | `./get-token.sh` |
| **[notas.txt](./notas.txt)** | Notas de desarrollo y troubleshooting | Referencia |

### 📊 Configuración

| Archivo | Propósito | Ubicación |
|---------|-----------|-----------|
| `gateway/docker-compose.yml` | Stack del gateway | `gateway/` |
| `agent/docker-compose.yml` | Stack del agent | `agent/` |
| `gateway/envoy/envoy.yaml` | Configuración de Envoy | `gateway/envoy/` |
| `gateway/alloy-gateway/config.alloy` | Configuración del gateway | `gateway/alloy-gateway/` |
| `agent/alloy-agent/config.alloy` | Configuración del agent | `agent/alloy-agent/` |

---

## 🎯 Documentos por Caso de Uso

### "Quiero entender qué hace este proyecto"
1. Leer **[README.md](./README.md)** → Sección "Arquitectura"
2. Ver **[RESUMEN-EJECUTIVO.md](./RESUMEN-EJECUTIVO.md)** → Sección "Solución al Problema"

### "Quiero configurar Keycloak"
1. Leer **[KEYCLOAK-QUICKSTART.md](./KEYCLOAK-QUICKSTART.md)** (20 min)
2. Seguir checklist
3. Si hay problemas, consultar **[KEYCLOAK-SETUP.md](./KEYCLOAK-SETUP.md)** → Sección "Troubleshooting"

### "Quiero agregar un nuevo tenant"
1. Leer **[README-MULTI-TENANT.md](./README-MULTI-TENANT.md)** → Sección "Agregar Nuevo Tenant"
2. Crear client en Keycloak (ver **[KEYCLOAK-SETUP.md](./KEYCLOAK-SETUP.md)**)
3. Agregar datasources en Grafana
4. Actualizar `.env` del agent

### "Quiero troubleshootear un problema"
1. Verificar health: `make health`
2. Ver logs: `make logs-gateway` o `make logs-agent`
3. Consultar **[README-MULTI-TENANT.md](./README-MULTI-TENANT.md)** → Sección "Troubleshooting"
4. Consultar **[notas.txt](./notas.txt)**

### "Quiero preparar el stack para producción"
1. Leer **[ESTADO-ACTUAL.md](./ESTADO-ACTUAL.md)** → Sección "Cuestiones Pendientes"
2. Implementar token refresh (Opción B: Sidecar)
3. Configurar rate limiting (ver **[README-MULTI-TENANT.md](./README-MULTI-TENANT.md)**)
4. Habilitar mTLS
5. Setup de High Availability

---

## 🗂️ Estructura de Documentación

```
observability-stack/
├── README.md                       ← Inicio aquí
├── INDEX.md                        ← Este archivo
├── RESUMEN-EJECUTIVO.md            ← Estado y próximos pasos
├── ESTADO-ACTUAL.md                ← Estado técnico detallado
├── README-MULTI-TENANT.md          ← Arquitectura multi-tenant
├── KEYCLOAK-QUICKSTART.md          ← Guía rápida Keycloak
├── KEYCLOAK-SETUP.md               ← Guía completa Keycloak
├── Makefile                        ← Comandos (make help)
├── notas.txt                       ← Notas de desarrollo
│
├── gateway/
│   ├── docker-compose.yml          ← Orquestación gateway
│   ├── envoy/
│   │   └── envoy.yaml              ← Config Envoy proxy
│   ├── alloy-gateway/
│   │   └── config.alloy            ← Config Alloy gateway
│   ├── auth-service/
│   │   ├── auth_service.py         ← Servicio de autenticación
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── grafana/
│       └── provisioning/
│           └── datasources/
│               └── datasources.yaml ← 13 datasources
│
└── agent/
    ├── docker-compose.yml          ← Orquestación agent
    ├── .env                        ← Variables de entorno
    ├── get-token.sh                ← Script JWT testing
    └── alloy-agent/
        └── config.alloy            ← Config Alloy agent
```

---

## 📝 Orden de Lectura Recomendado

### Para Developers
1. README.md
2. README-MULTI-TENANT.md
3. gateway/alloy-gateway/config.alloy
4. agent/alloy-agent/config.alloy

### Para DevOps
1. README.md
2. KEYCLOAK-QUICKSTART.md
3. Makefile (make help)
4. gateway/docker-compose.yml

### Para Arquitectos
1. README.md
2. ESTADO-ACTUAL.md
3. README-MULTI-TENANT.md
4. gateway/envoy/envoy.yaml
5. gateway/auth-service/auth_service.py

### Para Security
1. KEYCLOAK-SETUP.md
2. gateway/auth-service/auth_service.py
3. gateway/envoy/envoy.yaml
4. ESTADO-ACTUAL.md → Sección "Seguridad"

---

## 🔍 Búsqueda Rápida

### Por Componente

- **Envoy:** `gateway/envoy/envoy.yaml`, README-MULTI-TENANT.md
- **Auth Service:** `gateway/auth-service/`, KEYCLOAK-SETUP.md
- **Keycloak:** KEYCLOAK-QUICKSTART.md, KEYCLOAK-SETUP.md
- **Alloy Gateway:** `gateway/alloy-gateway/config.alloy`, README-MULTI-TENANT.md
- **Alloy Agent:** `agent/alloy-agent/config.alloy`, README-MULTI-TENANT.md
- **Grafana:** `gateway/grafana/provisioning/`, README.md
- **Mimir:** `gateway/mimir/config.yaml`, README-MULTI-TENANT.md
- **Loki:** `gateway/loki/config.yaml`, README-MULTI-TENANT.md
- **Tempo:** `gateway/tempo/config.yaml`, README-MULTI-TENANT.md

### Por Concepto

- **Multi-tenancy:** README-MULTI-TENANT.md, ESTADO-ACTUAL.md
- **JWT Authentication:** KEYCLOAK-SETUP.md, gateway/auth-service/
- **OTLP Protocol:** README.md, gateway/alloy-gateway/config.alloy
- **Datasources:** gateway/grafana/provisioning/datasources/datasources.yaml
- **Labels:** README-MULTI-TENANT.md → Sección "Labels Estándar"
- **Troubleshooting:** README-MULTI-TENANT.md, notas.txt

---

## 🧪 Scripts y Herramientas

| Script | Descripción | Uso |
|--------|-------------|-----|
| `make help` | Ver todos los comandos | `make help` |
| `make health` | Health check completo | `make health` |
| `make start-gateway` | Iniciar gateway | `make start-gateway` |
| `make start-agent` | Iniciar agent | `make start-agent` |
| `make keycloak-ui` | Abrir Keycloak UI | `make keycloak-ui` |
| `make grafana-ui` | Abrir Grafana UI | `make grafana-ui` |
| `make get-token` | Obtener JWT token | `make get-token` |
| `make test-keycloak` | Test de Keycloak | `make test-keycloak` |
| `make test-auth-service` | Test del auth service | `make test-auth-service` |
| `make check-tenants` | Verificar aislamiento | `make check-tenants` |
| `make logs-gateway` | Ver logs del gateway | `make logs-gateway` |
| `make logs-agent` | Ver logs del agent | `make logs-agent` |
| `agent/get-token.sh` | Obtener JWT manualmente | `cd agent && ./get-token.sh` |

---

## 📊 Estadísticas de Documentación

| Métrica | Valor |
|---------|-------|
| **Documentos totales** | 8 principales |
| **Líneas de documentación** | ~1,500 |
| **Líneas de código** | ~800 |
| **Comandos Make** | 30+ |
| **Tiempo de lectura total** | ~2 horas |
| **Tiempo de configuración** | ~40 minutos |

---

## 🎯 Rutas de Aprendizaje

### Ruta 1: Quick Start (30 min)
```
README.md (Overview)
  → KEYCLOAK-QUICKSTART.md (Setup)
  → make get-token (Testing)
  → Grafana UI (Verificación)
```

### Ruta 2: Arquitectura Completa (1 hora)
```
README.md
  → README-MULTI-TENANT.md
  → ESTADO-ACTUAL.md
  → gateway/alloy-gateway/config.alloy
  → gateway/envoy/envoy.yaml
```

### Ruta 3: Seguridad y Auth (45 min)
```
KEYCLOAK-SETUP.md
  → gateway/auth-service/auth_service.py
  → gateway/envoy/envoy.yaml (ext_authz)
  → ESTADO-ACTUAL.md (Seguridad)
```

### Ruta 4: Operación (30 min)
```
Makefile (make help)
  → agent/get-token.sh
  → notas.txt
  → README-MULTI-TENANT.md (Troubleshooting)
```

---

## 💡 Tips de Navegación

### Buscar en toda la documentación
```bash
# Buscar un término
grep -r "multi-tenant" *.md

# Buscar en configuraciones
grep -r "X-Scope-OrgID" gateway/ agent/

# Ver estructura de archivos
tree -L 2 -I 'node_modules|bin|obj'
```

### Enlaces útiles (localhost)
- Grafana: http://localhost:3000
- Keycloak: http://localhost:8090
- Envoy Admin: http://localhost:9901
- Alloy Gateway UI: http://localhost:5000
- Alloy Agent UI: http://localhost:25000

---

## 📞 Contacto y Soporte

### Preguntas Frecuentes

**Q: ¿Por dónde empiezo?**
A: Leer [README.md](./README.md) → [KEYCLOAK-QUICKSTART.md](./KEYCLOAK-QUICKSTART.md) → `make get-token`

**Q: ¿Cómo agrego un nuevo tenant?**
A: Ver [README-MULTI-TENANT.md](./README-MULTI-TENANT.md) sección "Agregar Nuevo Tenant"

**Q: ¿Qué falta por hacer?**
A: Ver [RESUMEN-EJECUTIVO.md](./RESUMEN-EJECUTIVO.md) sección "Trabajo Pendiente"

**Q: ¿Cómo troubleshooteo?**
A: `make health` → `make logs-gateway` → Consultar [README-MULTI-TENANT.md](./README-MULTI-TENANT.md) Troubleshooting

**Q: ¿Está listo para producción?**
A: 80% completo. Ver [ESTADO-ACTUAL.md](./ESTADO-ACTUAL.md) → "Próximos Pasos"

---

## 🚀 Próximos Pasos

Dependiendo de tu rol:

- **Developer:** Leer README.md + README-MULTI-TENANT.md
- **DevOps:** Configurar Keycloak (KEYCLOAK-QUICKSTART.md)
- **Arquitecto:** Revisar ESTADO-ACTUAL.md
- **Security:** Revisar KEYCLOAK-SETUP.md + auth_service.py

**Todos:** Ejecutar `make health` para verificar el estado actual.

---

**Última actualización:** Enero 2025
**Versión de documentación:** v1.0.0
