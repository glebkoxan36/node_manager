#!/bin/bash

# Blockchain Module Auto-Installer
# Version: 1.0.0
# Author: Blockchain Module Team

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/glebkoxan36/node_manager.git"
INSTALL_DIR="$HOME/blockchain_module"
VENV_DIR="$INSTALL_DIR/venv"
PYTHON_VERSION="python3.9"
REQUIREMENTS_FILE="requirements.txt"

# Function to print colored messages
print_message() {
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

# Function to check prerequisites
check_prerequisites() {
    print_message "Проверка системных требований..."
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then 
        print_warning "Не рекомендуется запускать скрипт от root. Продолжить? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            print_error "Прервано пользователем"
            exit 1
        fi
    fi
    
    # Check Python version
    if ! command -v python3.9 &> /dev/null; then
        if command -v python3.8 &> /dev/null; then
            PYTHON_VERSION="python3.8"
            print_warning "Python 3.9 не найден, будет использован Python 3.8"
        elif command -v python3.7 &> /dev/null; then
            PYTHON_VERSION="python3.7"
            print_warning "Python 3.9 не найден, будет использован Python 3.7"
        else
            print_error "Python 3.7+ не установлен. Установите Python и повторите попытку."
            exit 1
        fi
    fi
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 не установлен. Установите pip и повторите попытку."
        exit 1
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        print_error "Git не установлен. Установите git и повторите попытку."
        exit 1
    fi
    
    # Check Docker (optional for monitoring)
    if ! command -v docker &> /dev/null; then
        print_warning "Docker не установлен. Мониторинг через Docker не будет доступен."
        DOCKER_AVAILABLE=false
    else
        DOCKER_AVAILABLE=true
    fi
    
    print_success "Проверка системных требований завершена"
}

# Function to create installation directory
create_installation_directory() {
    print_message "Создание директории установки..."
    
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Директория $INSTALL_DIR уже существует"
        echo "Выберите действие:"
        echo "1) Удалить и переустановить"
        echo "2) Выйти"
        echo "3) Обновить существующую установку"
        
        read -r choice
        case $choice in
            1)
                print_message "Удаление старой установки..."
                rm -rf "$INSTALL_DIR"
                mkdir -p "$INSTALL_DIR"
                ;;
            2)
                print_error "Прервано пользователем"
                exit 1
                ;;
            3)
                print_message "Обновление существующей установки..."
                ;;
            *)
                print_error "Неверный выбор"
                exit 1
                ;;
        esac
    else
        mkdir -p "$INSTALL_DIR"
    fi
    
    print_success "Директория создана: $INSTALL_DIR"
}

# Function to clone repository
clone_repository() {
    print_message "Клонирование репозитория..."
    
    cd "$INSTALL_DIR"
    
    if [ -d ".git" ]; then
        print_message "Обновление репозитория..."
        git pull origin main
    else
        git clone "$REPO_URL" .
    fi
    
    # Check if clone was successful
    if [ $? -ne 0 ]; then
        print_error "Ошибка при клонировании репозитория"
        exit 1
    fi
    
    print_success "Репоизторий успешно клонирован"
}

# Function to setup Python virtual environment
setup_virtual_environment() {
    print_message "Настройка Python виртуального окружения..."
    
    # Check if virtual environment exists
    if [ -d "$VENV_DIR" ]; then
        print_warning "Виртуальное окружение уже существует"
        echo "Выберите действие:"
        echo "1) Пересоздать"
        echo "2) Использовать существующее"
        
        read -r choice
        case $choice in
            1)
                rm -rf "$VENV_DIR"
                "$PYTHON_VERSION" -m venv "$VENV_DIR"
                ;;
            2)
                print_message "Используется существующее виртуальное окружение"
                ;;
            *)
                print_error "Неверный выбор"
                exit 1
                ;;
        esac
    else
        "$PYTHON_VERSION" -m venv "$VENV_DIR"
    fi
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    print_success "Виртуальное окружение создано"
}

# Function to install Python dependencies
install_dependencies() {
    print_message "Установка зависимостей Python..."
    
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install requirements
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        print_warning "Файл requirements.txt не найден, устанавливаем основные зависимости..."
        pip install aiohttp aiosqlite prometheus-client aiohttp-cors psutil click questionary rich
    fi
    
    # Install module in development mode
    if [ -f "setup.py" ]; then
        pip install -e .
    fi
    
    print_success "Зависимости установлены"
}

