"""
Пул соединений для управления HTTP/WebSocket соединениями
"""

import asyncio
import aiohttp
import logging
import time
from typing import Optional, Dict, Any, AsyncIterator
from contextlib import asynccontextmanager

logger = logging.getLogger(__name__)

class ConnectionPool:
    
    def __init__(self, max_connections: int = 10):
        self.max_connections = max_connections
        
        self._session: Optional[aiohttp.ClientSession] = None
        self._websockets: Dict[str, aiohttp.ClientWebSocketResponse] = {}
        self._pool_lock = asyncio.Lock()
        
        self.stats = {
            'total_requests': 0,
            'failed_connections': 0,
            'successful_connections': 0,
            'created_at': time.time(),
        }
        
        logger.info(f"Connection pool initialized (max_connections={max_connections})")
    
    async def get_session(self) -> aiohttp.ClientSession:
        async with self._pool_lock:
            if self._session is None or self._session.closed:
                connector = aiohttp.TCPConnector(
                    limit=self.max_connections,
                    limit_per_host=self.max_connections
                )
                
                timeout = aiohttp.ClientTimeout(total=30)
                
                self._session = aiohttp.ClientSession(
                    connector=connector,
                    timeout=timeout,
                    headers={'User-Agent': 'BlockchainModule/2.0.0'}
                )
                
                logger.info("HTTP session created")
            
            self.stats['total_requests'] += 1
            
            return self._session
    
    async def get_websocket_connection(self, url: str, **kwargs) -> aiohttp.ClientWebSocketResponse:
        """Получить WebSocket соединение без контекстного менеджера"""
        ws_key = f"ws_{hash(url)}"
        
        async with self._pool_lock:
            if ws_key in self._websockets:
                ws = self._websockets[ws_key]
                if not ws.closed:
                    self.stats['total_requests'] += 1
                    return ws
        
        session = await self.get_session()
        
        default_kwargs = {
            'heartbeat': 30,
            'timeout': 30,
            'autoping': True
        }
        default_kwargs.update(kwargs)
        
        retries = 0
        max_retries = 3
        ws = None
        
        while retries < max_retries:
            try:
                start_time = time.time()
                ws = await session.ws_connect(url, **default_kwargs)
                connect_time = time.time() - start_time
                
                async with self._pool_lock:
                    self._websockets[ws_key] = ws
                    self.stats['total_requests'] += 1
                    self.stats['successful_connections'] += 1
                
                logger.info(f"WebSocket connected to {url[:50]}... in {connect_time:.2f}s")
                return ws
                
            except Exception as e:
                retries += 1
                logger.warning(f"WebSocket connection failed (attempt {retries}/{max_retries}): {e}")
                self.stats['failed_connections'] += 1
                
                if retries < max_retries:
                    await asyncio.sleep(2 ** retries)
                else:
                    logger.error(f"Failed to connect to WebSocket after {max_retries} attempts: {url}")
                    raise ConnectionError(f"Failed to connect to WebSocket: {url}")
    
    async def close_websocket(self, url: str):
        ws_key = f"ws_{hash(url)}"
        
        async with self._pool_lock:
            if ws_key in self._websockets:
                ws = self._websockets[ws_key]
                if not ws.closed:
                    try:
                        await ws.close()
                        logger.info(f"WebSocket connection closed: {url[:50]}...")
                    except Exception as e:
                        logger.warning(f"Error closing WebSocket: {e}")
                
                del self._websockets[ws_key]
    
    async def close(self):
        async with self._pool_lock:
            for ws_key, ws in list(self._websockets.items()):
                if not ws.closed:
                    try:
                        await ws.close()
                    except Exception as e:
                        logger.warning(f"Error closing WebSocket: {e}")
            
            self._websockets.clear()
            
            if self._session and not self._session.closed:
                try:
                    await self._session.close()
                except Exception as e:
                    logger.warning(f"Error closing HTTP session: {e}")
            
            self._session = None
            
            logger.info("Connection pool closed")
    
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()
    
    def is_healthy(self) -> bool:
        try:
            if self._session is None or self._session.closed:
                return False
            
            if self.stats['failed_connections'] > self.stats['successful_connections'] * 0.5:
                return False
            
            return True
            
        except Exception:
            return False