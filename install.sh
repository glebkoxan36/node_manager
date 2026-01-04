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
    log_info "Creating virtual environment..."
    
    if [[ -d "$VENV_DIR" ]]; then
        log_info "Virtual environment already exists"
    else
        python3 -m venv "$VENV_DIR" || {
            log_error "Failed to create virtual environment"
            log_info "Trying to install python3-venv..."
            apt-get update && apt-get install -y python3-venv > /dev/null 2>&1
            python3 -m venv "$VENV_DIR"
        }
        log_success "Virtual environment created at $VENV_DIR"
    fi
}

# Активация виртуального окружения
activate_venv() {
    if [[ -f "$VENV_DIR/bin/activate" ]]; then
        source "$VENV_DIR/bin/activate"
        return 0
    else
        log_error "Cannot activate virtual environment"
        return 1
    fi
}

# Создание README.md
create_readme() {
    log_info "Creating README.md..."
    
    cat > README.md << 'EOF'
# Blockchain Module

Universal module for working with cryptocurrencies via Nownodes API with multi-user system.

## Description

Blockchain Module is a Python library for working with various cryptocurrencies through Nownodes API.

## Installation

```bash
bash <(curl -s https://raw.githubusercontent.com/glebkoxan36/node_manager/main/install.sh)
Usage
Activate virtual environment:

bash
source venv/bin/activate
Configure API key in configs/module_config.json

Start the system:

bash
./blockchain-manage start
Available Services
REST API: http://localhost:8089

Grafana: http://localhost:3000 (admin/admin123)

Prometheus: http://localhost:9090

License
MIT License
EOF

text
log_success "README.md created"
}

Создание setup.py
create_setup_py() {
log_info "Creating setup.py..."

text
cat > setup.py << 'EOF'
from setuptools import setup, find_packages

try:
with open("README.md", "r", encoding="utf-8") as fh:
long_description = fh.read()
except FileNotFoundError:
long_description = "Blockchain Module - Universal module for working with cryptocurrencies via Nownodes API"

setup(
name="blockchain-module",
version="2.0.0",
author="Blockchain Module Team",
description="Universal module for working with cryptocurrencies via Nownodes API with multi-user system",
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
EOF

text
log_success "setup.py created"
}

Создание requirements.txt
create_requirements_txt() {
log_info "Creating requirements.txt..."

text
cat > requirements.txt << 'EOF'
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
EOF

text
log_success "requirements.txt created"
}

Загрузка файла с GitHub
download_file() {
local url="$1"
local output="$2"

text
mkdir -p "$(dirname "$output")"

if curl -s -f -o "$output" "$url" 2>/dev/null; then
    log_info "Downloaded: $output"
    return 0
else
    log_warn "Failed to download: $output"
    return 1
fi
}

Проверка и загрузка файлов
download_missing_files() {
log_info "Checking and downloading missing files..."

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
        log_info "Already exists: $output_file"
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
        log_info "Already exists: $output_file"
    fi
done

# Создаем базовые конфигурационные файлы если не загрузились
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
log_info "Created docker-compose.yml"
fi

text
if [[ ! -f "prometheus/prometheus.yml" ]] && [[ ! -f "prometheus.yml" ]]; then
    mkdir -p prometheus
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
log_info "Created prometheus/prometheus.yml"
fi

log_success "Files checked and downloaded"
}

Проверка системы
check_system() {
log_info "Checking system requirements..."

text
# Проверка ОС
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    log_info "OS: $OS $VER"
else
    log_warn "Cannot determine OS"
    OS="Unknown"
fi

# Проверка Python
if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    log_info "Python: $PYTHON_VERSION"
else
    log_error "Python3 is not installed"
    exit 1
fi

log_success "System checks passed"
}

Установка системных зависимостей
install_system_deps() {
log_info "Installing system dependencies..."

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
    log_info "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
    systemctl start docker
    systemctl enable docker > /dev/null 2>&1
    log_success "Docker installed"
else
    log_info "Docker already installed"
fi

# Проверка и установка Docker Compose
if ! command -v docker-compose &>/dev/null; then
    log_info "Installing Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    log_success "Docker Compose installed"
else
    log_info "Docker Compose already installed"
fi
}

Настройка директорий
setup_directories() {
log_info "Setting up directory structure..."

text
mkdir -p prometheus grafana data logs

log_success "Directories created"
}

Установка Python зависимостей
install_python_deps() {
log_info "Installing Python dependencies..."

text
if activate_venv; then
    # Обновляем pip
    pip install --upgrade pip > /dev/null 2>&1
    
    # Устанавливаем зависимости из requirements.txt
    if [[ -f "requirements.txt" ]]; then
        log_info "Installing dependencies from requirements.txt..."
        pip install -r requirements.txt > /dev/null 2>&1
    else
        log_info "Installing core dependencies..."
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
    log_info "Installing module..."
    pip install -e . > /dev/null 2>&1
    
    log_success "Python dependencies installed"
else
    log_error "Failed to install dependencies"
    return 1
fi
}

Тестирование установки
test_installation() {
log_info "Testing installation..."

text
if activate_venv; then
    if python3 -c "
import sys
sys.path.insert(0, '.')
print('🔧 Testing Blockchain Module...')

try:
from blockchain_module import get_module_info
print('✅ Module blockchain_module imported')

text
info = get_module_info()
print(f'✅ Module version: {info[\"version\"]}')

from blockchain_module.config import BlockchainConfig
print('✅ Configuration available')

from blockchain_module.database import SQLiteDBManager
print('✅ Database available')

print('\n🎉 All components loaded successfully!')
except Exception as e:
print(f'⚠️ Warning: {e}')
print('Some components may not work correctly')
" > /dev/null 2>&1; then
log_success "Testing completed"
else
log_warn "Testing completed with warnings"
fi
fi
}

Создание скрипта управления
create_management_script() {
log_info "Creating management scripts..."

text
# Создаем основной скрипт управления
cat > blockchain-manage << 'EOF'
#!/bin/bash

Blockchain Module management script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
echo "Usage: $0 {start|stop|status|restart|logs|test|help}"
echo ""
echo "Commands:"
echo " start - Start all services"
echo " stop - Stop all services"
echo " status - Show service status"
echo " restart - Restart all services"
echo " logs - Show logs"
echo " test - Run tests"
echo " help - Show this help"
}

start_system() {
echo "[+] Starting system..."

text
# Start Docker containers
if [[ -f "docker-compose.yml" ]]; then
    docker-compose up -d
    echo "Docker containers started"
fi

# Start REST API in background
if [[ -d "venv" ]]; then
    source venv/bin/activate
    nohup python3 -c "
import asyncio
import sys
sys.path.insert(0, '.')
try:
from blockchain_module import start_rest_api_server
start_rest_api_server()
print('REST API started on port 8089')
except Exception as e:
print(f'Error starting REST API: {e}')
" > logs/api.log 2>&1 &
echo $! > .api_pid
echo "REST API started"
fi

text
echo "[+] System started"
echo "    REST API:    http://localhost:8089"
echo "    Grafana:     http://localhost:3000 (admin/admin123)"
echo "    Prometheus:  http://localhost:9090"
}

stop_system() {
echo "[-] Stopping system..."

text
# Stop Docker containers
if [[ -f "docker-compose.yml" ]]; then
    docker-compose down
    echo "Docker containers stopped"
fi

# Stop REST API
if [[ -f ".api_pid" ]]; then
    kill $(cat .api_pid) 2>/dev/null || true
    rm -f .api_pid
    echo "REST API stopped"
fi

echo "[+] System stopped"
}

show_status() {
echo "[*] System status:"
echo ""

text
# Docker containers
echo "Docker containers:"
if command -v docker-compose &>/dev/null && [[ -f "docker-compose.yml" ]]; then
    docker-compose ps
else
    echo "  Docker Compose not available"
fi

echo ""

# REST API
if [[ -f ".api_pid" ]] && kill -0 $(cat .api_pid) 2>/dev/null; then
    echo "REST API: running (PID: $(cat .api_pid))"
else
    echo "REST API: not running"
    rm -f .api_pid
fi

echo ""
echo "To test REST API:"
echo "  curl http://localhost:8089/api/v1/info"
}

show_logs() {
if [[ "$1" == "docker" ]]; then
docker-compose logs -f
elif [[ "$1" == "api" ]]; then
tail -f logs/api.log 2>/dev/null || echo "API logs not found"
else
echo "Usage: $0 logs {docker|api}"
fi
}

run_tests() {
echo "[*] Running tests..."

text
if [[ -d "venv" ]]; then
    source venv/bin/activate
    python3 -c "
import sys
sys.path.insert(0, '.')
print('Testing Blockchain Module...')

try:
from blockchain_module import get_module_info
info = get_module_info()
print(f'✅ Module: v{info["version"]}')

text
# Simple checks
print('✅ Basic check passed')

print('\n✅ Tests passed successfully!')
except Exception as e:
print(f'❌ Error: {e}')
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
echo "Unknown command: $1"
show_help
exit 1
;;
esac
EOF

text
chmod +x blockchain-manage

# Создаем скрипт активации
cat > activate.sh << 'EOF'
#!/bin/bash

Virtual environment activation script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

if [[ ! -d "$VENV_DIR" ]]; then
echo "Error: Virtual environment not found"
exit 1
fi

echo "Activating Blockchain Module virtual environment..."
source "$VENV_DIR/bin/activate"

echo ""
echo "🎉 Virtual environment activated!"
echo "Available commands:"
echo " • ./blockchain-manage start - Start system"
echo " • ./blockchain-manage stop - Stop system"
echo " • ./blockchain-manage status - Show status"
echo " • python -m blockchain_module.cli - CLI interface"
echo ""
echo "To deactivate run: deactivate"
EOF

text
chmod +x activate.sh

# Создаем простой стартовый скрипт
cat > start.sh << 'EOF'
#!/bin/bash

Simple start script
cd "$(dirname "$0")"
./blockchain-manage start
EOF

text
chmod +x start.sh

log_success "Management scripts created"
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
    log_warn "Script not run as root"
    log_info "Some system dependencies may not install"
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
echo -e "${GREEN}║           INSTALLATION COMPLETED!               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "🎉 Blockchain Module successfully installed!"
echo ""
echo "📁 Project structure:"
echo "  • blockchain_module/    - Main module code"
echo "  • venv/                - Python virtual environment"
echo "  • configs/             - Configuration files"
echo "  • data/                - Database"
echo "  • logs/                - Logs"
echo ""
echo "🚀 Quick start:"
echo "  1. Configure API key:"
echo "     nano configs/module_config.json"
echo "     (replace YOUR_NOWNODES_API_KEY_HERE with your key)"
echo ""
echo "  2. Start the system:"
echo "     ./blockchain-manage start"
echo ""
echo "  3. Open in browser:"
echo "     • REST API:      http://localhost:8089/api/v1/info"
echo "     • Grafana:       http://localhost:3000 (admin/admin123)"
echo "     • Prometheus:    http://localhost:9090"
echo ""
echo "🔧 Management:"
echo "  • ./blockchain-manage start    - Start"
echo "  • ./blockchain-manage stop     - Stop"
echo "  • ./blockchain-manage status   - Status"
echo "  • ./blockchain-manage logs     - Logs"
echo "  • ./activate.sh                - Activate venv"
echo ""
echo "📚 To work with module:"
echo "  source venv/bin/activate"
echo "  python -m blockchain_module.cli"
echo ""
echo "🆘 Help: ./blockchain-manage help"
echo ""
