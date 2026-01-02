"""
Конфигурация модуля с поддержкой мультипользовательства
"""

import os
import json
import logging
from typing import Dict, Any, Optional, List
from pathlib import Path

logger = logging.getLogger(__name__)

class ConfigManager:
    
    def __init__(self, config_file: Optional[str] = None):
        if config_file:
            self.config_path = Path(config_file)
        else:
            # Создаем директорию configs если не существует
            config_dir = Path(__file__).parent.parent / "configs"
            config_dir.mkdir(exist_ok=True, parents=True)
            self.config_path = config_dir / "module_config.json"
        
        self.default_module_settings = {
            "api_key": "",
            "log_level": "INFO",
            "connection_pool_size": 10,
            "default_confirmations": 3,
            "max_reconnect_attempts": 10,
            "monitoring": {
                "enabled": True,
                "prometheus_port": 9090,
                "metrics_prefix": "blockchain_module"
            },
            "rest_api": {
                "enabled": True,
                "host": "0.0.0.0",
                "port": 8080,
                "api_key_required": True,
                "rate_limit": 100,
                "enable_auth": True
            },
            "multiuser": {
                "enabled": True,
                "default_user_quotas": {
                    "max_monitored_addresses": 100,
                    "max_daily_api_calls": 10000,
                    "max_concurrent_monitors": 5,
                    "can_collect_funds": False,
                    "can_create_addresses": True,
                    "can_view_transactions": True
                },
                "admin_api_key": "",
                "session_timeout": 3600
            }
        }
        
        self.config_data = {}
        self.load_config()
    
    def load_config(self) -> bool:
        try:
            if not self.config_path.exists():
                logger.warning(f"Config file not found: {self.config_path}")
                self.create_default_config()
                return True
            
            with open(self.config_path, 'r', encoding='utf-8') as f:
                self.config_data = json.load(f)
            
            if 'module_settings' not in self.config_data:
                self.config_data['module_settings'] = self.default_module_settings.copy()
            
            if 'coins' not in self.config_data:
                self.config_data['coins'] = {}
            
            # Ensure all default settings are present
            for key, value in self.default_module_settings.items():
                if key not in self.config_data['module_settings']:
                    self.config_data['module_settings'][key] = value
                elif isinstance(value, dict) and key == 'multiuser':
                    # Merge multiuser settings
                    for sub_key, sub_value in value.items():
                        if sub_key not in self.config_data['module_settings'][key]:
                            self.config_data['module_settings'][key][sub_key] = sub_value
            
            logger.info(f"Configuration loaded from {self.config_path}")
            return True
            
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in config file: {e}")
            self.create_default_config()
            return False
        except Exception as e:
            logger.error(f"Error loading config: {e}")
            self.create_default_config()
            return False
    
    def create_default_config(self) -> None:
        self.config_data = {
            'module_settings': self.default_module_settings.copy(),
            'coins': {
                'LTC': {
                    "symbol": "LTC",
                    "name": "Litecoin",
                    "decimals": 8,
                    "blockbook_url": "https://ltcbook.nownodes.io",
                    "required_confirmations": 3,
                    "min_collection_amount": 0.001,
                    "collection_fee": 0.0001
                },
                'DOGE': {
                    "symbol": "DOGE",
                    "name": "Dogecoin",
                    "decimals": 8,
                    "blockbook_url": "https://dogebook.nownodes.io",
                    "required_confirmations": 6,
                    "min_collection_amount": 1.0,
                    "collection_fee": 0.1
                }
            }
        }
        
        self.save_config()
        logger.info("Default configuration created")
    
    def save_config(self) -> bool:
        try:
            self.config_path.parent.mkdir(exist_ok=True, parents=True)
            
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(self.config_data, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Configuration saved to {self.config_path}")
            return True
        except Exception as e:
            logger.error(f"Error saving config: {e}")
            return False
    
    def get_module_setting(self, key: str, default: Any = None) -> Any:
        return self.config_data.get('module_settings', {}).get(key, default)
    
    def set_module_setting(self, key: str, value: Any) -> None:
        if 'module_settings' not in self.config_data:
            self.config_data['module_settings'] = {}
        
        self.config_data['module_settings'][key] = value
        self.save_config()
    
    def get_monitoring_config(self) -> Dict[str, Any]:
        return self.get_module_setting('monitoring', {})
    
    def get_rest_api_config(self) -> Dict[str, Any]:
        return self.get_module_setting('rest_api', {})
    
    def get_multiuser_config(self) -> Dict[str, Any]:
        return self.get_module_setting('multiuser', {})
    
    def get_coin_config(self, coin_symbol: str) -> Dict[str, Any]:
        coin_symbol = coin_symbol.upper()
        
        if coin_symbol in self.config_data.get('coins', {}):
            return self.config_data['coins'][coin_symbol].copy()
        
        return {
            'symbol': coin_symbol,
            'name': coin_symbol,
            'decimals': 8,
            'blockbook_url': f"https://{coin_symbol.lower()}book.nownodes.io",
            'required_confirmations': 3,
            'min_collection_amount': 0.001,
            'collection_fee': 0.0001
        }
    
    def set_coin_config(self, coin_symbol: str, config: Dict[str, Any]) -> bool:
        coin_symbol = coin_symbol.upper()
        
        if 'coins' not in self.config_data:
            self.config_data['coins'] = {}
        
        self.config_data['coins'][coin_symbol] = config
        return self.save_config()
    
    def get_all_coins(self) -> List[str]:
        return list(self.config_data.get('coins', {}).keys())
    
    def get_config_summary(self) -> Dict[str, Any]:
        return {
            'config_file': str(self.config_path.absolute()),
            'configured_coins': self.get_all_coins(),
            'total_coins': len(self.get_all_coins()),
            'multiuser_enabled': self.get_multiuser_config().get('enabled', False)
        }
    
    def validate_coin_config(self, coin_symbol: str) -> Dict[str, Any]:
        errors = []
        warnings = []
        
        coin_symbol = coin_symbol.upper()
        config = self.get_coin_config(coin_symbol)
        
        required_fields = ['symbol', 'name', 'decimals']
        for field in required_fields:
            if field not in config or not config[field]:
                errors.append(f"Missing required field: {field}")
        
        return {
            'valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings,
            'has_warnings': len(warnings) > 0
        }

class BlockchainConfig:
    
    _config_manager: Optional[ConfigManager] = None
    
    @classmethod
    def _get_config_manager(cls) -> ConfigManager:
        if cls._config_manager is None:
            cls._config_manager = ConfigManager()
        return cls._config_manager
    
    @classmethod
    def get_api_key(cls) -> str:
        api_key = cls._get_config_manager().get_module_setting('api_key', '')
        
        if not api_key:
            api_key = os.getenv('NOWNODES_API_KEY', '')
            if api_key:
                cls.set_api_key(api_key)
        
        return api_key
    
    @classmethod
    def set_api_key(cls, api_key: str) -> None:
        cls._get_config_manager().set_module_setting('api_key', api_key)
        logger.info("API key updated in configuration")
    
    @classmethod
    def get_coin_config(cls, coin_symbol: str) -> Dict[str, Any]:
        return cls._get_config_manager().get_coin_config(coin_symbol)
    
    @classmethod
    def add_coin_config(cls, coin_symbol: str, config: Dict[str, Any]) -> bool:
        return cls._get_config_manager().set_coin_config(coin_symbol, config)
    
    @classmethod
    def get_supported_coins(cls) -> List[str]:
        return cls._get_config_manager().get_all_coins()
    
    @classmethod
    def get_module_setting(cls, key: str, default: Any = None) -> Any:
        return cls._get_config_manager().get_module_setting(key, default)
    
    @classmethod
    def get_monitoring_config(cls) -> Dict[str, Any]:
        return cls._get_config_manager().get_monitoring_config()
    
    @classmethod
    def get_rest_api_config(cls) -> Dict[str, Any]:
        return cls._get_config_manager().get_rest_api_config()
    
    @classmethod
    def get_multiuser_config(cls) -> Dict[str, Any]:
        return cls._get_config_manager().get_multiuser_config()
    
    @classmethod
    def is_monitoring_enabled(cls) -> bool:
        monitoring_config = cls.get_monitoring_config()
        return monitoring_config.get('enabled', False)
    
    @classmethod
    def is_rest_api_enabled(cls) -> bool:
        rest_api_config = cls.get_rest_api_config()
        return rest_api_config.get('enabled', False)
    
    @classmethod
    def is_multiuser_enabled(cls) -> bool:
        multiuser_config = cls.get_multiuser_config()
        return multiuser_config.get('enabled', False)
    
    @classmethod
    def get_prometheus_port(cls) -> int:
        monitoring_config = cls.get_monitoring_config()
        return monitoring_config.get('prometheus_port', 9090)
    
    @classmethod
    def get_config_summary(cls) -> Dict[str, Any]:
        return cls._get_config_manager().get_config_summary()
    
    @classmethod
    def reload_config(cls) -> bool:
        if cls._config_manager:
            return cls._config_manager.load_config()
        return False
    
    @classmethod
    def save_config(cls) -> bool:
        if cls._config_manager:
            return cls._get_config_manager().save_config()
        return False
    
    @classmethod
    def is_configured(cls) -> bool:
        return bool(cls.get_api_key() and cls.get_supported_coins())