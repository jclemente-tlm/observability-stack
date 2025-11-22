#!/bin/bash
#
# Script para importar el realm 'observability' en Keycloak
# Uso: ./import-realm.sh
#

set -e

echo "🔐 Importando realm 'observability' en Keycloak..."
echo ""

# Configuración
KEYCLOAK_URL=${KEYCLOAK_URL:-http://localhost:8090}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-admin}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-admin}
REALM_FILE="gateway/keycloak/observability-realm.json"

# Verificar que el archivo existe
if [ ! -f "$REALM_FILE" ]; then
    echo "❌ Error: Archivo $REALM_FILE no encontrado"
    exit 1
fi

# Verificar que Keycloak está corriendo
echo "📡 Verificando conectividad con Keycloak..."
if ! curl -sf "$KEYCLOAK_URL/health" > /dev/null; then
    echo "❌ Error: Keycloak no está accesible en $KEYCLOAK_URL"
    echo "   Asegúrate de que el gateway está corriendo: make start-gateway"
    exit 1
fi
echo "✅ Keycloak está respondiendo"
echo ""

# Obtener token de administrador
echo "🔑 Obteniendo token de administrador..."
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KEYCLOAK_ADMIN" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
    echo "❌ Error: No se pudo obtener token de administrador"
    echo "   Verifica las credenciales: KEYCLOAK_ADMIN=$KEYCLOAK_ADMIN"
    exit 1
fi
echo "✅ Token obtenido"
echo ""

# Verificar si el realm ya existe
echo "🔍 Verificando si el realm 'observability' ya existe..."
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
    "$KEYCLOAK_URL/admin/realms/observability" \
    -H "Authorization: Bearer $ADMIN_TOKEN")

if [ "$REALM_EXISTS" = "200" ]; then
    echo "⚠️  El realm 'observability' ya existe"
    read -p "¿Deseas eliminarlo y reimportarlo? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Eliminando realm existente..."
        curl -s -X DELETE "$KEYCLOAK_URL/admin/realms/observability" \
            -H "Authorization: Bearer $ADMIN_TOKEN"
        echo "✅ Realm eliminado"
    else
        echo "❌ Importación cancelada"
        exit 0
    fi
fi
echo ""

# Importar el realm
echo "📦 Importando realm desde $REALM_FILE..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d @"$REALM_FILE")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "204" ]; then
    echo "✅ Realm importado exitosamente"
else
    echo "❌ Error al importar realm (HTTP $HTTP_CODE)"
    echo "$BODY" | jq 2>/dev/null || echo "$BODY"
    exit 1
fi
echo ""

# Generar nuevos secrets para los clients
echo "🔑 Generando secrets para los clients..."
echo ""

for CLIENT_ID in agent-pe agent-mx agent-co; do
    echo "  📝 Client: $CLIENT_ID"

    # Obtener el ID interno del client
    INTERNAL_ID=$(curl -s "$KEYCLOAK_URL/admin/realms/observability/clients" \
        -H "Authorization: Bearer $ADMIN_TOKEN" | \
        jq -r ".[] | select(.clientId==\"$CLIENT_ID\") | .id")

    if [ -z "$INTERNAL_ID" ]; then
        echo "     ❌ Error: No se pudo encontrar el client"
        continue
    fi

    # Regenerar secret
    curl -s -X POST "$KEYCLOAK_URL/admin/realms/observability/clients/$INTERNAL_ID/client-secret" \
        -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null

    # Obtener el nuevo secret
    SECRET=$(curl -s "$KEYCLOAK_URL/admin/realms/observability/clients/$INTERNAL_ID/client-secret" \
        -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.value')

    echo "     🔐 Secret: $SECRET"

    # Guardar en archivo temporal
    echo "$CLIENT_ID=$SECRET" >> /tmp/keycloak-secrets.txt
done

echo ""
echo "💾 Secrets guardados en: /tmp/keycloak-secrets.txt"
echo ""

# Mostrar instrucciones
cat << 'EOF'
✨ ¡Realm importado exitosamente!

📋 Próximos pasos:

1. Configurar agent/.env con los secrets:

   cd agent
   nano .env

   # Agregar:
   KEYCLOAK_URL=http://172.17.0.1:8090
   KEYCLOAK_REALM=observability
   KEYCLOAK_CLIENT_ID=agent-pe
   KEYCLOAK_CLIENT_SECRET=<usar_secret_de_arriba>

2. Obtener token JWT:

   ./get-token.sh

3. Verificar que funciona:

   make test-auth-service

4. Ver en Keycloak UI:

   make keycloak-ui
   # Login: admin/admin
   # Realm: observability (cambiar en dropdown)

📚 Clients configurados:
   - agent-pe  (tenant-pe)
   - agent-mx  (tenant-mx)
   - agent-co  (tenant-co)

✅ Todos los clients tienen:
   - Service accounts habilitados
   - Mapper "tenant-id-claim" configurado
   - Token lifespan: 5 minutos

EOF

# Limpiar
unset ADMIN_TOKEN
