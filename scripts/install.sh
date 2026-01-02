#!/bin/bash
# Blockchain Module v2.0 - Автоматическая установка и настройка
# Полная установка модуля, зависимостей, мониторинга и запуск

set -e  # Прерывать при ошибках

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка прав
if [ "$EUID" -eq 0 ]; then 
    log_warning "Скрипт запущен с правами root. Продолжаем..."
fi

echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Blockchain Module v2.0 - Автоматическая установка   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Обновление системы и установка базовых зависимостей
log_info "1. Обновление системы и установка зависимостей..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    git \
    curl \
    wget \
    net-tools \
    lsof \
    htop \
    screen \
    sqlite3 \
    libsqlite3-dev

# 2. Установка Docker и Docker Compose
log_info "2. Установка Docker и Docker Compose..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    log_success "Docker установлен"
else
    log_success "Docker уже установлен"
fi

if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose установлен"
else
    log_success "Docker Compose уже установлен"
fi

# 3. Создание структуры директорий
log_info "3. Создание структуры директорий..."
mkdir -p {configs,data,logs,backups,scripts,monitoring/{prometheus,grafana,alerts}}

# 4. Создание виртуального окружения Python
log_info "4. Настройка Python окружения..."
python3 -m venv venv
source venv/bin/activate

# 5. Установка Python зависимостей
log_info "5. Установка Python зависимостей..."
pip install --upgrade pip
pip install aiohttp aiosqlite prometheus-client psutil requests

# Создание файла requirements.txt
cat > requirements.txt << 'EOF'
aiohttp>=3.8.0
aiosqlite>=0.19.0
prometheus-client>=0.17.0
psutil>=5.9.0
requests>=2.28.0
asyncio>=3.4.3
typing-extensions>=4.5.0
pyyaml>=6.0
EOF

pip install -r requirements.txt

# 6. Копирование файлов модуля
log_info "6. Настройка структуры модуля..."

# Создание директории модуля
mkdir -p blockchain_module

# Копирование основных файлов (если они в текущей директории)
copy_file() {
    if [ -f "$1" ]; then
        cp "$1" "blockchain_module/$1"
        log_success "Скопирован: $1"
    else
        log_warning "Файл не найден: $1"
    fi
}

# Копирование основных модулей
for file in __init__.py config.py connection_pool.py database.py blockchain_monitor.py \
             funds_collector.py health_check.py monitoring.py nownodes_client.py \
             rest_api.py users.py utils.py; do
    copy_file "$file"
done

# 7. Настройка конфигурационных файлов
log_info "7. Настройка конфигурационных файлов..."

# Основной конфиг
cat > configs/module_config.json << 'EOF'
{
  "module_settings": {
    "api_key": "",
    "log_level": "INFO",
    "connection_pool_size": 10,
    "default_confirmations": 3,
    "max_reconnect_attempts": 10,
    "monitoring": {
      "enabled": true,
      "prometheus_port": 9090,
      "metrics_prefix": "blockchain_module"
    },
    "rest_api": {
      "enabled": true,
      "host": "0.0.0.0",
      "port": 8080,
      "api_key_required": true,
      "rate_limit": 100,
      "enable_auth": true
    },
    "multiuser": {
      "enabled": true,
      "default_user_quotas": {
        "max_monitored_addresses": 100,
        "max_daily_api_calls": 10000,
        "max_concurrent_monitors": 5,
        "can_collect_funds": false,
        "can_create_addresses": true,
        "can_view_transactions": true
      },
      "admin_api_key": "",
      "session_timeout": 3600
    }
  },
  "coins": {
    "LTC": {
      "symbol": "LTC",
      "name": "Litecoin",
      "decimals": 8,
      "blockbook_url": "https://ltcbook.nownodes.io",
      "required_confirmations": 3,
      "min_collection_amount": 0.001,
      "collection_fee": 0.0001
    },
    "DOGE": {
      "symbol": "DOGE",
      "name": "Dogecoin",
      "decimals": 8,
      "blockbook_url": "https://dogebook.nownodes.io",
      "required_confirmations": 6,
      "min_collection_amount": 1.0,
      "collection_fee": 0.1
    }
  }
}
EOF

# Конфиг Prometheus
cat > monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: 'production'

rule_files:
  - "/etc/prometheus/alerts.yml"

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
EOF

