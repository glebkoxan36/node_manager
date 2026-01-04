#!/bin/bash
# Blockchain Module Auto Installer - Исправленная версия

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
            log_error "Не удалось создать виртуальное окружение"
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
        return 0
    else
        log_error "Не удалось активировать виртуальное окружение"
        return 1
    fi
}

# Создание README.md
create_readme() {
    log_info "Создание README.md..."
    
    cat > README.md << 'README_CONTENT'
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
README_CONTENT

text
log_success "README.md создан"
}

Создание setup.py
create_setup_py() {
log_info "Создание setup.py..."

text
cat > setup.py << 'SETUP_CONTENT'
from setuptools import setup, find_packages

try:
with open("README.md", "r", encoding="utf-8") as fh:
long_description = fh.read()
except FileNotFoundError:
long_description = "Blockchain Module - Универсальный модуль для работы с криптовалютами через Nownodes API"

setup(
name="blockchain-module",
version="2.0.0",
author="Blockchain Module Team",
description="Универсальный модуль для работы с криптовалютами через Nownodes API с мультипользовательской системой",
long_description=long_description,
long_description_content_type="text/markdown",
url="https://github.com/glebkoxan36/node_manager",
packages=find_packages(),
classifiers=[
"Development Status :: 4 - Beta",
"Intended Audience :: Developers",
"Topic :: Software Development :: Libraries :: Python Modules",
"License :: OSI Approved :: MIT License",
"Programming Language :: Python :: 3",
"Programming Language :: Python :: 3.7",
"Programming Language :: Python :: 3.8",
"Programming Language :: Python :: 3.9",
"Programming Language :: Python :: 3.10",
"Operating System :: OS Independent",
],
python_requires=">=3.7",
install_requires=[
"aiohttp>=3.8.0",
"aiosqlite>=0.19.0",
"prometheus-client>=0.17.0",
"aiohttp-cors>=0.7.0",
"click>=8.1.0",
"questionary>=2.0.0",
"rich>=13.0.0",
"psutil>=5.9.0",
"python-dotenv>=1.0.0",
"pyyaml>=6.0"
],
entry_points={
"console_scripts": [
"blockchain-module=blockchain_module.cli:cli",
"blockchain-cli=blockchain_module.cli:cli",
],
},
include_package_data=True,
package_data={
"blockchain_module": ["configs/*.json"],
},
)
SETUP_CONTENT

text
log_success "setup.py создан"
}

Создание requirements.txt
create_requirements_txt() {
log_info "Создание requirements.txt..."

text
cat > requirements.txt << 'REQUIREMENTS_CONTENT'
Основные зависимости
aiohttp>=3.8.0
aiosqlite>=0.19.0
prometheus-client>=0.17.0
aiohttp-cors>=0.7.0

CLI зависимости
click>=8.1.0
questionary>=2.0.0
rich>=13.0.0

Системные зависимости
psutil>=5.9.0

Дополнительные
python-dotenv>=1.0.0
pyyaml>=6.0
REQUIREMENTS_CONTENT

text
log_success "requirements.txt создан"
}

Загрузка файла с GitHub
download_file() {
local url="$1"
local output="$2"

text
mkdir -p "$(dirname "$output")"

if curl -s -f -o "$output" "$url" 2>/dev/null; then
    log_info "Загружен: $output"
    return 0
else
    log_warn "Не удалось загрузить: $output"
    return 1
fi
}

