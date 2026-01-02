#!/bin/bash

set -e

echo "[WARNING] Скрипт запущен с правами root. Продолжаем..."

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║       Blockchain Module v2.0 - Автоматическая установка   ║
╚══════════════════════════════════════════════════════════╝
EOF

# Конфигурация
MODULE_DIR="/root/blockchain-module"
VENV_DIR="$MODULE_DIR/venv"
CONFIG_DIR="$MODULE_DIR/configs"
DATA_DIR="$MODULE_DIR/data"
LOGS_DIR="$MODULE_DIR/logs"
SCRIPTS_DIR="$MODULE_DIR/scripts"

echo "[INFO] 1. Обновление системы и установка зависимостей..."
apt-get update
apt-get upgrade -y
apt-get install -y python3 python3-pip python3-venv python3-dev \
                   build-essential git curl wget net-tools lsof htop screen \
                   sqlite3 libsqlite3-dev

echo "[INFO] 2. Установка Docker и Docker Compose..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo "[SUCCESS] Docker установлен"
else
    echo "[SUCCESS] Docker уже установлен"
fi

if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "[SUCCESS] Docker Compose установлен"
else
    echo "[SUCCESS] Docker Compose уже установлен"
fi

usermod -aG docker $USER || true

echo "[INFO] 3. Создание структуры директорий..."
mkdir -p $MODULE_DIR $CONFIG_DIR $DATA_DIR $LOGS_DIR $SCRIPTS_DIR

echo "[INFO] 4. Настройка Python окружения..."
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

echo "[INFO] 5. Установка Python зависимостей..."
pip install --upgrade pip

cat > $MODULE_DIR/requirements.txt << 'EOF'
aiohttp>=3.8.0
aiosqlite>=0.19.0
prometheus-client>=0.17.0
psutil>=5.9.0
requests>=2.28.0
asyncio>=3.4.3
typing-extensions>=4.5.0
pyyaml>=6.0
aiohttp_cors>=0.7.0
EOF

pip install -r $MODULE_DIR/requirements.txt

echo "[INFO] 6. Клонирование и установка модуля..."
cd /tmp
rm -rf blockchain_module_temp 2>/dev/null || true
git clone https://github.com/glebkoxan36/node_manager.git blockchain_module_temp

# Создаем структуру модуля
mkdir -p $MODULE_DIR/blockchain_module

# Копируем основные файлы модуля
MODULE_FILES=(
    "__init__.py"
    "config.py" 
    "connection_pool.py"
    "database.py"
    "blockchain_monitor.py"
    "funds_collector.py"
    "health_check.py"
    "monitoring.py"
    "nownodes_client.py"
    "rest_api.py"
    "users.py"
    "utils.py"
)

for file in "${MODULE_FILES[@]}"; do
    if [ -f "/tmp/blockchain_module_temp/blockchain_module/$file" ]; then
        cp "/tmp/blockchain_module_temp/blockchain_module/$file" "$MODULE_DIR/blockchain_module/"
        echo "[SUCCESS] Файл $file скопирован"
    else
        # Если файл не найден, создаем базовый
        echo "[WARNING] Файл $file не найден, создаем базовую версию"
        touch "$MODULE_DIR/blockchain_module/$file"
    fi
done

# Копируем дополнительные файлы
cp "/tmp/blockchain_module_temp/install.sh" "$MODULE_DIR/" 2>/dev/null || true
cp "/tmp/blockchain_module_temp/requirements.txt" "$MODULE_DIR/" 2>/dev/null || true

# Создаем __init__.py если он пустой
if [ ! -s "$MODULE_DIR/blockchain_module/__init__.py" ]; then
    cat > "$MODULE_DIR/blockchain_module/__init__.py" << 'EOF'
"""
Blockchain Module - Универсальный модуль для работы с криптовалютами через Nownodes API
"""

import logging
import sys
import os

__version__ = "2.0.0"
__author__ = "Blockchain Module Team"

# Добавляем путь к модулю
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Инициализация логгера
logging.getLogger(__name__).addHandler(logging.NullHandler())

def setup_logging(level=logging.INFO):
    """Настройка логирования"""
    logger = logging.getLogger(__name__)
    logger.setLevel(level)
    
    if not logger.handlers:
        handler = logging.StreamHandler()
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    
    return logger

# Проверка версии Python
if sys.version_info < (3, 7):
    raise RuntimeError("Этот модуль требует Python 3.7 или выше")

logger = setup_logging()
logger.info(f"Blockchain Module v{__version__} инициализирован")
EOF
fi

echo "[INFO] 7. Настройка конфигурационных файлов..."

# Создаем конфигурационный файл
cat > $CONFIG_DIR/module_config.json << 'EOF'
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

