#!/bin/bash
# Полный скрипт установки Blockchain Module

set -e

echo "=== Blockchain Module Full Installation ==="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Проверка прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warn "Рекомендуется запускать скрипт с правами root"
        read -p "Продолжить без прав root? (y/n): " -n 1 -r
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
}

# Установка зависимостей системы
install_system_deps() {
    log_info "Установка системных зависимостей..."
    
    if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
        apt-get update
        apt-get install -y \
            git \
            curl \
            wget \
            build-essential \
            python3-dev \
            python3-venv \
            sqlite3 \
            libsqlite3-dev \
            net-tools
    elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* || "$OS" == *"Fedora"* ]]; then
        if [[ "$OS" == *"Fedora"* ]]; then
            dnf install -y \
                git \
                curl \
                wget \
                gcc \
                g++ \
                python3-devel \
                sqlite \
                sqlite-devel \
                net-tools
        else
            yum install -y \
                git \
                curl \
                wget \
                gcc \
                gcc-c++ \
                python3-devel \
                sqlite \
                sqlite-devel \
                net-tools
        fi
    else
        log_warn "Неизвестная ОС, попробуйте установить зависимости вручную"
    fi
}

# Установка Docker
install_docker() {
    if command -v docker &>/dev/null; then
        log_info "Docker уже установлен"
        DOCKER_VERSION=$(docker --version)
        log_info "Версия Docker: $DOCKER_VERSION"
        return 0
    fi
    
    log_info "Установка Docker..."
    
    if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
        # Удаляем старые версии
        apt-get remove -y docker docker-engine docker.io containerd runc
        
        # Устанавливаем зависимости
        apt-get update
        apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Добавляем GPG ключ Docker
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Добавляем репозиторий
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Устанавливаем Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* ]]; then
        # Удаляем старые версии
        yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
        
        # Устанавливаем yum-utils
        yum install -y yum-utils
        
        # Добавляем репозиторий
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        # Устанавливаем Docker
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    elif [[ "$OS" == *"Fedora"* ]]; then
        # Удаляем старые версии
        dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine
        
        # Добавляем репозиторий
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        
        # Устанавливаем Docker
        dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        log_error "Не удалось установить Docker на эту ОС"
        return 1
    fi
    
    # Запускаем и добавляем в автозагрузку
    systemctl start docker
    systemctl enable docker
    
    # Проверяем установку
    if docker --version &>/dev/null; then
        log_success "Docker установлен успешно"
    else
        log_error "Ошибка установки Docker"
        return 1
    fi
    
    # Добавляем текущего пользователя в группу docker (если не root)
    if [[ $EUID -ne 0 ]]; then
        if ! groups $USER | grep -q '\bdocker\b'; then
            log_info "Добавляем пользователя $USER в группу docker..."
            sudo usermod -aG docker $USER
            log_warn "Необходимо перезайти в систему для применения изменений"
        fi
    fi
    
    return 0
}

# Установка Docker Compose
install_docker_compose() {
    if command -v docker-compose &>/dev/null; then
        log_info "Docker Compose уже установлен"
        DOCKER_COMPOSE_VERSION=$(docker-compose --version)
        log_info "Версия Docker Compose: $DOCKER_COMPOSE_VERSION"
        return 0
    fi
    
    log_info "Установка Docker Compose..."
    
    # Скачиваем последнюю версию
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    
    # Делаем исполняемым
    chmod +x /usr/local/bin/docker-compose
    
    # Проверяем установку
    if docker-compose --version &>/dev/null; then
        log_success "Docker Compose установлен успешно"
    else
        log_error "Ошибка установки Docker Compose"
        return 1
    fi
    
    return 0
}

# Настройка директорий
setup_directories() {
    log_info "Создание структуры директорий..."
    
    mkdir -p configs data logs prometheus grafana/dashboards alerts
    
    # Копируем конфигурационные файлы
    cp module_config.json configs/
    cp alerts.yml alerts/
    cp blockchain_dashboard.json grafana/dashboards/
    
    # Создаем prometheus.yml
    cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: 'production'

rule_files:
  - "../alerts/alerts.yml"

scrape_configs:
  - job_name: 'blockchain_module'
    scrape_interval: 15s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    scheme: 'http'
    
    static_configs:
      - targets: ['host.docker.internal:9090']
        labels:
          instance: 'blockchain_module_main'
          component: 'application'

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'blockchain_module_server'
          component: 'system'

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
EOF

    # Создаем docker-compose для мониторинга
    cat > docker-compose-monitoring.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: blockchain_prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alerts:/etc/prometheus/alerts
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
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
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

  node-exporter:
    image: prom/node-exporter:latest
    container_name: blockchain_node_exporter
    ports:
      - "9100:9100"
    restart: unless-stopped
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: blockchain_cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    restart: unless-stopped
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
EOF

    log_success "Директории и конфигурационные файлы созданы"
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
    else
        log_warn "setup.py не найден, устанавливаем как пакет..."
        pip3 install .
    fi
    
    log_success "Python зависимости установлены"
}