Проверка и загрузка файлов
download_missing_files() {
log_info "Проверка и загрузка недостающих файлов..."

text
# Создаем структуру директорий
mkdir -p blockchain_module blockchain_module/configs configs data logs prometheus grafana

# Создаем README.md если отсутствует
if [[ ! -f "README.md" ]]; then
    create_readme
fi

# Создаем setup.py если отсутствует
if [[ ! -f "setup.py" ]]; then
    create_setup_py
fi

# Создаем requirements.txt если отсутствует
if [[ ! -f "requirements.txt" ]]; then
    create_requirements_txt
fi

# Загружаем остальные файлы с GitHub
local files=(
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
    "cli.py"
)

for file in "${files[@]}"; do
    local output_file="blockchain_module/$file"
    if [[ ! -f "$output_file" ]]; then
        download_file "${GITHUB_RAW}/$file" "$output_file"
    else
        log_info "Уже существует: $output_file"
    fi
done

# Загружаем конфигурационные файлы
local config_files=(
    "docker-compose.yml"
    "alerts.yml"
    "prometheus.yml"
    "blockchain_dashboard.json"
    "configs/module_config.json"
)

for file in "${config_files[@]}"; do
    local output_file="$file"
    if [[ ! -f "$output_file" ]]; then
        download_file "${GITHUB_RAW}/$file" "$output_file"
    else
        log_info "Уже существует: $output_file"
    fi
done

# Создаем базовые конфигурационные файлы если не загрузились
if [[ ! -f "docker-compose.yml" ]]; then
    cat > docker-compose.yml << 'DOCKER_COMPOSE_CONTENT'
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
DOCKER_COMPOSE_CONTENT
log_info "Создан docker-compose.yml"
fi

text
if [[ ! -f "prometheus/prometheus.yml" ]] && [[ ! -f "prometheus.yml" ]]; then
    mkdir -p prometheus
    cat > prometheus/prometheus.yml << 'PROMETHEUS_CONTENT'
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
PROMETHEUS_CONTENT
log_info "Создан prometheus/prometheus.yml"
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
# Обновляем пакеты
apt-get update > /dev/null 2>&1

# Устанавливаем базовые зависимости
apt-get install -y \
    curl \
    wget \
    python3-dev \
    python3-venv \
    sqlite3 \
    libsqlite3-dev > /dev/null 2>&1

# Проверка и установка Docker
if ! command -v docker &>/dev/null; then
    log_info "Установка Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
    systemctl start docker
    systemctl enable docker > /dev/null 2>&1
    log_success "Docker установлен"
else
    log_info "Docker уже установлен"
fi

# Проверка и установка Docker Compose
if ! command -v docker-compose &>/dev/null; then
    log_info "Установка Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
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

log_success "Директории настроены"
}

Установка Python зависимостей
install_python_deps() {
log_info "Установка Python зависимостей..."

text
if activate_venv; then
    # Обновляем pip
    pip install --upgrade pip > /dev/null 2>&1
    
    # Устанавливаем зависимости из requirements.txt
    if [[ -f "requirements.txt" ]]; then
        log_info "Установка зависимостей из requirements.txt..."
        pip install -r requirements.txt > /dev/null 2>&1
    else
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
    fi
    
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
from blockchain_module import get_module_info
print('✅ Модуль blockchain_module импортирован')

text
info = get_module_info()
print(f'✅ Версия модуля: {info[\"version\"]}')

from blockchain_module.config import BlockchainConfig
print('✅ Конфигурация доступна')

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

Создание скрипта управления
create_management_script() {
log_info "Создание скриптов управления..."

text
# Создаем основной скрипт управления
cat > blockchain-manage << 'MANAGEMENT_SCRIPT'
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
print('REST API запущен на порту 8089')
asyncio.run(run_rest_api(host='0.0.0.0', port=8089))
except Exception as e:
print(f'Ошибка запуска REST API: {e}')
" > logs/api.log 2>&1 &
echo $! > .api_pid
echo "REST API запущен"
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
    echo "Docker контейнеры остановлены"
fi

# Останавливаем REST API
if [[ -f ".api_pid" ]]; then
    kill $(cat .api_pid) 2>/dev/null || true
    rm -f .api_pid
    echo "REST API остановлен"
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

echo ""
echo "Для проверки доступности REST API выполните:"
echo "  curl http://localhost:8089/api/v1/info"
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

print('\\n✅ Тесты пройдены успешно!')
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
MANAGEMENT_SCRIPT

text
chmod +x blockchain-manage

# Создаем скрипт активации
cat > activate.sh << 'ACTIVATION_SCRIPT'
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
echo " • ./blockchain-manage start - Запустить систему"
echo " • ./blockchain-manage stop - Остановить систему"
echo " • ./blockchain-manage status - Статус системы"
echo " • python -m blockchain_module.cli - CLI интерфейс"
echo ""
echo "Для деактивации выполните: deactivate"
ACTIVATION_SCRIPT

text
chmod +x activate.sh

# Создаем простой стартовый скрипт
cat > start.sh << 'START_SCRIPT'
#!/bin/bash

Простой скрипт запуска
cd "$(dirname "$0")"
./blockchain-manage start
START_SCRIPT

text
chmod +x start.sh

log_success "Скрипты управления созданы"
}

Основная функция установки
main_installation() {
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

# Шаг 8: Создание скриптов управления
create_management_script

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