# Создаем конфигурацию Prometheus
cat > $CONFIG_DIR/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: 'production'

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: 'blockchain_module'
    scrape_interval: 15s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    scheme: 'http'
    
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'blockchain_module_main'
          component: 'application'

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'blockchain_module_server'
          component: 'system'

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Создаем алерты
cat > $CONFIG_DIR/alerts.yml << 'EOF'
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
      
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          component: system
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for 5 minutes"
      
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80
        for: 5m
        labels:
          severity: warning
          component: system
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 80% for 5 minutes"
EOF

echo "[INFO] 8. Настройка Docker Compose для мониторинга..."
cat > $MODULE_DIR/docker-compose.yml << 'EOF'
version: '3.8'

services:
  node_exporter:
    image: prom/node-exporter:latest
    container_name: blockchain_node_exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - "/proc:/host/proc:ro"
      - "/sys:/host/sys:ro"
      - "/:/rootfs:ro"
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - blockchain_network

  prometheus:
    image: prom/prometheus:latest
    container_name: blockchain_prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./configs/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./configs/alerts.yml:/etc/prometheus/alerts.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - blockchain_network

  grafana:
    image: grafana/grafana:latest
    container_name: blockchain_grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./configs/grafana_dashboards:/etc/grafana/provisioning/dashboards
      - ./configs/grafana_datasources:/etc/grafana/provisioning/datasources
    networks:
      - blockchain_network
    depends_on:
      - prometheus

volumes:
  prometheus_data:
  grafana_data:

networks:
  blockchain_network:
    driver: bridge
EOF

echo "[INFO] 9. Создание скриптов управления..."
cat > $MODULE_DIR/blockchain-manager.sh << 'EOF'
#!/bin/bash

MODULE_DIR="/root/blockchain-module"
VENV_DIR="$MODULE_DIR/venv"
CONFIG_DIR="$MODULE_DIR/configs"
LOGS_DIR="$MODULE_DIR/logs"

source $VENV_DIR/bin/activate

start_api() {
    echo "Запуск REST API..."
    cd $MODULE_DIR
    screen -dmS blockchain_api python3 -c "
import sys
sys.path.insert(0, '.')
from blockchain_module.rest_api import run_rest_api
import asyncio
asyncio.run(run_rest_api())
"
    echo "REST API запущен на порту 8080"
}

stop_api() {
    echo "Остановка REST API..."
    screen -S blockchain_api -X quit 2>/dev/null || true
    pkill -f "rest_api" 2>/dev/null || true
    echo "REST API остановлен"
}

start_monitoring() {
    echo "Запуск мониторинга..."
    cd $MODULE_DIR
    docker-compose up -d
    echo "Мониторинг запущен"
}

stop_monitoring() {
    echo "Остановка мониторинга..."
    cd $MODULE_DIR
    docker-compose down
    echo "Мониторинг остановлен"
}

start_cli() {
    echo "Запуск CLI интерфейса..."
    cd $MODULE_DIR
    python3 -c "
import sys
sys.path.insert(0, '.')
from blockchain_module import start_cli
import asyncio
asyncio.run(start_cli())
"
}

restart_api() {
    stop_api
    start_api
}

status() {
    echo "=== Blockchain Module Status ==="
    echo ""
    echo "1. Python процессы:"
    pgrep -f "rest_api\|blockchain_api" || echo "  ❌ Нет запущенных процессов"
    echo ""
    
    echo "2. Docker контейнеры:"
    cd $MODULE_DIR
    docker-compose ps 2>/dev/null || echo "  Docker Compose не найден"
    echo ""
    
    echo "3. Порт 8080 (REST API):"
    netstat -tlnp | grep :8080 || echo "  Порт 8080 не слушается"
    echo ""
    
    echo "4. Порт 9090 (Prometheus):"
    netstat -tlnp | grep :9090 || echo "  Порт 9090 не слушается"
}

case "$1" in
    start-api)
        start_api
        ;;
    stop-api)
        stop_api
        ;;
    restart-api)
        restart_api
        ;;
    start-monitoring)
        start_monitoring
        ;;
    stop-monitoring)
        stop_monitoring
        ;;
    cli)
        start_cli
        ;;
    status)
        status
        ;;
    *)
        echo "Использование: $0 {start-api|stop-api|restart-api|start-monitoring|stop-monitoring|cli|status}"
        echo ""
        echo "Команды:"
        echo "  start-api        Запустить REST API"
        echo "  stop-api         Остановить REST API"
        echo "  restart-api      Перезапустить REST API"
        echo "  start-monitoring Запустить мониторинг (Prometheus/Grafana)"
        echo "  stop-monitoring  Остановить мониторинг"
        echo "  cli              Запустить CLI интерфейс"
        echo "  status           Показать статус всех сервисов"
        exit 1
        ;;
