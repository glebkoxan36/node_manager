#!/bin/bash
# Полный скрипт установки Blockchain Module

set -e

echo "=== Blockchain Module Full Installation ==="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# GitHub репозиторий
GITHUB_REPO="https://github.com/glebkoxan36/node_manager"
GITHUB_RAW="https://raw.githubusercontent.com/glebkoxan36/node_manager/main"

# Проверка и загрузка файлов
download_missing_files() {
    log_info "Проверка и загрузка недостающих файлов..."
    
    # Создаем структуру директорий если их нет
    mkdir -p blockchain_module blockchain_module/configs
    
    # Файлы из корня репозитория
    root_files=(
        "module_config.json"
        "alerts.yml"
        "blockchain_dashboard.json"
        "docker-compose.yml"
        "prometheus.yml"
        "requirements.txt"
        "setup.py"
        "README.md"
    )
    
    # Файлы из blockchain_module
    module_files=(
        "__init__.py"
        "blockchain_monitor.py"
        "config.py"
        "connection_pool.py"
        "database.py"
        "funds_collector.py"
        "health_check.py"
        "monitoring.py"
        "nownodes_client.py"
        "rest_api.py"
        "users.py"
        "utils.py"
    )
    
    # Файлы из blockchain_module/configs
    config_files=(
        "module_config.json"
    )
    
    # Загружаем файлы из корня
    for file in "${root_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_info "Загрузка $file..."
            if curl -s -f -o "$file" "${GITHUB_RAW}/$file"; then
                log_success "Файл $file загружен"
            else
                log_warn "Не удалось загрузить $file"
            fi
        else
            log_info "Файл $file уже существует"
        fi
    done
    
    # Загружаем файлы из blockchain_module
    for file in "${module_files[@]}"; do
        if [[ ! -f "blockchain_module/$file" ]]; then
            log_info "Загрузка blockchain_module/$file..."
            if curl -s -f -o "blockchain_module/$file" "${GITHUB_RAW}/blockchain_module/$file"; then
                log_success "Файл blockchain_module/$file загружен"
            else
                log_warn "Не удалось загрузить blockchain_module/$file"
            fi
        else
            log_info "Файл blockchain_module/$file уже существует"
        fi
    done
    
    # Загружаем файлы из blockchain_module/configs
    for file in "${config_files[@]}"; do
        if [[ ! -f "blockchain_module/configs/$file" ]]; then
            log_info "Загрузка blockchain_module/configs/$file..."
            if curl -s -f -o "blockchain_module/configs/$file" "${GITHUB_RAW}/blockchain_module/configs/$file"; then
                log_success "Файл blockchain_module/configs/$file загружен"
            else
                log_warn "Не удалось загрузить blockchain_module/configs/$file"
            fi
        else
            log_info "Файл blockchain_module/configs/$file уже существует"
        fi
    done
    
    # Проверяем наличие критических файлов
    critical_files=(
        "module_config.json"
        "blockchain_module/__init__.py"
        "blockchain_module/config.py"
        "blockchain_module/database.py"
    )
    
    missing_critical=()
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_critical+=("$file")
        fi
    done
    
    if [[ ${#missing_critical[@]} -gt 0 ]]; then
        log_error "Отсутствуют критические файлы:"
        for file in "${missing_critical[@]}"; do
            log_error "  - $file"
        done
        log_error "Попробуйте клонировать репозиторий вручную:"
        log_error "git clone https://github.com/glebkoxan36/node_manager.git"
        exit 1
    fi
    
    log_success "Все файлы проверены и загружены"
}

# Проверка прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warn "Рекомендуется запускать скрипт с правами root"
        read -p "Продолжить без прав root? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Проверка системы
check_system() {
    log_info "Проверка системы..."
    
    # Проверка ОС
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        log_info "ОС: $OS $VER"
    else
        log_error "Не удалось определить ОС"
        exit 1
    fi
    
    # Проверка Python
    if command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version | awk '{print $2}')
        log_info "Python: $PYTHON_VERSION"
        
        if [[ $(python3 -c "import sys; print('OK' if sys.version_info >= (3,7) else 'FAIL')") == "FAIL" ]]; then
            log_error "Требуется Python 3.7 или выше"
            exit 1
        fi
    else
        log_error "Python3 не установлен"
        exit 1
    fi
    
    # Проверка pip
    if ! command -v pip3 &>/dev/null; then
        log_warn "pip3 не найден, устанавливаем..."
        if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
            apt-get update && apt-get install -y python3-pip
        elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* ]]; then
            yum install -y python3-pip
        elif [[ "$OS" == *"Fedora"* ]]; then
            dnf install -y python3-pip
        else
            log_error "Не удалось установить pip3"
            exit 1
        fi
    fi
    
    # Проверка curl
    if ! command -v curl &>/dev/null; then
        log_warn "curl не найден, устанавливаем..."
        if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
            apt-get install -y curl
        elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* ]]; then
            yum install -y curl
        elif [[ "$OS" == *"Fedora"* ]]; then
            dnf install -y curl
        fi
    fi
}

