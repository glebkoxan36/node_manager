#!/bin/bash
# Автоматическая настройка и запуск Blockchain Module

set -e  # Прерывать скрипт при ошибках

echo "=== Blockchain Module Auto Setup ==="

# Функции
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

# 1. Остановим все Python процессы
log_info "Остановка всех процессов blockchain_module..."
pkill -f "blockchain_module" 2>/dev/null || true
pkill -f "python.*rest_api" 2>/dev/null || true
pkill -f "python.*808" 2>/dev/null || true

sleep 2

# 2. Проверим освободились ли порты
log_info "Проверка занятых портов..."
if sudo netstat -tlnp 2>/dev/null | grep :808; then
    log_error "Порты 808x все еще заняты"
    echo "Попытка освободить порты..."
    sudo kill $(sudo lsof -t -i :8080 2>/dev/null) 2>/dev/null || true
    sudo kill $(sudo lsof -t -i :8081 2>/dev/null) 2>/dev/null || true
    sudo kill $(sudo lsof -t -i :8082 2>/dev/null) 2>/dev/null || true
    sleep 2
fi

# 3. Отключим автозапуск REST API в конфигурации
log_info "Отключение автозапуска REST API..."
CONFIG_FILE="configs/module_config.json"
if [ -f "$CONFIG_FILE" ]; then
    # Отключаем REST API и мониторинг
    sed -i 's/"enabled": true/"enabled": false/g' "$CONFIG_FILE"
    sed -i 's/"port": 8080/"port": 8089/g' "$CONFIG_FILE"
    log_success "Конфигурация обновлена"
