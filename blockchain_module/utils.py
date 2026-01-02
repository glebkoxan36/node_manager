"""
Утилиты для работы с блокчейном
"""
import re
from typing import Dict, Any

def validate_address_format(address: str, coin_symbol: str) -> bool:
    if not address or not isinstance(address, str):
        return False
    
    coin_symbol = coin_symbol.upper()
    address = address.strip()
    
    if len(address) < 26 or len(address) > 95:
        return False
    
    address_prefixes = {
        'BTC': ['1', '3', 'bc1'],
        'LTC': ['L', 'M', 'ltc1'],
        'DOGE': ['D', 'A'],
        'ETH': ['0x'],
    }
    
    if coin_symbol in address_prefixes:
        prefixes = address_prefixes[coin_symbol]
        if not any(address.startswith(prefix) for prefix in prefixes):
            return False
    
    if coin_symbol in ['BTC', 'LTC'] and address.startswith(('bc1', 'ltc1')):
        bech32_chars = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
        address_lower = address.lower()
        
        if address.startswith('bc1'):
            main_part = address_lower[3:]
            if len(address) not in [42, 62]:
                return False
        elif address.startswith('ltc1'):
            main_part = address_lower[4:]
            if len(address) not in [43, 63]:
                return False
        else:
            return False
            
        if not all(c in bech32_chars for c in main_part):
            return False
    
    if coin_symbol in ['ETH'] and address.startswith('0x'):
        if len(address) != 42:
            return False
        if not re.match(r'^0x[0-9a-fA-F]{40}$', address):
            return False
    
    if coin_symbol in ['BTC', 'LTC', 'DOGE']:
        if not re.match(r'^[1-9A-HJ-NP-Za-km-z]+$', address):
            return False
    
    return True

def satoshi_to_coin(satoshi: int, decimals: int = 8) -> float:
    if satoshi == 0:
        return 0.0
    return satoshi / (10 ** decimals)

def coin_to_satoshi(coin_amount: float, decimals: int = 8) -> int:
    if coin_amount == 0:
        return 0
    return int(coin_amount * (10 ** decimals))

def format_amount(amount: float, coin_symbol: str) -> str:
    coin_symbol = coin_symbol.upper()
    
    if amount == 0:
        return f"0 {coin_symbol}"
    
    if amount < 0.000001:
        return f"{amount:.10f} {coin_symbol}"
    elif amount < 0.001:
        return f"{amount:.8f} {coin_symbol}"
    elif amount < 1:
        return f"{amount:.6f} {coin_symbol}"
    elif amount < 1000:
        return f"{amount:.4f} {coin_symbol}"
    else:
        return f"{amount:.2f} {coin_symbol}"

def parse_transaction_data(tx_data: Dict[str, Any], coin_symbol: str) -> Dict[str, Any]:
    result = {
        'coin': coin_symbol,
        'txid': tx_data.get('txid', ''),
        'confirmations': tx_data.get('confirmations', 0),
        'timestamp': tx_data.get('time'),
        'inputs': [],
        'outputs': []
    }
    
    for vin in tx_data.get('vin', []):
        input_data = {
            'txid': vin.get('txid'),
            'vout': vin.get('vout'),
            'address': vin.get('address'),
            'amount': vin.get('value', 0)
        }
        result['inputs'].append(input_data)
    
    for vout in tx_data.get('vout', []):
        output_data = {
            'n': vout.get('n'),
            'amount': vout.get('value', 0)
        }
        
        script_pubkey = vout.get('scriptPubKey', {})
        if 'addresses' in script_pubkey:
            output_data['addresses'] = script_pubkey['addresses']
        elif 'address' in script_pubkey:
            output_data['addresses'] = [script_pubkey['address']]
        
        result['outputs'].append(output_data)
    
    return result

def is_valid_api_key(api_key: str) -> bool:
    if not api_key or not isinstance(api_key, str):
        return False
    
    if len(api_key) < 10:
        return False
    
    if not re.match(r'^[a-zA-Z0-9\-_]+$', api_key):
        return False
    
    return True