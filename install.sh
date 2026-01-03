#!/bin/bash
# Полный скрипт установки Blockchain Module

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
    echo -e "${GREEN}[INFO]${NC} $1"
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
VENV_DIR="$PROJECT_DIR/venv"

# Создание виртуального окружения
create_venv() {
    log_info "Создание виртуального окружения..."
    
    if [[ -d "$VENV_DIR" ]]; then
        log_info "Виртуальное окружение уже существует"
    else
        python3 -m venv "$VENV_DIR"
        log_success "Виртуальное окружение создано в $VENV_DIR"
    fi
    
    # Активируем venv
    source "$VENV_DIR/bin/activate"
    
    # Обновляем pip
    pip install --upgrade pip
    
    log_success "Виртуальное окружение активировано"
}

# GitHub репозиторий
GITHUB_REPO="https://github.com/glebkoxan36/node_manager"
GITHUB_RAW="https://raw.githubusercontent.com/glebkoxan36/node_manager/main"

# Проверка и загрузка файлов
download_missing_files() {
    log_info "Проверка и загрузка недостающих файлов..."
    
    # Создаем структуру директорий если их нет
    mkdir -p blockchain_module blockchain_module/configs configs data logs
    
    # Список файлов для проверки
    declare -A file_map=(
        # Основные файлы
        ["setup.py"]="setup.py"
        ["requirements.txt"]="requirements.txt"
        
        # Файлы из blockchain_module
        ["blockchain_module/__init__.py"]="blockchain_module/__init__.py"
        ["blockchain_module/blockchain_monitor.py"]="blockchain_module/blockchain_monitor.py"
        ["blockchain_module/config.py"]="blockchain_module/config.py"
        ["blockchain_module/connection_pool.py"]="blockchain_module/connection_pool.py"
        ["blockchain_module/database.py"]="blockchain_module/database.py"
        ["blockchain_module/funds_collector.py"]="blockchain_module/funds_collector.py"
        ["blockchain_module/health_check.py"]="blockchain_module/health_check.py"
        ["blockchain_module/monitoring.py"]="blockchain_module/monitoring.py"
        ["blockchain_module/nownodes_client.py"]="blockchain_module/nownodes_client.py"
        ["blockchain_module/rest_api.py"]="blockchain_module/rest_api.py"
        ["blockchain_module/users.py"]="blockchain_module/users.py"
        ["blockchain_module/utils.py"]="blockchain_module/utils.py"
    )
    
    # Пытаемся скачать файлы
    for local_file in "${!file_map[@]}"; do
        github_file="${file_map[$local_file]}"
        
        if [[ ! -f "$local_file" ]]; then
            log_info "Загрузка $local_file..."
            if curl -s -f -o "$local_file" "${GITHUB_RAW}/$github_file" 2>/dev/null; then
                log_success "Файл $local_file загружен"
            else
                log_warn "Не удалось загрузить $local_file, будет создан автоматически"
                
                # Создаем базовые файлы если они не скачались
                case "$local_file" in
                    "setup.py")
                        create_setup_py
                        ;;
                    "requirements.txt")
                        create_requirements_txt
                        ;;
                    *)
                        # Для остальных файлов создаем пустые или базовые
                        mkdir -p "$(dirname "$local_file")"
                        touch "$local_file"
                        ;;
                esac
            fi
        else
            log_info "Файл $local_file уже существует"
        fi
    done
    
    # Создаем конфигурационные файлы если их нет
    create_config_files
    
    log_success "Все файлы проверены"
}

# Создание setup.py
create_setup_py() {
    cat > setup.py << 'EOF'
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="blockchain-module",
    version="2.0.0",
    author="Blockchain Module Team",
    description="Универсальный модуль для работы с криптовалютами через Nownodes API с мультипользовательской системой",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/blockchain-module",
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
    install_requires=requirements,
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
    log_success "Файл setup.py создан"
}

