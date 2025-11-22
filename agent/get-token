#!/bin/bash
#
# Script para obtener JWT token de Keycloak
# Uso: ./get-token.sh
#
# Requisitos:
#   - Variables de entorno: KEYCLOAK_URL, KEYCLOAK_REALM, KEYCLOAK_CLIENT_ID, KEYCLOAK_CLIENT_SECRET
#   - Herramientas: curl, jq
#

set -e

# Cargar variables desde .env si existe
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Configuración
KEYCLOAK_URL=${KEYCLOAK_URL:-http://172.17.0.1:8090}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-observability}
KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID}
KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET}

# Validar variables requeridas
if [ -z "$KEYCLOAK_CLIENT_ID" ] || [ -z "$KEYCLOAK_CLIENT_SECRET" ]; then
    echo "Error: KEYCLOAK_CLIENT_ID y KEYCLOAK_CLIENT_SECRET son requeridos"
    echo "Configurarlos en el archivo .env o como variables de entorno"
    exit 1
fi

echo "🔐 Obteniendo token JWT de Keycloak..."
echo "   URL: $KEYCLOAK_URL"
echo "   Realm: $KEYCLOAK_REALM"
echo "   Client: $KEYCLOAK_CLIENT_ID"
echo ""

# Obtener token
RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "client_id=$KEYCLOAK_CLIENT_ID" \
    -d "client_secret=$KEYCLOAK_CLIENT_SECRET")

# Verificar si hubo error
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "❌ Error al obtener token:"
    echo "$RESPONSE" | jq
    exit 1
fi

# Extraer access token
ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
EXPIRES_IN=$(echo "$RESPONSE" | jq -r '.expires_in')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ No se pudo extraer el access_token"
    echo "$RESPONSE" | jq
    exit 1
fi

echo "✅ Token obtenido exitosamente"
echo "   Expira en: ${EXPIRES_IN} segundos"
echo ""

# Decodificar el payload del JWT para verificar tenant_id
echo "📋 Información del token:"
PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null || echo "{}")
echo "$PAYLOAD" | jq '.'

# Extraer tenant_id si existe
TENANT_ID=$(echo "$PAYLOAD" | jq -r '.tenant_id // "N/A"')
echo ""
echo "🏢 Tenant ID: $TENANT_ID"

# Guardar token en archivo temporal (útil para testing)
echo "$ACCESS_TOKEN" > /tmp/keycloak-token.txt
echo ""
echo "💾 Token guardado en: /tmp/keycloak-token.txt"

# Mostrar header de autorización
echo ""
echo "📤 Header para usar en requests OTLP:"
echo "Authorization: Bearer $ACCESS_TOKEN"
echo ""

# Opcional: probar el token con el auth service
if command -v nc &> /dev/null; then
    if nc -z localhost 8000 2>/dev/null; then
        echo "🧪 Probando token con auth service..."
        AUTH_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8000/authz \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Content-Type: application/json")

        HTTP_CODE=$(echo "$AUTH_RESPONSE" | tail -n1)
        BODY=$(echo "$AUTH_RESPONSE" | head -n-1)

        if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ Auth service validó el token correctamente"
            echo "   Headers retornados:"
            echo "$BODY" | jq -r '.headers | to_entries[] | "   - \(.key): \(.value)"' 2>/dev/null || echo "$BODY"
        else
            echo "⚠️  Auth service retornó código: $HTTP_CODE"
            echo "$BODY"
        fi
    fi
fi

echo ""
echo "✨ Listo! Puedes usar este token en tus requests OTLP"
