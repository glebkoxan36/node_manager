#!/bin/bash

# Blockchain Module Auto-Installer
# Version: 2.0.5
# Author: Blockchain Module Team

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/glebkoxan36/node_manager.git"
INSTALL_DIR="$HOME/blockchain_module"
VENV_DIR="$INSTALL_DIR/venv"

# Function to print messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fix shell directory issue at script start
fix_shell_directory() {
    # This fixes the "shell-init: error retrieving current directory" issue
    # by ensuring we're in a valid directory before doing anything
    if ! cd /tmp 2>/dev/null; then
        cd / 2>/dev/null || cd "$HOME" 2>/dev/null || return 1
    fi
    return 0
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "centos"
    else
        echo "$(uname -s | tr '[:upper:]' '[:lower:]')"
    fi
}

# Check and install Python 3.9
install_python39() {
    local os=$1
    
    case $os in
        ubuntu|debian)
            print_info "Установка Python 3.9 на Ubuntu/Debian..."
            apt-get update
            apt-get install -y software-properties-common
            add-apt-repository -y ppa:deadsnakes/ppa
            apt-get update
            apt-get install -y python3.9 python3.9-venv python3.9-distutils
            
            # Install pip for python3.9
            curl -sS https://bootstrap.pypa.io/get-pip.py | python3.9
            ;;
        centos|rhel|fedora)
            print_info "Установка Python 3.9 на CentOS/RHEL/Fedora..."
            yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel wget make
            
            cd /tmp
            wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz
            tar xzf Python-3.9.18.tgz
            cd Python-3.9.18
            ./configure --enable-optimizations
            make altinstall
            
            # Install pip
            curl -sS https://bootstrap.pypa.io/get-pip.py | python3.9
            ;;
        *)
            print_error "Неподдерживаемая ОС: $os"
            exit 1
            ;;
    esac
}

# Check Python version
check_python() {
    print_info "Проверка Python..."
    
    # Check python3.9
    if command -v python3.9 &> /dev/null; then
        PYTHON_CMD="python3.9"
        print_success "Найден Python 3.9"
        return 0
    fi
    
    # Check python3.8
    if command -v python3.8 &> /dev/null; then
        PYTHON_CMD="python3.8"
        print_success "Найден Python 3.8"
        return 0
    fi
    
    # Check python3.7
    if command -v python3.7 &> /dev/null; then
        PYTHON_CMD="python3.7"
        print_success "Найден Python 3.7"
        return 0
    fi
    
    # Check python3
    if command -v python3 &> /dev/null; then
        # Check version
        version=$(python3 -c 'import sys; v = sys.version_info; print(f"{v.major}.{v.minor}")')
        if [ "$version" = "3.7" ] || [ "$version" = "3.8" ] || [ "$version" = "3.9" ] || [ "$version" = "3.10" ]; then
            PYTHON_CMD="python3"
            print_success "Найден Python $version"
            return 0
        fi
    fi
    
    return 1
}

# Install system dependencies
install_system_deps() {
    local os=$1
    
    case $os in
        ubuntu|debian)
            apt-get install -y git curl wget
            ;;
        centos|rhel|fedora)
            yum install -y git curl wget
            ;;
    esac
}

# Clean installation directory
clean_install_dir() {
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Директория $INSTALL_DIR уже существует"
        echo "Выберите действие:"
        echo "1) Удалить и переустановить (рекомендуется)"
        echo "2) Создать резервную копию и переустановить"
        echo "3) Выйти"
        
        read -r choice
        case $choice in
            1)
                print_info "Удаление старой установки..."
                # Go to a safe directory
                cd /tmp 2>/dev/null || cd "$HOME" 2>/dev/null || cd /
                rm -rf "$INSTALL_DIR"
                mkdir -p "$INSTALL_DIR"
                ;;
            2)
                BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
                print_info "Создание резервной копии: $BACKUP_DIR"
                # Go to a safe directory
                cd /tmp 2>/dev/null || cd "$HOME" 2>/dev/null || cd /
                mv "$INSTALL_DIR" "$BACKUP_DIR"
                mkdir -p "$INSTALL_DIR"
                ;;
            3)
                print_error "Прервано пользователем"
                exit 1
                ;;
            *)
                print_error "Неверный выбор"
                exit 1
                ;;
        esac
    else
        mkdir -p "$INSTALL_DIR"
    fi
}

