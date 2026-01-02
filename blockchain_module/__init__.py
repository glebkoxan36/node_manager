"""
Blockchain Module - Универсальный модуль для работы с криптовалютами через Nownodes API
"""

import logging
import sys
import os
import asyncio
from typing import Dict, List, Optional, Any, Callable

logging.getLogger(__name__).addHandler(logging.NullHandler())

__version__ = "2.0.0"
__author__ = "Blockchain Module Team"

# Ленивые импорты
_config_manager = None
_metrics = None
_user_manager = None

def _get_config_manager():
    global _config_manager
    if _config_manager is None:
        from .config import ConfigManager
        _config_manager = ConfigManager()
    return _config_manager

def _get_metrics():
    global _metrics
    if _metrics is None:
        try:
            from .monitoring import BlockchainMetrics
            _metrics = BlockchainMetrics()
        except ImportError:
            class DummyMetrics:
                def __getattr__(self, name):
                    return lambda *args, **kwargs: None
            _metrics = DummyMetrics()
    return _metrics

async def _get_user_manager():
    """Асинхронный геттер для UserManager"""
    global _user_manager
    if _user_manager is None:
        from .users import UserManager
        _user_manager = UserManager()
        await _user_manager.initialize()
    return _user_manager

try:
    # Основные импорты
    from .connection_pool import ConnectionPool
    from .health_check import HealthChecker
    from .utils import validate_address_format, satoshi_to_coin, coin_to_satoshi
    from .database import SQLiteDBManager
    
    # Импорт остальных модулей
    BlockchainConfig = None
    UniversalNownodesClient = None
    BlockchainMonitor = None
    FundsCollector = None
    
    def _lazy_import_config():
        global BlockchainConfig
        if BlockchainConfig is None:
            from .config import BlockchainConfig as BC
            BlockchainConfig = BC
        return BlockchainConfig
    
    def _lazy_import_client():
        global UniversalNownodesClient
        if UniversalNownodesClient is None:
            from .nownodes_client import UniversalNownodesClient as UNC
            UniversalNownodesClient = UNC
        return UniversalNownodesClient
    
    def _lazy_import_monitor():
        global BlockchainMonitor
        if BlockchainMonitor is None:
            from .blockchain_monitor import BlockchainMonitor as BM
            BlockchainMonitor = BM
        return BlockchainMonitor
    
    def _lazy_import_collector():
        global FundsCollector
        if FundsCollector is None:
            from .funds_collector import FundsCollector as FC
            FundsCollector = FC
        return FundsCollector
    
    # Импорт мониторинга
    try:
        from .monitoring import (
            BlockchainMetrics, metrics, 
            monitor_api_request, monitor_transaction, monitor_funds_collection,
            PROMETHEUS_AVAILABLE
        )
        if hasattr(metrics, 'set_module_info'):
            metrics.set_module_info(__version__, __author__)
    except ImportError:
        PROMETHEUS_AVAILABLE = False
        
        def monitor_api_request(func):
            return func
        
        def monitor_transaction(func):
            return func
        
        def monitor_funds_collection(func):
            return func
    
    # Импорт REST API
    try:
        from .rest_api import create_rest_api, run_rest_api, BlockchainRestAPI
        REST_API_AVAILABLE = True
    except ImportError:
        REST_API_AVAILABLE = False
        
        def create_rest_api(*args, **kwargs):
            raise ImportError("REST API module not available")
        
        def run_rest_api(*args, **kwargs):
            raise ImportError("REST API module not available")
    
    # Импорт CLI
    try:
        from .cli import AdminCLI
        CLI_AVAILABLE = True
    except ImportError:
        CLI_AVAILABLE = False
        
        class AdminCLI:
            def __init__(self, *args, **kwargs):
                raise ImportError("CLI module not available")
    
    # Импорт пользователей
    from .users import UserManager, UserRole, UserStatus
    
    __all__ = [
        'BlockchainConfig',
        'ConnectionPool',
        'HealthChecker',
        'UniversalNownodesClient',
        'BlockchainMonitor',
        'FundsCollector',
        'SQLiteDBManager',
        'UserManager',
        'UserRole',
        'UserStatus',
        'AdminCLI',
        'validate_address_format',
        'satoshi_to_coin',
        'coin_to_satoshi',
        'PROMETHEUS_AVAILABLE',
        'REST_API_AVAILABLE',
        'CLI_AVAILABLE',
        'create_rest_api',
        'run_rest_api',
        'BlockchainRestAPI',
        'monitor_api_request',
        'monitor_transaction',
        'monitor_funds_collection',
        '__version__',
        '__author__'
    ]
    
    # Инициализация конфигурации
    config_manager = _get_config_manager()
    SUPPORTED_COINS = config_manager.get_all_coins()
    
    def get_module_info() -> Dict[str, Any]:
        return {
            'version': __version__,
            'author': __author__,
            'supported_coins': SUPPORTED_COINS,
            'multiuser_enabled': config_manager.get_multiuser_config().get('enabled', False)
        }
    
    def setup_logging(level: int = logging.INFO) -> logging.Logger:
        logger = logging.getLogger(__name__)
        logger.setLevel(level)
        
        if not logger.handlers:
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
            logger.addHandler(console_handler)
        
        logger.info(f"Blockchain Module v{__version__} initialized")
        return logger
    
    __all__.extend(['get_module_info', 'setup_logging', 'SUPPORTED_COINS'])
    
    # Получаем настройки
    DEFAULT_CONFIRMATIONS = config_manager.get_module_setting('default_confirmations', 3)
    DEFAULT_COLLECTION_FEE = config_manager.get_module_setting('default_collection_fee', 0.0001)
    DEFAULT_MIN_COLLECTION = config_manager.get_module_setting('default_min_collection', 0.001)
    DEFAULT_CONNECTION_POOL_SIZE = config_manager.get_module_setting('connection_pool_size', 10)
    
    __all__.extend([
        'DEFAULT_CONFIRMATIONS',
        'DEFAULT_COLLECTION_FEE',
        'DEFAULT_MIN_COLLECTION',
        'DEFAULT_CONNECTION_POOL_SIZE'
    ])
    
    def list_supported_coins() -> List[str]:
        return config_manager.get_all_coins()
    
    def get_coin_info(coin_symbol: str) -> Dict[str, Any]:
        logger = logging.getLogger(__name__)
        try:
            config = config_manager.get_coin_config(coin_symbol)
            return {
                'symbol': config.get('symbol'),
                'name': config.get('name'),
                'decimals': config.get('decimals', 8),
                'required_confirmations': config.get('required_confirmations', DEFAULT_CONFIRMATIONS),
                'min_collection_amount': config.get('min_collection_amount', DEFAULT_MIN_COLLECTION),
                'collection_fee': config.get('collection_fee', DEFAULT_COLLECTION_FEE),
            }
        except Exception as e:
            logger.error(f"Error getting coin info for {coin_symbol}: {e}")
            return {}
    
    def add_custom_coin(coin_symbol: str, config: Dict[str, Any]) -> bool:
        logger = logging.getLogger(__name__)
        try:
            coin_symbol = coin_symbol.upper()
            
            required_fields = ['symbol', 'name', 'decimals']
            for field in required_fields:
                if field not in config:
                    logger.error(f"Missing required field '{field}' in coin config")
                    return False
            
            success = config_manager.set_coin_config(coin_symbol, config)
            if success:
                logger.info(f"Custom coin {coin_symbol} added successfully")
            return success
            
        except Exception as e:
            logger.error(f"Error adding custom coin {coin_symbol}: {e}")
            return False
    
    async def create_client(coin_symbol: str, api_key: Optional[str] = None, 
                           connection_pool: Optional[ConnectionPool] = None) -> UniversalNownodesClient:
        if api_key:
            config_manager.set_module_setting('api_key', api_key)
        
        client_class = _lazy_import_client()
        return client_class(coin_symbol, connection_pool)
    
    async def create_monitor(coin_symbol: str, user_id: int,
                           db_manager: Optional[SQLiteDBManager] = None,
                           connection_pool: Optional[ConnectionPool] = None,
                           on_transaction: Optional[Callable] = None) -> BlockchainMonitor:
        if db_manager is None:
            db_manager = SQLiteDBManager()
            await db_manager.initialize()
        
        monitor_class = _lazy_import_monitor()
        return monitor_class(
            user_id=user_id,
            coin_symbol=coin_symbol,
            db_manager=db_manager,
            connection_pool=connection_pool,
            on_transaction_callback=on_transaction,
        )
    
    async def create_funds_collector(coin_symbol: str, user_id: int,
                                   master_address: str, 
                                   connection_pool: Optional[ConnectionPool] = None) -> FundsCollector:
        collector_class = _lazy_import_collector()
        return collector_class(
            user_id=user_id,
            coin_symbol=coin_symbol,
            master_address=master_address,
            connection_pool=connection_pool
        )
    
    def create_connection_pool(max_connections: int = DEFAULT_CONNECTION_POOL_SIZE) -> ConnectionPool:
        return ConnectionPool(max_connections=max_connections)
    
    __all__.extend([
        'list_supported_coins',
        'get_coin_info',
        'add_custom_coin',
        'create_client', 
        'create_monitor', 
        'create_funds_collector',
        'create_connection_pool',
    ])
    
    def get_config_summary() -> Dict[str, Any]:
        return config_manager.get_config_summary()
    
    def reload_configuration() -> bool:
        return config_manager.load_config()
    
    def save_configuration() -> bool:
        return config_manager.save_config()
    
    def validate_configuration() -> Dict[str, Any]:
        errors = []
        warnings = []
        
        if not config_manager.get_module_setting('api_key'):
            errors.append("API key is not configured")
        
        for coin in config_manager.get_all_coins():
            validation = config_manager.validate_coin_config(coin)
            if not validation['valid']:
                errors.append(f"Invalid config for {coin}: {', '.join(validation['errors'])}")
            if validation['has_warnings']:
                warnings.append(f"Warnings for {coin}: {', '.join(validation['warnings'])}")
        
        return {
            'valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings,
            'has_warnings': len(warnings) > 0
        }
    
    def start_monitoring(port: Optional[int] = None) -> bool:
        if not PROMETHEUS_AVAILABLE:
            logger = logging.getLogger(__name__)
            logger.warning("Prometheus client not installed.")
            return False
        
        if port is None:
            monitoring_config = config_manager.get_monitoring_config()
            port = monitoring_config.get('prometheus_port', 9090)
        
        metrics.start_metrics_server(port=port)
        return True
    
    def start_rest_api_server() -> bool:
        if not REST_API_AVAILABLE:
            logger = logging.getLogger(__name__)
            logger.warning("REST API module not available")
            return False
        
        try:
            rest_config = config_manager.get_rest_api_config()
            
            if not rest_config.get('enabled', False):
                logger.info("REST API is disabled in configuration")
                return False
            
            host = rest_config.get('host', '0.0.0.0')
            port = rest_config.get('port', 8080)
            
            import threading
            
            def run_server():
                try:
                    loop = asyncio.new_event_loop()
                    asyncio.set_event_loop(loop)
                    loop.run_until_complete(run_rest_api(host, port))
                except Exception as e:
                    import logging
                logging.getLogger(__name__).error(f"REST API server error: {e}")
            
            thread = threading.Thread(target=run_server, daemon=True, name="REST-API-Server")
            thread.start()
            
            logger.info(f"REST API server started on {host}:{port}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to start REST API server: {e}")
            return False
    
    async def start_cli():
        """Запустить CLI интерфейс"""
        if not CLI_AVAILABLE:
            logger = logging.getLogger(__name__)
            logger.warning("CLI module not available")
            return False
        
        try:
            cli = AdminCLI()
            await cli.run()
            return True
        except Exception as e:
            logger.error(f"Failed to start CLI: {e}")
            return False
    
    __all__.extend([
        'get_config_summary',
        'reload_configuration',
        'save_configuration',
        'validate_configuration',
        'start_monitoring',
        'start_rest_api_server',
        'start_cli'
    ])
    
    # Автозапуск сервисов
    def _auto_start_services():
        logger = logging.getLogger(__name__)
        
        monitoring_config = config_manager.get_monitoring_config()
        if monitoring_config.get('enabled', False):
            try:
                start_monitoring()
                logger.info("Monitoring service started")
            except Exception as e:
                logger.error(f"Failed to start monitoring: {e}")
        
        if config_manager.get_rest_api_config().get('enabled', False):
            try:
                start_rest_api_server()
                logger.info("REST API service started")
            except Exception as e:
                logger.error(f"Failed to start REST API: {e}")
    
    _auto_start_services()
    
    logger = logging.getLogger(__name__)
    logger.info(f"Blockchain Module v{__version__} initialized with {len(SUPPORTED_COINS)} coins")
    logger.info(f"Multiuser mode: {config_manager.get_multiuser_config().get('enabled', 'Not configured')}")
    
