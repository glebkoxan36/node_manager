"""
REST API модуль для Blockchain Module с поддержкой мультипользовательства
"""

import asyncio
import logging
import json
import time
import secrets
from typing import Dict, List, Optional, Any

from aiohttp import web
import aiohttp_cors

logger = logging.getLogger(__name__)

class BlockchainRestAPI:
    
    def __init__(self, host: str = '0.0.0.0', port: int = 8080):
        self.host = host
        self.port = port
        
        self.app = web.Application(middlewares=[
            self.error_middleware,
            self.logging_middleware,
            self.auth_middleware
        ])
        
        self.cors = aiohttp_cors.setup(self.app, defaults={
            "*": aiohttp_cors.ResourceOptions(
                allow_credentials=True,
                expose_headers="*",
                allow_headers="*",
            )
        })
        
        self.setup_routes()
        
        self.monitors: Dict[str, Dict[str, Any]] = {}  # user_id -> {coin -> monitor}
        self.collectors: Dict[str, Dict[str, Any]] = {}  # user_id -> {coin -> collector}
        self.connection_pools: Dict[str, Any] = {}
        self.db_manager = None
        self.user_manager = None
        
        logger.info(f"REST API инициализирован: {host}:{port}")
    
    async def initialize_database(self):
        """Инициализировать базу данных и менеджер пользователей"""
        try:
            # Инициализируем базу данных
            from .database import SQLiteDBManager
            self.db_manager = SQLiteDBManager("blockchain_module.db")
            await self.db_manager.initialize()
            
            # Инициализируем менеджер пользователей
            from .users import UserManager
            self.user_manager = UserManager("blockchain_module.db")
            await self.user_manager.initialize()
            
            logger.info("Database and user manager initialized for REST API")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize database: {e}")
            return False
    
    @web.middleware
    async def auth_middleware(self, request, handler):
        """Middleware для аутентификации пользователей"""
        # Публичные эндпоинты
        public_endpoints = [
            '/api/v1/info',
            '/api/v1/health',
            '/metrics',
            '/api/v1/auth/login',
            '/api/v1/auth/register'
        ]
        
        if request.path in public_endpoints or request.path.startswith('/api/v1/public/'):
            return await handler(request)
        
        # Получаем API ключ из заголовков
        api_key = request.headers.get('X-API-Key') or request.headers.get('Authorization')
        
        if api_key and api_key.startswith('Bearer '):
            api_key = api_key[7:]
        
        if not api_key:
            return web.json_response({
                'success': False,
                'error': 'API key is required'
            }, status=401)
        
        # Проверяем, инициализирован ли менеджер пользователей
        if not self.user_manager:
            return web.json_response({
                'success': False,
                'error': 'User manager not initialized'
            }, status=500)
        
        # Аутентифицируем пользователя
        user = await self.user_manager.authenticate_user(api_key)
        
        if not user:
            return web.json_response({
                'success': False,
                'error': 'Invalid API key'
            }, status=401)
        
        if user.get('status') != 'active':
            return web.json_response({
                'success': False,
                'error': 'Account is not active'
            }, status=403)
        
        # Добавляем пользователя в запрос
        request['user'] = user
        
        # Проверяем квоты для API вызовов
        if not await self.user_manager.check_quota(user['id'], 'daily_api_calls'):
            return web.json_response({
                'success': False,
                'error': 'Daily API call quota exceeded'
            }, status=429)
        
        return await handler(request)
    
    @web.middleware
    async def error_middleware(self, request, handler):
        try:
            response = await handler(request)
            return response
        except web.HTTPException as ex:
            return web.json_response({
                'success': False,
                'error': ex.reason,
                'status': ex.status
            }, status=ex.status)
        except Exception as e:
            logger.error(f"Unhandled error: {e}")
            return web.json_response({
                'success': False,
                'error': 'Internal server error'
            }, status=500)
    
    @web.middleware
    async def logging_middleware(self, request, handler):
        start_time = time.time()
        
        user_id = request.get('user', {}).get('id', 'anonymous')
        method = request.method
        path = request.path
        
        response = await handler(request)
        
        duration = time.time() - start_time
        
        logger.info(f"User:{user_id} {method} {path} - {response.status} "
                   f"({duration:.3f}s) - {request.remote}")
        
        # Логируем активность пользователя
        if 'user' in request and self.user_manager:
            await self.user_manager.log_activity(
                user_id=request['user']['id'],
                action=f"api_{method.lower()}",
                resource_type=path.split('/')[3] if len(path.split('/')) > 3 else None,
                resource_id=path.split('/')[4] if len(path.split('/')) > 4 else None,
                ip_address=request.remote,
                user_agent=request.headers.get('User-Agent')
            )
        
        return response
    
    def setup_routes(self):
        # Публичные эндпоинты
        self.app.router.add_get('/api/v1/info', self.get_module_info)
        self.app.router.add_get('/api/v1/health', self.get_health_status)
        self.app.router.add_get('/metrics', self.get_metrics)
        
        # Аутентификация
        self.app.router.add_post('/api/v1/auth/login', self.login)
        self.app.router.add_post('/api/v1/auth/register', self.register)
        
        # Пользовательские эндпоинты (требуют аутентификации)
        self.app.router.add_get('/api/v1/user/profile', self.get_user_profile)
        self.app.router.add_put('/api/v1/user/profile', self.update_user_profile)
        self.app.router.add_get('/api/v1/user/stats', self.get_user_stats)
        self.app.router.add_post('/api/v1/user/api-key/regenerate', self.regenerate_api_key)
        
        # Монеты
        self.app.router.add_get('/api/v1/coins', self.list_coins)
        self.app.router.add_get('/api/v1/coins/{coin_symbol}', self.get_coin_info)
        
        # Адреса
        self.app.router.add_get('/api/v1/addresses', self.list_addresses)
        self.app.router.add_post('/api/v1/addresses/monitor', self.monitor_address)
        self.app.router.add_delete('/api/v1/addresses/{address_id}/monitor', self.stop_monitoring_address)
        self.app.router.add_get('/api/v1/addresses/{coin_symbol}/balance/{address}', self.get_address_balance)
        
        # Мониторинг
        self.app.router.add_post('/api/v1/monitor/{coin_symbol}/start', self.start_monitor)
        self.app.router.add_post('/api/v1/monitor/{coin_symbol}/stop', self.stop_monitor)
        self.app.router.add_get('/api/v1/monitor/{coin_symbol}/status', self.get_monitor_status)
        
        # Сбор средств
        self.app.router.add_post('/api/v1/collect/{coin_symbol}', self.collect_funds)
        
        # Транзакции
        self.app.router.add_get('/api/v1/transactions', self.list_transactions)
        self.app.router.add_get('/api/v1/transactions/{txid}', self.get_transaction)
        
        # Админские эндпоинты
        self.app.router.add_get('/api/v1/admin/users', self.admin_list_users)
        self.app.router.add_post('/api/v1/admin/users', self.admin_create_user)
        self.app.router.add_get('/api/v1/admin/users/{user_id}', self.admin_get_user)
        self.app.router.add_put('/api/v1/admin/users/{user_id}', self.admin_update_user)
        self.app.router.add_delete('/api/v1/admin/users/{user_id}', self.admin_delete_user)
        self.app.router.add_post('/api/v1/admin/users/{user_id}/api-key/reset', self.admin_reset_api_key)
        self.app.router.add_get('/api/v1/admin/stats', self.admin_get_stats)
        
        # Применяем CORS
        for route in list(self.app.router.routes()):
            self.cors.add(route)
    
    # Публичные эндпоинты
    async def get_module_info(self, request):
        try:
            # Используем локальный импорт для избежания циклических зависимостей
            from . import get_module_info as get_module_info_func
            
            info = get_module_info_func()
            
            return web.json_response({
                'success': True,
                'data': info
            })
        except Exception as e:
            logger.error(f"Error getting module info: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def get_health_status(self, request):
        try:
            from .health_check import HealthChecker
            
            health_checker = HealthChecker(
                monitors=self.monitors,
                collectors=self.collectors,
                connection_pools=self.connection_pools
            )
            
            health_report = await health_checker.comprehensive_check()
            
            return web.json_response({
                'success': True,
                'data': health_report
            })
        except Exception as e:
            logger.error(f"Error getting health status: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def get_metrics(self, request):
        try:
            from .monitoring import metrics, PROMETHEUS_AVAILABLE
            
            if not PROMETHEUS_AVAILABLE:
                return web.Response(
                    text='Prometheus not available',
                    status=503,
                    content_type='text/plain'
                )
            
            metrics_data = metrics.get_metrics()
            
            return web.Response(
                body=metrics_data,
                content_type='text/plain'
            )
        except Exception as e:
            logger.error(f"Error getting metrics: {e}")
            return web.Response(
                text=f'Error: {str(e)}',
                status=500,
                content_type='text/plain'
            )
    
    # Аутентификация
    async def login(self, request):
        try:
            data = await request.json()
            api_key = data.get('api_key')
            
            if not api_key:
                return web.json_response({
                    'success': False,
                    'error': 'API key is required'
                }, status=400)
            
            if not self.user_manager:
                return web.json_response({
                    'success': False,
                    'error': 'User manager not initialized'
                }, status=500)
            
            user = await self.user_manager.authenticate_user(api_key)
            
            if not user:
                return web.json_response({
                    'success': False,
                    'error': 'Invalid API key'
                }, status=401)
            
            # Создаем сессию
            session_token = secrets.token_urlsafe(32)
            
            # Сохраняем сессию в базе данных
            async with self.db_manager.connection.cursor() as cursor:
                await cursor.execute('''
                    INSERT INTO user_sessions 
                    (user_id, session_token, expires_at, ip_address, user_agent)
                    VALUES (?, ?, datetime('now', '+1 hour'), ?, ?)
                ''', (
                    user['id'],
                    session_token,
                    request.remote,
                    request.headers.get('User-Agent')
                ))
                await self.db_manager.connection.commit()
            
            return web.json_response({
                'success': True,
                'data': {
                    'user': {
                        'id': user['id'],
                        'username': user['username'],
                        'email': user.get('email'),
                        'role': user['role'],
                        'status': user['status']
                    },
                    'session_token': session_token,
                    'expires_in': 3600
                }
            })
        except json.JSONDecodeError:
            return web.json_response({
                'success': False,
                'error': 'Invalid JSON'
            }, status=400)
        except Exception as e:
            logger.error(f"Error during login: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def register(self, request):
        try:
            data = await request.json()
            username = data.get('username')
            email = data.get('email')
            
            if not username:
                return web.json_response({
                    'success': False,
                    'error': 'Username is required'
                }, status=400)
            
            # Проверяем, разрешена ли регистрация
            from .config import BlockchainConfig
            if not BlockchainConfig.is_multiuser_enabled():
                return web.json_response({
                    'success': False,
                    'error': 'Registration is disabled'
                }, status=403)
            
            if not self.user_manager:
                return web.json_response({
                    'success': False,
                    'error': 'User manager not initialized'
                }, status=500)
            
            # Создаем пользователя
            result = await self.user_manager.create_user(username, email)
            
            if result['success']:
                return web.json_response({
                    'success': True,
                    'data': {
                        'user_id': result['user_id'],
                        'username': result['username'],
                        'api_key': result['api_key'],
                        'message': result['message']
                    }
                })
            else:
                return web.json_response({
                    'success': False,
                    'error': result['error']
                }, status=400)
                
        except json.JSONDecodeError:
            return web.json_response({
                'success': False,
                'error': 'Invalid JSON'
            }, status=400)
        except Exception as e:
            logger.error(f"Error during registration: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    # Пользовательские эндпоинты
    async def get_user_profile(self, request):
        user = request['user']
        
        return web.json_response({
            'success': True,
            'data': {
                'id': user['id'],
                'username': user['username'],
                'email': user.get('email'),
                'role': user['role'],
                'status': user['status'],
                'created_at': user.get('created_at'),
                'last_login': user.get('last_login'),
                'settings': json.loads(user['settings']) if user.get('settings') else {},
                'quotas': {
                    'max_monitored_addresses': user.get('max_monitored_addresses', 100),
                    'max_daily_api_calls': user.get('max_daily_api_calls', 10000),
                    'max_concurrent_monitors': user.get('max_concurrent_monitors', 5),
                    'can_collect_funds': bool(user.get('can_collect_funds', 0)),
                    'can_create_addresses': bool(user.get('can_create_addresses', 1)),
                    'can_view_transactions': bool(user.get('can_view_transactions', 1))
                }
            }
        })
    
    async def update_user_profile(self, request):
        try:
            user = request['user']
            data = await request.json()
            
            if not self.user_manager:
                return web.json_response({
                    'success': False,
                    'error': 'User manager not initialized'
                }, status=500)
            
            updates = {}
            if 'email' in data:
                updates['email'] = data['email']
            if 'settings' in data:
                updates['settings'] = data['settings']
            
            if updates:
                success = await self.user_manager.update_user(user['id'], updates)
                if success:
                    return web.json_response({
                        'success': True,
                        'message': 'Profile updated successfully'
                    })
                else:
                    return web.json_response({
                        'success': False,
                        'error': 'Failed to update profile'
                    }, status=500)
            else:
                return web.json_response({
                    'success': False,
                    'error': 'No updates provided'
                }, status=400)
                
        except json.JSONDecodeError:
            return web.json_response({
                'success': False,
                'error': 'Invalid JSON'
            }, status=400)
        except Exception as e:
            logger.error(f"Error updating user profile: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def get_user_stats(self, request):
        user = request['user']
        
        if not self.user_manager:
            return web.json_response({
                'success': False,
                'error': 'User manager not initialized'
            }, status=500)
        
        stats = await self.user_manager.get_user_stats(user['id'])
        
        if stats['success']:
            return web.json_response({
                'success': True,
                'data': stats
            })
        else:
            return web.json_response({
                'success': False,
                'error': stats['error']
            }, status=500)
    
    async def regenerate_api_key(self, request):
        user = request['user']
        
        if not self.user_manager:
            return web.json_response({
                'success': False,
                'error': 'User manager not initialized'
            }, status=500)
        
        new_api_key = await self.user_manager.regenerate_api_key(user['id'])
        
        if new_api_key:
            return web.json_response({
                'success': True,
                'data': {
                    'new_api_key': new_api_key,
                    'message': 'API key regenerated successfully'
                }
            })
        else:
            return web.json_response({
                'success': False,
                'error': 'Failed to regenerate API key'
            }, status=500)
    
    # Монеты
    async def list_coins(self, request):
        try:
            from . import list_supported_coins
            
            coins = list_supported_coins()
            
            return web.json_response({
                'success': True,
                'data': {
                    'coins': coins,
                    'total': len(coins)
                }
            })
        except Exception as e:
            logger.error(f"Error listing coins: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def get_coin_info(self, request):
        try:
            coin_symbol = request.match_info['coin_symbol'].upper()
            
            from . import get_coin_info as get_coin_info_func
            
            info = get_coin_info_func(coin_symbol)
            
            if not info:
                return web.json_response({
                    'success': False,
                    'error': f'Coin {coin_symbol} not found'
                }, status=404)
            
            return web.json_response({
                'success': True,
                'data': info
            })
        except Exception as e:
            logger.error(f"Error getting coin info: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    # Адреса
    async def list_addresses(self, request):
        try:
            user = request['user']
            coin = request.query.get('coin')
            
            if not self.db_manager:
                return web.json_response({
                    'success': False,
                    'error': 'Database manager not initialized'
                }, status=500)
            
            async with self.db_manager.connection.cursor() as cursor:
                if coin:
                    await cursor.execute(
                        "SELECT * FROM monitored_addresses WHERE user_id = ? AND coin = ? AND is_active = 1 ORDER BY added_at DESC",
                        (user['id'], coin.upper())
                    )
                else:
                    await cursor.execute(
                        "SELECT * FROM monitored_addresses WHERE user_id = ? AND is_active = 1 ORDER BY added_at DESC",
                        (user['id'],)
                    )
                
                rows = await cursor.fetchall()
                columns = [description[0] for description in cursor.description]
                addresses = [dict(zip(columns, row)) for row in rows]
                
                return web.json_response({
                    'success': True,
                    'data': {
                        'addresses': addresses,
                        'total': len(addresses)
                    }
                })
                
        except Exception as e:
            logger.error(f"Error listing addresses: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def monitor_address(self, request):
        try:
            user = request['user']
            data = await request.json()
            
            coin_symbol = data.get('coin')
            address = data.get('address')
            label = data.get('label')
            
            if not coin_symbol or not address:
                return web.json_response({
                    'success': False,
                    'error': 'Coin and address are required'
                }, status=400)
            
            if not self.user_manager:
                return web.json_response({
                    'success': False,
                    'error': 'User manager not initialized'
                }, status=500)
            
            if not self.db_manager:
                return web.json_response({
                    'success': False,
                    'error': 'Database manager not initialized'
                }, status=500)
            
            # Проверяем квоту
            if not await self.user_manager.check_quota(user['id'], 'monitored_addresses'):
                return web.json_response({
                    'success': False,
                    'error': 'Maximum monitored addresses quota exceeded'
                }, status=403)
            
            # Проверяем валидность адреса
            from .utils import validate_address_format
            if not validate_address_format(address, coin_symbol):
                return web.json_response({
                    'success': False,
                    'error': 'Invalid address format'
                }, status=400)
            
            # Добавляем адрес для мониторинга
            success = await self.db_manager.add_address_to_monitor(
                user['id'], coin_symbol.upper(), address, label
            )
            
            if success:
                # Обновляем монитор, если он запущен
                user_id_str = str(user['id'])
                if user_id_str in self.monitors and coin_symbol.upper() in self.monitors[user_id_str]:
                    monitor = self.monitors[user_id_str][coin_symbol.upper()]
                    await monitor.monitor_address(address)
                
                return web.json_response({
                    'success': True,
                    'message': f'Address {address} added to monitoring'
                })
            else:
                return web.json_response({
                    'success': False,
                    'error': 'Failed to add address to monitoring'
                }, status=500)
                
        except json.JSONDecodeError:
            return web.json_response({
                'success': False,
                'error': 'Invalid JSON'
            }, status=400)
        except Exception as e:
            logger.error(f"Error monitoring address: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def stop_monitoring_address(self, request):
        try:
            user = request['user']
            address_id = int(request.match_info['address_id'])
            
            if not self.db_manager:
                return web.json_response({
                    'success': False,
                    'error': 'Database manager not initialized'
                }, status=500)
            
            async with self.db_manager.connection.cursor() as cursor:
                await cursor.execute(
                    "SELECT coin, address FROM monitored_addresses WHERE id = ? AND user_id = ?",
                    (address_id, user['id'])
                )
                address_data = await cursor.fetchone()
                
                if not address_data:
                    return web.json_response({
                        'success': False,
                        'error': 'Address not found'
                    }, status=404)
                
                coin, address = address_data
                
                await cursor.execute(
                    "UPDATE monitored_addresses SET is_active = 0 WHERE id = ?",
                    (address_id,)
                )
                await self.db_manager.connection.commit()
                
                # Останавливаем мониторинг если активен
                user_id_str = str(user['id'])
                if user_id_str in self.monitors and coin in self.monitors[user_id_str]:
                    monitor = self.monitors[user_id_str][coin]
                    await monitor.stop_monitoring_address(address)
                
                return web.json_response({
                    'success': True,
                    'message': f'Stopped monitoring address {address}'
                })
                
        except ValueError:
            return web.json_response({
                'success': False,
                'error': 'Invalid address ID'
            }, status=400)
        except Exception as e:
            logger.error(f"Error stopping monitoring: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def get_address_balance(self, request):
        try:
            user = request['user']
            coin_symbol = request.match_info['coin_symbol'].upper()
            address = request.match_info['address']
            
            if not self.db_manager:
                return web.json_response({
                    'success': False,
                    'error': 'Database manager not initialized'
                }, status=500)
            
            # Проверяем права доступа к адресу
            async with self.db_manager.connection.cursor() as cursor:
                await cursor.execute(
                    "SELECT id FROM monitored_addresses WHERE user_id = ? AND coin = ? AND address = ? AND is_active = 1",
                    (user['id'], coin_symbol, address)
                )
                if not await cursor.fetchone():
                    return web.json_response({
                        'success': False,
                        'error': 'Address not found or access denied'
                    }, status=404)
            
            from . import create_client
            
            client = await create_client(coin_symbol)
            
            balance = await client.get_balance(address)
            
            return web.json_response({
                'success': True,
                'data': {
                    'coin': coin_symbol,
                    'address': address,
                    'balance': balance,
                    'formatted': f"{balance:.8f} {coin_symbol}"
                }
            })
        except Exception as e:
            logger.error(f"Error getting address balance: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    # Мониторинг
    async def start_monitor(self, request):
        try:
            user = request['user']
            coin_symbol = request.match_info['coin_symbol'].upper()
            
            if not self.user_manager:
                return web.json_response({
                    'success': False,
                    'error': 'User manager not initialized'
                }, status=500)
            
            if not self.db_manager:
                return web.json_response({
                    'success': False,
                    'error': 'Database manager not initialized'
                }, status=500)
            
            # Проверяем квоту
            if not await self.user_manager.check_quota(user['id'], 'concurrent_monitors'):
                return web.json_response({
                    'success': False,
                    'error': 'Maximum concurrent monitors quota exceeded'
                }, status=403)
            
            user_id_str = str(user['id'])
            
            if user_id_str not in self.monitors:
                self.monitors[user_id_str] = {}
            
            if coin_symbol in self.monitors[user_id_str]:
                return web.json_response({
                    'success': False,
                    'error': f'Monitor for {coin_symbol} is already running'
                }, status=400)
            
            from . import create_connection_pool, create_monitor
            
            if coin_symbol not in self.connection_pools:
                self.connection_pools[coin_symbol] = create_connection_pool()
            
            monitor = await create_monitor(
                user_id=user['id'],
                coin_symbol=coin_symbol,
                db_manager=self.db_manager,
                connection_pool=self.connection_pools[coin_symbol],
                on_transaction=self._on_transaction_callback
            )
            
            success = await monitor.initialize()
            
            if success:
                self.monitors[user_id_str][coin_symbol] = monitor
                asyncio.create_task(monitor.start())
                
                # Сохраняем состояние монитора
                await self.db_manager.save_monitor_state(
                    user['id'], coin_symbol, f"monitor_{coin_symbol}", 'running'
                )
                
                return web.json_response({
                    'success': True,
                    'data': {
                        'message': f'Monitor for {coin_symbol} started successfully',
                        'monitor_id': f"monitor_{coin_symbol}"
                    }
                })
            else:
                return web.json_response({
                    'success': False,
                    'error': f'Failed to initialize monitor for {coin_symbol}'
                }, status=500)
                
        except Exception as e:
            logger.error(f"Failed to start monitor: {e}")
            return web.json_response({
                'success': False,
                'error': f'Failed to start monitor: {str(e)}'
            }, status=500)
    
    async def stop_monitor(self, request):
        try:
            user = request['user']
            coin_symbol = request.match_info['coin_symbol'].upper()
            
            user_id_str = str(user['id'])
            
            if user_id_str not in self.monitors or coin_symbol not in self.monitors[user_id_str]:
                return web.json_response({
                    'success': False,
                    'error': f'Monitor for {coin_symbol} is not running'
                }, status=400)
            
            monitor = self.monitors[user_id_str].pop(coin_symbol)
            await monitor.close()
            
            if not self.db_manager:
                return web.json_response({
                    'success': False,
                    'error': 'Database manager not initialized'
                }, status=500)
            
            # Обновляем состояние монитора
            await self.db_manager.save_monitor_state(
                user['id'], coin_symbol, f"monitor_{coin_symbol}", 'stopped'
            )
            
            if not self.monitors[user_id_str]:
                del self.monitors[user_id_str]
            
            return web.json_response({
                'success': True,
                'message': f'Monitor for {coin_symbol} stopped successfully'
            })
        except Exception as e:
            logger.error(f"Error stopping monitor: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def get_monitor_status(self, request):
        try:
            user = request['user']
            coin_symbol = request.match_info['coin_symbol'].upper()
            
            user_id_str = str(user['id'])
            
            if user_id_str in self.monitors and coin_symbol in self.monitors[user_id_str]:
                monitor = self.monitors[user_id_str][coin_symbol]
                stats = monitor.get_stats()
                
                return web.json_response({
                    'success': True,
                    'data': {
                        'coin': coin_symbol,
                        'running': True,
                        'stats': stats
                    }
                })
            else:
                if not self.db_manager:
                    return web.json_response({
                        'success': False,
                        'error': 'Database manager not initialized'
                    }, status=500)
                
                # Проверяем в базе данных
                monitors = await self.db_manager.get_user_monitors(user['id'])
                monitor_info = next((m for m in monitors if m['coin'] == coin_symbol), None)
                
                return web.json_response({
                    'success': True,
                    'data': {
                        'coin': coin_symbol,
                        'running': False,
                        'last_status': monitor_info['status'] if monitor_info else 'unknown'
                    }
                })
        except Exception as e:
            logger.error(f"Error getting monitor status: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    # Сбор средств
    async def collect_funds(self, request):
        try:
            user = request['user']
            coin_symbol = request.match_info['coin_symbol'].upper()
            data = await request.json()
            
            # Проверяем права на сбор средств
            if not user.get('can_collect_funds', 0):
                return web.json_response({
                    'success': False,
                    'error': 'Funds collection not permitted for your account'
                }, status=403)
            
            address = data.get('address')
            private_key = data.get('private_key')
            master_address = data.get('master_address')
            
            if not address or not private_key:
                return web.json_response({
                    'success': False,
                    'error': 'Address and private_key are required'
                }, status=400)
            
            from . import create_connection_pool, create_funds_collector
            
            if coin_symbol not in self.connection_pools:
                self.connection_pools[coin_symbol] = create_connection_pool()
            
            collector = await create_funds_collector(
                user_id=user['id'],
                coin_symbol=coin_symbol,
                master_address=master_address,
                connection_pool=self.connection_pools[coin_symbol]
            )
            
            result = await collector.collect_funds(address, private_key, self.db_manager)
            
            return web.json_response(result)
            
        except json.JSONDecodeError:
            return web.json_response({
                'success': False,
                'error': 'Invalid JSON'
            }, status=400)
        except Exception as e:
            logger.error(f"Error collecting funds: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    # Транзакции
    async def list_transactions(self, request):
        try:
            user = request['user']
            coin = request.query.get('coin')
            address = request.query.get('address')
            status = request.query.get('status')
            limit = int(request.query.get('limit', 50))
            offset = int(request.query.get('offset', 0))
            
            if not self.db_manager:
                return web.json_response({
                    'success': False,
                    'error': 'Database manager not initialized'
                }, status=500)
            
            async with self.db_manager.connection.cursor() as cursor:
                query = "SELECT * FROM transactions WHERE user_id = ?"
                params = [user['id']]
                
                if coin:
                    query += " AND coin = ?"
                    params.append(coin.upper())
                
                if address:
                    query += " AND address = ?"
                    params.append(address)
                
                if status:
                    query += " AND status = ?"
                    params.append(status)
                
                query += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
                params.extend([limit, offset])
                
                await cursor.execute(query, params)
                rows = await cursor.fetchall()
                columns = [description[0] for description in cursor.description]
                transactions = [dict(zip(columns, row)) for row in rows]
                
                # Получаем общее количество
                count_query = "SELECT COUNT(*) FROM transactions WHERE user_id = ?"
                count_params = [user['id']]
                
                if coin:
                    count_query += " AND coin = ?"
                    count_params.append(coin.upper())
                
                if address:
                    count_query += " AND address = ?"
                    count_params.append(address)
                
                if status:
                    count_query += " AND status = ?"
                    count_params.append(status)
                
                await cursor.execute(count_query, count_params)
                total = (await cursor.fetchone())[0]
                
                return web.json_response({
                    'success': True,
                    'data': {
                        'transactions': transactions,
                        'total': total,
                        'limit': limit,
                        'offset': offset
                    }
                })
                
        except Exception as e:
            logger.error(f"Error listing transactions: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def get_transaction(self, request):
        try:
            user = request['user']
            txid = request.match_info['txid']
            
            if not self.db_manager:
                return web.json_response({
                    'success': False,
                    'error': 'Database manager not initialized'
                }, status=500)
            
            async with self.db_manager.connection.cursor() as cursor:
                await cursor.execute(
                    "SELECT * FROM transactions WHERE user_id = ? AND txid = ?",
                    (user['id'], txid)
                )
                row = await cursor.fetchone()
                
                if not row:
                    return web.json_response({
                        'success': False,
                        'error': 'Transaction not found'
                    }, status=404)
                
                columns = [description[0] for description in cursor.description]
                transaction = dict(zip(columns, row))
                
                return web.json_response({
                    'success': True,
                    'data': transaction
                })
                
        except Exception as e:
            logger.error(f"Error getting transaction: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    # Админские эндпоинты
    async def admin_list_users(self, request):
        user = request['user']
        
        if user['role'] != 'admin':
            return web.json_response({
                'success': False,
                'error': 'Admin access required'
            }, status=403)
        
        if not self.user_manager:
            return web.json_response({
                'success': False,
                'error': 'User manager not initialized'
            }, status=500)
        
        page = int(request.query.get('page', 1))
        per_page = int(request.query.get('per_page', 20))
        
        result = await self.user_manager.list_users(page, per_page)
        
        if result['success']:
            return web.json_response({
                'success': True,
                'data': result
            })
        else:
            return web.json_response({
                'success': False,
                'error': result['error']
            }, status=500)
    
    async def admin_create_user(self, request):
        user = request['user']
        
        if user['role'] != 'admin':
            return web.json_response({
                'success': False,
                'error': 'Admin access required'
            }, status=403)
        
        if not self.user_manager:
            return web.json_response({
                'success': False,
                'error': 'User manager not initialized'
            }, status=500)
        
        try:
            data = await request.json()
            username = data.get('username')
            email = data.get('email')
            role = data.get('role', 'user')
            quotas = data.get('quotas', {})
            
            if not username:
                return web.json_response({
                    'success': False,
                    'error': 'Username is required'
                }, status=400)
            
            result = await self.user_manager.create_user(username, email, role, quotas)
            
            if result['success']:
                return web.json_response({
                    'success': True,
                    'data': {
                        'user_id': result['user_id'],
                        'username': result['username'],
                        'api_key': result['api_key'],
                        'role': result['role'],
                        'quotas': result['quotas']
                    }
                })
            else:
                return web.json_response({
                    'success': False,
                    'error': result['error']
                }, status=400)
                
        except json.JSONDecodeError:
            return web.json_response({
                'success': False,
                'error': 'Invalid JSON'
            }, status=400)
        except Exception as e:
            logger.error(f"Error creating user: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def admin_get_user(self, request):
        user = request['user']
        
        if user['role'] != 'admin':
            return web.json_response({
                'success': False,
                'error': 'Admin access required'
            }, status=403)
        
        if not self.user_manager:
            return web.json_response({
                'success': False,
                'error': 'User manager not initialized'
            }, status=500)
        
        try:
            user_id = int(request.match_info['user_id'])
            
            user_data = await self.user_manager.get_user_by_id(user_id)
            
            if user_data:
                return web.json_response({
                    'success': True,
                    'data': user_data
                })
            else:
                return web.json_response({
                    'success': False,
                    'error': 'User not found'
                }, status=404)
                
        except ValueError:
            return web.json_response({
                'success': False,
                'error': 'Invalid user ID'
            }, status=400)
        except Exception as e:
            logger.error(f"Error getting user: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def admin_update_user(self, request):
        user = request['user']
        
        if user['role'] != 'admin':
            return web.json_response({
                'success': False,
                'error': 'Admin access required'
            }, status=403)
        
        if not self.user_manager:
            return web.json_response({
                'success': False,
                'error': 'User manager not initialized'
            }, status=500)
        
        try:
            user_id = int(request.match_info['user_id'])
            data = await request.json()
            
            success = await self.user_manager.update_user(user_id, data)
            
            if success:
                return web.json_response({
                    'success': True,
                    'message': 'User updated successfully'
                })
            else:
                return web.json_response({
                    'success': False,
                    'error': 'Failed to update user'
                }, status=500)
                
        except json.JSONDecodeError:
            return web.json_response({
                'success': False,
                'error': 'Invalid JSON'
            }, status=400)
        except ValueError:
            return web.json_response({
                'success': False,
                'error': 'Invalid user ID'
            }, status=400)
        except Exception as e:
            logger.error(f"Error updating user: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def admin_delete_user(self, request):
        user = request['user']
        
        if user['role'] != 'admin':
            return web.json_response({
                'success': False,
                'error': 'Admin access required'
            }, status=403)
        
        if not self.user_manager:
            return web.json_response({
                'success': False,
                'error': 'User manager not initialized'
            }, status=500)
        
        try:
            user_id = int(request.match_info['user_id'])
            
            success = await self.user_manager.delete_user(user_id)
            
            if success:
                return web.json_response({
                    'success': True,
                    'message': 'User deleted successfully'
                })
            else:
                return web.json_response({
                    'success': False,
                    'error': 'Failed to delete user'
                }, status=500)
                
        except ValueError:
            return web.json_response({
                'success': False,
                'error': 'Invalid user ID'
            }, status=400)
        except Exception as e:
            logger.error(f"Error deleting user: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def admin_reset_api_key(self, request):
        user = request['user']
        
        if user['role'] != 'admin':
            return web.json_response({
                'success': False,
                'error': 'Admin access required'
            }, status=403)
        
        if not self.user_manager:
            return web.json_response({
                'success': False,
                'error': 'User manager not initialized'
            }, status=500)
        
        try:
            user_id = int(request.match_info['user_id'])
            
            new_api_key = await self.user_manager.regenerate_api_key(user_id)
            
            if new_api_key:
                return web.json_response({
                    'success': True,
                    'data': {
                        'new_api_key': new_api_key,
                        'message': 'API key reset successfully'
                    }
                })
            else:
                return web.json_response({
                    'success': False,
                    'error': 'Failed to reset API key'
                }, status=500)
                
        except ValueError:
            return web.json_response({
                'success': False,
                'error': 'Invalid user ID'
            }, status=400)
        except Exception as e:
            logger.error(f"Error resetting API key: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    async def admin_get_stats(self, request):
        user = request['user']
        
        if user['role'] != 'admin':
            return web.json_response({
                'success': False,
                'error': 'Admin access required'
            }, status=403)
        
        if not self.db_manager:
            return web.json_response({
                'success': False,
                'error': 'Database manager not initialized'
            }, status=500)
        
        try:
            stats = await self.db_manager.get_stats()
            
            return web.json_response({
                'success': True,
                'data': stats
            })
        except Exception as e:
            logger.error(f"Error getting admin stats: {e}")
            return web.json_response({
                'success': False,
                'error': str(e)
            }, status=500)
    
    def _on_transaction_callback(self, transaction_info):
        logger.info(f"New transaction: {transaction_info}")
        
        try:
            from .monitoring import metrics
            metrics.record_transaction(
                coin=transaction_info.get('coin', 'unknown'),
                amount=transaction_info.get('amount', 0),
                status=transaction_info.get('status', 'unknown')
            )
        except ImportError:
            pass
    
    async def start(self):
        """Запустить REST API сервер"""
        if not await self.initialize_database():
            logger.error("Failed to initialize database, REST API cannot start")
            return None
        
        runner = web.AppRunner(self.app)
        await runner.setup()
        
        site = web.TCPSite(runner, self.host, self.port)
        await site.start()
        
        logger.info(f"REST API запущен на http://{self.host}:{self.port}")
        
        return runner
    
    async def stop(self, runner):
        """Остановить REST API сервер"""
        for user_id_str, user_monitors in list(self.monitors.items()):
            for coin_symbol, monitor in list(user_monitors.items()):
                try:
                    await monitor.close()
                except Exception as e:
                    logger.error(f"Error stopping monitor for {coin_symbol}: {e}")
        
        for coin_symbol, pool in list(self.connection_pools.items()):
            try:
                await pool.close()
            except Exception as e:
                logger.error(f"Error closing connection pool for {coin_symbol}: {e}")
        
        if self.db_manager:
            try:
                await self.db_manager.close()
            except Exception as e:
                logger.error(f"Error closing database: {e}")
        
        if self.user_manager:
            try:
                await self.user_manager.close()
            except Exception as e:
                logger.error(f"Error closing user manager: {e}")
        
        await runner.cleanup()
        logger.info("REST API остановлен")

def create_rest_api(host: str = '0.0.0.0', port: int = 8080) -> BlockchainRestAPI:
    return BlockchainRestAPI(host, port)

async def run_rest_api(host: str = '0.0.0.0', port: int = 8080):
    api = create_rest_api(host, port)
    runner = await api.start()
    
    if not runner:
        logger.error("Failed to start REST API")
        return
    
    try:
        await asyncio.Event().wait()
    except KeyboardInterrupt:
        pass
    finally:
        await api.stop(runner)