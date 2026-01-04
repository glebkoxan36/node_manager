#!/bin/bash

# Blockchain Module Auto-Installer
# Автоматическая установка модуля blockchain_module из GitHub

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
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

# Проверка прав администратора
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Скрипт запущен с правами root. Это не рекомендуется для установки Python пакетов."
        read -p "Продолжить? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Проверка зависимостей
check_dependencies() {
    print_info "Проверка системных зависимостей..."
    
    local missing_deps=()
    
    # Проверка Python
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    # Проверка pip
    if ! command -v pip3 &> /dev/null; then
        missing_deps+=("python3-pip")
    fi
    
    # Проверка git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    # Проверка Docker (опционально)
    if ! command -v docker &> /dev/null; then
        print_warning "Docker не установлен. Мониторинг через Docker будет недоступен."
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_warning "Docker Compose не установлен. Мониторинг через Docker будет недоступен."
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Отсутствуют необходимые зависимости: ${missing_deps[*]}"
        
        # Предложение установить зависимости
        if [ -f /etc/debian_version ]; then
            print_info "Обнаружена система Debian/Ubuntu"
            read -p "Установить недостающие зависимости? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo apt-get update
                sudo apt-get install -y "${missing_deps[@]}"
            else
                print_error "Установите зависимости вручную и запустите скрипт снова."
                exit 1
            fi
        elif [ -f /etc/redhat-release ]; then
            print_info "Обнаружена система RHEL/CentOS/Fedora"
            read -p "Установить недостающие зависимости? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if command -v dnf &> /dev/null; then
                    sudo dnf install -y "${missing_deps[@]}"
                elif command -v yum &> /dev/null; then
                    sudo yum install -y "${missing_deps[@]}"
                fi
            else
                print_error "Установите зависимости вручную и запустите скрипт снова."
                exit 1
            fi
        else
            print_error "Не удалось определить систему. Установите зависимости вручную:"
            echo "  - Python 3.7+"
            echo "  - pip3"
            echo "  - git"
            exit 1
        fi
    fi
    
    # Проверка версии Python
    local python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    if [[ $(echo "$python_version < 3.7" | bc) -eq 1 ]]; then
        print_error "Требуется Python 3.7 или выше. Текущая версия: $python_version"
        exit 1
    fi
    
    print_success "Все зависимости установлены"
}

# Клонирование репозитория
clone_repository() {
    local repo_url="https://github.com/glebkoxan36/node_manager.git"
    local target_dir="$HOME/blockchain_module"
    
    print_info "Клонирование репозитория..."
    
    if [ -d "$target_dir" ]; then
        print_warning "Директория $target_dir уже существует"
        read -p "Перезаписать? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$target_dir"
        else
            print_info "Использование существующей директории"
            return
        fi
    fi
    
    git clone "$repo_url" "$target_dir"
    
    if [ ! -d "$target_dir" ]; then
        print_error "Не удалось клонировать репозиторий"
        exit 1
    fi
    
    cd "$target_dir"
    print_success "Репозиторий клонирован в $target_dir"
}

# Установка Python зависимостей
install_python_deps() {
    print_info "Установка Python зависимостей..."
    
    # Создание виртуального окружения
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    
    # Активация виртуального окружения
    source venv/bin/activate
    
    # Обновление pip
    pip install --upgrade pip
    
    # Установка зависимостей
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        # Установка зависимостей вручную
        pip install aiohttp>=3.8.0
        pip install aiosqlite>=0.19.0
        pip install prometheus-client>=0.17.0
        pip install aiohttp-cors>=0.7.0
        pip install click>=8.1.0
        pip install questionary>=2.0.0
        pip install rich>=13.0.0
        pip install psutil>=5.9.0
        pip install python-dotenv>=1.0.0
        pip install pyyaml>=6.0
    fi
    
    print_success "Python зависимости установлены"
}

# Установка модуля
install_module() {
    print_info "Установка модуля blockchain_module..."
    
    # Проверяем, активировано ли виртуальное окружение
    if [[ -z "$VIRTUAL_ENV" ]]; then
        source venv/bin/activate
    fi
    
    # Устанавливаем модуль
    if [ -f "setup.py" ]; then
        pip install -e .
    else
        print_error "Файл setup.py не найден"
        exit 1
    fi
    
    print_success "Модуль blockchain_module установлен"
}