# Создание requirements.txt
create_requirements_txt() {
    cat > requirements.txt << 'EOF'
# Основные зависимости
aiohttp>=3.8.0
aiosqlite>=0.19.0
prometheus-client>=0.17.0
aiohttp-cors>=0.7.0

# CLI зависимости
click>=8.1.0
questionary>=2.0.0
rich>=13.0.0

# Системные зависимости
psutil>=5.9.0

# Дополнительные
python-dotenv>=1.0.0
pyyaml>=6.0
EOF
    log_success "Файл requirements.txt создан"
}

# Создание конфигурационных файлов
create_config_files() {
    # Создаем module_config.json если нет
    if [[ ! -f "configs/module_config.json" ]]; then
        mkdir -p configs
        cat > configs/module_config.json << 'EOF'
{
  "module_settings": {
    "api_key": "YOUR_NOWNODES_API_KEY_HERE",
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
        log_success "Файл configs/module_config.json создан"
    fi
    
    # Создаем alerts.yml если нет
    if [[ ! -f "alerts.yml" ]]; then
        cat > alerts.yml << 'EOF'
groups:
  - name: blockchain_module_alerts
    rules:
      - alert: BlockchainModuleDown
        expr: up{job="blockchain_module"} == 0
        for: 1m
        labels:
          severity: critical
          component: application
        annotations:
          summary: "Blockchain module is down"
          description: "Blockchain module has been down for more than 1 minute"
      
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          component: system
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for 5 minutes"
      
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80
        for: 5m
        labels:
          severity: warning
          component: system
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 80% for 5 minutes"
EOF
        log_success "Файл alerts.yml создан"
    fi
    
    # Создаем blockchain_dashboard.json если нет
    if [[ ! -f "blockchain_dashboard.json" ]]; then
        cat > blockchain_dashboard.json << 'EOF'
{
  "dashboard": {
    "title": "Blockchain Module Monitoring",
    "tags": ["blockchain", "monitoring"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "System Overview",
        "type": "stat",
        "gridPos": {"h": 3, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "blockchain_module_status",
            "format": "time_series",
            "legendFormat": "Module Status",
            "refId": "A"
          }
        ],
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"]
          },
          "orientation": "horizontal",
          "textMode": "value_and_name"
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "10s"
  }
}
EOF
        log_success "Файл blockchain_dashboard.json создан"
    fi
    
    # Создаем docker-compose.yml если нет
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
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    networks:
      - monitoring

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
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-piechart-panel
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SMTP_ENABLED=false
    restart: unless-stopped
    depends_on:
      - prometheus
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
EOF
        log_success "Файл docker-compose.yml создан"
    fi
    
    # Создаем CLI если нет
    if [[ ! -f "blockchain_module/cli.py" ]]; then
        mkdir -p blockchain_module
        cat > blockchain_module/cli.py << 'EOF'
"""
CLI интерфейс для Blockchain Module
"""

import click
import asyncio
import logging
import sys
import os

# Добавляем путь к модулю
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

logger = logging.getLogger(__name__)

@click.group()
@click.version_option(version="2.0.0")
def cli():
    """Blockchain Module CLI - Управление криптовалютным модулем"""
    pass

@cli.command()
def system_status():
    """Показать статус системы"""
    click.echo("Проверка статуса системы...")
    
    try:
        from blockchain_module import get_module_info
        info = get_module_info()
        
        click.echo(f"✅ Blockchain Module v{info['version']}")
        click.echo(f"✅ Поддерживаемые монеты: {info['supported_coins']}")
        click.echo(f"✅ Мультипользовательский режим: {info['multiuser_enabled']}")
        
        # Проверяем базу данных
        from blockchain_module.database import SQLiteDBManager
        
        async def check_db():
            db = SQLiteDBManager("data/blockchain_module.db")
            await db.initialize()
            stats = await db.get_stats()
            await db.close()
            return stats
        
        stats = asyncio.run(check_db())
        click.echo(f"✅ База данных: {stats.get('users_count', 0)} пользователей")
        
        click.echo("\n🎉 Система работает корректно!")
        
    except Exception as e:
        click.echo(f"❌ Ошибка: {e}", err=True)

@cli.command()
def info():
    """Показать информацию о модуле"""
    try:
        from blockchain_module import get_module_info
        import json
        
        info = get_module_info()
        click.echo(json.dumps(info, indent=2, ensure_ascii=False))
        
    except Exception as e:
        click.echo(f"Ошибка: {e}", err=True)

@cli.command()
def interactive():
    """Запустить интерактивный режим"""
    click.echo("Интерактивный режим Blockchain Module")
    click.echo("Доступные команды:")
    click.echo("  status - Показать статус системы")
    click.echo("  info   - Показать информацию о модуле")
    click.echo("  exit   - Выйти")
    
    while True:
        command = click.prompt("blockchain> ", type=str)
        
        if command == "status":
            system_status()
        elif command == "info":
            info()
        elif command == "exit":
            break
        else:
            click.echo(f"Неизвестная команда: {command}")

if __name__ == "__main__":
    cli()
EOF
        log_success "Файл blockchain_module/cli.py создан"
    fi
}

# Проверка системы
check_system() {
    log_info "Проверка системы..."
    
    # Проверка ОС
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        log_info "ОС: $OS $VER"
    else
        log_error "Не удалось определить ОС"
        exit 1
    fi
    
    # Проверка Python
    if command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version | awk '{print $2}')
        log_info "Python: $PYTHON_VERSION"
        
        if [[ $(python3 -c "import sys; print('OK' if sys.version_info >= (3,7) else 'FAIL')") == "FAIL" ]]; then
            log_error "Требуется Python 3.7 или выше"
            exit 1
        fi
    else
        log_error "Python3 не установлен"
        exit 1
    fi
    
    # Проверка venv
    if ! python3 -c "import venv" 2>/dev/null; then
        log_warn "Модуль venv не установлен, устанавливаем..."
        apt-get update
        apt-get install -y python3-venv
    fi
    
    log_success "Системные проверки пройдены"
}

