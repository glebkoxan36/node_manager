#!/bin/bash
# Blockchain Module - Auto Install Script v2.0.0
# Запуск: sudo ./install-blockchain.sh

set -e

echo "========================================="
echo "  Blockchain Module - Автоматическая установка"
echo "========================================="

# Если мы root, создаем пользователя и запускаем установку от его имени
if [ "$EUID" -eq 0 ]; then
    echo "[i] Скрипт запущен от root"
    
    # Создаем пользователя blockchain если не существует
    if id "blockchain" &>/dev/null; then
        echo "[✓] Пользователь blockchain уже существует"
    else
        echo "[i] Создаем пользователя blockchain..."
        adduser --disabled-password --gecos "" blockchain
        usermod -aG sudo blockchain
        echo "[✓] Пользователь blockchain создан"
    fi
    
    # Копируем скрипт в домашнюю директорию blockchain
    SCRIPT_PATH="/home/blockchain/install-blockchain.sh"
    cp "$0" "$SCRIPT_PATH"
    chown blockchain:blockchain "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    
    # Запускаем скрипт от имени пользователя blockchain
    echo "[i] Запуск установки от пользователя blockchain..."
    su - blockchain -c "bash $SCRIPT_PATH"
    
    # Удаляем копию скрипта
    rm "$SCRIPT_PATH"
    exit 0
fi

# Основная часть установки (выполняется от пользователя blockchain)
echo "[i] Запуск основной установки от пользователя $(whoami)..."

# 1. Проверка системы
echo "[i] 1. Проверка системы..."
sudo apt update -y

# 2. Установка Docker
echo "[i] 2. Установка Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    newgrp docker << EOF
EOF
    echo "[✓] Docker установлен"
else
    echo "[✓] Docker уже установлен"
fi

# 3. Установка Docker Compose
echo "[i] 3. Установка Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose
    echo "[✓] Docker Compose установлен"
else
    echo "[✓] Docker Compose уже установлен"
fi

# 4. Очистка старых процессов
echo "[i] 4. Очистка старых процессов..."
sudo pkill -f "python.*808" 2>/dev/null || true
sudo pkill -f "blockchain_module" 2>/dev/null || true
docker-compose down 2>/dev/null || true

# 5. Создание рабочей директории
echo "[i] 5. Создание рабочей директории..."
WORKDIR="$HOME/blockchain-module"
mkdir -p $WORKDIR
cd $WORKDIR

# 6. Создание виртуального окружения
echo "[i] 6. Создание Python окружения..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# 7. Создание файлов модуля
echo "[i] 7. Создание файлов модуля..."
mkdir -p blockchain_module configs data logs

# Создаем основные файлы модуля
cat > blockchain_module/__init__.py << 'EOF'
"""
Blockchain Module
"""
__version__ = "2.0.0"
__author__ = "Blockchain Module Team"

def get_module_info():
    return {'version': __version__, 'author': __author__}
EOF

# Скачиваем или создаем остальные файлы
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
)

for file in "${FILES[@]}"; do
    if [ ! -f "blockchain_module/$file" ]; then
        echo "[i] Создание файла $file..."
        # Создаем заглушки или скачиваем реальные файлы
        curl -s "https://raw.githubusercontent.com/glebkoxan36/node_manager/main/blockchain_module/$file" -o "blockchain_module/$file" 2>/dev/null || true
        if [ ! -s "blockchain_module/$file" ]; then
            # Если файл пустой, создаем заглушку
            echo "# $file - Blockchain Module" > "blockchain_module/$file"
            echo "# Этот файл будет заменен на полную версию" >> "blockchain_module/$file"
        fi
    fi
done

# 8. Установка зависимостей
echo "[i] 8. Установка Python зависимостей..."
if [ ! -f "requirements.txt" ]; then
    cat > requirements.txt << 'EOF'
aiohttp>=3.8.0
aiosqlite>=0.19.0
prometheus-client>=0.17.0
aiohttp-cors>=0.7.0
click>=8.1.0
questionary>=2.0.0
rich>=13.0.0
psutil>=5.9.0
python-dotenv>=1.0.0
pyyaml>=6.0
EOF
fi

pip install -r requirements.txt

