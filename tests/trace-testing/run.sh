#!/bin/bash

# Script de utilidad para gestionar el sistema de monitorización
# Uso: ./monitor.sh [comando]

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}Sistema de monitorización - Script de gestión${NC}"
    echo ""
    echo "Uso: ./monitor.sh [comando]"
    echo ""
    echo "Comandos disponibles:"
    echo -e "  ${GREEN}start${NC}      - Iniciar todos los servicios"
    echo -e "  ${GREEN}stop${NC}       - Detener todos los servicios"
    echo -e "  ${GREEN}restart${NC}    - Reiniciar todos los servicios"
    echo -e "  ${GREEN}status${NC}     - Ver estado de los servicios"
    echo -e "  ${GREEN}logs${NC}       - Ver logs de todos los servicios"
    echo -e "  ${GREEN}build${NC}      - Reconstruir las imágenes"
    echo -e "  ${GREEN}clean${NC}      - Limpiar contenedores y volúmenes"
    echo -e "  ${GREEN}test${NC}       - Generar tráfico de prueba"
    echo -e "  ${GREEN}test-orders${NC} - Generar tráfico para servicios Orders y Notifications"
    echo -e "  ${GREEN}logs-test${NC}  - Generar logs de prueba"
    echo -e "  ${GREEN}loki-status${NC} - Verificar estado de Loki"
    echo -e "  ${GREEN}urls${NC}       - Mostrar URLs de acceso"
    echo -e "  ${GREEN}backup${NC}     - Crear backup de datos"
    echo -e "  ${GREEN}help${NC}       - Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  ./monitor.sh start"
    echo "  ./monitor.sh logs prometheus"
    echo "  ./monitor.sh test 100"
    echo "  ./monitor.sh test-orders 50"
}

# Función para verificar si Docker está ejecutándose
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Error: Docker no está ejecutándose${NC}"
        exit 1
    fi
}

# Función para verificar si docker compose está disponible
check_docker_compose() {
    if ! command -v docker compose &> /dev/null; then
        echo -e "${RED}Error: docker compose no está instalado${NC}"
        exit 1
    fi
}

# Función para iniciar servicios
start_services() {
    echo -e "${BLUE}Iniciando sistema de monitorización...${NC}"
    docker compose up -d
    echo -e "${GREEN}✓ Servicios iniciados correctamente${NC}"
    sleep 5
    show_urls
}

# Función para detener servicios
stop_services() {
    echo -e "${BLUE}Deteniendo sistema de monitorización...${NC}"
    docker compose down
    echo -e "${GREEN}✓ Servicios detenidos correctamente${NC}"
}

# Función para reiniciar servicios
restart_services() {
    echo -e "${BLUE}Reiniciando sistema de monitorización...${NC}"
    docker compose restart
    echo -e "${GREEN}✓ Servicios reiniciados correctamente${NC}"
}

# Función para mostrar estado
show_status() {
    echo -e "${BLUE}Estado de los servicios:${NC}"
    docker compose ps
}

# Función para mostrar logs
show_logs() {
    if [ -n "$2" ]; then
        echo -e "${BLUE}Logs del servicio $2:${NC}"
        docker compose logs -f "$2"
    else
        echo -e "${BLUE}Logs de todos los servicios:${NC}"
        docker compose logs -f
    fi
}

# Función para reconstruir imágenes
build_images() {
    echo -e "${BLUE}Reconstruyendo imágenes...${NC}"
    docker compose build --no-cache
    echo -e "${GREEN}✓ Imágenes reconstruidas correctamente${NC}"
}

# Función para limpiar sistema
clean_system() {
    echo -e "${YELLOW}¿Estás seguro de que quieres limpiar todos los contenedores y volúmenes? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "${BLUE}Limpiando sistema...${NC}"
        docker compose down -v --remove-orphans
        docker system prune -f
        echo -e "${GREEN}✓ Sistema limpiado correctamente${NC}"
    else
        echo -e "${YELLOW}Operación cancelada${NC}"
    fi
}

# Función para generar tráfico de prueba
generate_test_traffic() {
    local requests=${2:-30}
    echo -e "${BLUE}Generando $requests solicitudes de prueba a la API...${NC}"

    # Verificar que la aplicación esté ejecutándose
    if ! curl -s http://localhost:8000/health > /dev/null; then
        echo -e "${RED}Error: La aplicación no responde en http://localhost:8000${NC}"
        return 1
    fi

    echo "Enviando solicitudes..."
    for ((i=1; i<=requests; i++)); do
        # Hacer requests a diferentes endpoints de la API
        case $((i % 5)) in
            0) curl -s http://localhost:8000/ > /dev/null ;;
            1) curl -s http://localhost:8000/health > /dev/null ;;
            2) curl -s http://localhost:8000/users > /dev/null ;;
            3) curl -s http://localhost:8000/data > /dev/null ;;
            4) curl -s -X POST http://localhost:8000/process > /dev/null ;;
        esac

        # Mostrar progreso cada 10 requests
        if ((i % 10 == 0)); then
            echo -ne "\rProgreso: $i/$requests requests"
        fi

        sleep 0.2
    done
    echo ""
    echo -e "${GREEN}✓ $requests solicitudes enviadas a los endpoints de la API${NC}"
}

