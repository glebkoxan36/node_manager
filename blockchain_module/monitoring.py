"""
Модуль мониторинга для сбора метрик Prometheus
"""

import time
import logging
import threading
from typing import Dict, Any, Optional
from functools import wraps

logger = logging.getLogger(__name__)

# Проверяем наличие Prometheus клиента
try:
    from prometheus_client import (
        Counter, Gauge, Histogram, Summary,
        generate_latest, REGISTRY,
        start_http_server
    )
    PROMETHEUS_AVAILABLE = True
except ImportError:
    PROMETHEUS_AVAILABLE = False
    logger.warning("Prometheus client not installed. Monitoring disabled.")
    
    # Заглушки
    class Counter:
        def __init__(self, *args, **kwargs): pass
        def inc(self, *args, **kwargs): pass
        def labels(self, **kwargs): return self
    
    class Gauge:
        def __init__(self, *args, **kwargs): pass
        def set(self, *args, **kwargs): pass
        def inc(self, *args, **kwargs): pass
        def dec(self, *args, **kwargs): pass
        def labels(self, **kwargs): return self
    
    class Histogram:
        def __init__(self, *args, **kwargs): pass
        def observe(self, *args, **kwargs): pass
        def labels(self, **kwargs): return self
    
    class Summary:
        def __init__(self, *args, **kwargs): pass
        def observe(self, *args, **kwargs): pass
        def labels(self, **kwargs): return self