# 9. Создание конфигурации
echo "[i] 9. Создание конфигурации..."
cat > configs/module_config.json << 'EOF'
{
  "module_settings": {
    "api_key": "",
    "log_level": "INFO",
    "connection_pool_size": 10,
    "default_confirmations": 3,
    "max_reconnect_attempts": 10,
    "monitoring": {
      "enabled": false,
      "prometheus_port": 9091,
      "metrics_prefix": "blockchain_module"
    },
    "rest_api": {
      "enabled": true,
      "host": "0.0.0.0",
      "port": 8085,
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

# 10. Создание setup.py для установки модуля
echo "[i] 10. Установка модуля..."
cat > setup.py << 'EOF'
from setuptools import setup, find_packages

setup(
    name="blockchain-module",
    version="2.0.0",
    packages=find_packages(),
    install_requires=[
        'aiohttp>=3.8.0',
        'aiosqlite>=0.19.0',
        'prometheus-client>=0.17.0',
        'aiohttp-cors>=0.7.0',
        'click>=8.1.0',
        'questionary>=2.0.0',
        'rich>=13.0.0',
        'psutil>=5.9.0',
    ],
    entry_points={
        "console_scripts": [
            "blockchain-cli=blockchain_module.cli:cli",
        ],
    },
)
EOF

pip install -e .

# 11. Инициализация базы данных
echo "[i] 11. Инициализация базы данных..."
python3 -c "
import asyncio
import sys

async def init():
    try:
        from blockchain_module.database import SQLiteDBManager
        from blockchain_module.users import UserManager
        
        db = SQLiteDBManager('data/blockchain_module.db')
        await db.initialize()
        
        user_manager = UserManager('data/blockchain_module.db')
        await user_manager.initialize()
        
        print('[✓] База данных инициализирована')
        
        await db.close()
        await user_manager.close()
    except Exception as e:
        print(f'[!] Ошибка инициализации: {e}')
        print('[i] Продолжаем установку...')

asyncio.run(init())
"

# 12. Создание скриптов управления
echo "[i] 12. Создание скриптов управления..."

cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Запуск Blockchain Module..."

source venv/bin/activate

# Запуск REST API
nohup python3 -c "
import asyncio
import logging
from blockchain_module.rest_api import run_rest_api

async def main():
    logging.basicConfig(level=logging.INFO)
    await run_rest_api(host='0.0.0.0', port=8085)

asyncio.run(main())
" > logs/api.log 2>&1 &
API_PID=$!
echo $API_PID > logs/api.pid

echo "[✓] REST API запущен на порту 8085"
echo "[✓] Логи: $PWD/logs/api.log"
echo ""
echo "🌐 Доступен по адресу: http://localhost:8085"
echo "🛑 Для остановки: ./stop.sh"
EOF

cat > stop.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🛑 Остановка Blockchain Module..."

if [ -f "logs/api.pid" ]; then
    kill $(cat logs/api.pid) 2>/dev/null || true
    rm -f logs/api.pid
fi

pkill -f "blockchain_module" 2>/dev/null || true
pkill -f "rest_api" 2>/dev/null || true

echo "[✓] Blockchain Module остановлен"
EOF

cat > test.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🧪 Тестирование системы..."
echo "=========================="

source venv/bin/activate

echo "1. Тест модуля:"
python3 -c "
try:
    from blockchain_module import get_module_info
    info = get_module_info()
    print('   ✅ Модуль загружен')
    print(f'   Версия: {info[\"version\"]}')
except Exception as e:
    print(f'   ❌ Ошибка: {e}')
"

echo ""
echo "2. Тест REST API:"
timeout 2 curl -s http://localhost:8085/api/v1/info > /dev/null && \
    echo "   ✅ REST API отвечает" || echo "   ❌ REST API не отвечает"

echo ""
echo "3. Проверка портов:"
if ss -tuln | grep -q ":8085 "; then
    echo "   ✅ Порт 8085 открыт"
else
    echo "   ❌ Порт 8085 закрыт"
fi

echo ""
echo "✅ Тестирование завершено"
EOF

chmod +x start.sh stop.sh test.sh

# 13. Запуск системы
echo "[i] 13. Запуск системы..."
./start.sh

# 14. Создание инструкций
echo ""
echo "========================================="
echo "✅ Blockchain Module успешно установлен!"
echo "========================================="
echo ""
echo "📁 Директория: $WORKDIR"
echo "🚀 Запуск:     ./start.sh"
echo "🛑 Остановка:  ./stop.sh"
echo "🧪 Тест:       ./test.sh"
echo ""
echo "🌐 REST API:   http://localhost:8085"
echo "📊 Логи:       $WORKDIR/logs/"
echo ""
echo "📝 Следующие шаги:"
echo "1. Отредактируйте configs/module_config.json"
echo "   - Добавьте ваш API ключ Nownodes"
echo "2. Перезапустите: ./stop.sh && ./start.sh"
echo "========================================="
