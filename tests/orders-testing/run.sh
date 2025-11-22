#!/bin/bash

# Script para generar tráfico de prueba en Orders y Notifications Services
# Uso: ./run.sh [número_de_órdenes]

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}Orders & Notifications Testing - Generador de tráfico${NC}"
    echo ""
    echo "Uso: ./run.sh [número_de_órdenes]"
    echo ""
    echo "Parámetros:"
    echo -e "  ${GREEN}número_de_órdenes${NC}  - Cantidad de órdenes a crear (default: 20)"
    echo ""
    echo "Ejemplos:"
    echo "  ./run.sh          # Genera 20 órdenes"
    echo "  ./run.sh 50       # Genera 50 órdenes"
    echo "  ./run.sh 100      # Genera 100 órdenes"
}

# Función para generar tráfico de órdenes y notificaciones
generate_orders_traffic() {
    local requests=${1:-20}
    echo -e "${BLUE}Generando tráfico para Orders y Notifications Service...${NC}"
    echo -e "${YELLOW}Total de órdenes a crear: $requests${NC}"
    echo ""

    # Detectar endpoint correcto para Orders
    local ORDERS_URL="http://orders:8081"
    local NOTIFICATIONS_URL="http://notifications:8082"

    # Si localhost responde, usarlo (caso ejecución local)
    if curl -s http://localhost:8081/health > /dev/null 2>&1; then
        ORDERS_URL="http://localhost:8081"
    fi
    if curl -s http://localhost:8082/health > /dev/null 2>&1; then
        NOTIFICATIONS_URL="http://localhost:8082"
    fi

    # Esperar a que los servicios estén listos con retry
    echo -e "${YELLOW}Esperando a que los servicios estén listos...${NC}"
    local max_attempts=30
    local attempt=0

    # Esperar Orders Service
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$ORDERS_URL/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Orders Service está listo${NC}"
            break
        fi
        attempt=$((attempt + 1))
        echo -e "${YELLOW}  Intento $attempt/$max_attempts - Esperando Orders Service...${NC}"
        sleep 2
    done

    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}Error: Orders Service no responde en $ORDERS_URL después de $max_attempts intentos${NC}"
        return 1
    fi

    # Esperar Notifications Service
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$NOTIFICATIONS_URL/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Notifications Service está listo${NC}"
            break
        fi
        attempt=$((attempt + 1))
        echo -e "${YELLOW}  Intento $attempt/$max_attempts - Esperando Notifications Service...${NC}"
        sleep 2
    done

    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}Error: Notifications Service no responde en $NOTIFICATIONS_URL después de $max_attempts intentos${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Ambos servicios están disponibles${NC}"
    echo ""

    # Arrays para datos de prueba
    local customers=("CUST-001" "CUST-002" "CUST-003" "CUST-004" "CUST-005" "CUST-006" "CUST-007" "CUST-008")
    local totals=(29.99 49.99 79.99 99.99 149.99 199.99 299.99 499.99 599.99 999.99)
    local statuses=("Pending" "Processing" "Completed" "Cancelled" "Failed")

    local created_orders=()
    local success_count=0
    local error_count=0

    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Iniciando generación de tráfico...${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""

    for ((i=1; i<=requests; i++)); do
        # Seleccionar datos aleatorios
        local customer=${customers[$RANDOM % ${#customers[@]}]}
        local total=${totals[$RANDOM % ${#totals[@]}]}

        echo -e "${YELLOW}[$i/$requests]${NC} Creando orden para ${BLUE}$customer${NC} - Total: ${GREEN}\$$total${NC}"

        # Crear orden
        local response=$(curl -s -w "\n%{http_code}" -X POST "$ORDERS_URL/api/orders" \
            -H "Content-Type: application/json" \
            -d "{\"customerId\":\"$customer\",\"total\":$total}")

        local http_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | head -n-1)

        if [ "$http_code" -eq 201 ]; then
            local order_id=$(echo "$body" | grep -o '"orderId":"[^"]*' | cut -d'"' -f4)
            created_orders+=("$order_id")
            success_count=$((success_count + 1))
            echo -e "   ${GREEN}✓${NC} Orden creada: ${BLUE}$order_id${NC}"

            # 70% de probabilidad de consultar la orden
            if [ $((RANDOM % 10)) -lt 7 ]; then
                sleep 0.2
                curl -s "$ORDERS_URL/api/orders/$order_id" > /dev/null
                echo -e "   ${GREEN}→${NC} Orden consultada"
            fi

            # 50% de probabilidad de actualizar el estado
            if [ $((RANDOM % 10)) -lt 5 ] && [ -n "$order_id" ]; then
                sleep 0.3
                local new_status=${statuses[$RANDOM % ${#statuses[@]}]}
                curl -s -X PATCH "$ORDERS_URL/api/orders/$order_id/status" \
                    -H "Content-Type: application/json" \
                    -d "{\"status\":\"$new_status\"}" > /dev/null
                echo -e "   ${GREEN}→${NC} Estado actualizado a: ${YELLOW}$new_status${NC}"
            fi
        else
            error_count=$((error_count + 1))
            echo -e "   ${RED}✗${NC} Error al crear orden (HTTP $http_code)"
        fi

        # 30% de probabilidad de consultar notificaciones
        if [ $((RANDOM % 10)) -lt 3 ]; then
            curl -s "$NOTIFICATIONS_URL/api/notifications" > /dev/null
            echo -e "   ${GREEN}→${NC} Notificaciones consultadas"
        fi

        echo ""
        sleep 0.5
    done

    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Generando consultas adicionales...${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""

    # Consultas adicionales
    echo -e "${YELLOW}Consultando todas las órdenes...${NC}"
    curl -s "$ORDERS_URL/api/orders" > /dev/null
    echo -e "${GREEN}✓${NC} Lista de órdenes obtenida"
    echo ""

    echo -e "${YELLOW}Consultando todas las notificaciones...${NC}"
    curl -s "$NOTIFICATIONS_URL/api/notifications" > /dev/null
    echo -e "${GREEN}✓${NC} Lista de notificaciones obtenida"
    echo ""

    # Consultar notificaciones por orden (para algunas órdenes creadas)
    local sample_size=$((${#created_orders[@]} < 5 ? ${#created_orders[@]} : 5))
    if [ $sample_size -gt 0 ]; then
        echo -e "${YELLOW}Consultando notificaciones por orden (muestra de $sample_size órdenes)...${NC}"
        for ((i=0; i<sample_size; i++)); do
            local order_id=${created_orders[$i]}
            curl -s "$NOTIFICATIONS_URL/api/notifications/order/$order_id" > /dev/null
            echo -e "${GREEN}→${NC} Notificaciones de orden ${BLUE}$order_id${NC}"
        done
        echo ""
    fi

    # Health checks finales
    echo -e "${YELLOW}Verificando health checks...${NC}"
    curl -s "$ORDERS_URL/health" > /dev/null
    echo -e "${GREEN}✓${NC} Orders Service - healthy"
    curl -s "$NOTIFICATIONS_URL/health" > /dev/null
    echo -e "${GREEN}✓${NC} Notifications Service - healthy"
    echo ""

    # Resumen
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Resumen de tráfico generado${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Órdenes creadas exitosamente:${NC} $success_count"
    echo -e "${RED}✗ Errores:${NC} $error_count"
    echo -e "${YELLOW}📊 Total de requests:${NC} ~$((requests * 3)) (incluyendo notificaciones y consultas)"
    echo ""
    echo -e "${GREEN}Puedes visualizar las trazas y logs en:${NC}"
    echo -e "   • Grafana: ${BLUE}http://localhost:3000${NC}"
    echo -e "   • Tempo: Buscar trazas de ${YELLOW}orders-service${NC} y ${YELLOW}notifications-service${NC}"
    echo -e "   • Loki: Filtrar por ${YELLOW}service_name${NC}"
    echo ""
}


# Función principal
main() {
    case "${1:-}" in
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            # Si es un número, usarlo como cantidad de órdenes
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                generate_orders_traffic "$1"
            else
                echo -e "${RED}Error: Parámetro inválido '$1'${NC}"
                echo ""
                show_help
                exit 1
            fi
            ;;
    esac
}

# Ejecutar función principal con todos los argumentos
main "$@"