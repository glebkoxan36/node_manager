#!/bin/bash

# Blockchain Module Auto-Installer
# Version: 1.1.0
# Author: Blockchain Module Team

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/glebkoxan36/node_manager.git"
INSTALL_DIR="$HOME/blockchain_module"
VENV_DIR="$INSTALL_DIR/venv"

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        OS_VERSION=$(cat /etc/redhat-release | sed 's/.*release \([0-9]\.[0-9]\).*/\1/')
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    echo "$OS $OS_VERSION"
}

# Install Python 3.9 on Ubuntu/Debian
install_python_ubuntu() {
    echo -e "${BLUE}[INFO]${NC} Установка Python 3.9 на Ubuntu/Debian..."
    
    apt-get update
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update
    apt-get install -y python3.9 python3.9-dev python3.9-distutils python3.9-venv
    apt-get install -y python3-pip
    
    # Create symlink if python3.9 is installed but python3 points to older version
    if command -v python3.9 &> /dev/null && ! command -v python3 &> /dev/null; then
        ln -s /usr/bin/python3.9 /usr/bin/python3
    fi
    
    echo -e "${GREEN}[SUCCESS]${NC} Python 3.9 установлен"
}

# Install Python 3.9 on CentOS/RHEL
install_python_centos() {
    echo -e "${BLUE}[INFO]${NC} Установка Python 3.9 на CentOS/RHEL..."
    
    yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel
    yum install -y wget make
    
    cd /tmp
    wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz
    tar xzf Python-3.9.18.tgz
    cd Python-3.9.18
    ./configure --enable-optimizations
    make altinstall
    
    # Create symlinks
    if [ -f /usr/local/bin/python3.9 ]; then
        ln -sf /usr/local/bin/python3.9 /usr/bin/python3
        ln -sf /usr/local/bin/python3.9 /usr/bin/python3.9
    fi
    
    # Install pip
    curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3.9 get-pip.py
    
    echo -e "${GREEN}[SUCCESS]${NC} Python 3.9 установлен"
}

# Install Python 3.9 based on OS
install_python39() {
    OS_INFO=$(detect_os)
    OS=$(echo $OS_INFO | awk '{print $1}')
    
    echo -e "${YELLOW}[WARNING]${NC} Python 3.7+ не найден. Установка Python 3.9..."
    
    case $OS in
        ubuntu|debian)
            install_python_ubuntu
            ;;
        centos|rhel|fedora)
            install_python_centos
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Неподдерживаемая ОС: $OS"
            echo "Пожалуйста, установите Python 3.9 вручную и повторите попытку."
            exit 1
            ;;
    esac
}

# Check and install Python 3.9
check_install_python() {
    echo -e "${BLUE}[INFO]${NC} Проверка наличия Python 3.7+..."
    
    # Check for python3.9 first
    if command -v python3.9 &> /dev/null; then
        PYTHON_VERSION="python3.9"
        echo -e "${GREEN}[SUCCESS]${NC} Найден Python 3.9"
        return 0
    fi
    
    # Check for python3.8
    if command -v python3.8 &> /dev/null; then
        PYTHON_VERSION="python3.8"
        echo -e "${GREEN}[SUCCESS]${NC} Найден Python 3.8"
        return 0
    fi
    
    # Check for python3.7
    if command -v python3.7 &> /dev/null; then
        PYTHON_VERSION="python3.7"
        echo -e "${GREEN}[SUCCESS]${NC} Найден Python 3.7"
        return 0
    fi
    
    # Check for python3
    if command -v python3 &> /dev/null; then
        # Check python3 version
        PY3_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        if [[ $PY3_VERSION == "3.7"* ]] || [[ $PY3_VERSION == "3.8"* ]] || [[ $PY3_VERSION == "3.9"* ]] || [[ $PY3_VERSION == "3.10"* ]]; then
            PYTHON_VERSION="python3"
            echo -e "${GREEN}[SUCCESS]${NC} Найден Python $PY3_VERSION"
            return 0
        fi
    fi
    
    # Python not found or version too old
    echo -e "${RED}[ERROR]${NC} Python 3.7+ не найден"
    
    # Ask for installation
    read -p "Установить Python 3.9 автоматически? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_python39
        
        # Verify installation
        if command -v python3.9 &> /dev/null; then
            PYTHON_VERSION="python3.9"
            echo -e "${GREEN}[SUCCESS]${NC} Python 3.9 успешно установлен"
            return 0
        elif command -v python3 &> /dev/null; then
            PYTHON_VERSION="python3"
            echo -e "${GREEN}[SUCCESS]${NC} Python 3 успешно установлен"
            return 0
        else
            echo -e "${RED}[ERROR]${NC} Не удалось установить Python 3.9"
            exit 1
        fi
    else
        echo -e "${RED}[ERROR]${NC} Установите Python 3.9 вручную и повторите попытку."
        echo "Для Ubuntu/Debian: sudo apt-get install python3.9 python3.9-venv"
        echo "Для CentOS/RHEL: sudo yum install python39"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}[INFO]${NC} Проверка системных требований..."
    
    # Check Python
    check_install_python
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        echo -e "${YELLOW}[WARNING]${NC} pip3 не найден. Установка..."
        curl -sS https://bootstrap.pypa.io/get-pip.py | python3
        if [ $? -ne 0 ]; then
            echo -e "${RED}[ERROR]${NC} Не удалось установить pip3"
            exit 1
        fi
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}[WARNING]${NC} Git не найден. Установка..."
        OS_INFO=$(detect_os)
        OS=$(echo $OS_INFO | awk '{print $1}')
        case $OS in
            ubuntu|debian)
                apt-get install -y git
                ;;
            centos|rhel|fedora)
                yum install -y git
                ;;
        esac
    fi
    
    echo -e "${GREEN}[SUCCESS]${NC} Все зависимости проверены"
}