esac
EOF

chmod +x $MODULE_DIR/blockchain-manager.sh

# Создаем простой CLI скрипт
cat > $MODULE_DIR/cli.py << 'EOF'
#!/usr/bin/env python3
"""
CLI интерфейс для Blockchain Module
"""

import asyncio
import sys
import os

# Добавляем путь к модулю
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

async def main():
    print("Blockchain Module CLI v2.0.0")
    print("=" * 40)
    
    try:
        from blockchain_module import start_cli
        await start_cli()
    except ImportError as e:
        print(f"Ошибка импорта: {e}")
        print("Убедитесь, что модуль установлен правильно.")
        sys.exit(1)
    except Exception as e:
        print(f"Ошибка: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
EOF

chmod +x $MODULE_DIR/cli.py

echo "[INFO] 10. Создание systemd сервисов..."
cat > /etc/systemd/system/blockchain-api.service << EOF
[Unit]
Description=Blockchain Module REST API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$MODULE_DIR
Environment="PATH=$VENV_DIR/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$VENV_DIR/bin/python3 -c "
import sys
sys.path.insert(0, '.')
from blockchain_module.rest_api import run_rest_api
import asyncio
asyncio.run(run_rest_api())
"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/blockchain-monitoring.service << EOF
[Unit]
Description=Blockchain Module Monitoring (Prometheus/Grafana)
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
WorkingDirectory=$MODULE_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo "[INFO] 11. Настройка API ключа..."
read -p "Введите ваш Nownodes API ключ (или нажмите Enter для настройки позже): " api_key

if [ -n "$api_key" ]; then
    python3 -c "
import json
import os
config_path = '$CONFIG_DIR/module_config.json'
if os.path.exists(config_path):
    with open(config_path, 'r') as f:
        config = json.load(f)
    config['module_settings']['api_key'] = '$api_key'
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    print('[SUCCESS] API ключ сохранен в конфигурации')
else:
    print('[ERROR] Конфигурационный файл не найден')
"
fi

echo "[INFO] 12. Запуск сервисов..."
read -p "Запустить мониторинг (Prometheus/Grafana) сейчас? (y/n): " start_monitoring

if [[ $start_monitoring =~ ^[Yy]$ ]]; then
    cd $MODULE_DIR
    docker-compose up -d
    echo "[SUCCESS] Мониторинг запущен"
else
    echo "[INFO] Мониторинг не запущен. Запустите позже командой: ./blockchain-manager.sh start-monitoring"
fi

read -p "Запустить REST API сейчас? (y/n): " start_api

if [[ $start_api =~ ^[Yy]$ ]]; then
    systemctl start blockchain-api
    systemctl enable blockchain-api
    echo "[SUCCESS] REST API запущен как systemd сервис"
else
    echo "[INFO] REST API не запущен. Запустите позже командой: ./blockchain-manager.sh start-api"
fi

cat << EOF
[SUCCESS] Установка завершена успешно!

╔══════════════════════════════════════════════════════════╗
║            Blockchain Module v2.0 установлен!            ║
╚══════════════════════════════════════════════════════════╝

📊 СЕРВИСЫ:
  • REST API:           http://localhost:8080
  • Prometheus:         http://localhost:9090
  • Grafana:            http://localhost:3000 (admin/admin)
  • Node Exporter:      http://localhost:9100

🔧 УПРАВЛЕНИЕ:
  ./blockchain-manager.sh [команда]

📝 ОСНОВНЫЕ КОМАНДЫ:
  ./blockchain-manager.sh start-api        # Запустить REST API
  ./blockchain-manager.sh start-monitoring # Запустить мониторинг
  ./blockchain-manager.sh status           # Статус всех сервисов
  ./blockchain-manager.sh cli              # CLI интерфейс

⚙️  КОНФИГУРАЦИЯ:
  Файл конфигурации:    configs/module_config.json
  База данных:          data/blockchain_module.db
  Логи:                 logs/

🔐 АДМИНИСТРАТИВНЫЙ ДОСТУП:
  Для доступа к API используйте API ключ администратора
  (сгенерирован автоматически при первом запуске)

⚠️  ПЕРЕЗАГРУЗИТЕ СИСТЕМУ или выполните: newgrp docker
   чтобы права Docker вступили в силу
EOF

# Создаем символическую ссылку для удобства
ln -sf $MODULE_DIR/blockchain-manager.sh /usr/local/bin/blockchain-manager 2>/dev/null || true

echo ""
echo "Для начала работы выполните:"
echo "  cd $MODULE_DIR"
echo "  ./blockchain-manager.sh status"
EOF