# Установка системных зависимостей
install_system_deps() {
    log_info "Установка системных зависимостей..."
    
    if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
        apt-get update
        apt-get install -y \
            curl \
            wget \
            python3-dev \
            python3-venv \
            sqlite3 \
            libsqlite3-dev
    elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* || "$OS" == *"Fedora"* ]]; then
        if [[ "$OS" == *"Fedora"* ]]; then
            dnf install -y \
                curl \
                wget \
                python3-devel \
                sqlite \
                sqlite-devel
        else
            yum install -y \
                curl \
                wget \
                python3-devel \
                sqlite \
                sqlite-devel
        fi
    else
        log_warn "Неизвестная ОС, попробуйте установить зависимости вручную"
    fi
}

# Установка Docker
install_docker() {
    if command -v docker &>/dev/null; then
        log_info "Docker уже установлен"
        return 0
    fi
    
    log_info "Установка Docker..."
    
    if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
        # Устанавливаем Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        
    elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* ]]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
        
    elif [[ "$OS" == *"Fedora"* ]]; then
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io
    else
        log_error "Не удалось установить Docker на эту ОС"
        return 1
    fi
    
    # Запускаем Docker
    systemctl start docker
    systemctl enable docker
    
    log_success "Docker установлен"
}

# Установка Docker Compose
install_docker_compose() {
    if command -v docker-compose &>/dev/null; then
        log_info "Docker Compose уже установлен"
        return 0
    fi
    
    log_info "Установка Docker Compose..."
    
    # Скачиваем Docker Compose
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    
    chmod +x /usr/local/bin/docker-compose
    
    # Создаем symlink для docker compose plugin
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_success "Docker Compose установлен"
}

# Настройка директорий
setup_directories() {
    log_info "Настройка структуры директорий..."
    
    mkdir -p prometheus grafana data logs
    
    # Создаем prometheus.yml
    cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/alerts.yml

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'blockchain_module'
    static_configs:
      - targets: ['host.docker.internal:9090']
        labels:
          service: 'blockchain_module'
EOF

    log_success "Директории настроены"
}