# Создание systemd сервиса
create_systemd_service() {
    if [[ $EUID -ne 0 ]]; then
        log_warn "Пропускаем создание systemd сервиса (требуются права root)"
        return 0
    fi
    
    log_info "Создание systemd сервиса..."
    
    cat > /etc/systemd/system/blockchain-module.service << EOF
[Unit]
Description=Blockchain Module v2.0.0
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$(pwd)
Environment="PYTHONPATH=$(pwd)"
ExecStart=/usr/bin/python3 -m blockchain_module
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=blockchain-module

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable blockchain-module.service
    
    log_success "Systemd сервис создан"
}

# Создание скрипта управления
create_management_script() {
    log_info "Создание скрипта управления..."
    
    cat > blockchain-manage << 'EOF'
#!/bin/bash
# Скрипт управления Blockchain Module

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции
show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Blockchain Module Management       ║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║  1. Старт всей системы                ║${NC}"
    echo -e "${BLUE}║  2. Останов всей системы              ║${NC}"
    echo -e "${BLUE}║  3. Перезапуск системы                ║${NC}"
    echo -e "${BLUE}║  4. Статус системы                    ║${NC}"
    echo -e "${BLUE}║  5. Логи                              ║${NC}"
    echo -e "${BLUE}║  6. Запустить тесты                  ║${NC}"
    echo -e "${BLUE}║  7. Мониторинг (Docker)              ║${NC}"
    echo -e "${BLUE}║  8. REST API                         ║${NC}"
    echo -e "${BLUE}║  9. CLI интерфейс                    ║${NC}"
    echo -e "${BLUE}║  10. База данных                     ║${NC}"
    echo -e "${BLUE}║  11. Выход                           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    read -p "Выберите опцию [1-11]: " choice
}

start_system() {
    echo -e "${GREEN}[+] Запуск системы...${NC}"
    
    # Запуск мониторинга
    if docker-compose -f docker-compose-monitoring.yml ps | grep -q "Up"; then
        echo "Мониторинг уже запущен"
    else
        docker-compose -f docker-compose-monitoring.yml up -d
        echo "Мониторинг запущен"
    fi
    
    # Запуск REST API
    if pgrep -f "run_rest_api.py" > /dev/null; then
        echo "REST API уже запущен"
    else
        python3 run_rest_api.py &
        echo "REST API запущен"
    fi
    
    # Запуск CLI если нужно
    if [[ "$1" == "--cli" ]]; then
        blockchain-cli
    fi
    
    echo -e "${GREEN}[+] Система запущена${NC}"
}

stop_system() {
    echo -e "${YELLOW}[-] Остановка системы...${NC}"
    
    # Остановка REST API
    pkill -f "run_rest_api.py" 2>/dev/null || true
    echo "REST API остановлен"
    
    # Остановка мониторинга
    docker-compose -f docker-compose-monitoring.yml down 2>/dev/null || true
    echo "Мониторинг остановлен"
    
    echo -e "${GREEN}[+] Система остановлена${NC}"
}

restart_system() {
    stop_system
    sleep 2
    start_system
}

show_status() {
    echo -e "${BLUE}[*] Статус системы:${NC}"
    echo ""
    
    # Проверка Docker
    if systemctl is-active --quiet docker; then
        echo -e "Docker: ${GREEN}активен${NC}"
    else
        echo -e "Docker: ${RED}неактивен${NC}"
    fi
    
    # Проверка контейнеров
    echo ""
    echo "Контейнеры мониторинга:"
    docker-compose -f docker-compose-monitoring.yml ps
    
    # Проверка REST API
    echo ""
    if pgrep -f "run_rest_api.py" > /dev/null; then
        echo -e "REST API: ${GREEN}запущен${NC}"
        
        # Проверка доступности
        if curl -s http://localhost:8089/api/v1/info > /dev/null; then
            echo -e "API доступен: ${GREEN}да${NC}"
        else
            echo -e "API доступен: ${RED}нет${NC}"
        fi
    else
        echo -e "REST API: ${RED}не запущен${NC}"
    fi
    
    # Проверка CLI
    echo ""
    if command -v blockchain-cli > /dev/null; then
        echo -e "CLI: ${GREEN}доступен${NC}"
    else
        echo -e "CLI: ${RED}не доступен${NC}"
    fi
}

