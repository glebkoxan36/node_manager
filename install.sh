#!/bin/bash
# Blockchain Module Auto Installer - Оптимизированный и исправленный

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
    echo -e "${BLUE}[INFO]${NC} $1"
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

# Текущая директория
PROJECT_DIR="$(pwd)"
VENV_DIR="$PROJECT_DIR/venv"

# GitHub репозиторий
GITHUB_REPO="https://github.com/glebkoxan36/node_manager"
GITHUB_RAW="https://raw.githubusercontent.com/glebkoxan36/node_manager/main"

# Создание виртуального окружения
create_venv() {
    log_info "Создание виртуального окружения..."
    
    if [[ -d "$VENV_DIR" ]]; then
        log_info "Виртуальное окружение уже существует"
    else
        python3 -m venv "$VENV_DIR" || {
            log_warn "Не удалось создать виртуальное окружение"
            log_info "Попробуем установить python3-venv..."
            apt-get update && apt-get install -y python3-venv > /dev/null 2>&1
            python3 -m venv "$VENV_DIR"
        }
        log_success "Виртуальное окружение создано в $VENV_DIR"
    fi
}

# Активация виртуального окружения
activate_venv() {
    if [[ -f "$VENV_DIR/bin/activate" ]]; then
        source "$VENV_DIR/bin/activate"
    else
        log_error "Не удалось активировать виртуальное окружение"
        return 1
    fi
}