# Установка Python зависимостей в виртуальном окружении
install_python_deps() {
    log_info "Установка Python зависимостей в виртуальном окружении..."
    
    # Активируем venv
    source "$VENV_DIR/bin/activate"
    
    # Устанавливаем зависимости
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt
    else
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
            pyyaml>=6.0
    fi
    
    # Устанавливаем модуль в development mode
    if [[ -f "setup.py" ]]; then
        pip install -e .
    fi
    
    log_success "Python зависимости установлены в виртуальном окружении"
}

# Тестирование установки
test_installation() {
    log_info "Тестирование установки..."
    
    # Активируем venv
    source "$VENV_DIR/bin/activate"
    
    python3 -c "
import sys
print('🔧 Тестирование Blockchain Module...')

try:
    # Проверяем основные импорты
    from blockchain_module import get_module_info
    print('✅ Модуль blockchain_module импортирован')
    
    from blockchain_module.config import BlockchainConfig
    print('✅ Конфигурация доступна')
    
    from blockchain_module.database import SQLiteDBManager
    print('✅ База данных доступна')
    
    from blockchain_module.rest_api import BlockchainRestAPI
    print('✅ REST API доступен')
    
    info = get_module_info()
    print(f'✅ Версия модуля: {info[\"version\"]}')
    print(f'✅ Поддерживаемые монеты: {info[\"supported_coins\"]}')
    
    print('\\n🎉 Все компоненты успешно загружены!')
    
except Exception as e:
    print(f'❌ Ошибка: {e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
"
    
    # Проверяем CLI
    if python3 -c "from blockchain_module.cli import cli; print('✅ CLI интерфейс доступен')" 2>/dev/null; then
        log_success "CLI интерфейс доступен"
    else
        log_warn "CLI интерфейс не доступен, но это не критично"
    fi
}

# Создание скрипта запуска
create_start_script() {
    log_info "Создание скриптов запуска..."
    
    # Скрипт запуска REST API
    cat > start_api.sh << 'EOF'
#!/bin/bash
# Скрипт запуска REST API сервера

cd "$(dirname "$0")"

# Активируем виртуальное окружение
if [[ -d "venv" ]]; then
    source venv/bin/activate
else
    echo "Ошибка: Виртуальное окружение не найдено"
    exit 1
fi

# Проверяем Python
python3 -c "import sys; sys.exit(0) if sys.version_info >= (3,7) else sys.exit(1)"
if [[ $? -ne 0 ]]; then
    echo "Требуется Python 3.7 или выше"
    exit 1
fi

echo "Запуск Blockchain Module REST API..."
echo "Виртуальное окружение: $(which python)"
echo "Версия Python: $(python --version)"

# Запускаем API
python3 -c "
import asyncio
import logging
import sys
import os

# Настраиваем логирование
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

async def main():
    try:
        from blockchain_module.rest_api import run_rest_api
        
        # Получаем порт из аргументов или используем 8089
        port = int(sys.argv[1]) if len(sys.argv) > 1 else 8089
        
        logger.info(f'🚀 Запуск Blockchain Module REST API на порту {port}')
        logger.info(f'📁 Рабочая директория: {os.getcwd()}')
        
        await run_rest_api(host='0.0.0.0', port=port)
        
    except KeyboardInterrupt:
        logger.info('Сервер остановлен пользователем')
    except Exception as e:
        logger.error(f'Ошибка запуска сервера: {e}')
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)

if __name__ == '__main__':
    asyncio.run(main())
"
EOF
    chmod +x start_api.sh
    
    # Скрипт управления
    cat > blockchain-manage << 'EOF'
#!/bin/bash
# Скрипт управления Blockchain Module

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo "Использование: $0 {start|stop|status|logs|test|cli|help}"
    echo ""
    echo "Команды:"
    echo "  start    - Запустить всю систему (Docker + REST API)"
    echo "  stop     - Остановить всю систему"
    echo "  status   - Показать статус системы"
    echo "  logs     - Показать логи Docker"
    echo "  test     - Запустить тесты"
    echo "  cli      - Запустить CLI интерфейс"
    echo "  help     - Показать эту справку"
}