# Function to configure the module
configure_module() {
    print_message "Настройка модуля..."
    
    # Create configs directory if it doesn't exist
    mkdir -p "$INSTALL_DIR/configs"
    
    # Copy config files if they exist
    if [ -f "configs/module_config.json" ]; then
        cp configs/module_config.json configs/module_config.json.backup
    fi
    
    # Ask for Nownodes API key
    print_message "Настройка API ключа Nownodes..."
    echo "Введите ваш API ключ от Nownodes (оставьте пустым чтобы пропустить):"
    read -r api_key
    
    if [ -n "$api_key" ]; then
        # Create or update config file
        cat > configs/module_config.json << EOF
{
  "module_settings": {
    "api_key": "$api_key",
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
        print_success "Конфигурационный файл создан"
    else
        print_warning "API ключ не установлен. Вы можете установить его позже в configs/module_config.json"
    fi
    
    # Set up Prometheus configuration
    print_message "Настройка Prometheus..."
    
    if [ -f "prometheus.yml" ]; then
        # Backup original file
        cp prometheus.yml prometheus.yml.backup
        
        # Create Prometheus directory for Docker
        mkdir -p "$INSTALL_DIR/prometheus"
        cp prometheus.yml "$INSTALL_DIR/prometheus/"
        cp alerts.yml "$INSTALL_DIR/prometheus/" 2>/dev/null || true
    fi
    
    # Set up Grafana dashboard
    print_message "Настройка Grafana..."
    mkdir -p "$INSTALL_DIR/grafana/dashboards"
    
    if [ -f "blockchain_dashboard.json" ]; then
        cp blockchain_dashboard.json "$INSTALL_DIR/grafana/dashboards/"
    fi
    
    print_success "Конфигурация завершена"
}

# Function to setup Docker monitoring
setup_docker_monitoring() {
    if [ "$DOCKER_AVAILABLE" = true ]; then
        print_message "Настройка Docker мониторинга..."
        
        echo "Хотите настроить Docker мониторинг? (y/N)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            # Check if docker-compose.yml exists
            if [ -f "docker-compose.yml" ]; then
                print_message "Запуск Docker Compose..."
                docker-compose up -d
                
                # Check if successful
                if [ $? -eq 0 ]; then
                    print_success "Docker контейнеры запущены"
                    print_message "Сервисы мониторинга:"
                    print_message "  - Prometheus: http://localhost:9090"
                    print_message "  - Grafana: http://localhost:3000 (admin/admin)"
                    print_message "  - Node Exporter: http://localhost:9100"
                else
                    print_error "Ошибка при запуске Docker Compose"
                fi
            else
                print_warning "Файл docker-compose.yml не найден"
            fi
        fi
    fi
}

# Function to create systemd service
create_systemd_service() {
    print_message "Создание systemd сервиса..."
    
    echo "Хотите создать systemd сервис для автоматического запуска? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # Create service file
        SERVICE_FILE="/etc/systemd/system/blockchain-module.service"
        
        if [ -f "$SERVICE_FILE" ]; then
            print_warning "Сервис уже существует"
            echo "Выберите действие:"
            echo "1) Перезаписать"
            echo "2) Пропустить"
            
            read -r choice
            case $choice in
                1)
                    # Continue
                    ;;
                2)
                    return
                    ;;
                *)
                    print_error "Неверный выбор"
                    return
                    ;;
            esac
        fi
        
        # Create service file
        sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Blockchain Module Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/python -m blockchain_module
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=blockchain-module

[Install]
WantedBy=multi-user.target
EOF
        
        # Reload systemd and enable service
        sudo systemctl daemon-reload
        sudo systemctl enable blockchain-module.service
        
        print_success "Systemd сервис создан"
        print_message "Команды управления:"
        print_message "  sudo systemctl start blockchain-module"
        print_message "  sudo systemctl stop blockchain-module"
        print_message "  sudo systemctl status blockchain-module"
        print_message "  sudo journalctl -u blockchain-module -f"
    fi
}