class BlockchainMetrics:
    """Класс для управления метриками блокчейн-модуля"""
    
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if not hasattr(self, 'initialized'):
            self.namespace = "blockchain_module"
            self.metrics_initialized = False
            self.metrics = {}
            self.metrics_server = None
            self.stop_event = threading.Event()
            
            if PROMETHEUS_AVAILABLE:
                self._initialize_metrics()
            
            self.initialized = True
    
    def _initialize_metrics(self):
        """Инициализация метрик"""
        
        # Метрики состояния
        self.metrics['module_status'] = Gauge(
            f'{self.namespace}_status',
            'Module status (1=running, 0=stopped)'
        )
        
        self.metrics['uptime_seconds'] = Gauge(
            f'{self.namespace}_uptime_seconds',
            'Module uptime in seconds'
        )
        
        # Метрики API запросов
        self.metrics['api_requests_total'] = Counter(
            f'{self.namespace}_api_requests_total',
            'Total number of API requests',
            ['coin', 'endpoint', 'method', 'status']
        )
        
        self.metrics['api_request_duration_seconds'] = Histogram(
            f'{self.namespace}_api_request_duration_seconds',
            'API request duration in seconds',
            ['coin', 'endpoint', 'method'],
            buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
        )
        
        # Метрики ошибок
        self.metrics['api_errors_total'] = Counter(
            f'{self.namespace}_api_errors_total',
            'Total number of API errors',
            ['coin', 'endpoint', 'error_type']
        )
        
        # Метрики транзакций
        self.metrics['transactions_processed_total'] = Counter(
            f'{self.namespace}_transactions_processed_total',
            'Total number of processed transactions',
            ['coin', 'status']
        )
        
        # Метрики WebSocket
        self.metrics['websocket_connections'] = Gauge(
            f'{self.namespace}_websocket_connections',
            'Number of active WebSocket connections',
            ['coin']
        )
        
        # Метрики сбора средств
        self.metrics['funds_collections_total'] = Counter(
            f'{self.namespace}_funds_collections_total',
            'Total number of funds collections',
            ['coin', 'status']
        )
        
        self.metrics['collected_amount_total'] = Counter(
            f'{self.namespace}_collected_amount_total',
            'Total amount collected',
            ['coin']
        )
        
        # Метрики мониторинга адресов
        self.metrics['monitored_addresses'] = Gauge(
            f'{self.namespace}_monitored_addresses',
            'Number of monitored addresses',
            ['coin']
        )
        
        # Метрики здоровья
        self.metrics['health_status'] = Gauge(
            f'{self.namespace}_health_status',
            'Health status (1=healthy, 0=unhealthy)',
            ['coin', 'component', 'check']
        )
        
        # Системные метрики
        self.metrics['memory_usage_bytes'] = Gauge(
            f'{self.namespace}_memory_usage_bytes',
            'Memory usage in bytes'
        )
        
        self.metrics['cpu_usage_percent'] = Gauge(
            f'{self.namespace}_cpu_usage_percent',
            'CPU usage percentage'
        )
        
        # Метрики кэша
        self.metrics['cache_hits_total'] = Counter(
            f'{self.namespace}_cache_hits_total',
            'Total cache hits',
            ['coin', 'cache_type']
        )
        
        self.metrics['cache_misses_total'] = Counter(
            f'{self.namespace}_cache_misses_total',
            'Total cache misses',
            ['coin', 'cache_type']
        )
        
        self.metrics_initialized = True
        self.start_time = time.time()
        
        # Запускаем обновление uptime
        threading.Thread(
            target=self._uptime_updater,
            daemon=True,
            name="UptimeUpdater"
        ).start()
    
    def _uptime_updater(self):
        """Обновление uptime"""
        while not self.stop_event.is_set():
            try:
                uptime = time.time() - self.start_time
                self.metrics['uptime_seconds'].set(uptime)
                self.metrics['module_status'].set(1)
            except Exception as e:
                logger.error(f"Error updating uptime: {e}")
            
            time.sleep(1)
    
    def set_module_info(self, version: str, author: str):
        """Установить информацию о модуле"""
        self.module_version = version
        self.module_author = author
    
    # Методы для записи метрик
    def record_api_request(self, coin: str, endpoint: str, method: str, 
                          duration: float, status_code: int = 200):
        """Записать метрику API запроса"""
        if not self.metrics_initialized:
            return
        
        status = "success" if 200 <= status_code < 300 else "error"
        
        self.metrics['api_requests_total'].labels(
            coin=coin, endpoint=endpoint, method=method, status=status
        ).inc()
        
        self.metrics['api_request_duration_seconds'].labels(
            coin=coin, endpoint=endpoint, method=method
        ).observe(duration)
    
    def record_api_error(self, coin: str, endpoint: str, error_type: str):
        """Записать метрику ошибки API"""
        if not self.metrics_initialized:
            return
        
        self.metrics['api_errors_total'].labels(
            coin=coin, endpoint=endpoint, error_type=error_type
        ).inc()
    
    def record_transaction(self, coin: str, amount: float, status: str = "processed"):
        """Записать метрику транзакции"""
        if not self.metrics_initialized:
            return
        
        self.metrics['transactions_processed_total'].labels(
            coin=coin, status=status
        ).inc()
    
    def update_websocket_connection(self, coin: str, connected: bool):
        """Обновить метрику WebSocket соединения"""
        if not self.metrics_initialized:
            return
        
        if connected:
            self.metrics['websocket_connections'].labels(coin=coin).set(1)
        else:
            self.metrics['websocket_connections'].labels(coin=coin).set(0)
    
    def record_websocket_reconnect(self, coin: str, reason: str = "unknown"):
        """Записать метрику переподключения WebSocket"""
        pass
    
    def record_websocket_message(self, coin: str, message_type: str, 
                                direction: str = "incoming", size: int = 0):
        """Записать метрику сообщения WebSocket"""
        pass
    
    def record_funds_collection(self, coin: str, amount: float, fee: float, 
                               status: str):
        """Записать метрику сбора средств"""
        if not self.metrics_initialized:
            return
        
        self.metrics['funds_collections_total'].labels(
            coin=coin, status=status
        ).inc()
        
        if status == "success":
            self.metrics['collected_amount_total'].labels(coin=coin).inc(amount)
    
    def update_monitored_addresses(self, coin: str, count: int):
        """Обновить количество отслеживаемых адресов"""
        if not self.metrics_initialized:
            return
        
        self.metrics['monitored_addresses'].labels(coin=coin).set(count)
    
    def update_health_status(self, coin: str, component: str, check: str, 
                            healthy: bool, duration: float = None):
        """Обновить статус здоровья"""
        if not self.metrics_initialized:
            return
        
        status_value = 1 if healthy else 0
        
        self.metrics['health_status'].labels(
            coin=coin, component=component, check=check
        ).set(status_value)
    
    def update_system_metrics(self, memory_bytes: int, cpu_percent: float):
        """Обновить системные метрики"""
        if not self.metrics_initialized:
            return
        
        self.metrics['memory_usage_bytes'].set(memory_bytes)
        self.metrics['cpu_usage_percent'].set(cpu_percent)
    
    def record_cache_hit(self, coin: str, cache_type: str):
        """Записать попадание в кэш"""
        if not self.metrics_initialized:
            return
        
        self.metrics['cache_hits_total'].labels(
            coin=coin, cache_type=cache_type
        ).inc()
    
    def record_cache_miss(self, coin: str, cache_type: str):
        """Записать промах в кэш"""
        if not self.metrics_initialized:
            return
        
        self.metrics['cache_misses_total'].labels(
            coin=coin, cache_type=cache_type
        ).inc()
    
    def get_metrics(self) -> bytes:
        """Получить метрики в формате Prometheus"""
        if not self.metrics_initialized:
            return b""
        
        try:
            return generate_latest()
        except Exception as e:
            logger.error(f"Error generating metrics: {e}")
            return b""
    
    def start_metrics_server(self, port: int = 9090, addr: str = '0.0.0.0'):
        """Запустить HTTP сервер для метрик"""
        if not PROMETHEUS_AVAILABLE:
            logger.error("Prometheus client not installed.")
            return False
        
        try:
            start_http_server(port, addr=addr)
            self.metrics_server = True
            logger.info(f"Metrics server started on {addr}:{port}")
            return True
        except Exception as e:
            logger.error(f"Failed to start metrics server: {e}")
            return False
    
    def stop(self):
        """Остановить сбор метрик"""
        self.stop_event.set()
        logger.info("Metrics monitoring stopped")

