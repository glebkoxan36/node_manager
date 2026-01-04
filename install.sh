# Blockchain Module Auto Installer - Оптимизированный и исправленный

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
            log_warn "Не удалось создать виртуальное окружение"
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
    else
        log_error "Не удалось активировать виртуальное окружение"
        return 1
    fi
}

# Создание README.md если отсутствует
create_readme() {
    cat > README.md << 'EOF'
# Blockchain Module

Универсальный модуль для работы с криптовалютами через Nownodes API с мультипользовательской системой.

## Описание

Blockchain Module - это Python библиотека для работы с различными криптовалютами через API Nownodes.

## Установка

```bash
bash <(curl -s https://raw.githubusercontent.com/glebkoxan36/node_manager/main/install.sh)