# Main installation
main() {
    echo ""
    echo "==============================================="
    echo -e "${GREEN}Blockchain Module Auto-Installer${NC}"
    echo "==============================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then 
        echo -e "${YELLOW}[WARNING]${NC} Скрипт запущен от root"
        echo "Это нормально для установки системных зависимостей."
        read -p "Продолжить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}[ERROR]${NC} Прервано пользователем"
            exit 1
        fi
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Create installation directory
    echo -e "${BLUE}[INFO]${NC} Создание директории установки..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Clone repository
    echo -e "${BLUE}[INFO]${NC} Клонирование репозитория..."
    if [ -d ".git" ]; then
        echo "Репозиторий уже существует. Обновление..."
        git pull
    else
        git clone "$REPO_URL" .
    fi
    
    # Setup virtual environment
    echo -e "${BLUE}[INFO]${NC} Создание виртуального окружения..."
    if [ -d "$VENV_DIR" ]; then
        echo "Виртуальное окружение уже существует. Пересоздание..."
        rm -rf "$VENV_DIR"
    fi
    
    # Create venv with detected python version
    $PYTHON_VERSION -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    echo -e "${BLUE}[INFO]${NC} Обновление pip..."
    pip install --upgrade pip
    
    # Install dependencies
    echo -e "${BLUE}[INFO]${NC} Установка зависимостей Python..."
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        # Install core dependencies
        pip install aiohttp aiosqlite prometheus-client aiohttp-cors psutil
    fi
    
    # Install module in development mode
    if [ -f "setup.py" ]; then
        pip install -e .
    fi
    
    # Configure module
    echo -e "${BLUE}[INFO]${NC} Настройка модуля..."
    
    # Create config directory
    mkdir -p "$INSTALL_DIR/configs"
    
    # Create default config if it doesn't exist
    if [ ! -f "$INSTALL_DIR/configs/module_config.json" ]; then
        cat > "$INSTALL_DIR/configs/module_config.json" << EOF
{
  "module_settings": {
    "api_key": "ВАШ_API_КЛЮЧ_ЗДЕСЬ",
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
        echo -e "${YELLOW}[WARNING]${NC} Конфигурационный файл создан. Отредактируйте configs/module_config.json и добавьте ваш API ключ Nownodes."
    fi
    
    # Create startup script
    echo -e "${BLUE}[INFO]${NC} Создание скрипта запуска..."
    cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/bash

# Blockchain Module Startup Script
cd "$(dirname "$0")"

# Activate virtual environment
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "Ошибка: Виртуальное окружение не найдено"
    exit 1
fi

# Run the module
python -m blockchain_module
EOF
    
    chmod +x "$INSTALL_DIR/start.sh"
    
    # Create CLI script
    cat > "$INSTALL_DIR/cli.sh" << 'EOF'
#!/bin/bash

# Blockchain Module CLI Script
cd "$(dirname "$0")"

# Activate virtual environment
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "Ошибка: Виртуальное окружение не найдено"
    exit 1
fi

# Run CLI
python -m blockchain_module.cli "$@"
EOF
    
    chmod +x "$INSTALL_DIR/cli.sh"
    
    # Test installation
    echo -e "${BLUE}[INFO]${NC} Тестирование установки..."
    source "$VENV_DIR/bin/activate"
    if python -c "import blockchain_module; print('Модуль импортирован успешно')" &> /dev/null; then
        echo -e "${GREEN}[SUCCESS]${NC} Модуль установлен успешно"
    else
        echo -e "${YELLOW}[WARNING]${NC} Модуль не может быть импортирован, но установка продолжена"
    fi
    
    # Show summary
    echo ""
    echo "==============================================="
    echo -e "${GREEN}Установка завершена успешно!${NC}"
    echo "==============================================="
    echo ""
    echo -e "${BLUE}Директория установки:${NC} $INSTALL_DIR"
    echo ""
    echo -e "${BLUE}Команды запуска:${NC}"
    echo "  Основной запуск:  $INSTALL_DIR/start.sh"
    echo "  CLI интерфейс:    $INSTALL_DIR/cli.sh"
    echo "  Ручной запуск:    cd $INSTALL_DIR && source venv/bin/activate && python -m blockchain_module"
    echo ""
    echo -e "${BLUE}Настройка:${NC}"
    echo "  1. Отредактируйте файл конфигурации: $INSTALL_DIR/configs/module_config.json"
    echo "  2. Добавьте ваш API ключ Nownodes в поле 'api_key'"
    echo "  3. При необходимости настройте другие параметры"
    echo ""
    echo -e "${BLUE}Проверка работы:${NC}"
    echo "  cd $INSTALL_DIR"
    echo "  ./start.sh"
    echo ""
    echo "Для мониторинга также можно запустить Docker контейнеры:"
    echo "  docker-compose up -d  (если docker-compose.yml присутствует)"
    echo ""
}

# Run main function
main