# Алёрты Prometheus
cat > monitoring/prometheus/alerts.yml << 'EOF'
groups:
  - name: blockchain_module_alerts
    rules:
      - alert: BlockchainModuleDown
        expr: up{job="blockchain_module"} == 0
        for: 1m
        labels:
          severity: critical
          component: application
        annotations:
          summary: "Blockchain module is down"
          description: "Blockchain module has been down for more than 1 minute"
      
      - alert: HighAPIErrorRate
        expr: rate(blockchain_module_api_errors_total[5m]) / rate(blockchain_module_api_requests_total[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
          component: api
        annotations:
          summary: "High API error rate"
          description: "API error rate is above 10% for 2 minutes"
EOF

# Дашборд Grafana
cat > monitoring/grafana/dashboard.json << 'EOF'
{
  "dashboard": {
    "title": "Blockchain Module Monitoring",
    "tags": ["blockchain", "monitoring"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "System Overview",
        "type": "stat",
        "gridPos": {"h": 3, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "blockchain_module_status",
            "format": "time_series",
            "legendFormat": "Module Status",
            "refId": "A"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "10s"
  }
}
EOF

# 8. Настройка Docker Compose для мониторинга
log_info "8. Настройка Docker Compose для мониторинга..."

cat > docker-compose-monitoring.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: blockchain_prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
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
      - ./monitoring/grafana:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-piechart-panel
      - GF_USERS_ALLOW_SIGN_UP=false
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

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
EOF

# 9. Создание скриптов управления
log_info "9. Создание скриптов управления..."

# Скрипт запуска REST API
cat > scripts/start_api.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."
source venv/bin/activate
export PYTHONPATH=$PYTHONPATH:$(pwd)
python3 -c "
from blockchain_module.rest_api import run_rest_api
import asyncio
asyncio.run(run_rest_api(host='0.0.0.0', port=8080))
"
EOF
chmod +x scripts/start_api.sh

# Скрипт запуска мониторинга
cat > scripts/start_monitoring.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."
docker-compose -f docker-compose-monitoring.yml up -d
echo "Мониторинг запущен:"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3000 (admin/admin)"
echo "  Node Exporter: http://localhost:9100"
EOF
chmod +x scripts/start_monitoring.sh

# Скрипт остановки всего
cat > scripts/stop_all.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."
pkill -f "blockchain_module" 2>/dev/null || true
docker-compose -f docker-compose-monitoring.yml down
echo "Все сервисы остановлены"
EOF
chmod +x scripts/stop_all.sh

# Скрипт проверки статуса
cat > scripts/status.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."
echo "=== Blockchain Module Status ==="
echo ""
echo "1. Python процессы:"
pgrep -f "blockchain_module" && echo "  ✅ REST API запущен" || echo "  ❌ REST API не запущен"
echo ""
echo "2. Docker контейнеры:"
docker-compose -f docker-compose-monitoring.yml ps
echo ""
echo "3. Порт 8080 (REST API):"
netstat -tlnp 2>/dev/null | grep :8080 || echo "  Порт 8080 не слушается"
echo ""
echo "4. Порт 9090 (Prometheus):"
netstat -tlnp 2>/dev/null | grep :9090 || echo "  Порт 9090 не слушается"
EOF
chmod +x scripts/status.sh

# 10. Создание systemd сервисов (опционально)
log_info "10. Создание systemd сервисов..."

# Сервис для REST API
sudo tee /etc/systemd/system/blockchain-api.service > /dev/null << EOF
[Unit]
Description=Blockchain Module REST API
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
Environment="PYTHONPATH=$(pwd)"
ExecStart=$(pwd)/venv/bin/python3 -c "from blockchain_module.rest_api import run_rest_api; import asyncio; asyncio.run(run_rest_api(host='0.0.0.0', port=8080))"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 11. Запрос API ключа
log_info "11. Настройка API ключа..."
echo ""
read -p "Введите ваш Nownodes API ключ (или нажмите Enter для настройки позже): " api_key
if [ ! -z "$api_key" ]; then
    sed -i "s/\"api_key\": \"\"/\"api_key\": \"$api_key\"/g" configs/module_config.json
    log_success "API ключ сохранен в конфигурации"
else
    log_warning "API ключ не установлен. Вы можете установить его позже в configs/module_config.json"
fi

# 12. Запуск сервисов
echo ""
read -p "Запустить мониторинг (Prometheus/Grafana) сейчас? (y/n): " start_monitoring
if [[ $start_monitoring == "y" || $start_monitoring == "Y" ]]; then
    log_info "Запуск мониторинга..."
    docker-compose -f docker-compose-monitoring.yml up -d
    log_success "Мониторинг запущен"
fi

echo ""
read -p "Запустить REST API сейчас? (y/n): " start_api
if [[ $start_api == "y" || $start_api == "Y" ]]; then
    log_info "Запуск REST API..."
    source venv/bin/activate
    export PYTHONPATH=$PYTHONPATH:$(pwd)
    screen -dmS blockchain-api bash scripts/start_api.sh
    sleep 3
    if pgrep -f "blockchain_module" > /dev/null; then
        log_success "REST API запущен в screen сессии"
    else
        log_error "Не удалось запустить REST API"
    fi
fi

# 13. Создание финального скрипта управления
cat > blockchain-manager.sh << 'EOF'
#!/bin/bash
# Управление Blockchain Module

case "$1" in
    start-api)
        echo "Запуск REST API..."
        cd "$(dirname "$0")"
        source venv/bin/activate
        export PYTHONPATH=$PYTHONPATH:$(pwd)
        screen -dmS blockchain-api python3 -c "
from blockchain_module.rest_api import run_rest_api
import asyncio
asyncio.run(run_rest_api(host='0.0.0.0', port=8080))
"
        echo "REST API запущен на порту 8080"
        ;;
    start-monitoring)
        echo "Запуск мониторинга..."
        docker-compose -f docker-compose-monitoring.yml up -d
        echo "Мониторинг запущен:"
        echo "  Prometheus: http://localhost:9090"
        echo "  Grafana:    http://localhost:3000 (admin/admin)"
        ;;
    stop)
        echo "Остановка всех сервисов..."
        pkill -f "blockchain_module" 2>/dev/null || true
        docker-compose -f docker-compose-monitoring.yml down
        echo "Все сервисы остановлены"
        ;;
    status)
        echo "=== Blockchain Module Status ==="
        echo ""
        echo "1. Python процессы:"
        pgrep -f "blockchain_module" && echo "  ✅ REST API запущен" || echo "  ❌ REST API не запущен"
        echo ""
        echo "2. Docker контейнеры:"
        docker-compose -f docker-compose-monitoring.yml ps
        echo ""
        echo "3. Порт 8080 (REST API):"
        netstat -tlnp 2>/dev/null | grep :8080 || echo "  Порт 8080 не слушается"
        echo ""
        echo "4. Порт 9090 (Prometheus):"
        netstat -tlnp 2>/dev/null | grep :9090 || echo "  Порт 9090 не слушается"
        ;;
    logs-api)
        echo "Логи REST API:"
        screen -r blockchain-api
        ;;
    logs-monitoring)
        echo "Логи мониторинга:"
        docker-compose -f docker-compose-monitoring.yml logs -f
        ;;
    update-config)
        echo "Обновление конфигурации..."
        cd "$(dirname "$0")"
        nano configs/module_config.json
        echo "Конфигурация обновлена. Перезапустите сервисы."
        ;;
    cli)
        echo "Запуск CLI интерфейса..."
        cd "$(dirname "$0")"
        source venv/bin/activate
        python3 -c "
