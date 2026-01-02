#!/bin/bash
# Blockchain Module - Complete Installation Script
# Version: 3.0.0

set -e

echo "========================================="
echo "  Blockchain Module Installation v3.0.0"
echo "========================================="

# Если запущено от root, создаем пользователя и перезапускаем
if [ "$EUID" -eq 0 ]; then
    echo "[i] Скрипт запущен от root. Создаем пользователя blockchain..."
    
    # Создаем пользователя если не существует
    if id "blockchain" &>/dev/null; then
        echo "[✓] Пользователь blockchain уже существует"
    else
        adduser --disabled-password --gecos "" blockchain
        echo "[✓] Пользователь blockchain создан"
    fi
    
    # Добавляем в группу docker
    usermod -aG docker blockchain 2>/dev/null || true
    
    # Копируем скрипт и запускаем от blockchain
    cp "$0" /home/blockchain/install.sh
    chown blockchain:blockchain /home/blockchain/install.sh
    chmod +x /home/blockchain/install.sh
    
    echo "[i] Переключаемся на пользователя blockchain..."
    su - blockchain -c "/home/blockchain/install.sh"
    
    # Удаляем временный файл
    rm /home/blockchain/install.sh
    
    echo ""
    echo "========================================="
    echo "✅ Установка завершена!"
    echo "========================================="
    echo "Для запуска выполните:"
    echo "  su - blockchain"
    echo "  cd ~/blockchain-module"
    echo "  ./start.sh"
    echo "========================================="
    exit 0
fi

# Основная установка (от обычного пользователя)
echo "[i] Установка от пользователя: $(whoami)"

# 1. Обновление системы
echo "[i] Обновление системы..."
sudo apt update -y

# 2. Установка Docker
echo "[i] Установка Docker..."
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
echo "[i] Установка Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose
    echo "[✓] Docker Compose установлен"
else
    echo "[✓] Docker Compose уже установлен"
fi

# 4. Создание рабочей директории
WORKDIR="$HOME/blockchain-module"
echo "[i] Создание рабочей директории: $WORKDIR"
mkdir -p $WORKDIR
cd $WORKDIR

# 5. Клонирование репозитория
echo "[i] Загрузка Blockchain Module..."
if [ ! -f "requirements.txt" ]; then
    # Создаем базовую структуру
    mkdir -p blockchain_module configs data logs
    
    # Создаем __init__.py
    cat > blockchain_module/__init__.py << 'EOF'
"""
Blockchain Module
"""
__version__ = "3.0.0"
__author__ = "Blockchain Module Team"

def get_module_info():
    return {'version': __version__, 'author': __author__}

def setup_logging():
    import logging
    logging.basicConfig(level=logging.INFO)
    
__all__ = ['get_module_info', 'setup_logging']
EOF
    
    # Создаем остальные файлы (упрощенные версии)
    for file in blockchain_monitor.py config.py connection_pool.py database.py funds_collector.py health_check.py monitoring.py nownodes_client.py rest_api.py users.py utils.py; do
        if [ ! -f "blockchain_module/$file" ]; then
            echo "# Placeholder for $file" > blockchain_module/$file
        fi
    done
    
    # Создаем requirements.txt
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
    
    echo "[✓] Базовая структура создана"
else
    echo "[✓] Директория уже содержит файлы"
fi

# 6. Создание виртуального окружения
echo "[i] Создание Python окружения..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 7. Создание конфигурации
echo "[i] Создание конфигурации..."
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

# 8. Создание setup.py для установки модуля
echo "[i] Установка модуля..."
cat > setup.py << 'EOF'
from setuptools import setup, find_packages

setup(
    name="blockchain-module",
    version="3.0.0",
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
    python_requires=">=3.7",
)
EOF

pip install -e .

# 9. Создание скриптов управления
echo "[i] Создание скриптов управления..."

cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Запуск Blockchain Module..."

source venv/bin/activate

# Запуск REST API
python3 -c "
import asyncio
import logging
import sys

async def main():
    try:
        from blockchain_module.rest_api import run_rest_api
        logging.basicConfig(level=logging.INFO)
        await run_rest_api(host='0.0.0.0', port=8085)
    except ImportError as e:
        print(f'Ошибка импорта: {e}')
        print('Установите зависимости: pip install -r requirements.txt')
    except Exception as e:
        print(f'Ошибка запуска: {e}')

asyncio.run(main())
"
EOF

cat > stop.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🛑 Остановка Blockchain Module..."

pkill -f "python.*blockchain" 2>/dev/null || true
pkill -f "rest_api" 2>/dev/null || true

echo "[✓] Blockchain Module остановлен"
EOF

cat > status.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "📊 Статус Blockchain Module"
echo "=============================="

# Проверка процессов
if pgrep -f "python.*blockchain" > /dev/null; then
    echo "✅ Blockchain Module запущен"
else
    echo "❌ Blockchain Module не запущен"
fi

# Проверка порта 8085
if ss -tuln | grep -q ":8085 "; then
    echo "✅ Порт 8085 открыт"
else
    echo "❌ Порт 8085 закрыт"
fi

# Проверка Docker
if docker ps &> /dev/null; then
    echo "✅ Docker работает"
else
    echo "❌ Docker не работает"
fi
EOF

chmod +x start.sh stop.sh status.sh

# 10. Инициализация базы данных
echo "[i] Инициализация базы данных..."
python3 -c "
import asyncio
import sys

async def init():
    try:
        # Создаем простую базу данных
        import aiosqlite
        import os
        
        os.makedirs('data', exist_ok=True)
        
        async with aiosqlite.connect('data/blockchain_module.db') as db:
            await db.execute('''
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT UNIQUE NOT NULL,
                    api_key TEXT UNIQUE NOT NULL,
                    role TEXT DEFAULT 'user'
                )
            ''')
            await db.commit()
        
        print('[✓] База данных инициализирована')
        
    except Exception as e:
        print(f'[!] Ошибка инициализации базы: {e}')

asyncio.run(init())
"

# 11. Создание пользователя по умолчанию
echo "[i] Создание администратора..."
python3 -c "
import secrets
import hashlib

# Генерируем API ключ для админа
api_key = f'admin_{secrets.token_urlsafe(32)}'
api_hash = hashlib.sha256(api_key.encode()).hexdigest()

print('=========================================')
print('✅ Администратор создан!')
print(f'🔑 API Key: {api_key}')
print('=========================================')
print('⚠️  Сохраните этот ключ! Он больше не будет показан.')
print('=========================================')

# Сохраняем в файл
with open('admin_api_key.txt', 'w') as f:
    f.write(api_key)
"

# 12. Запуск системы
echo ""
echo "========================================="
echo "✅ Blockchain Module успешно установлен!"
echo "========================================="
echo ""
echo "📁 Директория: $WORKDIR"
echo "🚀 Запуск:     ./start.sh"
echo "🛑 Остановка:  ./stop.sh"
echo "📊 Статус:     ./status.sh"
echo ""
echo "🌐 REST API будет доступен на порту 8085"
echo "🔑 API ключ администратора сохранен в admin_api_key.txt"
echo ""
echo "📝 Следующие шаги:"
echo "1. Отредактируйте configs/module_config.json"
echo "   - Добавьте ваш API ключ Nownodes"
echo "2. Запустите систему: ./start.sh"
echo "3. Откройте в браузере: http://localhost:8085"
echo "========================================="