# Create __main__.py
create_main_py() {
    local main_py_path="$INSTALL_DIR/blockchain_module/__main__.py"
    
    if [ ! -f "$main_py_path" ]; then
        print_info "Создание __main__.py..."
        mkdir -p "$(dirname "$main_py_path")"
        cat > "$main_py_path" << 'EOF'
#!/usr/bin/env python3
"""
Blockchain Module - Точка входа
Универсальный модуль для работы с криптовалютами через Nownodes API
"""

import asyncio
import sys
import os
import logging

def run_cli():
    """Запуск CLI интерфейса"""
    from blockchain_module.cli import cli
    cli()

async def run_services():
    """Запуск всех сервисов модуля"""
    try:
        from blockchain_module import (
            setup_logging, get_module_info,
            start_monitoring, start_rest_api_server,
            get_config_summary
        )
        
        # Настройка логирования
        logger = setup_logging(logging.INFO)
        
        # Информация о модуле
        info = get_module_info()
        print("\n" + "="*50)
        print("🚀 Blockchain Module v{}".format(info.get('version', 'unknown')))
        print("="*50)
        print(f"👥 Мультипользовательский режим: {'✅ Включен' if info.get('multiuser_enabled') else '❌ Выключен'}")
        print(f"💰 Поддерживаемые монеты: {', '.join(info.get('supported_coins', []))}")
        
        # Запуск мониторинга
        print("\n📊 Запуск мониторинга...")
        if start_monitoring():
            print("✅ Мониторинг Prometheus запущен")
        else:
            print("⚠️  Мониторинг не запущен")
        
        # Запуск REST API
        print("🌐 Запуск REST API...")
        if start_rest_api_server():
            print("✅ REST API сервер запущен")
        else:
            print("⚠️  REST API сервер не запущен")
        
        # Информация о конфигурации
        config = get_config_summary()
        print(f"\n⚙️  Конфигурация:")
        print(f"   Файл конфигурации: {config.get('config_file', 'Не найден')}")
        print(f"   Настроено монет: {config.get('total_coins', 0)}")
        
        print("\n🔗 Доступные сервисы:")
        print("   • REST API: http://localhost:8080/api/v1/info")
        print("   • Метрики Prometheus: http://localhost:9090/metrics")
        print("   • Grafana (если установлен): http://localhost:3000")
        
        print("\n🎮 Управление:")
        print("   • CLI интерфейс: python -m blockchain_module cli")
        print("   • Интерактивный режим: python -m blockchain_module cli interactive")
        
        print("\n📝 Для выхода нажмите Ctrl+C")
        print("="*50 + "\n")
        
        # Бесконечный цикл
        while True:
            await asyncio.sleep(1)
            
    except ImportError as e:
        print(f"❌ Ошибка импорта: {e}")
        print("Убедитесь, что зависимости установлены: pip install -e .")
        return 1
    except Exception as e:
        print(f"❌ Ошибка запуска: {e}")
        return 1
    
    return 0

def main():
    """Основная точка входа"""
    try:
        # Проверяем аргументы командной строки
        if len(sys.argv) > 1 and sys.argv[1] == "cli":
            # Запускаем CLI
            run_cli()
        else:
            # Запускаем сервисы
            return asyncio.run(run_services())
    except KeyboardInterrupt:
        print("\n\n👋 Завершение работы...")
        return 0
    except Exception as e:
        print(f"❌ Критическая ошибка: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOF
        print_success "__main__.py создан"
    else
        print_info "__main__.py уже существует"
    fi
}

# Create startup scripts
create_startup_scripts() {
    print_info "Создание скриптов запуска..."
    
    # Create start.sh
    cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/bash

# Blockchain Module - Скрипт запуска
cd "$(dirname "$0")"

# Проверка виртуального окружения
if [ ! -d "venv" ]; then
    echo "❌ Ошибка: Виртуальное окружение не найдено"
    echo "Выполните: python3 -m venv venv"
    exit 1
fi

# Активация виртуального окружения
source venv/bin/activate

# Запуск модуля
python -m blockchain_module
EOF
    chmod +x "$INSTALL_DIR/start.sh"
    
    # Create cli.sh
    cat > "$INSTALL_DIR/cli.sh" << 'EOF'
#!/bin/bash

# Blockchain Module - CLI интерфейс
cd "$(dirname "$0")"

# Проверка виртуального окружения
if [ ! -d "venv" ]; then
    echo "❌ Ошибка: Виртуальное окружение не найдено"
    exit 1
fi

# Активация виртуального окружения
source venv/bin/activate

# Запуск CLI
python -m blockchain_module cli "$@"
EOF
    chmod +x "$INSTALL_DIR/cli.sh"
    
    # Create admin.sh (admin commands)
    cat > "$INSTALL_DIR/admin.sh" << 'EOF'
#!/bin/bash

# Blockchain Module - Админ команды
cd "$(dirname "$0")"

# Проверка виртуального окружения
if [ ! -d "venv" ]; then
    echo "❌ Ошибка: Виртуальное окружение не найдено"
    exit 1
fi

# Активация виртуального окружения
source venv/bin/activate

echo "🔐 Админ панель Blockchain Module"
echo "================================"
echo ""
echo "Доступные команды:"
echo "  1) Показать API ключ администратора"
echo "  2) Создать пользователя"
echo "  3) Список пользователей"
echo "  4) Сбросить API ключ пользователя"
echo "  5) Интерактивный режим"
echo "  6) Статус системы"
echo "  0) Выход"
echo ""
read -p "Выберите команду: " choice

case $choice in
    1)
        python -m blockchain_module.cli admin-key
        ;;
    2)
        python -m blockchain_module.cli create-user
        ;;
    3)
        python -m blockchain_module.cli list-users
        ;;
    4)
        read -p "Введите ID пользователя: " user_id
        python -m blockchain_module.cli reset-api-key --user-id "$user_id"
        ;;
    5)
        python -m blockchain_module.cli interactive
        ;;
    6)
        python -m blockchain_module.cli system-status
        ;;
    0)
        echo "Выход..."
        ;;
    *)
        echo "❌ Неверный выбор"
        ;;