from blockchain_module import start_cli
import asyncio
asyncio.run(start_cli())
"
        ;;
    *)
        echo "Использование: $0 {start-api|start-monitoring|stop|status|logs-api|logs-monitoring|update-config|cli}"
        echo ""
        echo "Команды:"
        echo "  start-api        - Запустить REST API"
        echo "  start-monitoring - Запустить мониторинг (Prometheus/Grafana)"
        echo "  stop             - Остановить все сервисы"
        echo "  status           - Показать статус сервисов"
        echo "  logs-api         - Показать логи REST API"
        echo "  logs-monitoring  - Показать логи мониторинга"
        echo "  update-config    - Редактировать конфигурацию"
        echo "  cli              - Запустить CLI интерфейс"
        exit 1
        ;;
esac
EOF

chmod +x blockchain-manager.sh

# 14. Финальный вывод
log_success "Установка завершена успешно!"
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Blockchain Module v2.0 установлен!            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "📊 СЕРВИСЫ:"
echo "  • REST API:           http://localhost:8080"
echo "  • Prometheus:         http://localhost:9090"
echo "  • Grafana:            http://localhost:3000 (admin/admin)"
echo "  • Node Exporter:      http://localhost:9100"
echo ""
echo "🔧 УПРАВЛЕНИЕ:"
echo "  ./blockchain-manager.sh [команда]"
echo ""
echo "📝 ОСНОВНЫЕ КОМАНДЫ:"
echo "  ./blockchain-manager.sh start-api        # Запустить REST API"
echo "  ./blockchain-manager.sh start-monitoring # Запустить мониторинг"
echo "  ./blockchain-manager.sh status           # Статус всех сервисов"
echo "  ./blockchain-manager.sh cli              # CLI интерфейс"
echo ""
echo "⚙️  КОНФИГУРАЦИЯ:"
echo "  Файл конфигурации:    configs/module_config.json"
echo "  База данных:          data/blockchain_module.db"
echo "  Логи:                 logs/"
echo ""
echo "🔐 АДМИНИСТРАТИВНЫЙ ДОСТУП:"
echo "  Для доступа к API используйте API ключ администратора"
echo "  (сгенерирован автоматически при первом запуске)"
echo ""
echo "📚 ДОКУМЕНТАЦИЯ:"
echo "  Полная документация:  https://github.com/ваш-репозиторий"
echo ""
echo -e "${YELLOW}⚠️  ПЕРЕЗАГРУЗИТЕ СИСТЕМУ или выполните: newgrp docker${NC}"
echo -e "${YELLOW}   чтобы права Docker вступили в силу${NC}"
