#!/bin/bash

echo "=========================================="
echo "Validación de Tenant Dinámico"
echo "=========================================="
echo ""

echo "1. Verificando configuración del Agent..."
docker logs observability-agent-alloy-agent 2>&1 | tail -5 | grep -q "level=info" && echo "✓ Agent corriendo" || echo "✗ Agent con problemas"

echo ""
echo "2. Verificando configuración del Gateway..."
docker logs observability-alloy-gateway 2>&1 | tail -5 | grep -q "level=info" && echo "✓ Gateway corriendo" || echo "✗ Gateway con problemas"

echo ""
echo "3. Consultando métricas en Mimir con tenant 'tenant-pe'..."
METRICS=$(curl -s "http://localhost:9009/prometheus/api/v1/query?query=up{tenant_id='tenant-pe'}" -H "X-Scope-OrgID: tenant-pe" 2>&1)
echo "$METRICS" | grep -q '"status":"success"' && echo "✓ Mimir respondiendo" || echo "✗ Error en Mimir"
echo "$METRICS" | grep -q '"result":\[' && echo "  Métricas encontradas" || echo "  Sin métricas aún"

echo ""
echo "4. Listando series con tenant_id en Mimir..."
curl -s "http://localhost:9009/prometheus/api/v1/series?match[]=up" -H "X-Scope-OrgID: tenant-pe" 2>&1 | \
  python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data['status'] == 'success':
        series = data['data']
        tenants = set()
        for s in series:
            if 'tenant_id' in s:
                tenants.add(s['tenant_id'])
        if tenants:
            print(f'✓ Tenants encontrados: {tenants}')
        else:
            print('⚠ No se encontró label tenant_id en las series')
            print(f'  Series disponibles: {len(series)}')
    else:
        print('✗ Error en consulta')
except:
    print('✗ Error parseando respuesta')
" 2>/dev/null || echo "  Error en consulta"

echo ""
echo "5. Verificando métricas de node-exporter del agent..."
curl -s "http://localhost:9009/prometheus/api/v1/query?query=node_cpu_seconds_total{tenant_id='tenant-pe'}" -H "X-Scope-OrgID: tenant-pe" 2>&1 | \
  python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data['status'] == 'success' and data['data']['result']:
        print(f'✓ Métricas node-exporter con tenant_id=tenant-pe: {len(data["data"]["result"])} series')
    else:
        print('✗ No se encontraron métricas de node-exporter con tenant_id=tenant-pe')
except:
    print('✗ Error parseando respuesta')
" 2>/dev/null || echo "  Error en consulta"

echo ""
echo "6. Verificando métricas de cadvisor del agent..."
curl -s "http://localhost:9009/prometheus/api/v1/query?query=container_cpu_usage_seconds_total{tenant_id='tenant-pe'}" -H "X-Scope-OrgID: tenant-pe" 2>&1 | \
  python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data['status'] == 'success' and data['data']['result']:
        print(f'✓ Métricas cadvisor con tenant_id=tenant-pe: {len(data["data"]["result"])} series')
    else:
        print('✗ No se encontraron métricas de cadvisor con tenant_id=tenant-pe')
except:
    print('✗ Error parseando respuesta')
" 2>/dev/null || echo "  Error en consulta"

echo ""
echo "=========================================="
echo "Resumen:"
echo "- Agent inyecta tenant_id=tenant-pe (o tenant-mx, tenant-co según .env)"
echo "- Gateway usa tenant_id=tenant-pe (configurable en .env)"
echo "- Todos los datos van al tenant del gateway en backends"
echo "- tenant_id se mantiene como label para identificar origen"
echo "=========================================="