esac
EOF
    chmod +x "$INSTALL_DIR/admin.sh"
    
    print_success "Скрипты запуска созданы"
}

# Create configuration
create_configuration() {
    print_info "Настройка конфигурации..."
    
    # Create configs directory
    mkdir -p "$INSTALL_DIR/configs"
    
    # Create config file if it doesn't exist
    if [ ! -f "$INSTALL_DIR/configs/module_config.json" ]; then
        cat > "$INSTALL_DIR/configs/module_config.json" << EOF
{
  "module_settings": {
    "api_key": "ВАШ_API_КЛЮЧ_NOWNODES_ЗДЕСЬ",
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
        print_warning "Отредактируйте configs/module_config.json и добавьте ваш API ключ Nownodes!"
        print_warning "Без API ключа модуль не будет работать!"
    else
        print_info "Конфигурационный файл уже существует"
    fi
}

# Setup monitoring services (optional)
setup_monitoring() {
    if command -v docker &> /dev/null; then
        print_info "Настройка Docker мониторинга..."
        
        read -p "Запустить Docker мониторинг (Prometheus/Grafana)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$INSTALL_DIR"
            
            # First, clean up any existing containers and volumes
            print_info "Очистка старых контейнеров и томов..."
            
            # Stop and remove any existing containers
            docker-compose down --volumes --remove-orphans 2>/dev/null || true
            
            # Remove existing Docker volumes
            docker volume rm -f blockchain_module_prometheus_data blockchain_module_grafana_data 2>/dev/null || true
            
            # Remove any orphaned containers with our names
            docker rm -f blockchain_prometheus blockchain_grafana blockchain_node_exporter blockchain_cadvisor 2>/dev/null || true
            
            # Create monitoring directory
            mkdir -p monitoring
            
            # Create simplified docker-compose.yml for monitoring
            cat > docker-compose.yml << 'DOCKER_COMPOSE'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: blockchain_prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
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
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped
    depends_on:
      - prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: blockchain_node_exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped
    privileged: true
    network_mode: "host"
    pid: "host"

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: blockchain_cadvisor
    ports:
      - "8081:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    restart: unless-stopped
    privileged: true

volumes:
  prometheus_data:
    driver: local
  grafana_data:
    driver: local
DOCKER_COMPOSE
            
            # Create prometheus config
            cat > monitoring/prometheus.yml << 'PROMETHEUS_CONFIG'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'blockchain_module'
    static_configs:
      - targets: ['localhost:9091']
PROMETHEUS_CONFIG
            
            print_info "Запуск Docker Compose..."
            docker-compose up -d
            
            if [ $? -eq 0 ]; then
                print_success "Docker мониторинг запущен"
                echo ""
                echo -e "${GREEN}🔗 Доступные сервисы:${NC}"
                echo "   Prometheus:       http://localhost:9090"
                echo "   Grafana:          http://localhost:3000"
                echo "   Логин Grafana:    admin / admin"
                echo "   Node экспортер:   http://localhost:9100"
                echo "   cAdvisor:         http://localhost:8081"
                echo ""
                print_info "Проверьте работу сервисов через несколько секунд"
            else
                print_warning "Не удалось запустить все сервисы мониторинга"
                print_info "Попробуйте запустить вручную:"
                print_info "cd $INSTALL_DIR && docker-compose up -d prometheus grafana"
            fi
        fi
    else
        print_warning "Docker не установлен, пропускаем настройку мониторинга"
        print_info "Для установки Docker выполните:"
        print_info "curl -fsSL https://get.docker.com | sh"
        print_info "sudo usermod -aG docker $USER"
    fi
}

# Test installation
test_installation() {
    print_info "Тестирование установки..."
    
    if [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate"
    else
        print_error "Виртуальное окружение не найдено: $VENV_DIR"
        return 1
    fi
    
    # Test imports
    if python -c "import blockchain_module" &> /dev/null; then
        print_success "Модуль blockchain_module импортирован успешно"
        
        # Test basic functionality
        if python -c "
from blockchain_module import get_module_info
info = get_module_info()
print('✅ Тест пройден')
print('   Версия:', info.get('version', 'unknown'))
print('   Автор:', info.get('author', 'unknown'))
" &> /dev/null; then
            print_success "Базовая функциональность работает"
        else
            print_warning "Базовая функциональность не работает (возможно, требуется настройка конфигурации)"
        fi
    else
        print_error "Модуль blockchain_module не может быть импортирован"
        return 1
    fi
    
    return 0
}

# Create systemd service (optional)
create_systemd_service() {
    print_info "Настройка systemd сервиса..."
    
    read -p "Создать systemd сервис для автоматического запуска? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SERVICE_FILE="/etc/systemd/system/blockchain-module.service"
        
        if [ -f "$SERVICE_FILE" ]; then
            print_warning "Сервис уже существует"
            read -p "Перезаписать? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return
            fi
        fi
        
        cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Blockchain Module Service
After=network.target
Requires=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/python -m blockchain_module
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=blockchain-module

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable blockchain-module.service
        
        print_success "Systemd сервис создан"
        print_info "Команды управления:"
        print_info "   sudo systemctl start blockchain-module"
        print_info "   sudo systemctl stop blockchain-module"
        print_info "   sudo systemctl status blockchain-module"
        print_info "   sudo journalctl -u blockchain-module -f"
    fi
}

# Show installation summary
show_summary() {
    echo ""
    echo "============================================================"
    echo -e "${GREEN}✅ Blockchain Module успешно установлен!${NC}"
    echo "============================================================"
    echo ""
    echo -e "${BLUE}📁 Директория установки:${NC}"
    echo "   $INSTALL_DIR"
    echo ""
    echo -e "${BLUE}🚀 Скрипты запуска:${NC}"
    echo "   $INSTALL_DIR/start.sh      - Запуск всех сервисов"
    echo "   $INSTALL_DIR/cli.sh        - CLI интерфейс"
    echo "   $INSTALL_DIR/admin.sh      - Админ панель"
    echo ""
    echo -e "${BLUE}⚙️  Настройка:${NC}"
    echo "   1. Отредактируйте конфигурационный файл:"
    echo "      nano $INSTALL_DIR/configs/module_config.json"
    echo ""
    echo "   2. Добавьте ваш API ключ Nownodes в поле 'api_key'"
    echo ""
    echo -e "${BLUE}🎮 Запуск:${NC}"
    echo "   cd $INSTALL_DIR"
    echo "   ./start.sh"
    echo ""
    echo -e "${BLUE}🔧 Дополнительные команды:${NC}"
    echo "   ./cli.sh --help              - Помощь по CLI"
    echo "   ./cli.sh interactive         - Интерактивный режим"
    echo "   ./cli.sh admin-key           - Показать API ключ администратора"
    echo "   ./admin.sh                   - Админ панель"
    echo ""
    
    if command -v docker &> /dev/null; then
        echo -e "${BLUE}📊 Мониторинг:${NC}"
        echo "   Docker мониторинг: docker-compose up -d"
        echo "   Prometheus:       http://localhost:9090"
        echo "   Grafana:          http://localhost:3000 (admin/admin)"
        echo "   Node экспортер:   http://localhost:9100"
        echo "   cAdvisor:         http://localhost:8081"
        echo ""
    fi
    
    echo -e "${BLUE}📞 Поддержка:${NC}"
    echo "   GitHub: https://github.com/glebkoxan36/node_manager"
    echo "   Issues: https://github.com/glebkoxan36/node_manager/issues"
    echo ""
    echo "============================================================"
}

# Main installation function
main_installation() {
    # Fix shell directory issue immediately
    fix_shell_directory
    
    echo ""
    echo "============================================================"
    echo -e "${GREEN}Blockchain Module Auto-Installer v2.0.5${NC}"
    echo "============================================================"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then 
        print_warning "Скрипт запущен от root"
        echo "Это нормально для установки системных зависимостей."
        read -p "Продолжить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Прервано пользователем"
            exit 1
        fi
    fi
    
    # Detect OS
    OS=$(detect_os)
    print_info "Обнаружена ОС: $OS"
    
    # Check Python
    if ! check_python; then
        print_warning "Python 3.7+ не найден"
        read -p "Установить Python 3.9 автоматически? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_python39 "$OS"
            
            # Verify installation
            if ! check_python; then
                print_error "Не удалось установить Python 3.9"
                exit 1
            fi
        else
            print_error "Установите Python 3.9 вручную и повторите попытку"
            echo "Для Ubuntu/Debian: sudo apt install python3.9 python3.9-venv"
            echo "Для CentOS/RHEL: sudo yum install python39"
            exit 1
        fi
    fi
    
    # Install system dependencies
    print_info "Установка системных зависимостей..."
    install_system_deps "$OS"
    
    # Clean installation directory
    clean_install_dir
    
    # Change to installation directory
    cd "$INSTALL_DIR" || {
        print_error "Не удалось перейти в директорию $INSTALL_DIR"
        exit 1
    }
    
    # Clone repository
    print_info "Клонирование репозитория..."
    git clone "$REPO_URL" .
    
    # Create virtual environment
    print_info "Создание виртуального окружения..."
    $PYTHON_CMD -m venv "$VENV_DIR"
    
    if [ ! -f "$VENV_DIR/bin/activate" ]; then
        print_error "Не удалось создать виртуальное окружение"
        exit 1
    fi
    
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    print_info "Обновление pip..."
    pip install --upgrade pip
    
    # Install dependencies
    print_info "Установка зависимостей Python..."
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        # Install core dependencies
        pip install aiohttp aiosqlite prometheus-client aiohttp-cors psutil click questionary rich python-dotenv pyyaml pytest
    fi
    
    # Install module in development mode
    if [ -f "setup.py" ]; then
        print_info "Установка модуля..."
        pip install -e .
    fi
    
    # Create __main__.py
    create_main_py
    
    # Create configuration
    create_configuration
    
    # Create startup scripts
    create_startup_scripts
    
    # Setup monitoring (optional)
    setup_monitoring
    
    # Test installation
    test_installation
    
    # Create systemd service (optional)
    create_systemd_service
    
    # Show summary
    show_summary
}

# Run installation
main_installation
