#!/bin/bash

echo "=== Validando métricas del agent en Mimir ==="
echo ""

echo "1. Consultando métricas 'up' con service.country=PE:"
curl -s "http://localhost:9009/prometheus/api/v1/query?query=up{service_country=\"PE\"}" \
  -H "X-Scope-OrgID: anonymous" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data['status'] == 'success' and data['data']['result']:
    print('✓ Encontradas métricas con service.country=PE:')
    for r in data['data']['result']:
        print(f\"  - {r['metric']}\")
else:
    print('✗ No se encontraron métricas con service.country=PE')
    print(f\"Response: {json.dumps(data, indent=2)}\")
"

echo ""
echo "2. Consultando todas las métricas 'node_*' disponibles:"
curl -s "http://localhost:9009/prometheus/api/v1/label/__name__/values" \
  -H "X-Scope-OrgID: anonymous" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data['status'] == 'success':
    node_metrics = [m for m in data['data'] if m.startswith('node_')]
    cadvisor_metrics = [m for m in data['data'] if m.startswith('container_')]
    print(f'✓ Métricas node_*: {len(node_metrics)}')
    print(f'✓ Métricas container_*: {len(cadvisor_metrics)}')
    if len(node_metrics) > 0:
        print(f'  Ejemplos node_: {node_metrics[:5]}')
    if len(cadvisor_metrics) > 0:
        print(f'  Ejemplos container_: {cadvisor_metrics[:5]}')
else:
    print('✗ Error consultando métricas')
"

echo ""
echo "3. Consultando métricas de node-exporter con job label:"
curl -s "http://localhost:9009/prometheus/api/v1/query?query=up{job=\"node-exporter\"}" \
  -H "X-Scope-OrgID: anonymous" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data['status'] == 'success' and data['data']['result']:
    print('✓ Métricas de node-exporter encontradas:')
    for r in data['data']['result']:
        print(f\"  - {r['metric']}\")
        print(f\"    Valor: {r['value'][1]}\")
else:
    print('✗ No se encontraron métricas de job=node-exporter')
"

echo ""
echo "=== Fin de validación ==="