# Глобальный экземпляр метрик
metrics = BlockchainMetrics()

# Декораторы для мониторинга
def monitor_api_request(func):
    """Декоратор для мониторинга API запросов"""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = time.time()
        
        coin = kwargs.get('coin_symbol', 'unknown')
        if args and hasattr(args[0], 'coin_symbol'):
            coin = args[0].coin_symbol
        
        endpoint = func.__name__
        method = "GET" if "get_" in endpoint else "POST"
        
        try:
            result = await func(*args, **kwargs)
            duration = time.time() - start_time
            
            metrics.record_api_request(
                coin=coin.upper(),
                endpoint=endpoint,
                method=method,
                duration=duration,
                status_code=200
            )
            
            return result
            
        except Exception as e:
            duration = time.time() - start_time
            error_type = type(e).__name__
            
            metrics.record_api_request(
                coin=coin.upper(),
                endpoint=endpoint,
                method=method,
                duration=duration,
                status_code=500
            )
            
            metrics.record_api_error(
                coin=coin.upper(),
                endpoint=endpoint,
                error_type=error_type
            )
            
            raise
    
    return wrapper

def monitor_transaction(func):
    """Декоратор для мониторинга транзакций"""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = time.time()
        
        try:
            result = await func(*args, **kwargs)
            duration = time.time() - start_time
            
            if isinstance(result, dict):
                coin = kwargs.get('coin_symbol', result.get('coin', 'unknown'))
                amount = result.get('amount', 0)
                status = result.get('status', 'processed')
                
                metrics.record_transaction(
                    coin=coin.upper(),
                    amount=amount,
                    status=status
                )
            
            return result
            
        except Exception as e:
            logger.error(f"Error in monitored transaction: {e}")
            raise
    
    return wrapper

def monitor_funds_collection(func):
    """Декоратор для мониторинга сбора средств"""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = time.time()
        
        try:
            result = await func(*args, **kwargs)
            duration = time.time() - start_time
            
            if isinstance(result, dict):
                coin = kwargs.get('coin_symbol', result.get('coin', 'unknown'))
                amount = result.get('amount_sent', 0)
                fee = result.get('fee', 0)
                status = "success" if result.get('success') else "failed"
                
                metrics.record_funds_collection(
                    coin=coin.upper(),
                    amount=amount,
                    fee=fee,
                    status=status
                )
            
            return result
            
        except Exception as e:
            duration = time.time() - start_time
            coin = kwargs.get('coin_symbol', 'unknown')
            
            metrics.record_funds_collection(
                coin=coin.upper(),
                amount=0,
                fee=0,
                status="error"
            )
            
            raise
    
    return wrapper