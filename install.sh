#!/bin/bash

# Blockchain Module Auto-Installer
# Version: 1.2.0
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

# Функция для очистки директории установки
clean_install_dir() {
    echo -e "${BLUE}[INFO]${NC} Очистка директории установки..."
    
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}[WARNING]${NC} Директория $INSTALL_DIR уже существует"
        echo "Выберите действие:"
        echo "1) Удалить и переустановить (рекомендуется)"
        echo "2) Создать резервную копию и переустановить"
        echo "3) Выйти"
        
        read -r choice
        case $choice in
            1)
                echo "Удаление старой установки..."
                rm -rf "$INSTALL_DIR"
                mkdir -p "$INSTALL_DIR"
                ;;
            2)
                BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
                echo "Создание резервной копии: $BACKUP_DIR"
                mv "$INSTALL_DIR" "$BACKUP_DIR"
                mkdir -p "$INSTALL_DIR"
                ;;
            3)
                echo -e "${RED}[ERROR]${NC} Прервано пользователем"
                exit 1
                ;;
            *)
                echo -e "${RED}[ERROR]${NC} Неверный выбор"
                exit 1
                ;;
        esac
    else
        mkdir -p "$INSTALL_DIR"
    fi
}

# Функция для проверки Python
check_python() {
    echo -e "${BLUE}[INFO]${NC} Проверка Python..."
    
    # Проверяем python3.9
    if command -v python3.9 &> /dev/null; then
        PYTHON_VERSION="python3.9"
        echo -e "${GREEN}[SUCCESS]${NC} Найден Python 3.9"
        return 0
    fi
    
    # Проверяем python3.8
    if command -v python3.8 &> /dev/null; then
        PYTHON_VERSION="python3.8"
        echo -e "${GREEN}[SUCCESS]${NC} Найден Python 3.8"
        return 0
    fi
    
    # Проверяем python3.7
    if command -v python3.7 &> /dev/null; then
        PYTHON_VERSION="python3.7"
        echo -e "${GREEN}[SUCCESS]${NC} Найден Python 3.7"
        return 0
    fi
    
    # Проверяем python3
    if command -v python3 &> /dev/null; then
        # Проверяем версию
        PY3_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        if [[ $PY3_VERSION == "3.7"* ]] || [[ $PY3_VERSION == "3.8"* ]] || [[ $PY3_VERSION == "3.9"* ]] || [[ $PY3_VERSION == "3.10"* ]]; then
            PYTHON_VERSION="python3"
            echo -e "${GREEN}[SUCCESS]${NC} Найден Python $PY3_VERSION"
            return 0
        fi
    fi
    
    return 1
}

# Функция для установки Python 3.9
install_python39() {
    echo -e "${YELLOW}[WARNING]${NC} Python 3.7+ не найден. Установка Python 3.9..."
    
    # Определяем ОС
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian)
                echo "Установка Python 3.9 на Ubuntu/Debian..."
                apt-get update
                apt-get install -y software-properties-common
                add-apt-repository -y ppa:deadsnakes/ppa
                apt-get update
                apt-get install -y python3.9 python3.9-venv python3.9-distutils
                
                # Устанавливаем pip для python3.9
                curl -sS https://bootstrap.pypa.io/get-pip.py | python3.9
                
                # Создаем симлинки
                if command -v python3.9 &> /dev/null && ! command -v python3 &> /dev/null; then
                    ln -s /usr/bin/python3.9 /usr/bin/python3
                fi
                ;;
            centos|rhel|fedora)
                echo "Установка Python 3.9 на CentOS/RHEL/Fedora..."
                yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel wget make
                
                cd /tmp
                wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz
                tar xzf Python-3.9.18.tgz
                cd Python-3.9.18
                ./configure --enable-optimizations
                make altinstall
                
                # Устанавливаем pip
                curl -sS https://bootstrap.pypa.io/get-pip.py | python3.9
                ;;
            *)
                echo -e "${RED}[ERROR]${NC} Неподдерживаемая ОС"
                exit 1
                ;;
        esac
    else
        echo -e "${RED}[ERROR]${NC} Не удалось определить ОС"
        exit 1
    fi
    
    # Проверяем установку
    if command -v python3.9 &> /dev/null; then
        PYTHON_VERSION="python3.9"
        echo -e "${GREEN}[SUCCESS]${NC} Python 3.9 успешно установлен"
        return 0
    elif command -v python3 &> /dev/null; then
        PYTHON_VERSION="python3"
        echo -e "${GREEN}[SUCCESS]${NC} Python 3 успешно установлен"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Не удалось установить Python"
        exit 1
    fi
}

