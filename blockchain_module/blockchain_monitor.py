"""
Монитор блокчейна для отслеживания транзакций с использованием WebSocket
с поддержкой мультипользовательства
"""

import asyncio
import logging
import json
import time
from typing import Dict, List, Optional, Any, Callable

logger = logging.getLogger(__name__)

class BlockchainMonitor:
    
    def __init__(self, user_id: int, coin_symbol: str, db_manager, 
                 connection_pool=None, on_transaction_callback: Optional[Callable] = None):
        self.user_id = user_id
        self.coin_symbol = coin_symbol.upper()
        self.db_manager = db_manager
        self.connection_pool = connection_pool
        self.on_transaction_callback = on_transaction_callback
        
        from .nownodes_client import UniversalNownodesClient
        from .monitoring import metrics
        
        self.client = UniversalNownodesClient(coin_symbol, connection_pool)
        self.metrics = metrics
        
        # Генерируем WebSocket URL на основе конфига
        from .config import BlockchainConfig
        config = BlockchainConfig.get_coin_config(coin_symbol)
        blockbook_url = config.get('blockbook_url', '')
        if blockbook_url:
            # Преобразуем HTTP URL в WebSocket URL
            self.ws_url = blockbook_url.replace('https://', 'wss://').replace('http://', 'ws://')
        else:
            # Fallback URL
            self.ws_url = f"wss://{coin_symbol.lower()}book.nownodes.io"
        
        self.connected = False
        self.websocket = None
        self.monitored_addresses = set()
        self.reconnect_attempts = 0
        self.max_reconnect_attempts = 10
        self.is_running = False
        
        self.stats = {
            'messages_received': 0,
            'transactions_processed': 0,
            'last_activity': 0,
            'start_time': time.time(),
            'errors': 0
        }
    
    async def initialize(self):
        try:
            addresses = await self.db_manager.get_all_addresses_for_coin(self.user_id, self.coin_symbol)
            self.monitored_addresses.update(addresses)
            
            logger.info(f"Initialized {self.coin_symbol} monitor for user {self.user_id} with {len(addresses)} addresses")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize monitor: {e}")
            return False
    
    async def monitor_address(self, address: str) -> bool:
        try:
            if not address or len(address) < 26:
                logger.error(f"Invalid address format: {address}")
                return False
            
            success = await self.db_manager.add_address_to_monitor(self.user_id, self.coin_symbol, address)
            
            if success:
                self.monitored_addresses.add(address)
                logger.info(f"Added address to monitor: user {self.user_id} - {self.coin_symbol} - {address[:10]}...")
                
                if hasattr(self.metrics, 'update_monitored_addresses'):
                    self.metrics.update_monitored_addresses(
                        coin=self.coin_symbol,
                        count=len(self.monitored_addresses)
                    )
                
                return True
            return False
                
        except Exception as e:
            logger.error(f"Error monitoring address: {e}")
            return False
    
    async def stop_monitoring_address(self, address: str) -> bool:
        try:
            success = await self.db_manager.remove_address_from_monitor(self.user_id, self.coin_symbol, address)
            
            if success:
                self.monitored_addresses.discard(address)
                logger.info(f"Stopped monitoring address: user {self.user_id} - {self.coin_symbol} - {address[:10]}...")
                
                if hasattr(self.metrics, 'update_monitored_addresses'):
                    self.metrics.update_monitored_addresses(
                        coin=self.coin_symbol,
                        count=len(self.monitored_addresses)
                    )
                
                return True
            return False
                
        except Exception as e:
            logger.error(f"Error stopping monitoring address: {e}")
            return False
    
    async def start(self):
        if self.is_running:
            logger.warning(f"Monitor for {self.coin_symbol} (user {self.user_id}) is already running")
            return False
        
        self.is_running = True
        self.stats['start_time'] = time.time()
        
        logger.info(f"Starting {self.coin_symbol} blockchain monitor for user {self.user_id}...")
        
        while self.is_running:
            try:
                await self._connect_websocket()
                await self._listen_websocket()
                
            except asyncio.CancelledError:
                break
                
            except Exception as e:
                logger.error(f"WebSocket error for {self.coin_symbol} (user {self.user_id}): {e}")
                self.stats['errors'] += 1
                
                if self.reconnect_attempts >= self.max_reconnect_attempts:
                    logger.error(f"Max reconnection attempts reached for {self.coin_symbol} (user {self.user_id})")
                    break
                
                await asyncio.sleep(min(2 ** self.reconnect_attempts, 30))
                self.reconnect_attempts += 1
        
        await self.close()
        return True
    
    async def _connect_websocket(self):
        try:
            if not self.connection_pool:
                # Создаем временную сессию если нет пула соединений
                import aiohttp
                session = aiohttp.ClientSession()
                self.websocket = await session.ws_connect(
                    self.ws_url,
                    heartbeat=30,
                    timeout=30,
                    autoping=True
                )
                self.session = session
            else:
                # Используем пул соединений
                session = await self.connection_pool.get_session()
                self.websocket = await session.ws_connect(
                    self.ws_url,
                    heartbeat=30,
                    timeout=30,
                    autoping=True
                )
            
            self.connected = True
            self.reconnect_attempts = 0
            
            await self._subscribe_to_addresses()
            
            logger.info(f"WebSocket connected for {self.coin_symbol} (user {self.user_id})")
            
            if hasattr(self.metrics, 'update_websocket_connection'):
                self.metrics.update_websocket_connection(
                    coin=self.coin_symbol,
                    connected=True
                )
            
            return True
                
        except Exception as e:
            logger.error(f"Failed to connect WebSocket for {self.coin_symbol} (user {self.user_id}): {e}")
            if hasattr(self.metrics, 'record_websocket_reconnect'):
                self.metrics.record_websocket_reconnect(
                    coin=self.coin_symbol,
                    reason="connection_failed"
                )
            raise
    
    async def _subscribe_to_addresses(self):
        if not self.websocket or not self.connected:
            return
        
        try:
            for address in self.monitored_addresses:
                subscribe_msg = {
                    "method": "subscribe",
                    "params": {
                        "address": address
                    }
                }
                await self.websocket.send_json(subscribe_msg)
                logger.debug(f"Subscribed to address: {address[:10]}...")
                
                if hasattr(self.metrics, 'record_websocket_message'):
                    self.metrics.record_websocket_message(
                        coin=self.coin_symbol,
                        message_type="subscribe",
                        direction="outgoing",
                        size=len(json.dumps(subscribe_msg))
                    )
                
            logger.info(f"Subscribed to {len(self.monitored_addresses)} addresses for user {self.user_id}")
            
        except Exception as e:
            logger.error(f"Error subscribing to addresses: {e}")
    
    async def _listen_websocket(self):
        if not self.websocket:
            return
        
        try:
            async for message in self.websocket:
                if message.type == 1:  # TEXT
                    await self._process_websocket_message(message.data)
                elif message.type == 8:  # CLOSE
                    logger.info(f"WebSocket closed for {self.coin_symbol} (user {self.user_id})")
                    break
                    
        except asyncio.CancelledError:
            raise
        except Exception as e:
            logger.error(f"Error in WebSocket listener for {self.coin_symbol} (user {self.user_id}): {e}")
            raise
    
    async def _process_websocket_message(self, message_data: str):
        try:
            message = json.loads(message_data)
            self.stats['messages_received'] += 1
            self.stats['last_activity'] = time.time()
            
            if hasattr(self.metrics, 'record_websocket_message'):
                self.metrics.record_websocket_message(
                    coin=self.coin_symbol,
                    message_type="data",
                    direction="incoming",
                    size=len(message_data)
                )
            
            if message.get('method') == 'subscribe' and 'params' in message:
                tx_data = message['params']
                await self._process_transaction(tx_data)
            
            elif message.get('method') == 'ping':
                await self._handle_ping(message)
            
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON message for {self.coin_symbol}: {e}")
        except Exception as e:
            logger.error(f"Error processing WebSocket message for {self.coin_symbol}: {e}")
            self.stats['errors'] += 1
    
    async def _process_transaction(self, tx_data: Dict):
        try:
            txid = tx_data.get('txid')
            address = tx_data.get('address')
            amount = tx_data.get('amount', 0)
            confirmations = tx_data.get('confirmations', 0)
            
            if not txid or not address:
                return
            
            if address not in self.monitored_addresses:
                logger.debug(f"Transaction for non-monitored address: {address[:10]}...")
                return
            
            logger.info(f"New transaction detected: user {self.user_id} - {self.coin_symbol} - {txid[:10]}...")
            
            status = 'mempool' if confirmations == 0 else 'confirming'
            if confirmations >= 3:
                status = 'confirmed'
            
            transaction_info = {
                'user_id': self.user_id,
                'coin': self.coin_symbol,
                'txid': txid,
                'address': address,
                'amount': amount,
                'confirmations': confirmations,
                'status': status,
                'timestamp': tx_data.get('timestamp', time.time()),
            }
            
            success = await self.db_manager.save_transaction(**transaction_info)
            
            if success:
                self.stats['transactions_processed'] += 1
                
                if hasattr(self.metrics, 'record_transaction'):
                    self.metrics.record_transaction(
                        coin=self.coin_symbol,
                        amount=amount,
                        status=status
                    )
                
                if self.on_transaction_callback:
                    try:
                        if asyncio.iscoroutinefunction(self.on_transaction_callback):
                            await self.on_transaction_callback(transaction_info)
                        else:
                            self.on_transaction_callback(transaction_info)
                    except Exception as e:
                        logger.error(f"Error in transaction callback: {e}")
                
                logger.info(f"Transaction saved: user {self.user_id} - {txid[:10]}... - {amount:.8f} {self.coin_symbol} - {status}")
            else:
                logger.error(f"Failed to save transaction: {txid[:10]}...")
                
        except Exception as e:
            logger.error(f"Error processing transaction: {e}")
            self.stats['errors'] += 1
    
    async def _handle_ping(self, message: Dict):
        try:
            if self.websocket and self.connected:
                pong_msg = {"method": "pong", "params": message.get('params', {})}
                await self.websocket.send_json(pong_msg)
                
                if hasattr(self.metrics, 'record_websocket_message'):
                    self.metrics.record_websocket_message(
                        coin=self.coin_symbol,
                        message_type="pong",
                        direction="outgoing",
                        size=len(json.dumps(pong_msg))
                    )
                
        except Exception as e:
            logger.error(f"Error handling ping: {e}")
    
    async def close(self):
        self.is_running = False
        self.connected = False
        
        if self.websocket:
            try:
                await self.websocket.close()
            except:
                pass
            self.websocket = None
        
        # Закрываем сессию если она была создана
        if hasattr(self, 'session'):
            try:
                await self.session.close()
            except:
                pass
        
        logger.info(f"Monitor for {self.coin_symbol} (user {self.user_id}) closed")
        
        if hasattr(self.metrics, 'update_websocket_connection'):
            self.metrics.update_websocket_connection(
                coin=self.coin_symbol,
                connected=False
            )
    
    def get_stats(self) -> Dict[str, Any]:
        uptime = time.time() - self.stats['start_time']
        
        return {
            'user_id': self.user_id,
            'coin': self.coin_symbol,
            'connected': self.connected,
            'is_running': self.is_running,
            'monitored_addresses': len(self.monitored_addresses),
            'messages_received': self.stats['messages_received'],
            'transactions_processed': self.stats['transactions_processed'],
            'errors': self.stats['errors'],
            'reconnect_attempts': self.reconnect_attempts,
            'uptime': uptime,
            'last_activity': self.stats['last_activity']
        }
    
    async def get_pending_transactions(self) -> List[Dict]:
        try:
            return await self.db_manager.get_pending_transactions(self.user_id, self.coin_symbol)
        except Exception as e:
            logger.error(f"Error getting pending transactions: {e}")
            return []
    
    async def update_transaction_status(self, txid: str, status: str, confirmations: int) -> bool:
        try:
            return await self.db_manager.update_transaction_status(self.user_id, txid, status, confirmations)
        except Exception as e:
            logger.error(f"Error updating transaction status: {e}")
            return False