# Установка зависимостей системы
install_system_deps() {
    log_info "Установка системных зависимостей..."
    
    if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
        apt-get update
        apt-get install -y \
            git \
            curl \
            wget \
            build-essential \
            python3-dev \
            python3-venv \
            sqlite3 \
            libsqlite3-dev \
            net-tools
    elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* || "$OS" == *"Fedora"* ]]; then
        if [[ "$OS" == *"Fedora"* ]]; then
            dnf install -y \
                git \
                curl \
                wget \
                gcc \
                g++ \
                python3-devel \
                sqlite \
                sqlite-devel \
                net-tools
        else
            yum install -y \
                git \
                curl \
                wget \
                gcc \
                gcc-c++ \
                python3-devel \
                sqlite \
                sqlite-devel \
                net-tools
        fi
    else
        log_warn "Неизвестная ОС, попробуйте установить зависимости вручную"
    fi
}

# Настройка директорий
setup_directories() {
    log_info "Создание структуры директорий..."
    
    mkdir -p configs data logs prometheus grafana/dashboards alerts
    
    # Копируем конфигурационные файлы
    if [[ -f "module_config.json" ]]; then
        cp module_config.json configs/
    else
        log_warn "Файл module_config.json не найден"
    fi
    
    if [[ -f "alerts.yml" ]]; then
        cp alerts.yml alerts/
    else
        log_warn "Файл alerts.yml не найден"
    fi
    
    if [[ -f "blockchain_dashboard.json" ]]; then
        cp blockchain_dashboard.json grafana/dashboards/
    else
        log_warn "Файл blockchain_dashboard.json не найден"
    fi
    
    # Создаем prometheus.yml
    cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: 'production'

rule_files:
  - "../alerts/alerts.yml"

scrape_configs:
  - job_name: 'blockchain_module'
    scrape_interval: 15s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    scheme: 'http'
    
    static_configs:
      - targets: ['host.docker.internal:9090']
        labels:
          instance: 'blockchain_module_main'
          component: 'application'

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'blockchain_module_server'
          component: 'system'

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
EOF

    # Создаем docker-compose для мониторинга
    cat > docker-compose-monitoring.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: blockchain_prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alerts:/etc/prometheus/alerts
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: blockchain_grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-piechart-panel
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SMTP_ENABLED=false
    restart: unless-stopped
    depends_on:
      - prometheus
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: blockchain_node_exporter
    ports:
      - "9100:9100"
    restart: unless-stopped
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: blockchain_cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    restart: unless-stopped
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
EOF

    log_success "Директории и конфигурационные файлы созданы"
}