else
    log_error "Конфигурационный файл не найден: $CONFIG_FILE"
    echo "Создание базовой конфигурации..."
    mkdir -p configs
    cat > "$CONFIG_FILE" << 'EOF'
{
  "module_settings": {
    "api_key": "",
    "log_level": "INFO",
    "connection_pool_size": 10,
    "default_confirmations": 3,
    "max_reconnect_attempts": 10,
    "monitoring": {
      "enabled": false,
      "prometheus_port": 9090,
      "metrics_prefix": "blockchain_module"
    },
    "rest_api": {
      "enabled": false,
      "host": "0.0.0.0",
      "port": 8089,
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
fi

# 4. Исправим ошибку с logger в __init__.py
log_info "Исправление ошибки в __init__.py..."
FIX_SCRIPT="/tmp/fix_init.py"
cat > "$FIX_SCRIPT" << 'EOF'
import os
import re

file_path = "blockchain_module/__init__.py"

with open(file_path, 'r') as f:
    content = f.read()

# Исправим функцию run_server
old_pattern = r'def run_server\(\):\s*\n\s+try:\s*\n.*?logger\.error\(f"REST API server error: {e}"\)'
new_code = '''def run_server():
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(run_rest_api(host, port))
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"REST API server error: {e}")'''

# Заменяем старую функцию на новую
if 'logger.error(f"REST API server error: {e}")' in content:
    # Простая замена строки
    content = content.replace('logger.error(f"REST API server error: {e}")', 
                             'import logging\n                logging.getLogger(__name__).error(f"REST API server error: {e}")')
    with open(file_path, 'w') as f:
        f.write(content)
    print("Fixed __init__.py - replaced logger.error line")
else:
    print("No fix needed or already fixed")
EOF

python3 "$FIX_SCRIPT"

# 5. Найдем свободный порт
log_info "Поиск свободного порта..."
FIND_PORT_SCRIPT="/tmp/find_port.py"
cat > "$FIND_PORT_SCRIPT" << 'EOF'
import socket
import sys

def find_free_port(start=8000, end=9000):
    for port in range(start, end):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                s.bind(('0.0.0.0', port))
                return port
        except OSError:
            continue
    return 8089  # fallback

port = find_free_port(8000, 9000)
print(port)
EOF

FREE_PORT=$(python3 "$FIND_PORT_SCRIPT")
log_success "Свободный порт найден: $FREE_PORT"

# 6. Создадим скрипт для запуска REST API
log_info "Создание скрипта запуска REST API..."
cat > run_rest_api.py << EOF
#!/usr/bin/env python3
"""Запуск REST API"""

import asyncio
import logging
import sys
from blockchain_module.rest_api import run_rest_api

async def main():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    
    # Используем порт из аргумента или свободный
    port = int(sys.argv[1]) if len(sys.argv) > 1 else $FREE_PORT
    logger.info(f"Starting REST API on port {port}")
    
    try:
        await run_rest_api(host='0.0.0.0', port=port)
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        raise

if __name__ == "__main__":
    asyncio.run(main())
EOF

chmod +x run_rest_api.py

# 7. Запустим REST API в фоне
log_info "Запуск REST API на порту $FREE_PORT..."
python3 run_rest_api.py $FREE_PORT &
API_PID=$!
sleep 5

# Проверим запустился ли процесс
if ps -p $API_PID > /dev/null; then
    log_success "REST API запущен (PID: $API_PID) на порту $FREE_PORT"
else
    log_error "Не удалось запустить REST API"
    # Попробуем альтернативный порт
    ALTERNATIVE_PORT=$((FREE_PORT + 1))
    log_info "Попытка альтернативного порта: $ALTERNATIVE_PORT"
    python3 run_rest_api.py $ALTERNATIVE_PORT &
    API_PID=$!
    sleep 3
    if ps -p $API_PID > /dev/null; then
        FREE_PORT=$ALTERNATIVE_PORT
        log_success "REST API запущен на альтернативном порту $FREE_PORT"
    fi
fi

# 8. Проверим работает ли API
log_info "Проверка работы API..."
sleep 3
if curl -s -o /dev/null -w "%{http_code}" http://localhost:$FREE_PORT/api/v1/info 2>/dev/null | grep -q "200\|401\|403"; then
    log_success "API работает! Доступен на http://localhost:$FREE_PORT"
else
    log_error "API не отвечает. Проверка через CLI..."
fi

# 9. Тестируем CLI
log_info "Тестирование CLI интерфейса..."
echo ""
echo "=== Доступные команды CLI ==="
blockchain-cli --help 2>/dev/null || {
    log_error "CLI не доступен"
    echo "Попытка установки CLI..."
    pip install -e . 2>/dev/null || true
}

echo ""
echo "=== Статус системы ==="
blockchain-cli system-status 2>/dev/null || echo "CLI команда не доступна"

echo ""
echo "=== Информация о модуле ==="
python3 -c "
try:
    from blockchain_module import get_module_info
    import json
    info = get_module_info()
    print(json.dumps(info, indent=2, ensure_ascii=False))
except Exception as e:
    print(f'Ошибка: {e}')
"

# 10. Проверим базу данных
log_info "Проверка базы данных..."
mkdir -p data
python3 -c "
import asyncio
import sys

async def test_db():
    try:
        from blockchain_module.database import SQLiteDBManager
        db = SQLiteDBManager('data/blockchain_module.db')
        await db.initialize()
        
        async with db.connection.cursor() as cursor:
            await cursor.execute(\"SELECT name FROM sqlite_master WHERE type='table';\")
            tables = await cursor.fetchall()
            print('Таблицы в базе:', [t[0] for t in tables])
        
        stats = await db.get_stats()
        print('Статистика базы:', stats)
        
        await db.close()
        print('✅ База данных работает корректно')
    except Exception as e:
        print(f'❌ Ошибка базы данных: {e}')
        sys.exit(1)

asyncio.run(test_db())
"

# 11. Вывод информации
log_success "Настройка завершена!"
echo ""
echo "========================================="
echo "          Blockchain Module v2.0.0"
echo "========================================="
echo "API URL:      http://localhost:$FREE_PORT"
echo "API PID:      $API_PID"
echo "API Ключ:     admin_rSfawTG3NTtwQ9qNBNS0JVNMJPhR96qxtQoxBrE6-2U"
echo "База данных:  data/blockchain_module.db"
echo "Конфигурация: configs/module_config.json"
echo ""
echo "Команды управления:"
echo "  • blockchain-cli --help          # Все команды"
echo "  • blockchain-cli system-status   # Статус системы"
echo "  • kill $API_PID                   # Остановить API"
echo "  • python3 run_rest_api.py        # Перезапустить API"
echo ""
echo "Для остановки всего: pkill -f blockchain_module"
echo "========================================="

# Сохраняем PID в файл для удобства
echo "$API_PID:$FREE_PORT" > .api_pid

# Ждем завершения (если запущено в фоне, выходим)
if [[ "$1" != "--background" ]]; then
    echo ""
    echo "Нажмите Ctrl+C для остановки..."
    wait $API_PID
fi