#!/bin/bash
# Detecta la IP del gateway de Docker para conectividad cross-network

# Método 1: Inspeccionar la red bridge por defecto
GATEWAY_IP=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)

# Método 2: Si falla, intentar con ip route (Linux)
if [ -z "$GATEWAY_IP" ]; then
    GATEWAY_IP=$(ip route | grep docker0 | awk '{print $9}' 2>/dev/null | head -n1)
fi

# Método 3: Verificar si estamos en Docker Desktop (Mac/Windows)
if [ -z "$GATEWAY_IP" ]; then
    # En Docker Desktop, probar host.docker.internal
    if ping -c 1 host.docker.internal &>/dev/null; then
        echo "host.docker.internal"
        exit 0
    fi
fi

# Método 4: Fallback a la IP más común
if [ -z "$GATEWAY_IP" ]; then
    GATEWAY_IP="172.17.0.1"
fi

echo "$GATEWAY_IP"
