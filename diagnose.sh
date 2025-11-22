#!/bin/bash

echo "========================================"
echo "Diagnóstico completo del stack"
echo "========================================"
echo ""

echo "1. Estado de contenedores:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "observability|NAMES"

echo ""
echo "2. Verificando variable TENANT_ID en gateway:"
docker exec observability-alloy-gateway env | grep TENANT_ID || echo "✗ Variable TENANT_ID no encontrada"

echo ""
echo "3. Verificando variable TENANT_ID en agent:"
docker exec observability-agent-alloy-agent env | grep TENANT_ID || echo "✗ Variable TENANT_ID no encontrada"

echo ""
echo "4. Últimas 10 líneas de logs del gateway:"
docker logs observability-alloy-gateway --tail 10 2>&1

echo ""
echo "5. Últimas 10 líneas de logs del agent:"
docker logs observability-agent-alloy-agent --tail 10 2>&1

echo ""
echo "6. Verificando si Mimir está escuchando:"
curl -s -o /dev/null -w "Status: %{http_code}\n" "http://localhost:9009/prometheus/api/v1/query?query=up" -H "X-Scope-OrgID: tenant-pe"

echo ""
echo "7. Verificando si Loki está escuchando:"
curl -s -o /dev/null -w "Status: %{http_code}\n" "http://localhost:3100/loki/api/v1/labels" -H "X-Scope-OrgID: tenant-pe"

echo ""
echo "8. Verificando si Tempo está escuchando:"
curl -s -o /dev/null -w "Status: %{http_code}\n" "http://localhost:3200/api/search/tags" -H "X-Scope-OrgID: tenant-pe"

echo ""
echo "9. Probando query en Mimir:"
curl -s "http://localhost:9009/prometheus/api/v1/query?query=up" -H "X-Scope-OrgID: tenant-pe" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('status') == 'success':
        results = data.get('data', {}).get('result', [])
        print(f'✓ Mimir respondió con {len(results)} series')
        if results:
            print(f'  Ejemplo: {results[0].get(\"metric\", {})}')
    else:
        print(f'✗ Error: {data}')
except Exception as e:
    print(f'✗ Error parseando: {e}')
"

echo ""
echo "10. Verificando conexión gateway → mimir:"
docker exec observability-alloy-gateway wget -qO- http://mimir:9009/ready 2>/dev/null && echo "✓ Gateway puede conectar a Mimir" || echo "✗ Gateway no puede conectar a Mimir"

echo ""
echo "========================================"
echo "Fin del diagnóstico"
echo "========================================"