# Создание README.md если отсутствует
create_readme() {
    cat > README.md << 'EOF'
# Blockchain Module

Универсальный модуль для работы с криптовалютами через Nownodes API с мультипользовательской системой.

## Описание

Blockchain Module - это Python библиотека для работы с различными криптовалютами через API Nownodes.

## Установка

```bash
bash <(curl -s https://raw.githubusercontent.com/glebkoxan36/node_manager/main/install.sh)
Использование
Активируйте виртуальное окружение:

bash
source venv/bin/activate
Настройте API ключ в configs/module_config.json

Запустите систему:

bash
./blockchain-manage start
Доступные сервисы
REST API: http://localhost:8089

Grafana: http://localhost:3000 (admin/admin123)

Prometheus: http://localhost:9090

Лицензия
MIT License
EOF
}

Проверка и загрузка файлов
download_missing_files() {
log_info "Проверка и загрузка недостающих файлов..."

text
# Создаем структуру директорий
mkdir -p blockchain_module blockchain_module/configs configs data logs prometheus grafana

# Создаем README.md первым (это решает проблему установки)
if [[ ! -f "README.md" ]]; then
    create_readme
    log_success "README.md создан"
fi

# Функция для загрузки файла
download_file() {
    local local_path="$1"
    local github_path="$2"
    
    mkdir -p "$(dirname "$local_path")"
    
    if [[ ! -f "$local_path" ]]; then
        if curl -s -f -o "$local_path" "${GITHUB_RAW}/$github_path" 2>/dev/null; then
            log_info "Загружен: $local_path"
            return 0
        else
            log_warn "Не удалось загрузить: $local_path"
            return 1
        fi
    else
        log_info "Уже существует: $local_path"
        return 0
    fi
}

# Основные файлы проекта
download_file "setup.py" "setup.py"
download_file "requirements.txt" "requirements.txt"
download_file "docker-compose.yml" "docker-compose.yml"
download_file "alerts.yml" "alerts.yml"
download_file "prometheus.yml" "prometheus.yml"
download_file "blockchain_dashboard.json" "blockchain_dashboard.json"
download_file "module_config.json" "module_config.json"

# Файлы модуля
download_file "blockchain_module/__init__.py" "__init__.py"
download_file "blockchain_module/blockchain_monitor.py" "blockchain_monitor.py"
download_file "blockchain_module/config.py" "config.py"
download_file "blockchain_module/connection_pool.py" "connection_pool.py"
download_file "blockchain_module/database.py" "database.py"
download_file "blockchain_module/funds_collector.py" "funds_collector.py"
download_file "blockchain_module/health_check.py" "health_check.py"
download_file "blockchain_module/monitoring.py" "monitoring.py"
download_file "blockchain_module/nownodes_client.py" "nownodes_client.py"
download_file "blockchain_module/rest_api.py" "rest_api.py"
download_file "blockchain_module/users.py" "users.py"
download_file "blockchain_module/utils.py" "utils.py"

# Создаем CLI файл если не загрузился
if [[ ! -f "blockchain_module/cli.py" ]]; then
    cat > blockchain_module/cli.py << 'EOF'
"""
CLI интерфейс для Blockchain Module
"""

import click
import asyncio
import logging
import sys
import os

logger = logging.getLogger(name)

@click.group()
@click.version_option(version="2.0.0")
def cli():
"""Blockchain Module CLI - Управление криптовалютным модулем"""
pass

@cli.command()
def system_status():
"""Показать статус системы"""
click.echo("Проверка статуса системы...")

text
try:
    sys.path.insert(0, os.getcwd())
    from blockchain_module import get_module_info
    info = get_module_info()
    
    click.echo(f"✅ Blockchain Module v{info['version']}")
    click.echo(f"✅ Поддерживаемые монеты: {info['supported_coins']}")
    
    click.echo("\n🎉 Система работает корректно!")
    
except Exception as e:
    click.echo(f"❌ Ошибка: {e}")
@cli.command()
def info():
"""Показать информацию о модуле"""
try:
import json
sys.path.insert(0, os.getcwd())
from blockchain_module import get_module_info

text
    info = get_module_info()
    click.echo(json.dumps(info, indent=2, ensure_ascii=False))
    
except Exception as e:
    click.echo(f"Ошибка: {e}")
@cli.command()
def start():
"""Запустить REST API сервер"""
click.echo("Запуск REST API...")

text
try:
    sys.path.insert(0, os.getcwd())
    from blockchain_module.rest_api import run_rest_api
    
    async def start_api():
        await run_rest_api(host='0.0.0.0', port=8089)
    
    asyncio.run(start_api())
    
except Exception as e:
    click.echo(f"Ошибка: {e}")
if name == "main":
cli()
EOF
log_info "Создан CLI файл"
fi

text
# Перемещаем конфигурационные файлы в правильные директории
if [[ -f "module_config.json" ]]; then
    mv -f module_config.json configs/ 2>/dev/null || true
fi

if [[ -f "prometheus.yml" ]]; then
    mv -f prometheus.yml prometheus/ 2>/dev/null || true
fi

log_success "Файлы проверены"
}

Проверка системы
check_system() {
log_info "Проверка системы..."

text
# Проверка ОС
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    log_info "ОС: $OS $VER"
else
    log_warn "Не удалось определить ОС"
    OS="Unknown"
fi

# Проверка Python
if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    log_info "Python: $PYTHON_VERSION"
else
    log_error "Python3 не установлен"
    exit 1
fi

log_success "Системные проверки пройдены"
}

Установка системных зависимостей
install_system_deps() {
log_info "Установка системных зависимостей..."

text
if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
    apt-get update > /dev/null 2>&1
    apt-get install -y \
        curl \
        wget \
        python3-dev \
        python3-venv \
        sqlite3 \
        libsqlite3-dev > /dev/null 2>&1
fi

# Проверка Docker
if ! command -v docker &>/dev/null; then
    log_info "Установка Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
    systemctl start docker
    systemctl enable docker
    log_success "Docker установлен"
else
    log_info "Docker уже установлен"
fi

# Проверка Docker Compose
if ! command -v docker-compose &>/dev/null; then
    log_info "Установка Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    log_success "Docker Compose установлен"
else
    log_info "Docker Compose уже установлен"
fi
}

Настройка директорий
setup_directories() {
log_info "Настройка структуры директорий..."

text
mkdir -p prometheus grafana data logs

# Создаем базовый prometheus.yml если не загрузился
if [[ ! -f "prometheus/prometheus.yml" ]]; then
    cat > prometheus/prometheus.yml << 'EOF'
global:
scrape_interval: 15s
evaluation_interval: 15s

rule_files:

"alerts.yml"

scrape_configs:

job_name: 'prometheus'
static_configs:

targets: ['localhost:9090']

job_name: 'blockchain_module'
static_configs:

targets: ['host.docker.internal:9090']
EOF
fi

Создаем базовый docker-compose.yml если не загрузился
if [[ ! -f "docker-compose.yml" ]]; then
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
prometheus:
image: prom/prometheus:latest
container_name: blockchain_prometheus
ports:
- "9090:9090"
volumes:
- ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
- ./alerts.yml:/etc/prometheus/alerts.yml
- prometheus_data:/prometheus
command:
- '--config.file=/etc/prometheus/prometheus.yml'
- '--storage.tsdb.path=/prometheus'
restart: unless-stopped

grafana:
image: grafana/grafana:latest
container_name: blockchain_grafana
ports:
- "3000:3000"
volumes:
- grafana_data:/var/lib/grafana
- ./blockchain_dashboard.json:/var/lib/grafana/dashboards/blockchain_dashboard.json
environment:
- GF_SECURITY_ADMIN_PASSWORD=admin123
restart: unless-stopped
depends_on:
- prometheus

volumes:
prometheus_data:
grafana_data:
EOF
fi

text
log_success "Директории настроены"
}

Установка Python зависимостей
install_python_deps() {
log_info "Установка Python зависимостей..."

text
if activate_venv; then
    # Обновляем pip
    pip install --upgrade pip > /dev/null 2>&1
    
    # Устанавливаем зависимости напрямую (без requirements.txt)
    log_info "Установка основных зависимостей..."
    pip install \
        aiohttp>=3.8.0 \
        aiosqlite>=0.19.0 \
        prometheus-client>=0.17.0 \
        aiohttp-cors>=0.7.0 \
        click>=8.1.0 \
        questionary>=2.0.0 \
        rich>=13.0.0 \
        psutil>=5.9.0 \
        python-dotenv>=1.0.0 \
        pyyaml>=6.0 > /dev/null 2>&1
    
    # Устанавливаем модуль в режиме разработки
    log_info "Установка модуля..."
    pip install -e . > /dev/null 2>&1
    
    log_success "Python зависимости установлены"
else
    log_error "Не удалось установить зависимости"
    return 1
fi
}

Тестирование установки
test_installation() {
log_info "Тестирование установки..."

text
if activate_venv; then
    python3 -c "
import sys
sys.path.insert(0, '.')
print('🔧 Тестирование Blockchain Module...')

try:
# Проверяем основные импорты
from blockchain_module import get_module_info
print('✅ Модуль blockchain_module импортирован')

text
info = get_module_info()
print(f'✅ Версия модуля: {info[\"version\"]}')

# Проверяем конфигурацию
from blockchain_module.config import BlockchainConfig
print('✅ Конфигурация доступна')

# Проверяем базу данных
from blockchain_module.database import SQLiteDBManager
print('✅ База данных доступна')

print('\\n🎉 Все компоненты успешно загружены!')
except Exception as e:
print(f'⚠️ Предупреждение: {e}')
print(' Некоторые компоненты могут работать некорректно')
"

text
    log_success "Тестирование завершено"
fi
}

Создание скрипта запуска
create_start_script() {
log_info "Создание скриптов запуска..."

text
# Основной скрипт управления
cat > blockchain-manage << 'EOF'
#!/bin/bash

Скрипт управления Blockchain Module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
echo "Использование: $0 {start|stop|status|restart|logs|test|help}"
echo ""
echo "Команды:"
echo " start - Запустить всю систему"
echo " stop - Остановить всю систему"
echo " status - Показать статус системы"
echo " restart - Перезапустить систему"
echo " logs - Показать логи"
echo " test - Запустить тесты"
echo " help - Показать эту справку"
}

start_system() {
echo "[+] Запуск системы..."

text
# Запускаем Docker контейнеры
if [[ -f "docker-compose.yml" ]]; then
    docker-compose up -d
    echo "Docker контейнеры запущены"
fi

# Запускаем REST API в фоне
if [[ -d "venv" ]]; then
    source venv/bin/activate
    python3 -c "
import asyncio
import sys
sys.path.insert(0, '.')
try:
from blockchain_module.rest_api import run_rest_api
asyncio.create_task(run_rest_api(host='0.0.0.0', port=8089))
print('REST API запущен на порту 8089')
except Exception as e:
print(f'Ошибка запуска REST API: {e}')
" &
echo $! > .api_pid
fi

text
echo "[+] Система запущена"
echo "    REST API: http://localhost:8089"
echo "    Grafana: http://localhost:3000 (admin/admin123)"
echo "    Prometheus: http://localhost:9090"
}

stop_system() {
echo "[-] Остановка системы..."

text
# Останавливаем Docker контейнеры
if [[ -f "docker-compose.yml" ]]; then
    docker-compose down
fi

# Останавливаем REST API
if [[ -f ".api_pid" ]]; then
    kill $(cat .api_pid) 2>/dev/null || true
    rm -f .api_pid
fi

echo "[+] Система остановлена"
}

show_status() {
echo "[*] Статус системы:"
echo ""

text
# Docker контейнеры
echo "Docker контейнеры:"
docker-compose ps 2>/dev/null || echo "  Docker Compose не доступен"

echo ""

# REST API
if [[ -f ".api_pid" ]] && kill -0 $(cat .api_pid) 2>/dev/null; then
    echo "REST API: запущен (PID: $(cat .api_pid))"
else
    echo "REST API: не запущен"
    rm -f .api_pid
fi

# Проверка доступности
echo ""
echo "Проверка доступности:"
if curl -s http://localhost:8089/api/v1/info >/dev/null 2>&1; then
    echo "  REST API: доступен"
else
    echo "  REST API: недоступен"
fi
}

show_logs() {
if [[ "$1" == "docker" ]]; then
docker-compose logs -f
elif [[ "$1" == "api" ]]; then
tail -f logs/api.log 2>/dev/null || echo "Логи API не найдены"
else
echo "Использование: $0 logs {docker|api}"
fi
}

run_tests() {
echo "[*] Запуск тестов..."

text
if [[ -d "venv" ]]; then
    source venv/bin/activate
    python3 -c "
import sys
sys.path.insert(0, '.')
print('Тестирование Blockchain Module...')

try:
from blockchain_module import get_module_info
info = get_module_info()
print(f'✅ Модуль: v{info["version"]}')

text
# Простые проверки
print('✅ Базовая проверка пройдена')
except Exception as e:
print(f'❌ Ошибка: {e}')
sys.exit(1)
"
fi
}

case "$1" in
start)
start_system
;;
stop)
stop_system
;;
restart)
stop_system
sleep 2
start_system
;;
status)
show_status
;;
logs)
show_logs "$2"
;;
test)
run_tests
;;
help|--help|-h)
show_help
;;
*)
echo "Неизвестная команда: $1"
show_help
exit 1
;;
esac
EOF

text
chmod +x blockchain-manage

# Скрипт активации
cat > activate.sh << 'EOF'
#!/bin/bash

Скрипт активации виртуального окружения
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

if [[ ! -d "$VENV_DIR" ]]; then
echo "Ошибка: Виртуальное окружение не найдено"
exit 1
fi

echo "Активация виртуального окружения Blockchain Module..."
source "$VENV_DIR/bin/activate"

echo ""
echo "🎉 Виртуальное окружение активировано!"
echo "Доступные команды:"
echo " • python -m blockchain_module.cli - CLI интерфейс"
echo " • ./blockchain-manage - Управление системой"
echo ""
echo "Для деактивации выполните: deactivate"
EOF

text
chmod +x activate.sh

# Простой стартовый скрипт
cat > start.sh << 'EOF'
#!/bin/bash

Простой скрипт запуска
cd "$(dirname "$0")"
./blockchain-manage start
EOF

text
chmod +x start.sh

log_success "Скрипты запуска созданы"
}

Основная функция установки
main() {
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║ Blockchain Module Auto Installer v2.0.0 ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

text
# Переходим в директорию проекта
cd "$PROJECT_DIR"

# Шаг 1: Загрузка файлов
download_missing_files

# Шаг 2: Проверка системы
check_system

# Шаг 3: Установка системных зависимостей (если root)
if [[ $EUID -eq 0 ]]; then
    install_system_deps
else
    log_warn "Скрипт запущен без прав root"
    log_info "Некоторые системные зависимости могут не установиться"
fi

# Шаг 4: Создание виртуального окружения
create_venv

# Шаг 5: Настройка директорий
setup_directories

# Шаг 6: Установка Python зависимостей
install_python_deps

# Шаг 7: Тестирование
test_installation

# Шаг 8: Создание скриптов запуска
create_start_script

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           УСТАНОВКА ЗАВЕРШЕНА!                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "🎉 Blockchain Module успешно установлен!"
echo ""
echo "📁 Структура проекта:"
echo "  • blockchain_module/    - Основной код модуля"
echo "  • venv/                - Виртуальное окружение Python"
echo "  • configs/             - Конфигурационные файлы"
echo "  • data/                - База данных"
echo "  • logs/                - Логи"
echo ""
echo "🚀 Быстрый старт:"
echo "  1. Настройте API ключ:"
echo "     nano configs/module_config.json"
echo "     (замените YOUR_NOWNODES_API_KEY_HERE на ваш ключ)"
echo ""
echo "  2. Запустите систему:"
echo "     ./blockchain-manage start"
echo ""
echo "  3. Откройте в браузере:"
echo "     • REST API:      http://localhost:8089/api/v1/info"
echo "     • Grafana:       http://localhost:3000 (admin/admin123)"
echo "     • Prometheus:    http://localhost:9090"
echo ""
echo "🔧 Управление:"
echo "  • ./blockchain-manage start    - Запустить"
echo "  • ./blockchain-manage stop     - Остановить"
echo "  • ./blockchain-manage status   - Статус"
echo "  • ./blockchain-manage logs     - Логи"
echo "  • ./activate.sh                - Активировать venv"
echo ""
echo "📚 Для работы с модулем:"
echo "  source venv/bin/activate"
echo "  python -m blockchain_module.cli"
echo ""
echo "🆘 Помощь: ./blockchain-manage help"
echo ""