# Создание структуры директорий
create_directory_structure() {
    print_info "Создание структуры директорий..."
    
    # Основные директории
    mkdir -p configs
    mkdir -p logs
    mkdir -p data
    mkdir -p prometheus
    mkdir -p grafana/dashboards
    
    # Копирование конфигурационных файлов
    if [ -f "module_config.json" ]; then
        cp module_config.json configs/
    fi
    
    if [ -f "prometheus.yml" ]; then
        cp prometheus.yml prometheus/
    fi
    
    if [ -f "alerts.yml" ]; then
        cp alerts.yml prometheus/
    fi
    
    if [ -f "blockchain_dashboard.json" ]; then
        cp blockchain_dashboard.json grafana/dashboards/
    fi
    
    # Создание файла .env
    if [ ! -f ".env" ]; then
        cat > .env << EOF
# Blockchain Module Configuration
NOWNODES_API_KEY=your_api_key_here
LOG_LEVEL=INFO
DB_PATH=data/blockchain_module.db
EOF
        print_warning "Файл .env создан. Отредактируйте его и добавьте ваш API ключ Nownodes"
    fi
    
    print_success "Структура директорий создана"
}

# Настройка конфигурации
setup_configuration() {
    print_info "Настройка конфигурации..."
    
    local config_file="configs/module_config.json"
    
    if [ ! -f "$config_file" ]; then
        # Создаем минимальную конфигурацию
        cat > "$config_file" << EOF
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
    fi
    
    # Запрашиваем API ключ у пользователя
    read -p "Введите ваш Nownodes API ключ (или нажмите Enter чтобы пропустить): " api_key
    
    if [ -n "$api_key" ]; then
        # Обновляем API ключ в конфигурации
        python3 -c "
import json
import sys

config_file = '$config_file'
api_key = '$api_key'

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    config['module_settings']['api_key'] = api_key
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    
    print('API ключ обновлен в конфигурации')
except Exception as e:
    print(f'Ошибка обновления конфигурации: {e}')
    sys.exit(1)
"
        
        # Также обновляем .env файл
        sed -i "s/NOWNODES_API_KEY=.*/NOWNODES_API_KEY=$api_key/" .env
    fi
    
    print_success "Конфигурация настроена"
}

# Настройка Docker мониторинга
setup_docker_monitoring() {
    if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
        print_warning "Docker или Docker Compose не установлены. Пропускаем настройку мониторинга."
        return
    fi
    
    print_info "Настройка Docker мониторинга..."
    
    # Проверяем наличие docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        print_error "Файл docker-compose.yml не найден"
        return
    fi
    
    # Создаем необходимые директории для Docker
    mkdir -p prometheus_data
    mkdir -p grafana_data
    mkdir -p alertmanager_data
    
    # Запрашиваем у пользователя
    read -p "Запустить Docker контейнеры для мониторинга? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Запуск Docker контейнеров..."
        docker-compose up -d
        
        if [ $? -eq 0 ]; then
            print_success "Docker контейнеры запущены"
            echo ""
            echo "Доступ к сервисам:"
            echo "  - Prometheus: http://localhost:9090"
            echo "  - Grafana: http://localhost:3000 (логин: admin, пароль: admin)"
            echo "  - Node Exporter: http://localhost:9100"
            echo "  - Alertmanager: http://localhost:9093"
            echo "  - cAdvisor: http://localhost:8080"
            echo ""
            echo "Для остановки выполните: docker-compose down"
        else
            print_error "Не удалось запустить Docker контейнеры"
        fi
    else
        print_info "Docker контейнеры не запущены. Вы можете запустить их позже командой: docker-compose up -d"
    fi
}

# Создание сервисного файла для systemd
create_systemd_service() {
    if [[ $EUID -ne 0 ]]; then
        print_warning "Для создания systemd сервиса требуются права root"
        return
    fi
    
    read -p "Создать systemd сервис для автостарта модуля? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    local service_file="/etc/systemd/system/blockchain-module.service"
    local install_dir=$(pwd)
    
    cat > "$service_file" << EOF
[Unit]
Description=Blockchain Module Service
After=network.target
Requires=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$install_dir
Environment="PATH=$install_dir/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$install_dir/venv/bin/python -c "from blockchain_module import start_rest_api_server; import asyncio; asyncio.run(start_rest_api_server())"
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=blockchain-module

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable blockchain-module.service
    
    print_success "Systemd сервис создан и включен"
    print_info "Для запуска выполните: sudo systemctl start blockchain-module.service"
}