# Función para generar logs de prueba
generate_test_logs() {
    echo -e "${BLUE}Generando logs de prueba...${NC}"

    # Verificar que la aplicación esté ejecutándose
    if ! curl -s http://localhost:8000/health > /dev/null; then
        echo -e "${RED}Error: La aplicación no responde en http://localhost:8000${NC}"
        return 1
    fi

    echo "Generando logs de prueba..."
    curl -s http://localhost:8000/logs > /dev/null

    echo -e "${GREEN}✓ Logs de prueba generados${NC}"
    echo -e "${YELLOW}Nota: Los logs aparecerán en Loki después de unos segundos${NC}"
}

# Función para verificar estado de Loki
check_loki_status() {
    echo -e "${BLUE}Verificando estado de Loki...${NC}"

    # Verificar si Loki está ejecutándose
    if ! docker compose ps | grep -q "loki.*Up"; then
        echo -e "${RED}✗ Loki no está ejecutándose${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Loki está ejecutándose${NC}"

    # Verificar endpoint de salud
    if curl -s http://localhost:3100/ready > /dev/null; then
        echo -e "${GREEN}✓ Loki responde correctamente${NC}"
    else
        echo -e "${YELLOW}⚠ Loki no responde en el endpoint de salud${NC}"
    fi

    # Verificar si Promtail está ejecutándose
    if docker compose ps | grep -q "promtail.*Up"; then
        echo -e "${GREEN}✓ Promtail está ejecutándose${NC}"
    else
        echo -e "${RED}✗ Promtail no está ejecutándose${NC}"
    fi

    # Mostrar estadísticas básicas
    echo ""
    echo -e "${BLUE}Estadísticas de Loki:${NC}"
    echo "Para ver logs en Grafana:"
    echo "1. Ir a http://localhost:3000"
    echo "2. Seleccionar 'Explore'"
    echo "3. Elegir datasource 'Loki'"
    echo "4. Usar query: {job=\"app-monitorizacion\"}"
}

# Función para mostrar URLs
show_urls() {
    echo -e "${BLUE}URLs de acceso al sistema:${NC}"
    echo ""
    echo -e "${GREEN}Grafana:${NC}         http://localhost:3000"
    echo -e "   ${YELLOW}Usuario:${NC}          admin"
    echo -e "   ${YELLOW}Contraseña:${NC}      admin123"
    echo ""
    echo -e "${GREEN}Prometheus:${NC}      http://localhost:9090"
    echo -e "${GREEN}Loki:${NC}           http://localhost:3100"
    echo -e "${GREEN}Node Exporter:${NC}   http://localhost:9100"
    echo -e "${GREEN}Aplicación:${NC}      http://localhost:8000"
    echo ""
    echo -e "Endpoints de la API:"
    echo -e "   ${BLUE}Principal:${NC}       http://localhost:8000/"
    echo -e "   ${BLUE}Salud:${NC}           http://localhost:8000/health"
    echo -e "   ${BLUE}Usuarios:${NC}        http://localhost:8000/users"
    echo -e "   ${BLUE}Datos:${NC}           http://localhost:8000/data"
    echo -e "   ${BLUE}Procesar:${NC}        http://localhost:8000/process"
    echo -e "   ${BLUE}Logs de prueba:${NC}   http://localhost:8000/logs"
    echo -e "   ${BLUE}Métricas:${NC}        http://localhost:8000/metrics"
}

# Función para crear backup
create_backup() {
    local backup_dir="backup-$(date +%Y%m%d-%H%M%S)"
    echo -e "${BLUE}Creando backup en $backup_dir...${NC}"

    mkdir -p "$backup_dir"

    # Backup de configuraciones
    cp -r prometheus "$backup_dir/"
    cp -r grafana "$backup_dir/"
    cp -r loki "$backup_dir/" 2>/dev/null || true
    cp -r promtail "$backup_dir/" 2>/dev/null || true
    cp docker-compose.yml "$backup_dir/"

    # Backup de datos de contenedores (si están ejecutándose)
    if docker compose ps | grep -q "Up"; then
        echo "Creando backup de datos de Grafana..."
        docker cp grafana:/var/lib/grafana "$backup_dir/grafana-data" 2>/dev/null || true

        echo "Creando backup de datos de Prometheus..."
        docker cp prometheus:/prometheus "$backup_dir/prometheus-data" 2>/dev/null || true

        echo "Creando backup de datos de Loki..."
        docker cp loki:/loki "$backup_dir/loki-data" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Backup creado en $backup_dir${NC}"
}

