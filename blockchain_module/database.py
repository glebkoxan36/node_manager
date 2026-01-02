"""
SQLite Database Manager для Blockchain Module с поддержкой мультипользовательства
"""

import logging
import json
from typing import Dict, List, Any, Optional
import aiosqlite

logger = logging.getLogger(__name__)

class SQLiteDBManager:
    """Асинхронный менеджер SQLite базы данных с поддержкой пользователей"""
    
    def __init__(self, db_path: str = "blockchain_module.db"):
        self.db_path = db_path
        self.connection = None
        
    async def initialize(self):
        """Инициализировать базу данных и создать таблицы"""
        self.connection = await aiosqlite.connect(self.db_path)
        await self._create_tables()
        logger.info(f"SQLite database initialized: {self.db_path}")
    
    async def _create_tables(self):
        """Создать необходимые таблицы"""
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
            
            # Таблица отслеживаемых адресов (теперь с user_id)
            await cursor.execute('''
                CREATE TABLE IF NOT EXISTS monitored_addresses (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    coin TEXT NOT NULL,
                    address TEXT NOT NULL,
                    label TEXT,
                    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    is_active BOOLEAN DEFAULT 1,
                    settings TEXT DEFAULT '{}'
                )
            ''')
            
            # Таблица транзакций
            await cursor.execute('''
                CREATE TABLE IF NOT EXISTS transactions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    coin TEXT NOT NULL,
                    txid TEXT NOT NULL,
                    address TEXT NOT NULL,
                    amount REAL NOT NULL,
                    confirmations INTEGER DEFAULT 0,
                    status TEXT DEFAULT 'pending',
                    timestamp TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    metadata TEXT DEFAULT '{}'
                )
            ''')
            
            # Таблица сборов средств
            await cursor.execute('''
                CREATE TABLE IF NOT EXISTS collections (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    coin TEXT NOT NULL,
                    address TEXT NOT NULL,
                    txid TEXT NOT NULL UNIQUE,
                    amount_sent REAL NOT NULL,
                    total_amount REAL NOT NULL,
                    fee REAL NOT NULL,
                    master_address TEXT NOT NULL,
                    status TEXT DEFAULT 'pending',
                    timestamp TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    metadata TEXT DEFAULT '{}'
                )
            ''')
            
            # Таблица мониторов пользователей
            await cursor.execute('''
                CREATE TABLE IF NOT EXISTS user_monitors (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    coin TEXT NOT NULL,
                    monitor_id TEXT NOT NULL,
                    status TEXT DEFAULT 'stopped',
                    settings TEXT DEFAULT '{}',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_active TIMESTAMP,
                    is_active BOOLEAN DEFAULT 1
                )
            ''')
            
            # Таблица пользовательских квот
            await cursor.execute('''
                CREATE TABLE IF NOT EXISTS user_quotas (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER UNIQUE NOT NULL,
                    max_monitored_addresses INTEGER DEFAULT 100,
                    max_daily_api_calls INTEGER DEFAULT 10000,
                    max_concurrent_monitors INTEGER DEFAULT 5,
                    can_collect_funds BOOLEAN DEFAULT 0,
                    can_create_addresses BOOLEAN DEFAULT 1,
                    can_view_transactions BOOLEAN DEFAULT 1
                )
            ''')
            
            # Индексы
            await cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_monitored_addresses_user_coin 
                ON monitored_addresses(user_id, coin, is_active)
            ''')
            await cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_transactions_user_coin_status 
                ON transactions(user_id, coin, status)
            ''')
            await cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_transactions_user_address 
                ON transactions(user_id, address)
            ''')
            await cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_collections_user_coin 
                ON collections(user_id, coin)
            ''')
            await cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_user_monitors_user_coin 
                ON user_monitors(user_id, coin, is_active)
            ''')
            
            await self.connection.commit()
    
    async def get_all_addresses_for_coin(self, user_id: int, coin: str) -> List[str]:
        async with self.connection.cursor() as cursor:
            await cursor.execute(
                "SELECT address FROM monitored_addresses WHERE user_id = ? AND coin = ? AND is_active = 1",
                (user_id, coin.upper())
            )
            rows = await cursor.fetchall()
            return [row[0] for row in rows]
    
    async def save_transaction(self, user_id: int, **kwargs) -> bool:
        try:
            metadata = kwargs.get('metadata', '{}')
            if isinstance(metadata, dict):
                metadata = json.dumps(metadata)
            
            async with self.connection.cursor() as cursor:
                await cursor.execute(
                    "SELECT id FROM transactions WHERE user_id = ? AND coin = ? AND txid = ? AND address = ?",
                    (user_id, kwargs.get('coin'), kwargs.get('txid'), kwargs.get('address'))
                )
                existing = await cursor.fetchone()
                
                if existing:
                    await cursor.execute('''
                        UPDATE transactions 
                        SET amount = ?, confirmations = ?, status = ?, 
                            timestamp = ?, updated_at = CURRENT_TIMESTAMP,
                            metadata = ?
                        WHERE id = ?
                    ''', (
                        kwargs.get('amount'),
                        kwargs.get('confirmations', 0),
                        kwargs.get('status', 'pending'),
                        kwargs.get('timestamp'),
                        metadata,
                        existing[0]
                    ))
                else:
                    await cursor.execute('''
                        INSERT INTO transactions 
                        (user_id, coin, txid, address, amount, confirmations, status, timestamp, metadata)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        user_id,
                        kwargs.get('coin'),
                        kwargs.get('txid'),
                        kwargs.get('address'),
                        kwargs.get('amount'),
                        kwargs.get('confirmations', 0),
                        kwargs.get('status', 'pending'),
                        kwargs.get('timestamp'),
                        metadata
                    ))
                
                await cursor.execute('''
                    UPDATE monitored_addresses 
                    SET added_at = CURRENT_TIMESTAMP
                    WHERE user_id = ? AND coin = ? AND address = ?
                ''', (user_id, kwargs.get('coin'), kwargs.get('address')))
                
                await self.connection.commit()
                return True
                
        except Exception as e:
            logger.error(f"Error saving transaction to database: {e}")
            return False
    
    async def get_pending_transactions(self, user_id: int, coin: str) -> List[Dict]:
        async with self.connection.cursor() as cursor:
            await cursor.execute(
                "SELECT * FROM transactions WHERE user_id = ? AND coin = ? AND status IN ('pending', 'mempool', 'confirming')",
                (user_id, coin.upper())
            )
            rows = await cursor.fetchall()
            columns = [description[0] for description in cursor.description]
            return [dict(zip(columns, row)) for row in rows]
    
    async def update_transaction_status(self, user_id: int, txid: str, status: str, confirmations: int) -> bool:
        try:
            async with self.connection.cursor() as cursor:
                await cursor.execute(
                    "UPDATE transactions SET status = ?, confirmations = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND txid = ?",
                    (status, confirmations, user_id, txid)
                )
                await self.connection.commit()
                return cursor.rowcount > 0
        except Exception as e:
            logger.error(f"Error updating transaction status: {e}")
            return False
    
    async def add_address_to_monitor(self, user_id: int, coin: str, address: str, label: str = None) -> bool:
        try:
            async with self.connection.cursor() as cursor:
                await cursor.execute(
                    "INSERT OR REPLACE INTO monitored_addresses (user_id, coin, address, label) VALUES (?, ?, ?, ?)",
                    (user_id, coin.upper(), address, label)
                )
                await self.connection.commit()
                return cursor.rowcount > 0
        except Exception as e:
            logger.error(f"Error adding address to monitor: {e}")
            return False
    
    async def remove_address_from_monitor(self, user_id: int, coin: str, address: str) -> bool:
        try:
            async with self.connection.cursor() as cursor:
                await cursor.execute(
                    "UPDATE monitored_addresses SET is_active = 0 WHERE user_id = ? AND coin = ? AND address = ?",
                    (user_id, coin.upper(), address)
                )
                await self.connection.commit()
                return cursor.rowcount > 0
        except Exception as e:
            logger.error(f"Error removing address from monitor: {e}")
            return False
    
    async def save_collection_record(self, user_id: int, **kwargs) -> bool:
        try:
            metadata = kwargs.get('metadata', '{}')
            if isinstance(metadata, dict):
                metadata = json.dumps(metadata)
            
            async with self.connection.cursor() as cursor:
                await cursor.execute('''
                    INSERT OR REPLACE INTO collections 
                    (user_id, coin, address, txid, amount_sent, total_amount, fee, 
                     master_address, status, timestamp, metadata)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    user_id,
                    kwargs.get('coin'),
                    kwargs.get('address'),
                    kwargs.get('txid'),
                    kwargs.get('amount_sent'),
                    kwargs.get('total_amount'),
                    kwargs.get('fee'),
                    kwargs.get('master_address'),
                    kwargs.get('status', 'pending'),
                    kwargs.get('timestamp'),
                    metadata
                ))
                await self.connection.commit()
                return True
        except Exception as e:
            logger.error(f"Error saving collection record: {e}")
            return False
    
    async def get_transactions_for_address(self, user_id: int, coin: str, address: str) -> List[Dict]:
        async with self.connection.cursor() as cursor:
            await cursor.execute(
                "SELECT * FROM transactions WHERE user_id = ? AND coin = ? AND address = ? ORDER BY timestamp DESC",
                (user_id, coin.upper(), address)
            )
            rows = await cursor.fetchall()
            columns = [description[0] for description in cursor.description]
            return [dict(zip(columns, row)) for row in rows]
    
    async def get_collections_for_address(self, user_id: int, coin: str, address: str) -> List[Dict]:
        async with self.connection.cursor() as cursor:
            await cursor.execute(
                "SELECT * FROM collections WHERE user_id = ? AND coin = ? AND address = ? ORDER BY timestamp DESC",
                (user_id, coin.upper(), address)
            )
            rows = await cursor.fetchall()
            columns = [description[0] for description in cursor.description]
            return [dict(zip(columns, row)) for row in rows]
    
    async def save_monitor_state(self, user_id: int, coin: str, monitor_id: str, status: str, settings: dict = None) -> bool:
        try:
            settings_str = json.dumps(settings) if settings else '{}'
            
            async with self.connection.cursor() as cursor:
                await cursor.execute('''
                    INSERT OR REPLACE INTO user_monitors 
                    (user_id, coin, monitor_id, status, settings, last_active, is_active)
                    VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, 1)
                ''', (
                    user_id,
                    coin.upper(),
                    monitor_id,
                    status,
                    settings_str
                ))
                await self.connection.commit()
                return True
        except Exception as e:
            logger.error(f"Error saving monitor state: {e}")
            return False
    
    async def get_user_monitors(self, user_id: int) -> List[Dict]:
        async with self.connection.cursor() as cursor:
            await cursor.execute(
                "SELECT * FROM user_monitors WHERE user_id = ? AND is_active = 1 ORDER BY last_active DESC",
                (user_id,)
            )
            rows = await cursor.fetchall()
            columns = [description[0] for description in cursor.description]
            return [dict(zip(columns, row)) for row in rows]
    
    async def get_stats(self, user_id: int = None) -> Dict:
        async with self.connection.cursor() as cursor:
            stats = {}
            
            if user_id:
                # Статистика для конкретного пользователя
                tables = ['monitored_addresses', 'transactions', 'collections', 'user_monitors']
                for table in tables:
                    await cursor.execute(f"SELECT COUNT(*) FROM {table} WHERE user_id = ?", (user_id,))
                    row = await cursor.fetchone()
                    stats[f'{table}_count'] = row[0]
                
                await cursor.execute('''
                    SELECT coin, COUNT(*) as count 
                    FROM monitored_addresses 
                    WHERE user_id = ? AND is_active = 1 
                    GROUP BY coin
                ''', (user_id,))
                rows = await cursor.fetchall()
                stats['active_addresses_by_coin'] = {row[0]: row[1] for row in rows}
                
                await cursor.execute('''
                    SELECT 
                        COUNT(*) as total_transactions,
                        SUM(amount) as total_volume
                    FROM transactions
                    WHERE user_id = ?
                ''', (user_id,))
                row = await cursor.fetchone()
                if row:
                    columns = [description[0] for description in cursor.description]
                    stats.update(dict(zip(columns, row)))
            else:
                # Глобальная статистика
                tables = ['monitored_addresses', 'transactions', 'collections', 'user_monitors', 'users']
                for table in tables:
                    await cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    row = await cursor.fetchone()
                    stats[f'{table}_count'] = row[0]
            
            return stats
    
    async def vacuum(self):
        try:
            await self.connection.execute("VACUUM")
            logger.info("Database vacuum completed")
        except Exception as e:
            logger.error(f"Error vacuuming database: {e}")
    
    async def close(self):
        if self.connection:
            await self.connection.close()
            logger.info("Database connection closed")