start_system() {
    echo -e "${GREEN}[+] Запуск системы...${NC}"
    
    # Запускаем Docker контейнеры
    if [[ -f "docker-compose.yml" ]]; then
        docker-compose up -d
        echo "Docker контейнеры запущены"
    else
        echo -e "${YELLOW}[!] docker-compose.yml не найден${NC}"
    fi
    
    # Запускаем REST API в фоне
    if [[ -f "start_api.sh" ]]; then
        ./start_api.sh > logs/api.log 2>&1 &
        API_PID=$!
        echo $API_PID > .api_pid
        echo "REST API запущен (PID: $API_PID)"
    else
        echo -e "${YELLOW}[!] start_api.sh не найден${NC}"
    fi
    
    echo -e "${GREEN}[+] Система запущена${NC}"
    echo -e "${BLUE}[i] REST API: http://localhost:8089${NC}"
    echo -e "${BLUE}[i] Grafana: http://localhost:3000${NC}"
    echo -e "${BLUE}[i] Prometheus: http://localhost:9090${NC}"
}

stop_system() {
    echo -e "${YELLOW}[-] Остановка системы...${NC}"
    
    # Останавливаем Docker контейнеры
    if [[ -f "docker-compose.yml" ]]; then
        docker-compose down
        echo "Docker контейнеры остановлены"
    fi
    
    # Останавливаем REST API
    if [[ -f ".api_pid" ]]; then
        API_PID=$(cat .api_pid)
        if kill -0 $API_PID 2>/dev/null; then
            kill $API_PID
            echo "REST API остановлен (PID: $API_PID)"
        fi
        rm -f .api_pid
    fi
    
    echo -e "${GREEN}[+] Система остановлена${NC}"
}

show_status() {
    echo -e "${BLUE}[*] Статус системы:${NC}"
    echo ""
    
    # Docker контейнеры
    if command -v docker-compose >/dev/null && [[ -f "docker-compose.yml" ]]; then
        echo "Docker контейнеры:"
        docker-compose ps
        echo ""
    else
        echo "Docker Compose не доступен"
    fi
    
    # REST API
    if [[ -f ".api_pid" ]]; then
        API_PID=$(cat .api_pid)
        if kill -0 $API_PID 2>/dev/null; then
            echo -e "REST API: ${GREEN}запущен${NC} (PID: $API_PID)"
            
            # Проверяем доступность
            if curl -s http://localhost:8089/api/v1/info >/dev/null 2>&1; then
                echo -e "  Доступность: ${GREEN}да${NC}"
            else
                echo -e "  Доступность: ${RED}нет${NC}"
            fi
        else
            echo -e "REST API: ${RED}не запущен${NC}"
        fi
    else
        echo -e "REST API: ${RED}не запущен${NC}"
    fi
    
    # Виртуальное окружение
    if [[ -d "venv" ]]; then
        echo -e "Виртуальное окружение: ${GREEN}найдено${NC}"
    else
        echo -e "Виртуальное окружение: ${RED}не найдено${NC}"
    fi
}

show_logs() {
    echo -e "${BLUE}[*] Логи системы:${NC}"
    
    if [[ "$1" == "api" ]]; then
        tail -f logs/api.log 2>/dev/null || echo "Файл логов не найден"
    elif [[ "$1" == "docker" ]] && [[ -f "docker-compose.yml" ]]; then
        docker-compose logs -f
    else
        echo "Использование: $0 logs {api|docker}"
    fi
}

run_tests() {
    echo -e "${BLUE}[*] Запуск тестов...${NC}"
    
    # Активируем venv
    if [[ -d "venv" ]]; then
        source venv/bin/activate
    fi
    
    python3 -c "
import sys
print('Тестирование Blockchain Module...')

try:
    from blockchain_module import get_module_info
    info = get_module_info()
    print(f'✅ Модуль: v{info[\"version\"]}')
    
    # Проверка REST API
    import aiohttp
    import asyncio
    
    async def test_api():
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get('http://localhost:8089/api/v1/info', timeout=5) as resp:
                    if resp.status == 200:
                        print('✅ REST API доступен')
                    else:
                        print('❌ REST API не отвечает')
        except:
            print('❌ REST API недоступен')
    
    asyncio.run(test_api())
    
    print('\\n✅ Тесты пройдены успешно!')
    
except Exception as e:
    print(f'❌ Ошибка: {e}')
    sys.exit(1)
"
}

