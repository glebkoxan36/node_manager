import asyncio
import logging
import time
from typing import Dict, List, Optional, Any

logger = logging.getLogger(__name__)

class FundsCollector:
    
    def __init__(self, user_id: int, coin_symbol: str, master_address: str, 
                 connection_pool=None):
        self.user_id = user_id
        self.coin_symbol = coin_symbol.upper()
        
        from .config import BlockchainConfig
        
        self.master_address = master_address
        self.connection_pool = connection_pool
        
        # Получаем настройки из конфига
        config = BlockchainConfig.get_coin_config(coin_symbol)
        self.collection_fee = config.get('collection_fee', 0.0001)
        self.min_collection_amount = config.get('min_collection_amount', 0.001)
        
        self.is_processing = False
        
        self.stats = {
            'collections': 0,
            'total_collected': 0.0,
            'errors': 0,
            'last_collection': None,
            'successful_collections': 0,
            'failed_collections': 0
        }
    
    async def collect_funds(self, address: str, private_key: str, 
                          db_manager=None) -> Dict:
        start_time = time.time()
        try:
            self.is_processing = True
            logger.info(f"Starting {self.coin_symbol} funds collection from {address[:10]}... for user {self.user_id}")
            
            if not private_key or len(private_key) < 30:
                error_msg = 'Invalid private key'
                logger.error(error_msg)
                
                self.stats['failed_collections'] += 1
                self.stats['errors'] += 1
                
                return {'success': False, 'error': error_msg}
            
            # Ленивый импорт клиента
            from .nownodes_client import UniversalNownodesClient
            client = UniversalNownodesClient(self.coin_symbol, self.connection_pool)
            
            utxos = await client.get_address_utxos(address)
            if not utxos:
                error_msg = 'No UTXOs found'
                logger.info(f"{error_msg} for address {address[:10]}...")
                
                self.stats['failed_collections'] += 1
                
                return {'success': False, 'error': error_msg}
            
            confirmed_utxos = [utxo for utxo in utxos if utxo.get('confirmations', 0) >= 1]
            if not confirmed_utxos:
                error_msg = 'No confirmed UTXOs'
                logger.info(f"{error_msg} for address {address[:10]}...")
                
                self.stats['failed_collections'] += 1
                
                return {'success': False, 'error': error_msg}
            
            total_amount = sum(utxo.get('amount', 0) for utxo in confirmed_utxos)
            
            if total_amount < self.min_collection_amount:
                error_msg = f'Amount too small: {total_amount:.8f}'
                logger.info(f"{error_msg} {self.coin_symbol}")
                
                self.stats['failed_collections'] += 1
                
                return {
                    'success': False, 
                    'error': error_msg, 
                    'amount': total_amount
                }
            
            amount_to_send = total_amount - self.collection_fee
            
            if amount_to_send <= 0:
                error_msg = 'Amount after fee is zero or negative'
                logger.warning(error_msg)
                
                self.stats['failed_collections'] += 1
                self.stats['errors'] += 1
                
                return {'success': False, 'error': error_msg}
            
            raw_tx = await self.create_collection_transaction(client, confirmed_utxos, amount_to_send)
            if not raw_tx:
                error_msg = 'Failed to create transaction'
                logger.error(error_msg)
                
                self.stats['failed_collections'] += 1
                self.stats['errors'] += 1
                
                return {'success': False, 'error': error_msg}
            
            signed_tx = await self.sign_transaction_with_key(client, raw_tx, private_key)
            if not signed_tx:
                error_msg = 'Failed to sign transaction'
                logger.error(error_msg)
                
                self.stats['failed_collections'] += 1
                self.stats['errors'] += 1
                
                return {'success': False, 'error': error_msg}
            
            result = await client.send_raw_transaction(signed_tx)
            
            if 'error' in result:
                error_msg = f"Failed to send transaction: {result['error']}"
                logger.error(error_msg)
                
                self.stats['failed_collections'] += 1
                self.stats['errors'] += 1
                
                return {'success': False, 'error': result['error']}
            
            txid = result.get('result')
            if not txid:
                error_msg = 'No TXID in response'
                logger.error(error_msg)
                
                self.stats['failed_collections'] += 1
                self.stats['errors'] += 1
                
                return {'success': False, 'error': error_msg}
            
            self.stats['collections'] += 1
            self.stats['successful_collections'] += 1
            self.stats['total_collected'] += amount_to_send
            self.stats['last_collection'] = time.time()
            
            duration = time.time() - start_time
            
            logger.info(f"Successfully collected {amount_to_send:.8f} {self.coin_symbol} from {address[:10]}... in {duration:.2f}s for user {self.user_id}")
            logger.info(f"Collection TXID: {txid}")
            
            if db_manager and hasattr(db_manager, 'save_collection_record'):
                await self.save_collection_record(db_manager, address, txid, amount_to_send, total_amount)
            
            # Обновляем метрики
            try:
                from .monitoring import metrics
                metrics.update_health_status(
                    coin=self.coin_symbol,
                    component="collector",
                    check="collection",
                    healthy=True,
                    duration=duration
                )
                metrics.record_funds_collection(
                    coin=self.coin_symbol,
                    amount=amount_to_send,
                    fee=self.collection_fee,
                    status="success"
                )
            except ImportError:
                pass
            
            return {
                'success': True,
                'user_id': self.user_id,
                'txid': txid,
                'amount_sent': amount_to_send,
                'total_amount': total_amount,
                'fee': self.collection_fee,
                'from_address': address,
                'to_address': self.master_address,
                'coin': self.coin_symbol,
                'timestamp': time.time(),
                'duration': duration,
                'utxos_count': len(confirmed_utxos)
            }
            
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"Error collecting funds for user {self.user_id}: {e}")
            self.stats['failed_collections'] += 1
            self.stats['errors'] += 1
            
            return {'success': False, 'error': str(e), 'duration': duration}
        finally:
            self.is_processing = False
    
    async def create_collection_transaction(self, client, utxos: List[Dict], amount_to_send: float) -> Optional[str]:
        try:
            inputs = []
            for utxo in utxos:
                inputs.append({
                    "txid": utxo['txid'],
                    "vout": utxo['vout']
                })
            
            outputs = {
                self.master_address: round(amount_to_send, 8)
            }
            
            result = await client.create_raw_transaction(inputs, outputs)
            
            if 'error' in result:
                logger.error(f"RPC error creating transaction: {result['error']}")
                return None
            
            return result.get('result')
            
        except Exception as e:
            logger.error(f"Error creating collection transaction: {e}")
            return None
    
    async def sign_transaction_with_key(self, client, raw_tx: str, private_key: str) -> Optional[str]:
        try:
            result = await client.sign_raw_transaction(raw_tx, [private_key])
            
            if 'error' in result:
                logger.error(f"Signing error: {result['error']}")
                return None
            
            signed_data = result.get('result', {})
            if not signed_data.get('complete', False):
                logger.error(f"Transaction signing not complete: {signed_data}")
                return None
            
            return signed_data.get('hex')
            
        except Exception as e:
            logger.error(f"Error signing transaction: {e}")
            return None
    
    async def save_collection_record(self, db_manager, address: str, txid: str, 
                                   amount_sent: float, total_amount: float):
        try:
            await db_manager.save_collection_record(
                user_id=self.user_id,
                coin=self.coin_symbol,
                address=address,
                txid=txid,
                amount_sent=amount_sent,
                total_amount=total_amount,
                fee=self.collection_fee,
                master_address=self.master_address,
                timestamp=time.time()
            )
            
            logger.debug(f"Collection record saved for user {self.user_id}, address {address[:10]}...")
            
        except Exception as e:
            logger.error(f"Error saving collection record: {e}")
    
    async def check_collection_eligibility(self, address: str) -> Dict:
        start_time = time.time()
        
        try:
            from .nownodes_client import UniversalNownodesClient
            client = UniversalNownodesClient(self.coin_symbol, self.connection_pool)
            
            utxos = await client.get_address_utxos(address)
            
            confirmed_utxos = []
            
            for utxo in utxos:
                if utxo.get('confirmations', 0) >= 1:
                    confirmed_utxos.append(utxo)
            
            confirmed_total = sum(utxo.get('amount', 0) for utxo in confirmed_utxos)
            can_collect = confirmed_total >= self.min_collection_amount
            amount_after_fee = confirmed_total - self.collection_fee if can_collect else 0
            
            if amount_after_fee <= 0:
                can_collect = False
            
            duration = time.time() - start_time
            
            return {
                'success': True,
                'user_id': self.user_id,
                'can_collect': can_collect,
                'confirmed_balance': confirmed_total,
                'min_collection_amount': self.min_collection_amount,
                'collection_fee': self.collection_fee,
                'amount_after_fee': amount_after_fee if amount_after_fee > 0 else 0,
                'coin': self.coin_symbol,
                'address': address,
                'duration': duration
            }
            
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"Error checking collection eligibility for user {self.user_id}: {e}")
            
            return {'success': False, 'error': str(e), 'duration': duration}
    
    def get_stats(self) -> Dict[str, Any]:
        success_rate = 0
        if self.stats['collections'] > 0:
            success_rate = self.stats['successful_collections'] / self.stats['collections']
        
        return {
            'user_id': self.user_id,
            'coin': self.coin_symbol,
            'master_address': self.master_address[:10] + '...',
            'collections': self.stats['collections'],
            'successful_collections': self.stats['successful_collections'],
            'failed_collections': self.stats['failed_collections'],
            'success_rate': success_rate,
            'total_collected': self.stats['total_collected'],
            'errors': self.stats['errors'],
            'last_collection': self.stats['last_collection'],
            'is_processing': self.is_processing
        }
    
    def is_healthy(self) -> bool:
        try:
            if self.stats['errors'] > 10 and self.stats['collections'] == 0:
                return False
            
            if (self.stats['last_collection'] and 
                time.time() - self.stats['last_collection'] > 86400 and 
                self.stats['errors'] > 0):
                return False
            
            return True
            
        except Exception:
            return False