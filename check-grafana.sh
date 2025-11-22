#!/bin/bash

echo "=========================================="
echo "Verificación rápida de datos en Grafana"
echo "=========================================="
echo ""

echo "1. Verificando métricas en Mimir (tenant-pe)..."
RESULT=$(curl -s "http://localhost:9009/prometheus/api/v1/query?query=up" -H "X-Scope-OrgID: tenant-pe")
COUNT=$(echo "$RESULT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('data',{}).get('result',[])) if data.get('status')=='success' else 0)" 2>/dev/null || echo "0")
if [ "$COUNT" -gt "0" ]; then
    echo "✓ Métricas encontradas: $COUNT series"
else
    echo "✗ No se encontraron métricas"
fi

echo ""
echo "2. Verificando logs en Loki (tenant-pe)..."
RESULT=$(curl -s "http://localhost:3100/loki/api/v1/label/__name__/values" -H "X-Scope-OrgID: tenant-pe")
STATUS=$(echo "$RESULT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('status','error'))" 2>/dev/null || echo "error")
if [ "$STATUS" = "success" ]; then
    echo "✓ Loki respondiendo correctamente"
else
    echo "✗ Error en Loki"
fi

echo ""
echo "3. Verificando trazas en Tempo (tenant-pe)..."
RESULT=$(curl -s "http://localhost:3200/api/search/tags" -H "X-Scope-OrgID: tenant-pe")
TAGS=$(echo "$RESULT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('tagNames',[])) if 'tagNames' in data else 0)" 2>/dev/null || echo "0")
if [ "$TAGS" -gt "0" ]; then
    echo "✓ Tempo tiene datos: $TAGS tags"
else
    echo "✗ No se encontraron trazas"
fi

echo ""
echo "=========================================="
echo "Accede a Grafana en: http://localhost:3000"
echo "Usuario: admin"
echo "Password: admin"
echo ""
echo "Los datasources ya están configurados con tenant-pe"
echo "=========================================="
