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
                    "configs/module_config.json")
                        create_module_config
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
    
    # Создаем критические файлы если их нет
    create_critical_files
    
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

# Создание module_config.json
create_module_config() {
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
    log_success "Файл module_config.json создан"
}

# Создание критических файлов
create_critical_files() {
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
    
    # Создаем базовый __init__.py для CLI если нет
    if [[ ! -f "blockchain_module/cli.py" ]]; then
        mkdir -p blockchain_module
        cat > blockchain_module/cli.py << 'EOF'
"""
CLI интерфейс для Blockchain Module
"""

import click
import asyncio
import logging
from typing import Optional

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
        # Проверяем базовые импорты
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
@click.option('--api-key', prompt=True, hide_input=True, help='API ключ Nownodes')
def setup(api_key):
    """Настроить API ключ"""
    try:
        from blockchain_module.config import BlockchainConfig
        BlockchainConfig.set_api_key(api_key)
        click.echo("✅ API ключ сохранен в конфигурации")
    except Exception as e:
        click.echo(f"❌ Ошибка: {e}", err=True)

@cli.command()
@click.option('--coin', required=True, help='Символ монеты (LTC, DOGE)')
@click.option('--address', required=True, help='Адрес для мониторинга')
@click.option('--user-id', default=1, help='ID пользователя')
def monitor_address(coin, address, user_id):
    """Добавить адрес для мониторинга"""
    click.echo(f"Добавление адреса {address} для мониторинга {coin}...")
    
    try:
        from blockchain_module.database import SQLiteDBManager
        
        async def add_address():
            db = SQLiteDBManager("data/blockchain_module.db")
            await db.initialize()
            success = await db.add_address_to_monitor(user_id, coin, address)
            await db.close()
            return success
        
        success = asyncio.run(add_address())
        
        if success:
            click.echo("✅ Адрес добавлен для мониторинга")
        else:
            click.echo("❌ Не удалось добавить адрес")
            
    except Exception as e:
        click.echo(f"❌ Ошибка: {e}", err=True)

@cli.command()
def interactive():
    """Запустить интерактивный режим"""
    click.echo("Запуск интерактивного режима...")
    
    # Простая интерактивная оболочка
    while True:
        click.echo("\nДоступные команды:")
        click.echo("1. Показать статус системы")
        click.echo("2. Настроить API ключ")
        click.echo("3. Добавить адрес для мониторинга")
        click.echo("4. Выйти")
        
        choice = click.prompt("Выберите опцию", type=int)
        
        if choice == 1:
            system_status()
        elif choice == 2:
            api_key = click.prompt("Введите API ключ Nownodes", hide_input=True)
            setup(api_key=api_key)
        elif choice == 3:
            coin = click.prompt("Символ монеты (LTC, DOGE)")
            address = click.prompt("Адрес для мониторинга")
            monitor_address(coin=coin, address=address)
        elif choice == 4:
            break
        else:
            click.echo("Неверный выбор")

if __name__ == "__main__":
    cli()
EOF
        log_success "Файл blockchain_module/cli.py создан"
    fi
}

# Проверка прав
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Скрипт запущен от root. Рекомендуется использовать обычного пользователя."
        read -p "Продолжить? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
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
    
    # Проверка pip
    if ! command -v pip3 &>/dev/null; then
        log_warn "pip3 не найден, устанавливаем..."
        if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
            apt-get update && apt-get install -y python3-pip
        elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* ]]; then
            yum install -y python3-pip
        elif [[ "$OS" == *"Fedora"* ]]; then
            dnf install -y python3-pip
        else
            log_error "Не удалось установить pip3"
            exit 1
        fi
    fi
    
    log_success "Системные проверки пройдены"
}

# Установка зависимостей системы
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
    
    # Добавляем текущего пользователя в группу docker
    if [[ $EUID -ne 0 ]]; then
        usermod -aG docker $USER
        log_warn "Необходимо перезайти в систему для применения изменений группы docker"
    fi
    
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
    
    log_success "Docker Compose установлен"
}

# Настройка директорий
setup_directories() {
    log_info "Настройка структуры директорий..."
    
    mkdir -p prometheus grafana
    
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

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

    log_success "Директории настроены"
}

# Установка Python зависимостей
install_python_deps() {
    log_info "Установка Python зависимостей..."
    
    # Обновляем pip
    pip3 install --upgrade pip
    
    # Устанавливаем зависимости
    if [[ -f "requirements.txt" ]]; then
        pip3 install -r requirements.txt
    else
        pip3 install \
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
    
    # Устанавливаем модуль
    if [[ -f "setup.py" ]]; then
        pip3 install -e .
    fi
    
    log_success "Python зависимости установлены"
}