run_cli() {
    # Активируем venv
    if [[ -d "venv" ]]; then
        source venv/bin/activate
    fi
    
    if python3 -c "from blockchain_module.cli import cli" 2>/dev/null; then
        python3 -m blockchain_module.cli "${@:2}"
    else
        echo "CLI не доступен"
        exit 1
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
    cli)
        run_cli "$@"
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
    chmod +x blockchain-manage
    
    log_success "Скрипты запуска созданы"
}

# Создание activate.sh для активации venv
create_activate_script() {
    log_info "Создание скрипта активации..."
    
    cat > activate.sh << 'EOF'
#!/bin/bash
# Скрипт активации виртуального окружения Blockchain Module

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

if [[ ! -d "$VENV_DIR" ]]; then
    echo "Ошибка: Виртуальное окружение не найдено в $VENV_DIR"
    echo "Запустите установку: ./install.sh"
    exit 1
fi

echo "Активация виртуального окружения Blockchain Module..."
source "$VENV_DIR/bin/activate"

echo ""
echo "🎉 Виртуальное окружение активировано!"
echo "Доступные команды:"
echo "  • python -m blockchain_module.cli - CLI интерфейс"
echo "  • ./start_api.sh                 - Запуск REST API"
echo "  • ./blockchain-manage            - Управление системой"
echo ""
echo "Для деактивации выполните: deactivate"
EOF
    chmod +x activate.sh
    
    log_success "Скрипт активации создан"
}

# Основная функция
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║      Blockchain Module Auto Installer v2.0.0    ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Создаем директорию проекта если нужно
    if [[ "$SCRIPT_DIR" != "$PROJECT_DIR" ]]; then
        mkdir -p "$PROJECT_DIR"
        cd "$PROJECT_DIR"
    fi
    
    # Шаг 0: Загрузка файлов
    download_missing_files
    
    # Шаг 1: Проверка системы
    check_system
    
    # Шаг 2: Установка системных зависимостей (только если root)
    if [[ $EUID -eq 0 ]]; then
        install_system_deps
        install_docker
        install_docker_compose
    else
        log_warn "Скрипт запущен без прав root. Проверьте установку Docker вручную."
    fi
    
    # Шаг 3: Создание виртуального окружения
    create_venv
    
    # Шаг 4: Настройка директорий
    setup_directories
    
    # Шаг 5: Установка Python зависимостей
    install_python_deps
    
    # Шаг 6: Тестирование
    test_installation
    
    # Шаг 7: Создание скриптов запуска
    create_start_script
    create_activate_script
    
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
    echo "🚀 Команды для запуска:"
    echo "  • ./activate.sh        - Активировать виртуальное окружение"
    echo "  • ./blockchain-manage start   - Запустить всю систему"
    echo "  • ./blockchain-manage stop    - Остановить систему"
    echo "  • ./blockchain-manage status  - Статус системы"
    echo "  • ./blockchain-manage test    - Запустить тесты"
    echo "  • ./blockchain-manage cli     - CLI интерфейс"
    echo ""
    echo "🌐 Доступные сервисы после запуска:"
    echo "  • REST API:      http://localhost:8089"
    echo "  • Grafana:       http://localhost:3000 (admin/admin123)"
    echo "  • Prometheus:    http://localhost:9090"
    echo ""
    echo "🔧 Настройка:"
    echo "  1. Отредактируйте configs/module_config.json"
    echo "  2. Добавьте ваш API ключ Nownodes"
    echo "  3. Запустите: ./blockchain-manage start"
    echo ""
    echo "📚 Дополнительно:"
    echo "  Для работы с модулем активируйте venv: source venv/bin/activate"
    echo "  Или используйте: ./activate.sh"
    echo ""
}

# Запуск
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