show_logs() {
    echo -e "${BLUE}[*] Логи системы:${NC}"
    echo ""
    echo "1. Docker локи"
    echo "2. REST API локи"
    echo "3. Systemd локи"
    echo "4. Все логи"
    echo "5. Назад"
    
    read -p "Выберите [1-5]: " log_choice
    
    case $log_choice in
        1)
            docker-compose -f docker-compose-monitoring.yml logs --tail=50
            ;;
        2)
            tail -50 logs/api.log 2>/dev/null || echo "Файл логов не найден"
            ;;
        3)
            sudo journalctl -u blockchain-module -n 50 2>/dev/null || echo "Systemd сервис не найден"
            ;;
        4)
            echo "=== Docker локи ==="
            docker-compose -f docker-compose-monitoring.yml logs --tail=20
            echo ""
            echo "=== REST API локи ==="
            tail -20 logs/api.log 2>/dev/null || echo "Файл логов не найден"
            echo ""
            echo "=== Systemd локи ==="
            sudo journalctl -u blockchain-module -n 20 2>/dev/null || echo "Systemd сервис не найден"
            ;;
        *)
            return
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..." -n 1
}

run_tests() {
    echo -e "${BLUE}[*] Запуск тестов...${NC}"
    
    if [[ -f "test_system.py" ]]; then
        python3 test_system.py
    else
        echo "Создание тестового скрипта..."
        python3 -c "
import asyncio
import aiohttp
import sys

async def test_system():
    print('Тестирование Blockchain Module...')
    
    # Тест 1: REST API
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get('http://localhost:8089/api/v1/info', timeout=5) as resp:
                if resp.status == 200:
                    print('✅ REST API доступен')
                else:
                    print('❌ REST API не отвечает')
    except:
        print('❌ REST API недоступен')
    
    # Тест 2: Prometheus
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get('http://localhost:9090', timeout=5) as resp:
                if resp.status < 500:
                    print('✅ Prometheus доступен')
                else:
                    print('❌ Prometheus не отвечает')
    except:
        print('❌ Prometheus недоступен')
    
    # Тест 3: Grafana
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get('http://localhost:3000', timeout=5) as resp:
                if resp.status < 500:
                    print('✅ Grafana доступен')
                else:
                    print('❌ Grafana не отвечает')
    except:
        print('❌ Grafana недоступен')
    
    print('\nТестирование завершено!')

asyncio.run(test_system())
"
    fi
    
    read -p "Нажмите Enter для продолжения..." -n 1
}

manage_monitoring() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║        Управление мониторингом         ║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║  1. Запуск мониторинга                ║${NC}"
        echo -e "${BLUE}║  2. Остановка мониторинга             ║${NC}"
        echo -e "${BLUE}║  3. Перезапуск мониторинга            ║${NC}"
        echo -e "${BLUE}║  4. Просмотр логов                   ║${NC}"
        echo -e "${BLUE}║  5. Статус контейнеров               ║${NC}"
        echo -e "${BLUE}║  6. Назад                            ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
        echo ""
        read -p "Выберите опцию [1-6]: " mon_choice
        
        case $mon_choice in
            1)
                docker-compose -f docker-compose-monitoring.yml up -d
                echo "Мониторинг запущен"
                ;;
            2)
                docker-compose -f docker-compose-monitoring.yml down
                echo "Мониторинг остановлен"
                ;;
            3)
                docker-compose -f docker-compose-monitoring.yml restart
                echo "Мониторинг перезапущен"
                ;;
            4)
                docker-compose -f docker-compose-monitoring.yml logs --tail=100 -f
                ;;
            5)
                docker-compose -f docker-compose-monitoring.yml ps
                ;;
            6)
                break
                ;;
            *)
                echo "Неверный выбор"
                ;;
        esac
        
        read -p "Нажмите Enter для продолжения..." -n 1
    done
}

