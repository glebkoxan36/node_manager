"""
Модуль управления пользователями для мультипользовательской системы
"""

import secrets
import hashlib
import json
import logging
import aiosqlite
import time
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
from enum import Enum

logger = logging.getLogger(__name__)

class UserRole(Enum):
    """Роли пользователей"""
    ADMIN = "admin"
    USER = "user"
    VIEWER = "viewer"

class UserStatus(Enum):
    """Статусы пользователей"""
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"
    BANNED = "banned"

class UserManager:
    """Менеджер пользователей с поддержкой мультипользовательской системы"""
    
    def __init__(self, db_path: str = "blockchain_module.db"):
        self.db_path = db_path
        self.connection = None
        
    async def initialize(self):
        """Инициализировать базу данных и создать таблицы пользователей"""
        self.connection = await aiosqlite.connect(self.db_path)
        await self._create_tables()
        await self._create_admin_user()
        logger.info("User management system initialized")
    
    async def _create_tables(self):
        """Создать таблицы для пользователей"""
        async with self.connection.cursor() as cursor:
            # Таблица пользователей
            await cursor.execute('''
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT UNIQUE NOT NULL,
                    email TEXT UNIQUE,
                    api_key TEXT UNIQUE NOT NULL,
                    api_key_hash TEXT NOT NULL,
                    role TEXT DEFAULT 'user',
                    status TEXT DEFAULT 'active',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_login TIMESTAMP,
                    settings TEXT DEFAULT '{}',
                    rate_limit INTEGER DEFAULT 100,
                    is_active BOOLEAN DEFAULT 1
                )
            ''')
            
            # Таблица сессий
            await cursor.execute('''
                CREATE TABLE IF NOT EXISTS user_sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    session_token TEXT UNIQUE NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    expires_at TIMESTAMP,
                    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    ip_address TEXT,
                    user_agent TEXT,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                )
            ''')
            
            # Таблица активностей пользователей
            await cursor.execute('''
                CREATE TABLE IF NOT EXISTS user_activities (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    action TEXT NOT NULL,
                    resource_type TEXT,
                    resource_id TEXT,
                    details TEXT,
                    ip_address TEXT,
                    user_agent TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                )
            ''')
            
            # Таблица квот пользователей
            await cursor.execute('''
                CREATE TABLE IF NOT EXISTS user_quotas (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER UNIQUE NOT NULL,
                    max_monitored_addresses INTEGER DEFAULT 100,
                    max_daily_api_calls INTEGER DEFAULT 10000,
                    max_concurrent_monitors INTEGER DEFAULT 5,
                    can_collect_funds BOOLEAN DEFAULT 0,
                    can_create_addresses BOOLEAN DEFAULT 1,
                    can_view_transactions BOOLEAN DEFAULT 1,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                )
            ''')
            
            # Индексы
            await cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_users_api_key_hash 
                ON users(api_key_hash)
            ''')
            await cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_user_sessions_token 
                ON user_sessions(session_token)
            ''')
            await cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_user_activities_user 
                ON user_activities(user_id, timestamp)
            ''')
            
            await self.connection.commit()
    
    async def _create_admin_user(self):
        """Создать административного пользователя по умолчанию"""
        try:
            async with self.connection.cursor() as cursor:
                await cursor.execute(
                    "SELECT id FROM users WHERE role = ?",
                    (UserRole.ADMIN.value,)
                )
                admin_exists = await cursor.fetchone()
                
                if not admin_exists:
                    admin_api_key = "admin_" + secrets.token_urlsafe(32)
                    api_key_hash = self._hash_api_key(admin_api_key)
                    
                    await cursor.execute('''
                        INSERT INTO users 
                        (username, api_key, api_key_hash, role, settings)
                        VALUES (?, ?, ?, ?, ?)
                    ''', (
                        'admin',
                        admin_api_key,
                        api_key_hash,
                        UserRole.ADMIN.value,
                        json.dumps({'notifications': True, 'theme': 'dark'})
                    ))
                    
                    user_id = cursor.lastrowid
                    
                    # Создаем квоты для администратора
                    await cursor.execute('''
                        INSERT INTO user_quotas 
                        (user_id, max_monitored_addresses, max_daily_api_calls, 
                         max_concurrent_monitors, can_collect_funds, 
                         can_create_addresses, can_view_transactions)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        user_id,
                        1000,  # max_monitored_addresses
                        100000,  # max_daily_api_calls
                        50,  # max_concurrent_monitors
                        1,  # can_collect_funds
                        1,  # can_create_addresses
                        1  # can_view_transactions
                    ))
                    
                    await self.connection.commit()
                    
                    logger.info(f"Admin user created. API Key: {admin_api_key}")
                    print(f"\n Важно: Сохраните API ключ администратора ⚠️")
                    print(f" API Key: {admin_api_key}")
                    print("  Этот ключ нельзя будет восстановить позже!\n")
        except Exception as e:
            logger.error(f"Error creating admin user: {e}")
    
    def _hash_api_key(self, api_key: str) -> str:
        """Хэшировать API ключ для безопасного хранения"""
        return hashlib.sha256(api_key.encode()).hexdigest()
    
    def _generate_api_key(self, prefix: str = "user") -> str:
        """Сгенерировать новый API ключ"""
        return f"{prefix}_{secrets.token_urlsafe(32)}"
    
    async def create_user(self, username: str, email: str = None, 
                         role: str = UserRole.USER.value, 
                         quotas: Dict[str, Any] = None) -> Dict[str, Any]:
        """Создать нового пользователя"""
        try:
            api_key = self._generate_api_key()
            api_key_hash = self._hash_api_key(api_key)
            
            default_quotas = {
                'max_monitored_addresses': 100,
                'max_daily_api_calls': 10000,
                'max_concurrent_monitors': 5,
                'can_collect_funds': False,
                'can_create_addresses': True,
                'can_view_transactions': True
            }
            
            if quotas:
                default_quotas.update(quotas)
            
            async with self.connection.cursor() as cursor:
                await cursor.execute('''
                    INSERT INTO users 
                    (username, email, api_key, api_key_hash, role, settings)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', (
                    username,
                    email,
                    api_key,
                    api_key_hash,
                    role,
                    json.dumps({'notifications': True, 'theme': 'light'})
                ))
                
                user_id = cursor.lastrowid
                
                # Создаем квоты для пользователя
                await cursor.execute('''
                    INSERT INTO user_quotas 
                    (user_id, max_monitored_addresses, max_daily_api_calls, 
                     max_concurrent_monitors, can_collect_funds, 
                     can_create_addresses, can_view_transactions)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    user_id,
                    default_quotas['max_monitored_addresses'],
                    default_quotas['max_daily_api_calls'],
                    default_quotas['max_concurrent_monitors'],
                    1 if default_quotas['can_collect_funds'] else 0,
                    1 if default_quotas['can_create_addresses'] else 0,
                    1 if default_quotas['can_view_transactions'] else 0
                ))
                
                await self.connection.commit()
                
                # Логируем активность
                await self.log_activity(
                    user_id=user_id,
                    action="user_created",
                    resource_type="user",
                    resource_id=str(user_id)
                )
                
                return {
                    'success': True,
                    'user_id': user_id,
                    'username': username,
                    'api_key': api_key,
                    'role': role,
                    'quotas': default_quotas,
                    'message': f'User {username} created successfully'
                }
                
        except aiosqlite.IntegrityError as e:
            if "username" in str(e):
                return {'success': False, 'error': 'Username already exists'}
            elif "email" in str(e):
                return {'success': False, 'error': 'Email already exists'}
            else:
                return {'success': False, 'error': str(e)}
        except Exception as e:
            logger.error(f"Error creating user: {e}")
            return {'success': False, 'error': str(e)}
    
    async def authenticate_user(self, api_key: str) -> Optional[Dict[str, Any]]:
        """Аутентифицировать пользователя по API ключу"""
        try:
            api_key_hash = self._hash_api_key(api_key)
            
            async with self.connection.cursor() as cursor:
                await cursor.execute('''
                    SELECT u.*, q.* 
                    FROM users u
                    LEFT JOIN user_quotas q ON u.id = q.user_id
                    WHERE u.api_key_hash = ? AND u.is_active = 1
                ''', (api_key_hash,))
                
                row = await cursor.fetchone()
                
                if row:
                    columns = [description[0] for description in cursor.description]
                    user_data = dict(zip(columns, row))
                    
                    # Обновляем время последнего входа
                    await cursor.execute(
                        "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?",
                        (user_data['id'],)
                    )
                    await self.connection.commit()
                    
                    # Логируем активность
                    await self.log_activity(
                        user_id=user_data['id'],
                        action="login",
                        resource_type="user",
                        resource_id=str(user_data['id'])
                    )
                    
                    return user_data
                
                return None
                
        except Exception as e:
            logger.error(f"Error authenticating user: {e}")
            return None
    
    async def get_user_by_id(self, user_id: int) -> Optional[Dict[str, Any]]:
        """Получить пользователя по ID"""
        try:
            async with self.connection.cursor() as cursor:
                await cursor.execute('''
                    SELECT u.*, q.* 
                    FROM users u
                    LEFT JOIN user_quotas q ON u.id = q.user_id
                    WHERE u.id = ? AND u.is_active = 1
                ''', (user_id,))
                
                row = await cursor.fetchone()
                if row:
                    columns = [description[0] for description in cursor.description]
                    return dict(zip(columns, row))
                return None
                
        except Exception as e:
            logger.error(f"Error getting user: {e}")
            return None
    
    async def update_user(self, user_id: int, updates: Dict[str, Any]) -> bool:
        """Обновить данные пользователя"""
        try:
            async with self.connection.cursor() as cursor:
                # Обновляем основную информацию
                if 'username' in updates or 'email' in updates or 'role' in updates:
                    set_clause = []
                    params = []
                    
                    if 'username' in updates:
                        set_clause.append("username = ?")
                        params.append(updates['username'])
                    
                    if 'email' in updates:
                        set_clause.append("email = ?")
                        params.append(updates['email'])
                    
                    if 'role' in updates:
                        set_clause.append("role = ?")
                        params.append(updates['role'])
                    
                    if 'status' in updates:
                        set_clause.append("status = ?")
                        params.append(updates['status'])
                    
                    if 'settings' in updates:
                        set_clause.append("settings = ?")
                        params.append(json.dumps(updates['settings']))
                    
                    if set_clause:
                        params.append(user_id)
                        query = f"UPDATE users SET {', '.join(set_clause)} WHERE id = ?"
                        await cursor.execute(query, params)
                
                # Обновляем квоты
                if 'quotas' in updates:
                    quotas = updates['quotas']
                    set_clause = []
                    params = []
                    
                    quota_fields = [
                        'max_monitored_addresses',
                        'max_daily_api_calls',
                        'max_concurrent_monitors',
                        'can_collect_funds',
                        'can_create_addresses',
                        'can_view_transactions'
                    ]
                    
                    for field in quota_fields:
                        if field in quotas:
                            set_clause.append(f"{field} = ?")
                            params.append(1 if quotas[field] else 0 if field in ['can_collect_funds', 'can_create_addresses', 'can_view_transactions'] else quotas[field])
                    
                    if set_clause:
                        params.append(user_id)
                        query = f"UPDATE user_quotas SET {', '.join(set_clause)} WHERE user_id = ?"
                        await cursor.execute(query, params)
                
                await self.connection.commit()
                
                # Логируем активность
                await self.log_activity(
                    user_id=user_id,
                    action="user_updated",
                    resource_type="user",
                    resource_id=str(user_id),
                    details=json.dumps({'updates': updates})
                )
                
                return True
                
        except Exception as e:
            logger.error(f"Error updating user: {e}")
            return False
    
    async def regenerate_api_key(self, user_id: int) -> Optional[str]:
        """Регенерировать API ключ для пользователя"""
        try:
            new_api_key = self._generate_api_key()
            api_key_hash = self._hash_api_key(new_api_key)
            
            async with self.connection.cursor() as cursor:
                await cursor.execute(
                    "UPDATE users SET api_key = ?, api_key_hash = ? WHERE id = ?",
                    (new_api_key, api_key_hash, user_id)
                )
                await self.connection.commit()
                
                # Логируем активность
                await self.log_activity(
                    user_id=user_id,
                    action="api_key_regenerated",
                    resource_type="user",
                    resource_id=str(user_id)
                )
                
                return new_api_key
                
        except Exception as e:
            logger.error(f"Error regenerating API key: {e}")
            return None
    
    async def delete_user(self, user_id: int) -> bool:
        """Удалить пользователя (мягкое удаление)"""
        try:
            async with self.connection.cursor() as cursor:
                await cursor.execute(
                    "UPDATE users SET is_active = 0, status = ? WHERE id = ?",
                    (UserStatus.INACTIVE.value, user_id)
                )
                await self.connection.commit()
                
                # Логируем активность
                await self.log_activity(
                    user_id=user_id,
                    action="user_deleted",
                    resource_type="user",
                    resource_id=str(user_id)
                )
                
                return True
                
        except Exception as e:
            logger.error(f"Error deleting user: {e}")
            return False
    
    async def list_users(self, page: int = 1, per_page: int = 20) -> Dict[str, Any]:
        """Получить список пользователей с пагинацией"""
        try:
            offset = (page - 1) * per_page
            
            async with self.connection.cursor() as cursor:
                # Получаем общее количество пользователей
                await cursor.execute("SELECT COUNT(*) FROM users WHERE is_active = 1")
                total = (await cursor.fetchone())[0]
                
                # Получаем пользователей
                await cursor.execute('''
                    SELECT u.*, q.* 
                    FROM users u
                    LEFT JOIN user_quotas q ON u.id = q.user_id
                    WHERE u.is_active = 1
                    ORDER BY u.created_at DESC
                    LIMIT ? OFFSET ?
                ''', (per_page, offset))
                
                rows = await cursor.fetchall()
                columns = [description[0] for description in cursor.description]
                
                users = []
                for row in rows:
                    user_data = dict(zip(columns, row))
                    # Маскируем API ключ для безопасности
                    if 'api_key' in user_data:
                        user_data['api_key'] = user_data['api_key'][:8] + '...'
                    users.append(user_data)
                
                return {
                    'success': True,
                    'users': users,
                    'pagination': {
                        'page': page,
                        'per_page': per_page,
                        'total': total,
                        'total_pages': (total + per_page - 1) // per_page
                    }
                }
                
        except Exception as e:
            logger.error(f"Error listing users: {e}")
            return {'success': False, 'error': str(e)}
    
    async def check_quota(self, user_id: int, quota_type: str, value: int = 1) -> bool:
        """Проверить, не превышает ли пользователь квоту"""
        try:
            async with self.connection.cursor() as cursor:
                await cursor.execute(
                    "SELECT * FROM user_quotas WHERE user_id = ?",
                    (user_id,)
                )
                row = await cursor.fetchone()
                
                if not row:
                    return False
                
                columns = [description[0] for description in cursor.description]
                quotas = dict(zip(columns, row))
                
                if quota_type == 'monitored_addresses':
                    # Получаем текущее количество отслеживаемых адресов
                    await cursor.execute(
                        "SELECT COUNT(*) FROM monitored_addresses WHERE user_id = ? AND is_active = 1",
                        (user_id,)
                    )
                    current_count = (await cursor.fetchone())[0]
                    return current_count + value <= quotas['max_monitored_addresses']
                
                elif quota_type == 'daily_api_calls':
                    # Получаем количество API вызовов за сегодня
                    today = datetime.now().date()
                    await cursor.execute('''
                        SELECT COUNT(*) FROM user_activities 
                        WHERE user_id = ? AND action LIKE '%api_%' 
                        AND DATE(timestamp) = ?
                    ''', (user_id, today))
                    current_count = (await cursor.fetchone())[0]
                    return current_count + value <= quotas['max_daily_api_calls']
                
                elif quota_type == 'concurrent_monitors':
                    # Получаем количество активных мониторов
                    await cursor.execute(
                        "SELECT COUNT(*) FROM user_monitors WHERE user_id = ? AND is_active = 1",
                        (user_id,)
                    )
                    current_count = (await cursor.fetchone())[0]
                    return current_count + value <= quotas['max_concurrent_monitors']
                
                return True
                
        except Exception as e:
            logger.error(f"Error checking quota: {e}")
            return False
    
    async def log_activity(self, user_id: int, action: str, 
                          resource_type: str = None, 
                          resource_id: str = None,
                          details: str = None,
                          ip_address: str = None,
                          user_agent: str = None):
        """Записать активность пользователя"""
        try:
            async with self.connection.cursor() as cursor:
                await cursor.execute('''
                    INSERT INTO user_activities 
                    (user_id, action, resource_type, resource_id, details, ip_address, user_agent)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    user_id,
                    action,
                    resource_type,
                    resource_id,
                    details,
                    ip_address,
                    user_agent
                ))
                await self.connection.commit()
                
        except Exception as e:
            logger.error(f"Error logging activity: {e}")
    
    async def get_user_stats(self, user_id: int) -> Dict[str, Any]:
        """Получить статистику пользователя"""
        try:
            async with self.connection.cursor() as cursor:
                # Основная статистика
                await cursor.execute('''
                    SELECT 
                        COUNT(DISTINCT ma.address) as monitored_addresses,
                        COUNT(DISTINCT t.txid) as total_transactions,
                        COUNT(DISTINCT CASE WHEN t.status = 'confirmed' THEN t.txid END) as confirmed_transactions,
                        SUM(t.amount) as total_volume,
                        COUNT(DISTINCT c.txid) as total_collections,
                        SUM(c.amount_sent) as total_collected
                    FROM monitored_addresses ma
                    LEFT JOIN transactions t ON ma.address = t.address AND ma.coin = t.coin
                    LEFT JOIN collections c ON ma.address = c.address AND ma.coin = c.coin
                    WHERE ma.user_id = ? AND ma.is_active = 1
                ''', (user_id,))
                
                stats_row = await cursor.fetchone()
                stats_columns = ['monitored_addresses', 'total_transactions', 
                               'confirmed_transactions', 'total_volume',
                               'total_collections', 'total_collected']
                
                stats = dict(zip(stats_columns, stats_row or [0, 0, 0, 0, 0, 0]))
                
                # Активность за последние 7 дней
                await cursor.execute('''
                    SELECT 
                        DATE(timestamp) as date,
                        COUNT(*) as activity_count
                    FROM user_activities
                    WHERE user_id = ? AND timestamp >= DATE('now', '-7 days')
                    GROUP BY DATE(timestamp)
                    ORDER BY date DESC
                ''', (user_id,))
                
                activity_rows = await cursor.fetchall()
                recent_activity = [{'date': row[0], 'count': row[1]} for row in activity_rows]
                
                # Распределение по монетам
                await cursor.execute('''
                    SELECT 
                        coin,
                        COUNT(DISTINCT address) as address_count,
                        COUNT(DISTINCT t.txid) as transaction_count
                    FROM monitored_addresses ma
                    LEFT JOIN transactions t ON ma.address = t.address AND ma.coin = t.coin
                    WHERE ma.user_id = ? AND ma.is_active = 1
                    GROUP BY coin
                ''', (user_id,))
                
                coin_rows = await cursor.fetchall()
                coins_distribution = [
                    {'coin': row[0], 'addresses': row[1], 'transactions': row[2]}
                    for row in coin_rows
                ]
                
                return {
                    'success': True,
                    'stats': stats,
                    'recent_activity': recent_activity,
                    'coins_distribution': coins_distribution
                }
                
        except Exception as e:
            logger.error(f"Error getting user stats: {e}")
            return {'success': False, 'error': str(e)}
    
    async def close(self):
        """Закрыть соединение с базой данных"""
        if self.connection:
            await self.connection.close()
            logger.info("User manager connection closed")

# Глобальный экземпляр менеджера пользователей
_user_manager_instance = None

async def get_user_manager():
    """Получить глобальный экземпляр менеджера пользователей"""
    global _user_manager_instance
    if _user_manager_instance is None:
        _user_manager_instance = UserManager()
        await _user_manager_instance.initialize()
    return _user_manager_instance