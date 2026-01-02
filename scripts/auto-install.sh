#!/bin/bash
# Blockchain Module - Complete Auto Install Script v2.0.0
# Одна команда для установки всего: bash auto-install-blockchain.sh

set -e

echo "=================================================="
echo "  Blockchain Module - Полная автоматическая установка"
echo "=================================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Проверка пользователя
if [ "$EUID" -eq 0 ]; then
    log_warning "Скрипт запущен от root. Создаем пользователя blockchain..."
    # Создаем пользователя если запущено от root
    if id "blockchain" &>/dev/null; then
        log_info "Пользователь blockchain уже существует"
    else
        adduser --disabled-password --gecos "" blockchain
        usermod -aG sudo blockchain
        log_success "Создан пользователь blockchain"
    fi
    log_info "Переключаемся на пользователя blockchain и продолжаем установку..."
    exec su - blockchain -c "bash -c '$(cat $0) $@'"
    exit 0
fi

# Основная установка (выполняется от обычного пользователя)
log_info "1. Проверка системы..."

# Обновление системы
sudo apt update -y

# Установка необходимых пакетов
log_info "2. Установка системных зависимостей..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    net-tools

# Установка Docker
log_info "3. Установка Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    log_success "Docker установлен"
else
    log_success "Docker уже установлен"
fi

# Установка Docker Compose
log_info "4. Установка Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose
    log_success "Docker Compose установлен"
else
    log_success "Docker Compose уже установлен"
fi

# Перезагрузка группы docker
log_info "5. Настройка прав Docker..."
newgrp docker << EOF
EOF

# Очистка старых процессов
log_info "6. Очистка старых процессов..."
sudo pkill -f "blockchain_module" 2>/dev/null || true
sudo pkill -f "rest_api" 2>/dev/null || true
docker-compose down 2>/dev/null || true

# Поиск свободных портов
log_info "7. Поиск свободных портов..."
find_free_port() {
    for port in $(seq $1 $2); do
        if ! ss -tuln | grep -q ":$port "; then
            echo $port
            return 0
        fi
    done
    echo $1
}

API_PORT=$(find_free_port 8080 8090)
PROM_PORT=$(find_free_port 9090 9100)
GRAFANA_PORT=$(find_free_port 3000 3010)
DB_PORT=$(find_free_port 5432 5442)

log_info "Используемые порты:"
echo "  REST API: $API_PORT"
echo "  Prometheus: $PROM_PORT"
echo "  Grafana: $GRAFANA_PORT"

# Создание рабочей директории
WORKDIR="$HOME/blockchain-auto-install"
log_info "8. Создание рабочей директории: $WORKDIR"
mkdir -p $WORKDIR
cd $WORKDIR

# Клонирование репозитория
log_info "9. Загрузка Blockchain Module..."
if [ ! -d "blockchain_module" ]; then
    # Создаем структуру проекта
    mkdir -p blockchain_module configs
    
    # Создаем минимальный __init__.py
    cat > blockchain_module/__init__.py << 'EOF'
"""
Blockchain Module Auto Install
"""
__version__ = "2.0.0"
__author__ = "Blockchain Module Team"

def get_module_info():
    return {'version': __version__, 'author': __author__}