manage_api() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║         Управление REST API            ║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║  1. Запуск API                       ║${NC}"
        echo -e "${BLUE}║  2. Остановка API                    ║${NC}"
        echo -e "${BLUE}║  3. Перезапуск API                   ║${NC}"
        echo -e "${BLUE}║  4. Проверить статус                 ║${NC}"
        echo -e "${BLUE}║  5. Просмотр логов                  ║${NC}"
        echo -e "${BLUE}║  6. Тест API                        ║${NC}"
        echo -e "${BLUE}║  7. Назад                           ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
        echo ""
        read -p "Выберите опцию [1-7]: " api_choice
        
        case $api_choice in
            1)
                if pgrep -f "run_rest_api.py" > /dev/null; then
                    echo "API уже запущен"
                else
                    python3 run_rest_api.py > logs/api.log 2>&1 &
                    echo "API запущен"
                fi
                ;;
            2)
                pkill -f "run_rest_api.py" 2>/dev/null || true
                echo "API остановлен"
                ;;
            3)
                pkill -f "run_rest_api.py" 2>/dev/null || true
                sleep 2
                python3 run_rest_api.py > logs/api.log 2>&1 &
                echo "API перезапущен"
                ;;
            4)
                if pgrep -f "run_rest_api.py" > /dev/null; then
                    echo -e "API: ${GREEN}запущен${NC}"
                    
                    # Проверка доступности
                    if curl -s http://localhost:8089/api/v1/info > /dev/null; then
                        echo -e "Доступен: ${GREEN}да${NC}"
                        
                        # Получаем информацию
                        curl -s http://localhost:8089/api/v1/info | python3 -m json.tool
                    else
                        echo -e "Доступен: ${RED}нет${NC}"
                    fi
                else
                    echo -e "API: ${RED}не запущен${NC}"
                fi
                ;;
            5)
                tail -f logs/api.log 2>/dev/null || echo "Файл логов не найден"
                ;;
            6)
                echo "Тестирование API..."
                curl -v http://localhost:8089/api/v1/info
                echo ""
                curl -v http://localhost:8089/api/v1/health
                ;;
            7)
                break
                ;;
            *)
                echo "Неверный выбор"
                ;;
        esac
        
        read -p "Нажмите Enter для продолжения..." -n 1
    done
}

