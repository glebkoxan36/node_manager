import asyncio
import time
import logging
import psutil
from typing import Dict, List, Optional, Any

logger = logging.getLogger(__name__)

class HealthStatus:
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"

class HealthChecker:
    
    def __init__(self, 
                 monitors: Optional[Dict[str, Any]] = None,
                 collectors: Optional[Dict[str, Any]] = None,
                 connection_pools: Optional[Dict[str, Any]] = None):
        self.monitors = monitors or {}
        self.collectors = collectors or {}
        self.connection_pools = connection_pools or {}
        
        self.thresholds = {
            'cpu_percent': 80.0,
            'memory_percent': 80.0,
            'response_time': 5.0,
            'ws_reconnect_attempts': 5,
            'collection_error_rate': 0.3,
        }
    
    async def check_websocket(self, monitor) -> Dict:
        start_time = time.time()
        component_name = f"websocket_{monitor.coin_symbol}"
        
        try:
            response_time = 0.0
            details = {
                'coin': monitor.coin_symbol,
                'connected': monitor.connected,
                'monitored_addresses': len(monitor.monitored_addresses),
                'reconnect_attempts': monitor.reconnect_attempts,
            }
            
            if not monitor.connected:
                status = HealthStatus.UNHEALTHY
                error = "WebSocket not connected"
            elif monitor.reconnect_attempts >= self.thresholds['ws_reconnect_attempts']:
                status = HealthStatus.DEGRADED
                error = f"High reconnect attempts: {monitor.reconnect_attempts}"
            else:
                time_since_last = time.time() - monitor.stats.get('last_activity', 0)
                if time_since_last > 60:
                    status = HealthStatus.DEGRADED
                    error = f"No activity for {time_since_last:.0f}s"
                else:
                    status = HealthStatus.HEALTHY
                    error = None
            
            response_time = time.time() - start_time
            
            try:
                from .monitoring import metrics
                metrics.update_health_status(
                    coin=monitor.coin_symbol,
                    component="websocket",
                    check="connection",
                    healthy=status == HealthStatus.HEALTHY,
                    duration=response_time
                )
            except ImportError:
                pass
            
            return {
                'name': component_name,
                'status': status,
                'response_time': response_time,
                'details': details,
                'error': error
            }
            
        except Exception as e:
            response_time = time.time() - start_time
            
            return {
                'name': component_name,
                'status': HealthStatus.UNHEALTHY,
                'response_time': response_time,
                'details': {},
                'error': str(e)
            }
    
    async def check_collector(self, collector) -> Dict:
        start_time = time.time()
        component_name = f"collector_{collector.coin_symbol}"
        
        try:
            response_time = 0.0
            stats = collector.get_stats()
            
            details = {
                'coin': collector.coin_symbol,
                'stats': stats,
                'is_processing': collector.is_processing
            }
            
            error_rate = 0
            if stats['collections'] > 0:
                error_rate = stats['errors'] / stats['collections']
            
            if error_rate > self.thresholds['collection_error_rate']:
                status = HealthStatus.DEGRADED
                error = f"High error rate: {error_rate:.2%}"
            elif not collector.is_healthy():
                status = HealthStatus.UNHEALTHY
                error = "Collector internal health check failed"
            else:
                status = HealthStatus.HEALTHY
                error = None
            
            response_time = time.time() - start_time
            
            try:
                from .monitoring import metrics
                metrics.update_health_status(
                    coin=collector.coin_symbol,
                    component="collector",
                    check="overall",
                    healthy=status == HealthStatus.HEALTHY,
                    duration=response_time
                )
            except ImportError:
                pass
            
            return {
                'name': component_name,
                'status': status,
                'response_time': response_time,
                'details': details,
                'error': error
            }
            
        except Exception as e:
            response_time = time.time() - start_time
            
            return {
                'name': component_name,
                'status': HealthStatus.UNHEALTHY,
                'response_time': response_time,
                'details': {},
                'error': str(e)
            }
    
    def check_system_resources(self) -> Dict:
        start_time = time.time()
        component_name = "system_resources"
        
        try:
            cpu_percent = psutil.cpu_percent(interval=0.1)
            memory = psutil.virtual_memory()
            
            response_time = time.time() - start_time
            
            details = {
                'cpu_percent': cpu_percent,
                'memory_percent': memory.percent,
                'memory_available_gb': memory.available / (1024**3),
            }
            
            errors = []
            
            if cpu_percent > self.thresholds['cpu_percent']:
                errors.append(f"High CPU usage: {cpu_percent}%")
            
            if memory.percent > self.thresholds['memory_percent']:
                errors.append(f"High memory usage: {memory.percent}%")
            
            if errors:
                status = HealthStatus.DEGRADED
                error = "; ".join(errors)
            else:
                status = HealthStatus.HEALTHY
                error = None
            
            try:
                from .monitoring import metrics
                metrics.update_system_metrics(
                    memory_bytes=memory.used,
                    cpu_percent=cpu_percent
                )
            except:
                pass
            
            return {
                'name': component_name,
                'status': status,
                'response_time': response_time,
                'details': details,
                'error': error
            }
            
        except Exception as e:
            response_time = time.time() - start_time
            return {
                'name': component_name,
                'status': HealthStatus.UNHEALTHY,
                'response_time': response_time,
                'details': {},
                'error': str(e)
            }
    
    async def comprehensive_check(self) -> Dict[str, Any]:
        overall_start_time = time.time()
        components = []
        
        logger.info("Starting comprehensive health check...")
        
        system_check = self.check_system_resources()
        components.append(system_check)
        
        for name, monitor in self.monitors.items():
            ws_check = await self.check_websocket(monitor)
            components.append(ws_check)
        
        for name, collector in self.collectors.items():
            collector_check = await self.check_collector(collector)
            components.append(collector_check)
        
        status_counts = {
            HealthStatus.HEALTHY: 0,
            HealthStatus.DEGRADED: 0,
            HealthStatus.UNHEALTHY: 0
        }
        
        for component in components:
            status_counts[component['status']] += 1
        
        if status_counts[HealthStatus.UNHEALTHY] > 0:
            overall_status = HealthStatus.UNHEALTHY
        elif status_counts[HealthStatus.DEGRADED] > 0:
            overall_status = HealthStatus.DEGRADED
        else:
            overall_status = HealthStatus.HEALTHY
        
        total_response_time = time.time() - overall_start_time
        
        report = {
            'status': overall_status,
            'timestamp': time.time(),
            'response_time': total_response_time,
            'components': {
                comp['name']: {
                    'status': comp['status'],
                    'response_time': comp['response_time'],
                    'details': comp['details'],
                    'error': comp.get('error')
                }
                for comp in components
            },
            'summary': {
                'total_components': len(components),
                'healthy': status_counts[HealthStatus.HEALTHY],
                'degraded': status_counts[HealthStatus.DEGRADED],
                'unhealthy': status_counts[HealthStatus.UNHEALTHY]
            }
        }
        
        logger.info(f"Health check completed: {overall_status} "
                   f"(healthy: {status_counts[HealthStatus.HEALTHY]}, "
                   f"degraded: {status_counts[HealthStatus.DEGRADED]}, "
                   f"unhealthy: {status_counts[HealthStatus.UNHEALTHY]})")
        
        try:
            from .monitoring import metrics
            metrics.update_health_status(
                coin="system",
                component="overall",
                check="comprehensive",
                healthy=overall_status == HealthStatus.HEALTHY,
                duration=total_response_time
            )
        except:
            pass
        
        return report