# Function to create startup script
create_startup_script() {
    print_message "Создание скрипта запуска..."
    
    # Create startup script
    cat > "$INSTALL_DIR/start_blockchain_module.sh" << 'EOF'
#!/bin/bash

# Blockchain Module Startup Script
# This script starts all components of the Blockchain Module

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Blockchain Module Startup${NC}"
echo "==============================="

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${RED}Ошибка: Виртуальное окружение не найдено${NC}"
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Function to check if port is in use
check_port() {
    local port=$1
    local service=$2
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${YELLOW}Предупреждение: Порт $port уже используется ($service)${NC}"
        return 1
    fi
    return 0
}

# Check ports
check_port 9090 "Prometheus метрики"
check_port 8080 "REST API"

# Start the module
echo -e "${GREEN}Запуск Blockchain Module...${NC}"

# Check if module can be imported
if python -c "import blockchain_module" &> /dev/null; then
    # Run the module
    python -m blockchain_module
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Blockchain Module запущен${NC}"
        echo -e "${GREEN}Сервисы:${NC}"
        echo "  - REST API: http://localhost:8080/api/v1/info"
        echo "  - Метрики: http://localhost:9090/metrics"
        echo "  - Админ CLI: python -m blockchain_module.cli"
    else
        echo -e "${RED}Ошибка при запуске Blockchain Module${NC}"
        exit 1
    fi
else
    echo -e "${RED}Ошибка: Модуль blockchain_module не найден${NC}"
    echo "Убедитесь что зависимости установлены: pip install -e ."
    exit 1
fi
EOF
    
    # Make script executable
    chmod +x "$INSTALL_DIR/start_blockchain_module.sh"
    
    # Create CLI alias script
    cat > "$INSTALL_DIR/blockchain_cli.sh" << 'EOF'
#!/bin/bash

# Blockchain Module CLI Wrapper

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

if [ ! -d "venv" ]; then
    echo "Ошибка: Виртуальное окружение не найдено"
    exit 1
fi

source venv/bin/activate

# Check if CLI is available
if python -c "from blockchain_module.cli import cli" &> /dev/null; then
    python -m blockchain_module.cli "$@"
else
    echo "CLI недоступен. Попробуйте: python -m blockchain_module"
fi
EOF
    
    chmod +x "$INSTALL_DIR/blockchain_cli.sh"
    
    print_success "Скрипты запуска созданы"
    print_message "Для запуска модуля: $INSTALL_DIR/start_blockchain_module.sh"
    print_message "Для запуска CLI: $INSTALL_DIR/blockchain_cli.sh"
}

# Function to test installation
test_installation() {
    print_message "Тестирование установки..."
    
    source "$VENV_DIR/bin/activate"
    
    # Test Python imports
    if python -c "import blockchain_module" &> /dev/null; then
        print_success "Модуль blockchain_module импортирован успешно"
    else
        print_error "Ошибка импорта модуля blockchain_module"
        return 1
    fi
    
    # Test basic functionality
    if python -c "
from blockchain_module import get_module_info
info = get_module_info()
print('Версия модуля:', info.get('version'))
print('Поддерживаемые монеты:', info.get('supported_coins', []))
" > /dev/null 2>&1; then
        print_success "Базовая функциональность работает"
    else
        print_warning "Базовая функциональность не работает (возможно отсутствует конфиг)"
    fi
    
    return 0
}

# Function to display installation summary
show_summary() {
    echo ""
    echo "==============================================="
    echo -e "${GREEN}Blockchain Module успешно установлен!${NC}"
    echo "==============================================="
    echo ""
    echo -e "${BLUE}Директория установки:${NC} $INSTALL_DIR"
    echo ""
    echo -e "${BLUE}Скрипты запуска:${NC}"
    echo "  Основной запуск: $INSTALL_DIR/start_blockchain_module.sh"
    echo "  CLI интерфейс:   $INSTALL_DIR/blockchain_cli.sh"
    echo ""
    echo -e "${BLUE}Конфигурационные файлы:${NC}"
    echo "  Основной конфиг:  $INSTALL_DIR/configs/module_config.json"
    echo "  Prometheus конфиг: $INSTALL_DIR/prometheus/prometheus.yml"
    echo ""
    
    if [ "$DOCKER_AVAILABLE" = true ]; then
        echo -e "${BLUE}Docker сервисы мониторинга:${NC}"
        echo "  Prometheus:  http://localhost:9090"
        echo "  Grafana:     http://localhost:3000 (admin/admin)"
        echo "  Node экспортер: http://localhost:9100"
        echo "  Управление:  docker-compose -f $INSTALL_DIR/docker-compose.yml [command]"
        echo ""
    fi
    
    echo -e "${BLUE}Проверка установки:${NC}"
    echo "  cd $INSTALL_DIR"
    echo "  source venv/bin/activate"
    echo "  python -c \"import blockchain_module; print(blockchain_module.get_module_info())\""
    echo ""
    echo -e "${BLUE}Документация:${NC}"
    echo "  GitHub: https://github.com/glebkoxan36/node_manager"
    echo "  Для помощи: python -m blockchain_module.cli --help"
    echo ""
    echo "==============================================="
}

# Main installation function
main() {
    echo ""
    echo "==============================================="
    echo -e "${GREEN}Blockchain Module Auto-Installer${NC}"
    echo "==============================================="
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Create installation directory
    create_installation_directory
    
    # Clone repository
    clone_repository
    
    # Setup virtual environment
    setup_virtual_environment
    
    # Install dependencies
    install_dependencies
    
    # Configure module
    configure_module
    
    # Setup Docker monitoring
    setup_docker_monitoring
    
    # Create startup scripts
    create_startup_script
    
    # Create systemd service (optional)
    create_systemd_service
    
    # Test installation
    test_installation
    
    # Show summary
    show_summary
}

# Run main function
main
