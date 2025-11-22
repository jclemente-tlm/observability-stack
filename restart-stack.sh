#!/bin/bash

set -e

echo "=========================================="
echo "Reinicio completo del Observability Stack"
echo "=========================================="
echo ""

# Función para esperar con progreso
wait_with_progress() {
    local seconds=$1
    local message=$2
    echo -n "$message"
    for ((i=1; i<=$seconds; i++)); do
        sleep 1
        echo -n "."
    done
    echo " ✓"
}

echo "Paso 1: Deteniendo todos los servicios..."
cd /mnt/d/dev/work/talma/observability-stack

echo "  - Deteniendo tests..."
cd tests && docker compose -f docker-compose.tests.yml down 2>/dev/null || true

echo "  - Deteniendo agent..."
cd ../agent && docker compose down 2>/dev/null || true

echo "  - Deteniendo gateway..."
cd ../gateway && docker compose down 2>/dev/null || true

echo ""
echo "Paso 2: Iniciando Gateway..."
cd /mnt/d/dev/work/talma/observability-stack/gateway
docker compose up -d

wait_with_progress 15 "  Esperando a que los servicios del gateway estén listos"

echo ""
echo "Paso 3: Verificando configuración del Gateway..."
GATEWAY_TENANT=$(docker exec observability-alloy-gateway env 2>/dev/null | grep TENANT_ID | cut -d'=' -f2)
if [ -z "$GATEWAY_TENANT" ]; then
    echo "  ✗ ERROR: Variable TENANT_ID no encontrada en gateway"
    echo "  Agregando variable y reiniciando..."
    docker compose restart alloy-gateway
    sleep 5
    GATEWAY_TENANT=$(docker exec observability-alloy-gateway env 2>/dev/null | grep TENANT_ID | cut -d'=' -f2)
fi
echo "  ✓ Gateway TENANT_ID: $GATEWAY_TENANT"

echo ""
echo "Paso 4: Verificando backends..."
echo -n "  - Mimir: "
curl -s -o /dev/null -w "%{http_code}" "http://localhost:9009/ready" | grep -q "200" && echo "✓ OK" || echo "✗ Error"

echo -n "  - Loki: "
curl -s -o /dev/null -w "%{http_code}" "http://localhost:3100/ready" | grep -q "200" && echo "✓ OK" || echo "✗ Error"

echo -n "  - Tempo: "
curl -s -o /dev/null -w "%{http_code}" "http://localhost:3200/ready" | grep -q "200" && echo "✓ OK" || echo "✗ Error"

echo -n "  - Grafana: "
curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/api/health" | grep -q "200" && echo "✓ OK" || echo "✗ Error"

echo ""
echo "Paso 5: Iniciando Agent..."
cd /mnt/d/dev/work/talma/observability-stack/agent
docker compose up -d

wait_with_progress 10 "  Esperando a que el agent esté listo"

AGENT_TENANT=$(docker exec observability-agent-alloy-agent env 2>/dev/null | grep TENANT_ID | cut -d'=' -f2)
echo "  ✓ Agent TENANT_ID: $AGENT_TENANT"

echo ""
echo "Paso 6: Esperando a que fluyan datos..."
wait_with_progress 20 "  Dando tiempo para scraping inicial"

echo ""
echo "Paso 7: Verificando datos en Mimir..."
METRICS_COUNT=$(curl -s "http://localhost:9009/prometheus/api/v1/query?query=up" -H "X-Scope-OrgID: $GATEWAY_TENANT" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(len(data.get('data', {}).get('result', [])))
except:
    print('0')
" 2>/dev/null || echo "0")

if [ "$METRICS_COUNT" -gt "0" ]; then
    echo "  ✓ Métricas encontradas en Mimir: $METRICS_COUNT series"
else
    echo "  ⚠ No se encontraron métricas aún (pueden tardar ~30s en aparecer)"
fi

echo ""
echo "Paso 8: Ejecutando tests para generar tráfico..."
cd /mnt/d/dev/work/talma/observability-stack
make test 2>&1 | tail -10

echo ""
echo "Paso 9: Verificación final..."
sleep 5

# Verificar métricas
FINAL_METRICS=$(curl -s "http://localhost:9009/prometheus/api/v1/query?query=up" -H "X-Scope-OrgID: $GATEWAY_TENANT" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(len(data.get('data', {}).get('result', [])))
except:
    print('0')
" 2>/dev/null || echo "0")

echo ""
echo "=========================================="
echo "RESUMEN:"
echo "=========================================="
echo "Gateway Tenant: $GATEWAY_TENANT"
echo "Agent Tenant:   $AGENT_TENANT"
echo "Métricas en Mimir: $FINAL_METRICS series"
echo ""
echo "Acceso a Grafana:"
echo "  URL:      http://localhost:3000"
echo "  Usuario:  admin"
echo "  Password: admin"
echo ""
echo "Query de prueba en Explore:"
echo "  up{tenant_id=\"$GATEWAY_TENANT\"}"
echo "=========================================="
echo ""

if [ "$FINAL_METRICS" -gt "5" ]; then
    echo "✓✓✓ Stack funcionando correctamente ✓✓✓"
else
    echo "⚠ ADVERTENCIA: Pocas métricas detectadas"
    echo ""
    echo "Para diagnóstico detallado, ejecuta:"
    echo "  bash diagnose.sh"
fi