# Основная функция
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║      Blockchain Module Auto Installer v2.0.0    ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Шаг 1: Загрузка недостающих файлов
    download_missing_files
    
    # Шаг 2: Проверка системы
    check_root
    check_system
    
    # Шаг 3: Установка системных зависимостей
    install_system_deps
    
    # Шаг 4: Настройка директорий
    setup_directories
    
    # Шаг 5: Установка Python зависимостей
    log_info "Установка Python зависимостей..."
    
    # Обновляем pip
    pip3 install --upgrade pip
    
    # Устанавливаем зависимости
    if [[ -f "requirements.txt" ]]; then
        pip3 install -r requirements.txt
    else
        pip3 install \
            aiohttp>=3.8.0 \
            aiosqlite>=0.19.0 \
            prometheus-client>=0.17.0 \
            aiohttp-cors>=0.7.0 \
            click>=8.1.0 \
            questionary>=2.0.0 \
            rich>=13.0.0 \
            psutil>=5.9.0 \
            python-dotenv>=1.0.0 \
            pyyaml>=6.0
    fi
    
    # Устанавливаем модуль
    if [[ -f "setup.py" ]]; then
        pip3 install -e .
    else
        log_warn "setup.py не найден, устанавливаем как пакет..."
        pip3 install .
    fi
    
    log_success "Python зависимости установлены"
    
    # Шаг 6: Создание скрипта запуска REST API
    log_info "Создание скрипта запуска REST API..."
    
    cat > run_rest_api.py << 'EOF'
#!/usr/bin/env python3
"""
Скрипт запуска REST API сервера Blockchain Module
"""

import asyncio
import logging
import sys
import os
from pathlib import Path

# Настраиваем логирование
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

async def main():
    try:
        from blockchain_module.rest_api import run_rest_api
        
        # Получаем порт из аргументов или конфигурации
        port = int(sys.argv[1]) if len(sys.argv) > 1 else 8089
        
        logger.info(f"Запуск Blockchain Module REST API на порту {port}")
        
        await run_rest_api(host='0.0.0.0', port=port)
        
    except KeyboardInterrupt:
        logger.info("Сервер остановлен пользователем")
    except Exception as e:
        logger.error(f"Ошибка запуска сервера: {e}")
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    # Создаем директорию для логов
    os.makedirs('logs', exist_ok=True)
    
    asyncio.run(main())
EOF
    
    chmod +x run_rest_api.py
    log_success "Скрипт запуска REST API создан"
    
    # Шаг 7: Тестирование установки
    log_info "Тестирование установки..."
    
    python3 -c "
import sys
print('Тестирование Blockchain Module...')

try:
    from blockchain_module import get_module_info, SUPPORTED_COINS
    info = get_module_info()
    print(f'✅ Модуль загружен: v{info[\"version\"]}')
    print(f'✅ Поддерживаемые монеты: {SUPPORTED_COINS}')
    
    from blockchain_module.config import BlockchainConfig
    print(f'✅ Конфигурация загружена')
    
    from blockchain_module.database import SQLiteDBManager
    print(f'✅ База данных доступна')
    
    from blockchain_module.rest_api import BlockchainRestAPI
    print(f'✅ REST API доступен')
    
    print('\\n🎉 Все компоненты успешно загружены!')
    
except Exception as e:
    print(f'❌ Ошибка: {e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
"
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           УСТАНОВКА ЗАВЕРШЕНА!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Доступные команды:"
    echo "  • python3 run_rest_api.py    - Запуск REST API"
    echo "  • python3 -m blockchain_module - Запуск модуля"
    echo ""
    echo "Структура файлов:"
    echo "  📁 blockchain_module/      - Основной код модуля"
    echo "  📁 configs/               - Конфигурационные файлы"
    echo "  📁 data/                  - База данных"
    echo "  📁 logs/                  - Логи"
    echo "  📄 run_rest_api.py        - Скрипт запуска API"
    echo "  📄 module_config.json     - Основной конфиг"
    echo ""
    echo "Для запуска Docker контейнеров мониторинга:"
    echo "  docker-compose -f docker-compose-monitoring.yml up -d"
    echo ""
    echo "Следующие шаги:"
    echo "  1. Настройте API ключ в configs/module_config.json"
    echo "  2. Запустите REST API: python3 run_rest_api.py"
    echo "  3. Откройте http://localhost:8089/api/v1/info"
    echo ""
}

# Запуск главной функции
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