# Главная функция установки
main() {
    echo ""
    echo "==============================================="
    echo -e "${GREEN}Blockchain Module Auto-Installer${NC}"
    echo "==============================================="
    echo ""
    
    # Проверяем, запущен ли от root
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
    
    # Проверяем Python
    if ! check_python; then
        echo -e "${YELLOW}[WARNING]${NC} Python 3.7+ не найден"
        read -p "Установить Python 3.9 автоматически? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_python39
        else
            echo -e "${RED}[ERROR]${NC} Установите Python 3.9 вручную и повторите попытку"
            exit 1
        fi
    fi
    
    # Проверяем pip
    if ! command -v pip3 &> /dev/null; then
        echo -e "${YELLOW}[WARNING]${NC} pip3 не найден. Установка..."
        curl -sS https://bootstrap.pypa.io/get-pip.py | python3
    fi
    
    # Проверяем git
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}[WARNING]${NC} Git не найден. Установка..."
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case $ID in
                ubuntu|debian)
                    apt-get install -y git
                    ;;
                centos|rhel|fedora)
                    yum install -y git
                    ;;
            esac
        fi
    fi
    
    # Очищаем директорию установки
    clean_install_dir
    
    # Переходим в директорию установки
    cd "$INSTALL_DIR"
    
    # Клонируем репозиторий
    echo -e "${BLUE}[INFO]${NC} Клонирование репозитория..."
    git clone "$REPO_URL" .
    
    # Создаем виртуальное окружение
    echo -e "${BLUE}[INFO]${NC} Создание виртуального окружения..."
    $PYTHON_VERSION -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Обновляем pip
    echo -e "${BLUE}[INFO]${NC} Обновление pip..."
    pip install --upgrade pip
    
    # Устанавливаем зависимости
    echo -e "${BLUE}[INFO]${NC} Установка зависимостей Python..."
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        # Основные зависимости
        pip install aiohttp aiosqlite prometheus-client aiohttp-cors psutil
    fi
    
    # Устанавливаем модуль
    if [ -f "setup.py" ]; then
        pip install -e .
    fi
    
    # Создаем конфигурационную директорию
    mkdir -p "$INSTALL_DIR/configs"
    
    # Создаем конфигурационный файл, если его нет
    if [ ! -f "$INSTALL_DIR/configs/module_config.json" ]; then
        echo -e "${BLUE}[INFO]${NC} Создание конфигурационного файла..."
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
        echo -e "${YELLOW}[WARNING]${NC} Отредактируйте configs/module_config.json и добавьте ваш API ключ Nownodes!"
    fi
    
    # Создаем скрипт запуска
    echo -e "${BLUE}[INFO]${NC} Создание скрипта запуска..."
    cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/bash

cd "$(dirname "$0")"

# Проверяем виртуальное окружение
if [ ! -d "venv" ]; then
    echo "Ошибка: Виртуальное окружение не найдено"
    echo "Сначала выполните: python3 -m venv venv"
    exit 1
fi

# Активируем виртуальное окружение
source venv/bin/activate

# Запускаем модуль
python -m blockchain_module
EOF
    
    chmod +x "$INSTALL_DIR/start.sh"
    
    # Создаем скрипт CLI
    cat > "$INSTALL_DIR/cli.sh" << 'EOF'
#!/bin/bash

cd "$(dirname "$0")"

# Проверяем виртуальное окружение
if [ ! -d "venv" ]; then
    echo "Ошибка: Виртуальное окружение не найдено"
    exit 1
fi

# Активируем виртуальное окружение
source venv/bin/activate

# Запускаем CLI
python -m blockchain_module.cli "$@"
EOF
    
    chmod +x "$INSTALL_DIR/cli.sh"
    
    # Тестируем установку
    echo -e "${BLUE}[INFO]${NC} Тестирование установки..."
    if python -c "import blockchain_module" &> /dev/null; then
        echo -e "${GREEN}[SUCCESS]${NC} Модуль успешно импортирован"
    else
        echo -e "${YELLOW}[WARNING]${NC} Модуль не может быть импортирован (возможно, требуется настройка конфигурации)"
    fi
    
    # Выводим итоговую информацию
    echo ""
    echo "==============================================="
    echo -e "${GREEN}Установка завершена успешно!${NC}"
    echo "==============================================="
    echo ""
    echo -e "${BLUE}Директория установки:${NC} $INSTALL_DIR"
    echo ""
    echo -e "${BLUE}Команды запуска:${NC}"
    echo "  $INSTALL_DIR/start.sh    - запуск модуля"
    echo "  $INSTALL_DIR/cli.sh      - CLI интерфейс"
    echo ""
    echo -e "${BLUE}Настройка:${NC}"
    echo "  1. Отредактируйте файл конфигурации:"
    echo "     $INSTALL_DIR/configs/module_config.json"
    echo ""
    echo "  2. Добавьте ваш API ключ Nownodes в поле 'api_key'"
    echo ""
    echo -e "${BLUE}Запуск:${NC}"
    echo "  cd $INSTALL_DIR"
    echo "  ./start.sh"
    echo ""
    echo -e "${BLUE}Мониторинг (опционально):${NC}"
    echo "  Для запуска Docker мониторинга:"
    echo "  docker-compose up -d  (если docker-compose.yml присутствует)"
    echo ""
}

# Запускаем установку
main