# Тестирование установки
test_installation() {
    log_info "Тестирование установки..."
    
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
    if python3 -c "from blockchain_module.cli import cli; print('CLI доступен')" 2>/dev/null; then
        log_success "CLI интерфейс доступен"
    else
        log_warn "CLI интерфейс не доступен, но это не критично"
    fi
}

# Создание скрипта запуска
create_start_script() {
    log_info "Создание скриптов запуска..."
    
    # Скрипт запуска REST API
    cat > start_api.py << 'EOF'
#!/usr/bin/env python3
"""
Скрипт запуска REST API сервера
"""

import asyncio
import logging
import sys
import os

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

async def main():
    try:
        from blockchain_module.rest_api import run_rest_api
        
        port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
        
        logger.info(f"Запуск REST API на порту {port}")
        await run_rest_api(host='0.0.0.0', port=port)
        
    except KeyboardInterrupt:
        logger.info("Сервер остановлен")
    except Exception as e:
        logger.error(f"Ошибка: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
EOF
    chmod +x start_api.py
    
    # Скрипт управления
    cat > blockchain-manage << 'EOF'
#!/bin/bash
# Скрипт управления Blockchain Module

case "$1" in
    start)
        echo "Запуск системы..."
        docker-compose up -d
        python3 start_api.py &
        echo $! > .api_pid
        echo "✅ Система запущена"
        ;;
    stop)
        echo "Остановка системы..."
        docker-compose down
        if [[ -f ".api_pid" ]]; then
            kill $(cat .api_pid) 2>/dev/null
            rm .api_pid
        fi
        echo "✅ Система остановлена"
        ;;
    status)
        echo "Статус системы:"
        docker-compose ps
        if [[ -f ".api_pid" ]] && kill -0 $(cat .api_pid) 2>/dev/null; then
            echo "✅ REST API запущен (PID: $(cat .api_pid))"
        else
            echo "❌ REST API не запущен"
        fi
        ;;
    logs)
        docker-compose logs -f
        ;;
    *)
        echo "Использование: $0 {start|stop|status|logs}"
        exit 1
        ;;
esac
EOF
    chmod +x blockchain-manage
    
    log_success "Скрипты запуска созданы"
}

# Запуск Docker контейнеров
start_docker_containers() {
    log_info "Запуск Docker контейнеров..."
    
    if docker-compose up -d; then
        log_success "Docker контейнеры запущены"
        
        # Ждем запуска
        sleep 10
        
        # Проверяем
        docker-compose ps
    else
        log_error "Не удалось запустить Docker контейнеры"
        return 1
    fi
}

# Основная функция
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║      Blockchain Module Auto Installer v2.0.0    ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Шаг 0: Загрузка файлов
    download_missing_files
    
    # Шаг 1: Проверка системы
    check_system
    
    # Шаг 2: Установка системных зависимостей
    install_system_deps
    
    # Шаг 3: Установка Docker
    install_docker
    install_docker_compose
    
    # Шаг 4: Настройка директорий
    setup_directories
    
    # Шаг 5: Установка Python зависимостей
    install_python_deps
    
    # Шаг 6: Тестирование
    test_installation
    
    # Шаг 7: Создание скриптов запуска
    create_start_script
    
    # Шаг 8: Запуск Docker контейнеров
    start_docker_containers
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           УСТАНОВКА ЗАВЕРШЕНА!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "🎉 Blockchain Module успешно установлен!"
    echo ""
    echo "📊 Сервисы мониторинга:"
    echo "  • Grafana:       http://localhost:3000"
    echo "  • Prometheus:    http://localhost:9090"
    echo ""
    echo "🚀 Управление системой:"
    echo "  • ./blockchain-manage start   - Запустить систему"
    echo "  • ./blockchain-manage stop    - Остановить систему"
    echo "  • ./blockchain-manage status  - Статус системы"
    echo "  • ./blockchain-manage logs    - Просмотр логов"
    echo ""
    echo "🔧 Настройка:"
    echo "  1. Отредактируйте configs/module_config.json"
    echo "  2. Добавьте ваш API ключ Nownodes"
    echo "  3. Запустите: ./blockchain-manage start"
    echo ""
    echo "📚 Документация:"
    echo "  • blockchain-cli --help       - CLI интерфейс"
    echo "  • http://localhost:8080/api/v1/info - REST API документация"
    echo ""
}

# Запуск
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