# Создание скриптов для управления
create_management_scripts() {
    print_info "Создание скриптов управления..."
    
    # Основной скрипт управления
    cat > manage.sh << 'EOF'
#!/bin/bash

# Скрипт управления Blockchain Module

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

case "$1" in
    start)
        if [ -f venv/bin/activate ]; then
            source venv/bin/activate
            python -c "from blockchain_module import start_rest_api_server; import asyncio; asyncio.run(start_rest_api_server())" &
            echo $! > blockchain_module.pid
            print_success "Модуль запущен (PID: $(cat blockchain_module.pid))"
        else
            print_error "Виртуальное окружение не найдено"
        fi
        ;;
    
    stop)
        if [ -f blockchain_module.pid ]; then
            kill $(cat blockchain_module.pid) 2>/dev/null && rm blockchain_module.pid
            print_success "Модуль остановлен"
        else
            print_error "PID файл не найден"
        fi
        ;;
    
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    
    status)
        if [ -f blockchain_module.pid ] && kill -0 $(cat blockchain_module.pid) 2>/dev/null; then
            print_success "Модуль работает (PID: $(cat blockchain_module.pid))"
        else
            print_error "Модуль не работает"
        fi
        ;;
    
    cli)
        source venv/bin/activate
        python -c "import asyncio; from blockchain_module import start_cli; asyncio.run(start_cli())"
        ;;
    
    monitor)
        if command -v docker-compose &> /dev/null; then
            docker-compose up -d
            print_success "Мониторинг запущен"
        else
            print_error "Docker Compose не установлен"
        fi
        ;;
    
    stop-monitor)
        if command -v docker-compose &> /dev/null; then
            docker-compose down
            print_success "Мониторинг остановлен"
        else
            print_error "Docker Compose не установлен"
        fi
        ;;
    
    update)
        git pull
        source venv/bin/activate
        pip install -r requirements.txt
        pip install -e .
        print_success "Модуль обновлен"
        ;;
    
    *)
        echo "Использование: $0 {start|stop|restart|status|cli|monitor|stop-monitor|update}"
        echo ""
        echo "Команды:"
        echo "  start         - Запустить модуль"
        echo "  stop          - Остановить модуль"
        echo "  restart       - Перезапустить модуль"
        echo "  status        - Проверить статус модуля"
        echo "  cli           - Запустить CLI интерфейс"
        echo "  monitor       - Запустить мониторинг (Docker)"
        echo "  stop-monitor  - Остановить мониторинг"
        echo "  update        - Обновить модуль из Git"
        exit 1
        ;;
esac
EOF
    
    chmod +x manage.sh
    
    # Скрипт для инициализации базы данных
    cat > init_db.py << 'EOF'
#!/usr/bin/env python3
"""
Скрипт инициализации базы данных Blockchain Module
"""

import asyncio
import logging
from blockchain_module import SQLiteDBManager, setup_logging

async def initialize_database():
    """Инициализировать базу данных"""
    logger = setup_logging()
    
    try:
        db_manager = SQLiteDBManager("data/blockchain_module.db")
        await db_manager.initialize()
        
        logger.info("База данных успешно инициализирована")
        print("✅ База данных успешно инициализирована")
        
        # Получаем статистику
        stats = await db_manager.get_stats()
        print(f"📊 Статистика базы данных:")
        print(f"   Пользователей: {stats.get('users_count', 0)}")
        print(f"   Адресов для мониторинга: {stats.get('monitored_addresses_count', 0)}")
        print(f"   Транзакций: {stats.get('transactions_count', 0)}")
        
        await db_manager.close()
        
    except Exception as e:
        logger.error(f"Ошибка инициализации базы данных: {e}")
        print(f"❌ Ошибка: {e}")
        return False
    
    return True

if __name__ == "__main__":
    asyncio.run(initialize_database())
EOF
    
    chmod +x init_db.py
    
    print_success "Скрипты управления созданы"
    print_info "Используйте ./manage.sh для управления модулем"
}

# Тестирование установки
test_installation() {
    print_info "Тестирование установки..."
    
    if [ -f venv/bin/activate ]; then
        source venv/bin/activate
        
        # Проверяем импорт модуля
        python3 -c "
try:
    from blockchain_module import __version__, get_module_info
    info = get_module_info()
    print(f'✅ Blockchain Module v{__version__} успешно импортирован')
    print(f'📦 Поддерживаемые монеты: {len(info.get(\"supported_coins\", []))}')
    print(f'👥 Мультипользовательский режим: {\"включен\" if info.get(\"multiuser_enabled\") else \"выключен\"}')
except Exception as e:
    print(f'❌ Ошибка импорта модуля: {e}')
    exit(1)
"
        
        # Проверяем конфигурацию
        python3 -c "
try:
    from blockchain_module import validate_configuration
    config_status = validate_configuration()
    if config_status['valid']:
        print('✅ Конфигурация валидна')
    else:
        print('⚠️  Проблемы с конфигурацией:')
        for error in config_status['errors']:
            print(f'   ❌ {error}')
        for warning in config_status['warnings']:
            print(f'   ⚠️  {warning}')
except Exception as e:
    print(f'❌ Ошибка проверки конфигурации: {e}')
"
    else
        print_error "Виртуальное окружение не найдено"
    fi
}

