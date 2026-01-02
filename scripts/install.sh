#!/bin/bash
# Blockchain Module - Complete Installation Script
# Version: 2.0.0

set -e  # Exit on error

echo "========================================="
echo "  Blockchain Module Installation v2.0.0"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run as root. Run as a normal user."
    exit 1
fi

# Step 1: Check system requirements
print_info "Step 1: Checking system requirements..."

# Check Python
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3.7+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
print_success "Python $PYTHON_VERSION detected"

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose."
    exit 1
fi

print_success "Docker $(docker --version) detected"
print_success "Docker Compose $(docker-compose --version) detected"

# Check ports availability
print_info "Checking port availability..."
PORTS=(8080 8081 8082 9090 3000 9093 9100)
for port in "${PORTS[@]}"; do
    if ss -tuln | grep -q ":$port "; then
        print_warning "Port $port is already in use"
    fi
done

# Step 2: Create project directory
print_info "Step 2: Setting up project directory..."
PROJECT_DIR="$HOME/blockchain-module"
if [ ! -d "$PROJECT_DIR" ]; then
    mkdir -p "$PROJECT_DIR"
    print_success "Created project directory: $PROJECT_DIR"
else
    print_warning "Project directory already exists: $PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# Step 3: Clone repository or copy files
print_info "Step 3: Getting source code..."
if [ -d ".git" ]; then
    print_info "Updating existing repository..."
    git pull
else
    if [ -f "requirements.txt" ]; then
        print_info "Source code already present"
    else
        print_error "Please place the source code in $PROJECT_DIR"
        print_info "Either clone the repository or copy all files manually"
        exit 1
    fi
fi

# Step 4: Create virtual environment
print_info "Step 4: Setting up Python virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    print_success "Virtual environment created"
fi

# Activate virtual environment
source venv/bin/activate

# Step 5: Install Python dependencies
print_info "Step 5: Installing Python dependencies..."
if [ -f "requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r requirements.txt
    pip install -e .
    print_success "Python dependencies installed"
else
    print_error "requirements.txt not found"
    exit 1
fi

# Step 6: Create necessary directories
print_info "Step 6: Creating directories..."
mkdir -p {configs,data,logs,prometheus_data,grafana_data,alertmanager_data}

# Step 7: Copy configuration files
print_info "Step 7: Setting up configuration..."
if [ ! -f "configs/module_config.json" ]; then
    if [ -f "module_config.json" ]; then
        cp module_config.json configs/module_config.json
        print_success "Configuration copied"
    else
        print_warning "Creating default configuration..."
        cat > configs/module_config.json << 'EOF'
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
fi

# Create .env file
if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
# Blockchain Module Environment Variables
NOWNODES_API_KEY=your_api_key_here

# Docker Compose variables
COMPOSE_PROJECT_NAME=blockchain-module
PROMETHEUS_DATA=./prometheus_data
GRAFANA_DATA=./grafana_data
ALERTMANAGER_DATA=./alertmanager_data
EOF
    print_warning "Created .env file. Please update NOWNODES_API_KEY"
fi

# Step 8: Setup Docker monitoring stack
print_info "Step 8: Setting up Docker monitoring stack..."

# Create necessary Docker directories
mkdir -p docker/{prometheus,grafana/provisioning/dashboards,grafana/provisioning/datasources,alertmanager}

# Create Prometheus config
cat > docker/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alerts.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  - job_name: 'blockchain_module'
    static_configs:
      - targets: ['host.docker.internal:9090']
        labels:
          service: 'blockchain_module'

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

cat > docker/prometheus/alerts.yml << 'EOF'
groups:
  - name: blockchain_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(blockchain_module_api_errors_total[5m]) / rate(blockchain_module_api_requests_total[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate on {{ $labels.coin }}"
          description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.coin }}"

      - alert: WebSocketDisconnected
        expr: blockchain_module_websocket_connections == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "WebSocket disconnected for {{ $labels.coin }}"
          description: "WebSocket has been disconnected for 1 minute"

      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(blockchain_module_api_request_duration_seconds_bucket[5m])) > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High response time for {{ $labels.coin }}"
          description: "95th percentile response time is {{ $value }}s"
EOF

# Create Alertmanager config
cat > docker/alertmanager/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@blockchain-module.com'
  smtp_auth_username: 'your_email@gmail.com'
  smtp_auth_password: 'your_password'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email'

receivers:
  - name: 'email'
    email_configs:
      - to: 'admin@example.com'
EOF

# Create Grafana datasource
cat > docker/grafana/provisioning/datasources/datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

# Create Grafana dashboard config
cat > docker/grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Copy blockchain dashboard
if [ -f "blockchain_dashboard.json" ]; then
    cp blockchain_dashboard.json docker/grafana/dashboards/
fi

# Step 9: Start monitoring stack
print_info "Step 9: Starting Docker monitoring stack..."
docker-compose up -d

# Wait for services to start
print_info "Waiting for services to initialize..."
sleep 10

# Step 10: Initialize the system
print_info "Step 10: Initializing Blockchain Module..."

# Initialize database
python3 -c "
import asyncio
import sys