# Función para generar tráfico de órdenes y notificaciones
generate_orders_traffic() {
    local requests=${2:-20}
    echo -e "${BLUE}Generando tráfico para Orders y Notifications Service...${NC}"
    echo -e "${YELLOW}Total de órdenes a crear: $requests${NC}"
    echo ""

    # Verificar que los servicios estén ejecutándose
    if ! curl -s http://localhost:8081/health > /dev/null 2>&1; then
        echo -e "${RED}Error: Orders Service no responde en http://localhost:8081${NC}"
        return 1
    fi

    if ! curl -s http://localhost:8082/health > /dev/null 2>&1; then
        echo -e "${RED}Error: Notifications Service no responde en http://localhost:8082${NC}"
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
        local response=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8081/api/orders \
            -H "Content-Type: application/json" \
            -d "{\"customerId\":\"$customer\",\"total\":$total}")

        local http_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | head -n-1)

        if [ "$http_code" -eq 201 ]; then
            local order_id=$(echo "$body" | grep -o '"orderId":"[^"]*' | cut -d'"' -f4)
            created_orders+=("$order_id")
            ((success_count++))
            echo -e "   ${GREEN}✓${NC} Orden creada: ${BLUE}$order_id${NC}"

            # 70% de probabilidad de consultar la orden
            if [ $((RANDOM % 10)) -lt 7 ]; then
                sleep 0.2
                curl -s http://localhost:8081/api/orders/$order_id > /dev/null
                echo -e "   ${GREEN}→${NC} Orden consultada"
            fi

            # 50% de probabilidad de actualizar el estado
            if [ $((RANDOM % 10)) -lt 5 ] && [ -n "$order_id" ]; then
                sleep 0.3
                local new_status=${statuses[$RANDOM % ${#statuses[@]}]}
                curl -s -X PATCH http://localhost:8081/api/orders/$order_id/status \
                    -H "Content-Type: application/json" \
                    -d "{\"status\":\"$new_status\"}" > /dev/null
                echo -e "   ${GREEN}→${NC} Estado actualizado a: ${YELLOW}$new_status${NC}"
            fi
        else
            ((error_count++))
            echo -e "   ${RED}✗${NC} Error al crear orden (HTTP $http_code)"
        fi

        # 30% de probabilidad de consultar notificaciones
        if [ $((RANDOM % 10)) -lt 3 ]; then
            curl -s http://localhost:8082/api/notifications > /dev/null
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
    curl -s http://localhost:8081/api/orders > /dev/null
    echo -e "${GREEN}✓${NC} Lista de órdenes obtenida"
    echo ""

    echo -e "${YELLOW}Consultando todas las notificaciones...${NC}"
    curl -s http://localhost:8082/api/notifications > /dev/null
    echo -e "${GREEN}✓${NC} Lista de notificaciones obtenida"
    echo ""

    # Consultar notificaciones por orden (para algunas órdenes creadas)
    local sample_size=$((${#created_orders[@]} < 5 ? ${#created_orders[@]} : 5))
    if [ $sample_size -gt 0 ]; then
        echo -e "${YELLOW}Consultando notificaciones por orden (muestra de $sample_size órdenes)...${NC}"
        for ((i=0; i<sample_size; i++)); do
            local order_id=${created_orders[$i]}
            curl -s http://localhost:8082/api/notifications/order/$order_id > /dev/null
            echo -e "${GREEN}→${NC} Notificaciones de orden ${BLUE}$order_id${NC}"
        done
        echo ""
    fi

    # Health checks finales
    echo -e "${YELLOW}Verificando health checks...${NC}"
    curl -s http://localhost:8081/health > /dev/null
    echo -e "${GREEN}✓${NC} Orders Service - healthy"
    curl -s http://localhost:8082/health > /dev/null
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
    # Verificar dependencias
    check_docker
    check_docker_compose

    case "${1:-help}" in
        "start")
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status"|"ps")
            show_status
            ;;
        "logs")
            show_logs "$@"
            ;;
        "build")
            build_images
            ;;
        "clean")
            clean_system
            ;;
        "test")
            generate_test_traffic "$@"
            ;;
        "test-orders")
            generate_orders_traffic "$@"
            ;;
        "logs-test")
            generate_test_logs
            ;;
        "loki-status")
            check_loki_status
            ;;
        "urls")
            show_urls
            ;;
        "backup")
            create_backup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}Comando desconocido: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal con todos los argumentos
main "$@"