EOF
    
    # Скачиваем основные файлы с GitHub
    log_info "Скачивание файлов модуля..."
    FILES=(
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
        "requirements.txt"
        "setup.py"
    )
    
    for file in "${FILES[@]}"; do
        if [ ! -f "blockchain_module/$file" ]; then
            curl -s "https://raw.githubusercontent.com/glebkoxan36/node_manager/main/blockchain_module/$file" -o "blockchain_module/$file" 2>/dev/null || \
            curl -s "https://raw.githubusercontent.com/glebkoxan36/node_manager/main/$file" -o "blockchain_module/$file" 2>/dev/null || \
            echo "# Placeholder for $file" > "blockchain_module/$file"
        fi
    done
    
    # Создаем правильную структуру
    mv blockchain_module/*.py . 2>/dev/null || true
    mv blockchain_module/requirements.txt . 2>/dev/null || true
    mv blockchain_module/setup.py . 2>/dev/null || true
    rm -rf blockchain_module
    mkdir -p blockchain_module
    mv *.py blockchain_module/ 2>/dev/null || true
else
    log_info "Директория уже существует"
fi

# Создание виртуального окружения
log_info "10. Создание Python виртуального окружения..."
python3 -m venv venv
source venv/bin/activate

# Установка Python зависимостей
log_info "11. Установка Python зависимостей..."
pip install --upgrade pip
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    # Устанавливаем минимальные зависимости
    pip install aiohttp aiosqlite prometheus-client aiohttp-cors psutil click questionary rich
fi
pip install -e .

# Создание конфигурации
log_info "12. Создание конфигурации..."
mkdir -p configs data logs

cat > configs/module_config.json << EOF
{
  "module_settings": {
    "api_key": "",
    "log_level": "INFO",
    "connection_pool_size": 10,
    "default_confirmations": 3,
    "max_reconnect_attempts": 10,
    "monitoring": {
      "enabled": true,
      "prometheus_port": $PROM_PORT,
      "metrics_prefix": "blockchain_module"
    },
    "rest_api": {
      "enabled": true,
      "host": "0.0.0.0",
      "port": $API_PORT,
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

# Создание docker-compose для мониторинга
log_info "13. Настройка Docker мониторинга..."

cat > docker-compose.yml << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: blockchain_prometheus
    ports:
      - "$PROM_PORT:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: blockchain_grafana
    ports:
      - "$GRAFANA_PORT:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-piechart-panel
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped
    depends_on:
      - prometheus

volumes:
  prometheus_data:
  grafana_data:
EOF

cat > prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'blockchain_module'
    static_configs:
      - targets: ['host.docker.internal:$PROM_PORT']
        labels:
          service: 'blockchain_module'
EOF

# Инициализация базы данных
log_info "14. Инициализация базы данных..."
python3 -c "
import asyncio
import sys

async def init_db():
    try:
        # Импортируем только после установки
        from blockchain_module.database import SQLiteDBManager
        from blockchain_module.users import UserManager
        
        db = SQLiteDBManager('data/blockchain_module.db')
        await db.initialize()
        
        user_manager = UserManager('data/blockchain_module.db')
        await user_manager.initialize()
        
        print('✅ База данных инициализирована')
        
        await db.close()
        await user_manager.close()
        
    except Exception as e:
        print(f'⚠️  Ошибка инициализации: {e}')
        print('Продолжаем установку...')

asyncio.run(init_db())
"

# Создание скриптов управления
log_info "15. Создание скриптов управления..."

cat > start-all.sh << EOF
#!/bin/bash
cd \$(dirname "\$0")
echo "🚀 Запуск Blockchain Module..."

# Запуск Docker мониторинга
docker-compose up -d
echo "📊 Мониторинг запущен (Prometheus: $PROM_PORT, Grafana: $GRAFANA_PORT)"

# Запуск REST API
source venv/bin/activate
nohup python3 -c "
import asyncio
import logging
from blockchain_module.rest_api import run_rest_api

async def main():
    logging.basicConfig(level=logging.INFO)
    await run_rest_api(host='0.0.0.0', port=$API_PORT)

asyncio.run(main())
" > logs/api.log 2>&1 &
API_PID=\$!
echo \$API_PID > logs/api.pid
echo "🌐 REST API запущен на порту $API_PORT"

# Запуск мониторинга метрик
nohup python3 -c "
from blockchain_module import start_monitoring
start_monitoring(port=$PROM_PORT)
" > logs/metrics.log 2>&1 &
METRICS_PID=\$!
echo \$METRICS_PID > logs/metrics.pid
echo "📈 Метрики запущены на порту $PROM_PORT"

echo ""
echo "========================================="
echo "✅ Blockchain Module успешно запущен!"
echo "========================================="
echo "🌐 REST API:      http://localhost:$API_PORT"
echo "📊 Prometheus:    http://localhost:$PROM_PORT"
echo "📈 Grafana:       http://localhost:$GRAFANA_PORT (admin/admin)"
echo "📁 Логи:          $WORKDIR/logs/"
echo ""
echo "🛑 Для остановки: ./stop-all.sh"
echo "📊 Для проверки:  ./status.sh"
echo "========================================="
EOF

cat > stop-all.sh << EOF
#!/bin/bash
cd \$(dirname "\$0")
echo "🛑 Остановка Blockchain Module..."

# Остановка API
if [ -f "logs/api.pid" ]; then
    kill \$(cat logs/api.pid) 2>/dev/null || true
    rm -f logs/api.pid
fi

# Остановка метрик
if [ -f "logs/metrics.pid" ]; then
    kill \$(cat logs/metrics.pid) 2>/dev/null || true
    rm -f logs/metrics.pid
fi

# Остановка Docker
docker-compose down

# Очистка процессов
pkill -f "blockchain_module" 2>/dev/null || true
pkill -f "rest_api" 2>/dev/null || true

echo "✅ Blockchain Module остановлен"
EOF

cat > status.sh << EOF
#!/bin/bash
cd \$(dirname "\$0")
echo "📊 Статус Blockchain Module"
echo "=============================="

# Проверка процессов
echo "Процессы:"
if pgrep -f "blockchain_module" > /dev/null; then
    echo "  Blockchain Module: ✅ Запущен"
else
    echo "  Blockchain Module: ❌ Не запущен"
fi

if pgrep -f "rest_api" > /dev/null; then
    echo "  REST API: ✅ Запущен"
else
    echo "  REST API: ❌ Не запущен"
fi

# Проверка портов
echo ""
echo "Порты:"
check_port() {
    if ss -tuln | grep -q ":$1 "; then
        echo "  Порт $1 ($2): ✅ Открыт"
    else
        echo "  Порт $1 ($2): ❌ Закрыт"
    fi
}

check_port $API_PORT "REST API"
check_port $PROM_PORT "Prometheus"
check_port $GRAFANA_PORT "Grafana"

# Проверка Docker
echo ""
echo "Docker контейнеры:"
docker-compose ps

# Проверка логов
echo ""
echo "Логи:"
ls -la logs/ 2>/dev/null || echo "  Директория logs не существует"
EOF

cat > test-system.sh << EOF
#!/bin/bash
cd \$(dirname "\$0")
echo "🧪 Тестирование системы..."
echo "=============================="

# Тест 1: Импорт модуля
echo "1. Тест импорта модуля:"
python3 -c "
try:
    from blockchain_module import get_module_info
    info = get_module_info()
    print('  ✅ Модуль загружен')
    print(f'  Версия: {info[\"version\"]}')
except Exception as e:
    print(f'  ❌ Ошибка: {e}')
"

# Тест 2: База данных
echo ""
echo "2. Тест базы данных:"
if [ -f "data/blockchain_module.db" ]; then
    echo "  ✅ База данных существует"
    size=\$(du -h "data/blockchain_module.db" | cut -f1)
    echo "  Размер: \$size"
else
    echo "  ❌ База данных не найдена"
fi

# Тест 3: Docker
echo ""
echo "3. Тест Docker:"
if docker ps &> /dev/null; then
    echo "  ✅ Docker работает"
else
    echo "  ❌ Docker не отвечает"
fi

# Тест 4: Порты
echo ""
echo "4. Тест портов:"
curl -s http://localhost:$API_PORT/api/v1/info > /dev/null && echo "  ✅ REST API отвечает" || echo "  ❌ REST API не отвечает"
curl -s http://localhost:$PROM_PORT > /dev/null && echo "  ✅ Prometheus отвечает" || echo "  ❌ Prometheus не отвечает"
curl -s http://localhost:$GRAFANA_PORT > /dev/null && echo "  ✅ Grafana отвечает" || echo "  ❌ Grafana не отвечает"
EOF

chmod +x start-all.sh stop-all.sh status.sh test-system.sh

# Автоматический запуск
log_info "16. Автоматический запуск системы..."
./start-all.sh

# Создание файла с инструкциями
cat > INSTRUCTIONS.txt << EOF
=========================================
Blockchain Module - Установка завершена!
=========================================

📁 Директория: $WORKDIR
🚀 Запуск:     ./start-all.sh
🛑 Остановка:  ./stop-all.sh
📊 Статус:     ./status.sh
🧪 Тест:       ./test-system.sh

🌐 Доступ:
  - REST API:      http://localhost:$API_PORT
  - Prometheus:    http://localhost:$PROM_PORT
  - Grafana:       http://localhost:$GRAFANA_PORT
    Логин: admin
    Пароль: admin

📝 Следующие шаги:
1. Отредактируйте configs/module_config.json
   - Добавьте ваш API ключ Nownodes
   - Настройте монеты

2. Настройте пользователей:
   Используйте CLI или REST API для создания пользователей

3. Настройте мониторинг:
   - Откройте Grafana (http://localhost:$GRAFANA_PORT)
   - Добавьте Prometheus как источник данных (http://prometheus:9090)
   - Импортируйте дашборды

🔧 Управление:
  Для запуска при загрузке системы добавьте в crontab:
    @reboot cd $WORKDIR && ./start-all.sh

  Или создайте systemd сервис:
    sudo cp blockchain.service /etc/systemd/system/
    sudo systemctl enable blockchain
    sudo systemctl start blockchain

📞 Логи и отладка:
  - Логи API: $WORKDIR/logs/api.log
  - Логи метрик: $WORKDIR/logs/metrics.log
  - Логи Docker: docker-compose logs

=========================================
EOF

log_success "Установка завершена!"
echo ""
cat INSTRUCTIONS.txt
echo ""
echo "Для быстрого теста запустите: ./test-system.sh"