async def initialize_system():
    try:
        from blockchain_module.database import SQLiteDBManager
        from blockchain_module.users import UserManager
        
        # Initialize database
        db = SQLiteDBManager('data/blockchain_module.db')
        await db.initialize()
        
        # Initialize user manager
        user_manager = UserManager('data/blockchain_module.db')
        await user_manager.initialize()
        
        print('✅ Database and user system initialized')
        
        # Get stats
        stats = await db.get_stats()
        print(f'📊 Database stats: {stats}')
        
        await db.close()
        await user_manager.close()
        
    except Exception as e:
        print(f'❌ Initialization error: {e}')
        sys.exit(1)

asyncio.run(initialize_system())
"

# Step 11: Run system tests
print_info "Step 11: Running system tests..."

# Test 1: Module import
python3 -c "
try:
    from blockchain_module import get_module_info
    info = get_module_info()
    print('✅ Module import successful')
    print(f'   Version: {info[\"version\"]}')
    print(f'   Supported coins: {info[\"supported_coins\"]}')
except Exception as e:
    print(f'❌ Module import failed: {e}')
"

# Test 2: CLI test
python3 -c "
try:
    from blockchain_module.cli import AdminCLI
    print('✅ CLI module available')
except ImportError as e:
    print('⚠️  CLI module not available (optional)')
except Exception as e:
    print(f'⚠️  CLI check: {e}')
"

# Test 3: REST API test
python3 -c "
try:
    from blockchain_module.rest_api import create_rest_api
    print('✅ REST API module available')
except ImportError as e:
    print('⚠️  REST API module not available (optional)')
except Exception as e:
    print(f'⚠️  REST API check: {e}')
"

# Step 12: Create startup scripts
print_info "Step 12: Creating management scripts..."

# Create start script
cat > start_blockchain.sh << 'EOF'
#!/bin/bash
# Start Blockchain Module with monitoring

cd "$(dirname "$0")"

echo "Starting Blockchain Module..."

# Start monitoring stack
docker-compose up -d

# Start REST API
source venv/bin/activate
python3 -c "
import asyncio
from blockchain_module.rest_api import run_rest_api
import threading

def start_api():
    asyncio.run(run_rest_api(host='0.0.0.0', port=8080))

api_thread = threading.Thread(target=start_api, daemon=True)
api_thread.start()
print('REST API started on port 8080')
"

# Start Prometheus metrics
python3 -c "
from blockchain_module import start_monitoring
start_monitoring(port=9090)
print('Prometheus metrics on port 9090')
"

echo "Blockchain Module is running!"
echo "Access:"
echo "  - REST API: http://localhost:8080"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin/admin)"
echo ""
echo "Press Ctrl+C to stop"
wait
EOF

# Create stop script
cat > stop_blockchain.sh << 'EOF'
#!/bin/bash
# Stop Blockchain Module

cd "$(dirname "$0")"

echo "Stopping Blockchain Module..."

# Stop Docker containers
docker-compose down

# Find and kill Python processes
pkill -f "blockchain_module" 2>/dev/null || true
pkill -f "rest_api" 2>/dev/null || true

echo "Blockchain Module stopped"
EOF

# Create status script
cat > status_blockchain.sh << 'EOF'
#!/bin/bash
# Check Blockchain Module status

cd "$(dirname "$0")"

echo "=== Blockchain Module Status ==="

# Check Docker services
echo "Docker Services:"
docker-compose ps

echo ""
echo "Port Status:"
PORTS=(8080 9090 3000 9093 9100)
for port in "${PORTS[@]}"; do
    if ss -tuln | grep -q ":$port "; then
        echo "  Port $port: ✓ Listening"
    else
        echo "  Port $port: ✗ Not listening"
    fi
done

echo ""
echo "Python Processes:"
pgrep -f "python.*blockchain" && echo "  Blockchain processes: ✓ Running" || echo "  Blockchain processes: ✗ Not running"

echo ""
echo "Database:"
if [ -f "data/blockchain_module.db" ]; then
    echo "  Database file: ✓ Present"
    size=$(du -h "data/blockchain_module.db" | cut -f1)
    echo "  Database size: $size"
else
    echo "  Database file: ✗ Missing"
fi
EOF

chmod +x start_blockchain.sh stop_blockchain.sh status_blockchain.sh

# Step 13: Display installation summary
print_info "Step 13: Installation complete!"

echo ""
echo "========================================="
echo "     Blockchain Module Installation"
echo "========================================="
echo ""
echo "📁 Project directory: $PROJECT_DIR"
echo "🐍 Python virtual environment: $PROJECT_DIR/venv"
echo "🐳 Docker monitoring stack: Running"
echo ""
echo "🔧 Next steps:"
echo "1. Edit configs/module_config.json with your Nownodes API key"
echo "2. Configure email in docker/alertmanager/alertmanager.yml for alerts"
echo "3. Review and adjust ports in docker-compose.yml if needed"
echo ""
echo "🚀 Start the system:"
echo "   ./start_blockchain.sh"
echo ""
echo "🛑 Stop the system:"
echo "   ./stop_blockchain.sh"
echo ""
echo "📊 Check status:"
echo "   ./status_blockchain.sh"
echo ""
echo "🌐 Access URLs:"
echo "   - REST API: http://localhost:8080"
echo "   - Prometheus: http://localhost:9090"
echo "   - Grafana: http://localhost:3000 (admin/admin)"
echo "   - Alertmanager: http://localhost:9093"
echo ""
echo "📝 Admin API Key was generated during setup."
echo "   Check the output above or run: blockchain-cli users list"
echo ""
echo "========================================="
print_success "Installation completed successfully!"