except ImportError as e:
    import warnings
    warnings.warn(f"Не удалось импортировать некоторые компоненты модуля: {e}")
    
    # Заглушки для основных классов
    class BlockchainConfig:
        NOWNODES_API_KEY = ""
        COINS = {}
        
        @classmethod
        def get_coin_config(cls, coin_symbol):
            coin_symbol = coin_symbol.upper()
            if coin_symbol in cls.COINS:
                return cls.COINS[coin_symbol].copy()
            return {}
    
    class ConnectionPool:
        def __init__(self, *args, **kwargs):
            pass
        
        async def get_session(self):
            raise ImportError("Модуль не полностью установлен.")
    
    class HealthChecker:
        def __init__(self, *args, **kwargs):
            pass
        
        async def check_health(self):
            return {"status": "unknown", "error": "Module not fully installed"}
    
    class UniversalNownodesClient:
        def __init__(self, *args, **kwargs):
            raise ImportError("Модуль не полностью установлен.")
    
    class BlockchainMonitor:
        def __init__(self, *args, **kwargs):
            raise ImportError("Модуль не полностью установлен.")
    
    class FundsCollector:
        def __init__(self, *args, **kwargs):
            raise ImportError("Модуль не полностью установлен.")
    
    class SQLiteDBManager:
        def __init__(self, *args, **kwargs):
            pass
        
        async def initialize(self):
            pass
        
        async def close(self):
            pass
    
    class UserManager:
        def __init__(self, *args, **kwargs):
            pass
        
        async def initialize(self):
            pass
    
    class UserRole:
        ADMIN = "admin"
        USER = "user"
        VIEWER = "viewer"
    
    class UserStatus:
        ACTIVE = "active"
        INACTIVE = "inactive"
        SUSPENDED = "suspended"
        BANNED = "banned"
    
    class AdminCLI:
        def __init__(self, *args, **kwargs):
            raise ImportError("CLI module not available")
    
    SUPPORTED_COINS = []
    DEFAULT_CONFIRMATIONS = 3
    DEFAULT_COLLECTION_FEE = 0.0001
    DEFAULT_MIN_COLLECTION = 0.001
    DEFAULT_CONNECTION_POOL_SIZE = 10
    PROMETHEUS_AVAILABLE = False
    REST_API_AVAILABLE = False
    CLI_AVAILABLE = False
    
    def get_module_info() -> Dict[str, Any]:
        return {'version': __version__, 'author': __author__}
    
    def setup_logging(level: int = logging.INFO) -> logging.Logger:
        logger = logging.getLogger(__name__)
        return logger
    
    __all__ = [
        'BlockchainConfig',
        'ConnectionPool',
        'HealthChecker',
        'UniversalNownodesClient',
        'BlockchainMonitor',
        'FundsCollector',
        'SQLiteDBManager',
        'UserManager',
        'UserRole',
        'UserStatus',
        'AdminCLI',
        'get_module_info',
        'setup_logging',
        'SUPPORTED_COINS',
        'DEFAULT_CONFIRMATIONS',
        'DEFAULT_COLLECTION_FEE',
        'DEFAULT_MIN_COLLECTION',
        'DEFAULT_CONNECTION_POOL_SIZE',
        'PROMETHEUS_AVAILABLE',
        'REST_API_AVAILABLE',
        'CLI_AVAILABLE',
        '__version__',
        '__author__',
    ]

if sys.version_info < (3, 7):
    raise RuntimeError("Этот модуль требует Python 3.7 или выше")