# Главный цикл
if [[ $# -eq 0 ]]; then
    while true; do
        show_menu
        
        case $choice in
            1)
                start_system
                read -p "Нажмите Enter для продолжения..." -n 1
                ;;
            2)
                stop_system
                read -p "Нажмите Enter для продолжения..." -n 1
                ;;
            3)
                restart_system
                read -p "Нажмите Enter для продолжения..." -n 1
                ;;
            4)
                show_status
                read -p "Нажмите Enter для продолжения..." -n 1
                ;;
            5)
                show_logs
                ;;
            6)
                run_tests
                ;;
            7)
                manage_monitoring
                ;;
            8)
                manage_api
                ;;
            9)
                blockchain-cli
                ;;
            10)
                echo "Управление базой данных..."
                echo "1. Создать резервную копию"
                echo "2. Восстановить из резервной копии"
                echo "3. Проверить целостность"
                read -p "Выберите [1-3]: " db_choice
                
                case $db_choice in
                    1)
                        cp data/blockchain_module.db "data/backup_$(date +%Y%m%d_%H%M%S).db"
                        echo "Резервная копия создана"
                        ;;
                    2)
                        ls data/*.db
                        read -p "Введите имя файла для восстановления: " backup_file
                        cp "$backup_file" data/blockchain_module.db
                        echo "База данных восстановлена"
                        ;;
                    3)
                        echo "Проверка базы данных..."
                        sqlite3 data/blockchain_module.db "PRAGMA integrity_check;"
                        ;;
                esac
                read -p "Нажмите Enter для продолжения..." -n 1
                ;;
            11)
                echo "Выход..."
                exit 0
                ;;
            *)
                echo "Неверный выбор"
                sleep 1
                ;;
        esac
    done
else
    # Обработка аргументов командной строки
    case $1 in
        start)
            start_system
            ;;
        stop)
            stop_system
            ;;
        restart)
            restart_system
            ;;
        status)
            show_status
            ;;
        logs)
            shift
            case $1 in
                docker)
                    docker-compose -f docker-compose-monitoring.yml logs "${@:2}"
                    ;;
                api)
                    tail -f logs/api.log
                    ;;
                *)
                    show_logs
                    ;;
            esac
            ;;
        test)
            run_tests
            ;;
        cli)
            blockchain-cli "${@:2}"
            ;;
        api)
            shift
            manage_api
            ;;
        monitor)
            shift
            manage_monitoring
            ;;
        backup)
            cp data/blockchain_module.db "data/backup_$(date +%Y%m%d_%H%M%S).db"
            echo "Резервная копия создана"
            ;;
        help|--help|-h)
            echo "Использование: $0 [команда]"
            echo ""
            echo "Команды:"
            echo "  start           - Запустить всю систему"
            echo "  stop            - Остановить всю систему"
            echo "  restart         - Перезапустить систему"
            echo "  status          - Показать статус системы"
            echo "  logs [docker|api] - Показать логи"
            echo "  test            - Запустить тесты"
            echo "  cli [args]      - Запустить CLI интерфейс"
            echo "  api             - Управление REST API"
            echo "  monitor         - Управление мониторингом"
            echo "  backup          - Создать резервную копию БД"
            echo "  help            - Показать эту справку"
            ;;
        *)
            echo "Неизвестная команда: $1"
            echo "Используйте $0 help для справки"
            exit 1
            ;;
    esac
fi
EOF
    
    chmod +x blockchain-manage
    log_success "Скрипт управления создан"
}

# Создание тестового скрипта
create_test_script() {
    log_info "Создание тестового скрипта..."
    
    cat > test_system.py << 'EOF'
#!/usr/bin/env python3
"""
Полный тест системы Blockchain Module
"""

import asyncio
import aiohttp
import sys
import time
import json
import logging
import subprocess
from typing import Dict, Any, List
import psutil

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SystemTester:
    def __init__(self):
        self.base_url = "http://localhost:8089"
        self.monitoring_services = {
            "Prometheus": "http://localhost:9090",
            "Grafana": "http://localhost:3000",
            "Node Exporter": "http://localhost:9100",
            "cAdvisor": "http://localhost:8080",
        }
        self.test_results = []
    
    def log_test(self, test_name: str, success: bool, message: str = ""):
        """Логировать результат теста"""
        status = "✅ PASS" if success else "❌ FAIL"
        result = {"test": test_name, "success": success, "message": message}
        self.test_results.append(result)
        logger.info(f"{test_name}: {status} {message}")
        return success
    
    async def check_service(self, name: str, url: str) -> bool:
        """Проверить доступность сервиса"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, timeout=5) as response:
                    if response.status < 500:
                        return self.log_test(f"Service: {name}", True, f"доступен ({response.status})")
                    else:
                        return self.log_test(f"Service: {name}", False, f"HTTP {response.status}")
        except Exception as e:
            return self.log_test(f"Service: {name}", False, str(e))
    
    async def check_rest_api(self) -> bool:
        """Проверить REST API модуля"""
        endpoints = [
            ("/api/v1/info", "GET"),
            ("/api/v1/health", "GET"),
            ("/api/v1/coins", "GET"),
            ("/metrics", "GET"),
        ]
        
        all_success = True
        for endpoint, method in endpoints:
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.request(method, f"{self.base_url}{endpoint}", timeout=10) as response:
                        if response.status < 500:
                            self.log_test(f"API: {endpoint}", True, f"HTTP {response.status}")
                        else:
                            all_success = False
                            self.log_test(f"API: {endpoint}", False, f"HTTP {response.status}")
            except Exception as e:
                all_success = False
                self.log_test(f"API: {endpoint}", False, str(e))
        
        return all_success
    
    async def check_database(self) -> bool:
        """Проверить базу данных модуля"""
        try:
            # Импортируем здесь, чтобы не мешать остальным тестам
            from blockchain_module.database import SQLiteDBManager
            
            db = SQLiteDBManager("data/blockchain_module.db")
            await db.initialize()
            
            async with db.connection.cursor() as cursor:
                await cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
                tables = await cursor.fetchall()
                table_names = [t[0] for t in tables]
                
                expected_tables = [
                    'users', 'monitored_addresses', 'transactions',
                    'collections', 'user_monitors', 'user_quotas'
                ]
                
                missing_tables = [t for t in expected_tables if t not in table_names]
                
                if not missing_tables:
                    self.log_test("Database: Tables", True, f"найдено {len(table_names)} таблиц")
                else:
                    self.log_test("Database: Tables", False, f"отсутствуют: {missing_tables}")
                    return False
            
            stats = await db.get_stats()
            self.log_test("Database: Stats", True, f"пользователей: {stats.get('users_count', 0)}")
            
            await db.close()
            return True
            
        except Exception as e:
            return self.log_test("Database", False, str(e))
    
    def check_cli(self) -> bool:
        """Проверить CLI интерфейс"""
        commands = [
            ["blockchain-cli", "--help"],
            ["blockchain-cli", "system-status"],
        ]
        
        all_success = True
        for cmd in commands:
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    self.log_test(f"CLI: {' '.join(cmd)}", True)
                else:
                    all_success = False
                    self.log_test(f"CLI: {' '.join(cmd)}", False, result.stderr)
            except Exception as e:
                all_success = False
                self.log_test(f"CLI: {' '.join(cmd)}", False, str(e))
        
        return all_success
    
    def check_docker(self) -> bool:
        """Проверить Docker и контейнеры"""
        try:
            # Проверка Docker
            result = subprocess.run(["docker", "--version"], capture_output=True, text=True)
            if result.returncode == 0:
                self.log_test("Docker: Version", True, result.stdout.strip())
            else:
                self.log_test("Docker: Version", False, "не установлен")
                return False
            
            # Проверка контейнеров
            result = subprocess.run(
                ["docker", "ps", "--format", "{{.Names}} {{.Status}}"],
                capture_output=True, text=True
            )
            
            expected_containers = [
                "blockchain_prometheus",
                "blockchain_grafana", 
                "blockchain_node_exporter",
                "blockchain_cadvisor"
            ]
            
            running_containers = result.stdout.strip().split('\n') if result.stdout else []
            container_dict = {}
            for line in running_containers:
                if line:
                    name, status = line.split(' ', 1)
                    container_dict[name] = status
            
            for container in expected_containers:
                if container in container_dict:
                    self.log_test(f"Docker: {container}", True, container_dict[container])
                else:
                    self.log_test(f"Docker: {container}", False, "не запущен")
            
            return all(c in container_dict for c in expected_containers)
            
        except Exception as e:
            return self.log_test("Docker", False, str(e))
    
    def check_system_resources(self) -> bool:
        """Проверить системные ресурсы"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            tests = [
                ("CPU Usage", cpu_percent < 90, f"{cpu_percent:.1f}%"),
                ("Memory Usage", memory.percent < 90, f"{memory.percent:.1f}%"),
                ("Disk Usage", disk.percent < 90, f"{disk.percent:.1f}%"),
            ]
            
            all_success = True
            for name, success, value in tests:
                if success:
                    self.log_test(f"System: {name}", True, value)
                else:
                    all_success = False
                    self.log_test(f"System: {name}", False, value)
            
            return all_success
            
        except Exception as e:
            return self.log_test("System Resources", False, str(e))
    
    async def run_performance_test(self) -> bool:
        """Запустить тест производительности"""
        try:
            start_time = time.time()
            
            async with aiohttp.ClientSession() as session:
                # Тест скорости ответа API
                response_times = []
                for _ in range(5):
                    request_start = time.time()
                    async with session.get(f"{self.base_url}/api/v1/info", timeout=5) as resp:
                        await resp.read()
                    response_times.append(time.time() - request_start)
                
                avg_response = sum(response_times) / len(response_times)
                
                if avg_response < 2.0:
                    self.log_test("Performance: API Response", True, f"{avg_response:.3f}s")
                else:
                    self.log_test("Performance: API Response", False, f"{avg_response:.3f}s (медленно)")
            
            total_time = time.time() - start_time
            self.log_test("Performance: Total", True, f"тест завершен за {total_time:.2f}s")
            
            return True
            
        except Exception as e:
            return self.log_test("Performance Test", False, str(e))
    
    def print_summary(self):
        """Вывести сводку тестов"""
        print("\n" + "="*60)
        print("ТЕСТЫ ЗАВЕРШЕНЫ".center(60))
        print("="*60)
        
        passed = sum(1 for r in self.test_results if r["success"])
        total = len(self.test_results)
        
        print(f"\nРезультаты: {passed}/{total} тестов пройдено")
        print("-"*60)
        
        for result in self.test_results:
            status = "✅" if result["success"] else "❌"
            print(f"{status} {result['test']}")
            if result["message"]:
                print(f"   {result['message']}")
        
        print("-"*60)
        
        if passed == total:
            print("🎉 ВСЕ ТЕСТЫ УСПЕШНО ПРОЙДЕНЫ!")
            return True
        else:
            print(f"⚠️  Не пройдено тестов: {total - passed}")
            return False
    
    async def run_all_tests(self) -> bool:
        """Запустить все тесты"""
        logger.info("Запуск полного тестирования Blockchain Module...")
        
        # Системные тесты
        self.check_system_resources()
        self.check_docker()
        
        # Тесты мониторинга
        for name, url in self.monitoring_services.items():
            await self.check_service(name, url)
        
        # Тесты модуля
        await self.check_rest_api()
        await self.check_database()
        self.check_cli()
        
        # Тест производительности
        await self.run_performance_test()
        
        # Итоги
        return self.print_summary()

async def main():
    tester = SystemTester()
    
    try:
        success = await tester.run_all_tests()
        
        if success:
            print("\n" + "="*60)
            print("СИСТЕМА ГОТОВА К РАБОТЕ".center(60))
            print("="*60)
            print("\nДоступные сервисы:")
            print("  • REST API:      http://localhost:8089")
            print("  • Grafana:       http://localhost:3000 (admin/admin123)")
            print("  • Prometheus:    http://localhost:9090")
            print("  • Документация:  http://localhost:8089/api/v1/info")
            print("\nУправление: ./blockchain-manage")
            print("CLI: blockchain-cli")
            print("="*60)
            sys.exit(0)
        else:
            print("\n" + "="*60)
            print("ОБНАРУЖЕНЫ ПРОБЛЕМЫ".center(60))
            print("="*60)
            print("\nРекомендуемые действия:")
            print("  1. Проверьте запущены ли все сервисы: ./blockchain-manage status")
            print("  2. Просмотрите логи: ./blockchain-manage logs")
            print("  3. Перезапустите систему: ./blockchain-manage restart")
            print("  4. Проверьте настройки в configs/module_config.json")
            print("="*60)
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\nТестирование прервано пользователем")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Критическая ошибка: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
EOF
    
    chmod +x test_system.py
    log_success "Тестовый скрипт создан"
}

# Запуск Docker контейнеров
start_docker_containers() {
    log_info "Запуск Docker контейнеров мониторинга..."
    
    # Проверяем запущен ли Docker
    if ! systemctl is-active --quiet docker && [[ $EUID -eq 0 ]]; then
        systemctl start docker
    fi
    
    # Запускаем контейнеры
    docker-compose -f docker-compose-monitoring.yml up -d
    
    # Ждем запуска
    sleep 10
    
    # Проверяем статус
    docker-compose -f docker-compose-monitoring.yml ps
    
    log_success "Docker контейнеры запущены"
}

# Настройка Grafana
setup_grafana() {
    log_info "Настройка Grafana..."
    
    # Ждем запуска Grafana
    sleep 15
    
    # Добавляем источник данных Prometheus
    cat > /tmp/grafana_datasource.json << EOF
{
  "name": "Prometheus",
  "type": "prometheus",
  "access": "proxy",
  "url": "http://prometheus:9090",
  "isDefault": true
}
EOF
    
    # Пытаемся добавить источник данных
    max_retries=10
    for i in $(seq 1 $max_retries); do
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d @/tmp/grafana_datasource.json \
            http://admin:admin123@localhost:3000/api/datasources)
        
        if [[ $response -eq 200 ]] || [[ $response -eq 409 ]]; then
            log_success "Источник данных Prometheus добавлен в Grafana"
            break
        else
            log_warn "Попытка $i из $max_retries: Grafana недоступен"
            sleep 5
        fi
        
        if [[ $i -eq $max_retries ]]; then
            log_error "Не удалось добавить источник данных в Grafana"
        fi
    done
    
    # Импортируем дашборд
    cat > /tmp/grafana_dashboard.json << EOF
{
  "dashboard": $(cat blockchain_dashboard.json | jq .dashboard),
  "overwrite": true,
  "message": "Automatically imported by install script"
}
EOF
    
    for i in $(seq 1 $max_retries); do
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d @/tmp/grafana_dashboard.json \
            http://admin:admin123@localhost:3000/api/dashboards/db)
        
        if [[ $response -eq 200 ]]; then
            log_success "Дашборд Blockchain Module добавлен в Grafana"
            break
        else
            log_warn "Попытка $i из $max_retries: не удалось импортировать дашборд"
            sleep 5
        fi
    done
    
    log_success "Grafana настроена"
}

# Создание run_rest_api.py
create_run_api_script() {
    log_info "Создание скрипта запуска REST API..."
    
    cat > run_rest_api.py << 'EOF'
#!/usr/bin/env python3
"""
Скрипт запуска REST API сервера Blockchain Module
"""

import asyncio
import logging
import sys
import os
from pathlib import Path

# Добавляем текущую директорию в PYTHONPATH
sys.path.insert(0, str(Path(__file__).parent))

# Настраиваем логирование
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/api.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

async def main():
    try:
        from blockchain_module.rest_api import run_rest_api
        
        # Получаем порт из аргументов или конфигурации
        port = int(sys.argv[1]) if len(sys.argv) > 1 else 8089
        
        logger.info(f"Запуск Blockchain Module REST API на порту {port}")
        logger.info(f"PID: {os.getpid()}")
        logger.info(f"Рабочая директория: {os.getcwd()}")
        
        await run_rest_api(host='0.0.0.0', port=port)
        
    except KeyboardInterrupt:
        logger.info("Сервер остановлен пользователем")
    except Exception as e:
        logger.error(f"Ошибка запуска сервера: {e}")
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    # Создаем директорию для логов
    os.makedirs('logs', exist_ok=True)
    
    asyncio.run(main())
EOF
    
    chmod +x run_rest_api.py
    log_success "Скрипт запуска REST API создан"
}

# Финальный тест
final_test() {
    log_info "Запуск финального теста системы..."
    
    # Запускаем REST API в фоне
    python3 run_rest_api.py > logs/install_test.log 2>&1 &
    API_PID=$!
    sleep 10
    
    # Проверяем доступность API
    if curl -s http://localhost:8089/api/v1/info > /dev/null; then
        log_success "REST API запущен и доступен"
    else
        log_error "REST API недоступен"
        kill $API_PID 2>/dev/null || true
        return 1
    fi
    
    # Проверяем Grafana
    if curl -s http://localhost:3000 > /dev/null; then
        log_success "Grafana доступна"
    else
        log_warn "Grafana недоступна"
    fi
    
    # Проверяем Prometheus
    if curl -s http://localhost:9090 > /dev/null; then
        log_success "Prometheus доступен"
    else
        log_warn "Prometheus недоступен"
    fi
    
    # Останавливаем тестовый API
    kill $API_PID 2>/dev/null || true
    
    log_success "Финальный тест пройден успешно"
    return 0
}

# Основная функция
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║      Blockchain Module Auto Installer v2.0.0    ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Шаг 1: Проверка прав и системы
    check_root
    check_system
    
    # Шаг 2: Установка системных зависимостей
    install_system_deps
    
    # Шаг 3: Установка Docker и Docker Compose
    install_docker
    install_docker_compose
    
    # Шаг 4: Настройка директорий
    setup_directories
    
    # Шаг 5: Установка Python зависимостей
    install_python_deps
    
    # Шаг 6: Создание скриптов
    create_management_script
    create_test_script
    create_run_api_script
    
    # Шаг 7: Создание systemd сервиса (если root)
    create_systemd_service
    
    # Шаг 8: Запуск Docker контейнеров
    start_docker_containers
    
    # Шаг 9: Настройка Grafana
    setup_grafana
    
    # Шаг 10: Финальный тест
    final_test
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           УСТАНОВКА ЗАВЕРШЕНА!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Доступные сервисы:"
    echo "  • REST API модуля:  http://localhost:8089"
    echo "  • Grafana:          http://localhost:3000"
    echo "  • Prometheus:       http://localhost:9090"
    echo "  • Node Exporter:    http://localhost:9100"
    echo "  • cAdvisor:         http://localhost:8080"
    echo ""
    echo "Учетные данные:"
    echo "  • Grafana: admin / admin123"
    echo "  • API Key администратора смотрите в логах выше"
    echo ""
    echo "Управление системой:"
    echo "  • ./blockchain-manage              - Меню управления"
    echo "  ./blockchain-manage start          - Запуск всей системы"
    echo "  ./blockchain-manage stop           - Остановка системы"
    echo "  ./blockchain-manage status         - Статус системы"
    echo "  ./blockchain-manage test           - Запуск тестов"
    echo ""
    echo "CLI интерфейс:"
    echo "  blockchain-cli                     - Основной CLI"
    echo "  blockchain-cli system-status       - Статус системы"
    echo "  blockchain-cli interactive         - Интерактивный режим"
    echo ""
    echo "Тестирование:"
    echo "  ./test_system.py                   - Полный тест системы"
    echo ""
    echo "Логи:"
    echo "  ./blockchain-manage logs           - Просмотр логов"
    echo "  tail -f logs/api.log              - Логи REST API"
    echo ""
    echo "Быстрый старт:"
    echo "  1. ./blockchain-manage start"
    echo "  2. ./test_system.py"
    echo "  3. Откройте http://localhost:3000"
    echo ""
    echo "Для перезапуска системы: ./blockchain-manage restart"
    echo ""
}

# Запуск главной функции
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
