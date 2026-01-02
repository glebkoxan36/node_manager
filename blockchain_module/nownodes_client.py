import aiohttp
import json
import logging
import time
from typing import Dict, List, Any, Optional
from .config import BlockchainConfig
from .monitoring import monitor_api_request, metrics

logger = logging.getLogger(__name__)

class UniversalNownodesClient:
    
    def __init__(self, coin_symbol: str, connection_pool=None):
        self.coin_symbol = coin_symbol.upper()
        self.config = BlockchainConfig.get_coin_config(self.coin_symbol)
        self.api_key = BlockchainConfig.get_api_key()
        
        self.connection_pool = connection_pool
        
        self.base_url = self.config['blockbook_url']
        self.rpc_url = f"https://{self.coin_symbol.lower()}.nownodes.io"
        
        self.headers = {"api-key": self.api_key} if self.api_key else {}
        
        self.stats = {
            'requests': 0,
            'errors': 0,
            'last_request': 0,
            'total_response_time': 0
        }
    
    @monitor_api_request
    async def _make_request(self, method: str, url: str, **kwargs) -> Dict[str, Any]:
        session = None
        try:
            if self.connection_pool:
                session = await self.connection_pool.get_session()
            else:
                connector = aiohttp.TCPConnector(limit=10)
                timeout = aiohttp.ClientTimeout(total=30)
                session = aiohttp.ClientSession(connector=connector, timeout=timeout)
            
            headers = kwargs.pop('headers', {})
            headers.update(self.headers)
            
            start_time = time.time()
            
            async with session.request(method, url, headers=headers, **kwargs) as response:
                response_time = time.time() - start_time
                self.stats['requests'] += 1
                self.stats['total_response_time'] += response_time
                self.stats['last_request'] = time.time()
                
                if response.status == 200:
                    result = await response.json()
                    
                    metrics.record_api_request(
                        coin=self.coin_symbol,
                        endpoint=url.split('/')[-1] if '/' in url else url,
                        method=method,
                        duration=response_time,
                        status_code=response.status
                    )
                    
                    return result
                else:
                    error_text = await response.text()
                    logger.error(f"HTTP {response.status} for {url}: {error_text}")
                    self.stats['errors'] += 1
                    
                    metrics.record_api_error(
                        coin=self.coin_symbol,
                        endpoint=url.split('/')[-1] if '/' in url else url,
                        error_type=f"HTTP_{response.status}"
                    )
                    
                    return {"error": f"HTTP {response.status}: {error_text}"}
                    
        except Exception as e:
            logger.error(f"Request error for {self.coin_symbol}: {e}")
            self.stats['errors'] += 1
            
            metrics.record_api_error(
                coin=self.coin_symbol,
                endpoint=url.split('/')[-1] if '/' in url else url,
                error_type=type(e).__name__
            )
            
            return {"error": str(e)}
        finally:
            if not self.connection_pool and session and not session.closed:
                await session.close()
    
    async def make_rpc_call(self, method: str, params: list = None) -> Dict:
        if params is None:
            params = []
            
        payload = {
            "jsonrpc": "2.0",
            "id": "blockchain_module",
            "method": method,
            "params": params
        }
        
        start_time = time.time()
        result = await self._make_request('POST', self.rpc_url, json=payload, timeout=30)
        
        metrics.record_api_request(
            coin=self.coin_symbol,
            endpoint="rpc",
            method=method,
            duration=time.time() - start_time,
            status_code=200 if 'error' not in result else 500
        )
        
        return result
    
    @monitor_api_request
    async def get_address_utxos(self, address: str) -> List[Dict]:
        try:
            url = f"{self.base_url}/api/v2/utxo/{address}"
            result = await self._make_request('GET', url, timeout=30)
            
            if 'error' in result:
                return []
            
            formatted_utxos = []
            for utxo in result:
                try:
                    value = utxo.get('value', '0')
                    value_int = int(value)
                    
                    amount = value_int / (10 ** 8)
                    
                    formatted_utxos.append({
                        'txid': utxo.get('txid', ''),
                        'vout': utxo.get('vout', 0),
                        'address': address,
                        'amount': amount,
                        'confirmations': utxo.get('confirmations', 0)
                    })
                except Exception as e:
                    logger.warning(f"Error processing UTXO: {e}")
                    continue
            
            return formatted_utxos
                    
        except Exception as e:
            logger.error(f"Error getting UTXOs for {self.coin_symbol}: {e}")
            return []
    
    @monitor_api_request
    async def get_address_info(self, address: str) -> Dict:
        url = f"{self.base_url}/api/v2/address/{address}"
        return await self._make_request('GET', url, timeout=30)
    
    @monitor_api_request
    async def get_transaction(self, txid: str) -> Dict:
        url = f"{self.base_url}/api/v2/tx/{txid}"
        result = await self._make_request('GET', url, timeout=30)
        
        if 'error' not in result:
            return result
        
        logger.warning(f"Blockbook API failed for {txid}, trying RPC...")
        rpc_result = await self.make_rpc_call("getrawtransaction", [txid, True])
        
        if 'error' in rpc_result:
            return rpc_result
        return rpc_result.get('result', {})
    
    @monitor_api_request
    async def get_blockchain_info(self) -> Dict:
        result = await self.make_rpc_call("getblockchaininfo")
        if 'error' in result:
            return result
        return result.get('result', {})
    
    @monitor_api_request
    async def send_raw_transaction(self, signed_tx: str) -> Dict:
        result = await self.make_rpc_call("sendrawtransaction", [signed_tx])
        return result
    
    @monitor_api_request
    async def create_raw_transaction(self, inputs: List[Dict], outputs: Dict) -> Dict:
        result = await self.make_rpc_call("createrawtransaction", [inputs, outputs])
        return result
    
    @monitor_api_request
    async def sign_raw_transaction(self, raw_tx: str, private_keys: List[str] = None) -> Dict:
        if private_keys is None:
            private_keys = []
        
        result = await self.make_rpc_call("signrawtransactionwithkey", [raw_tx, private_keys])
        return result
    
    async def get_balance(self, address: str) -> float:
        try:
            info = await self.get_address_info(address)
            if 'error' not in info:
                balance = info.get('balance', 0)
                if isinstance(balance, str):
                    return float(balance)
                return balance
            return 0.0
        except Exception as e:
            logger.error(f"Error getting balance: {e}")
            return 0.0
    
    def get_stats(self) -> Dict[str, Any]:
        avg_response_time = 0
        if self.stats['requests'] > 0:
            avg_response_time = self.stats['total_response_time'] / self.stats['requests']
        
        error_rate = 0
        if self.stats['requests'] > 0:
            error_rate = self.stats['errors'] / self.stats['requests']
        
        return {
            'coin': self.coin_symbol,
            'requests': self.stats['requests'],
            'errors': self.stats['errors'],
            'error_rate': error_rate,
            'avg_response_time': avg_response_time,
            'last_request': self.stats['last_request'],
            'api_key_configured': bool(self.api_key)
        }
    
    def is_healthy(self) -> bool:
        try:
            if not self.api_key:
                return False
            
            if not self.config:
                return False
            
            if self.stats['errors'] > self.stats['requests'] * 0.5:
                return False
            
            if time.time() - self.stats['last_request'] > 300 and self.stats['requests'] > 0:
                return False
            
            return True
            
        except Exception:
            return False