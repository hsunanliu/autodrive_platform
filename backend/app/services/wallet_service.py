# backend/app/services/wallet_service.py
"""
錢包管理服務
處理用戶錢包的創建、導入、簽署等功能
"""

import logging
from typing import Dict, Any, Optional
from datetime import datetime
import hashlib
import base64
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class WalletService:
    """錢包服務類 - 後端託管模式"""
    
    def __init__(self):
        self.node_url = settings.SUI_NODE_URL
    
    @staticmethod
    def _derive_key(password: str, salt: bytes) -> bytes:
        """從密碼派生加密密鑰"""
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
        )
        return base64.urlsafe_b64encode(kdf.derive(password.encode()))
    
    @staticmethod
    def encrypt_private_key(private_key: str, password: str) -> Dict[str, str]:
        """加密私鑰"""
        # 生成隨機 salt
        salt = hashlib.sha256(password.encode()).digest()
        
        # 派生加密密鑰
        key = WalletService._derive_key(password, salt)
        
        # 加密私鑰
        f = Fernet(key)
        encrypted = f.encrypt(private_key.encode())
        
        return {
            'encrypted_key': base64.b64encode(encrypted).decode(),
            'salt': base64.b64encode(salt).decode(),
        }
    
    @staticmethod
    def decrypt_private_key(encrypted_data: Dict[str, str], password: str) -> str:
        """解密私鑰"""
        try:
            # 解碼 salt
            salt = base64.b64decode(encrypted_data['salt'])
            
            # 派生密鑰
            key = WalletService._derive_key(password, salt)
            
            # 解密
            f = Fernet(key)
            encrypted = base64.b64decode(encrypted_data['encrypted_key'])
            decrypted = f.decrypt(encrypted)
            
            return decrypted.decode()
        except Exception as e:
            logger.error(f"解密失敗: {str(e)}")
            raise ValueError("密碼錯誤或數據損壞")
    
    async def create_wallet(self, password: str) -> Dict[str, Any]:
        """
        創建新錢包
        
        Returns:
            {
                'address': '0x...',
                'public_key': '0x...',
                'encrypted_private_key': {...},
                'mnemonic': 'word1 word2 ...',  # 僅返回一次
            }
        """
        try:
            # 使用 pysui 創建錢包
            # 注意：這裡簡化實現，實際應該使用 pysui 庫
            
            # 臨時方案：生成模擬數據
            # TODO: 替換為真實的 pysui 實現
            import secrets
            
            # 生成助記詞（12個單詞）
            wordlist = [
                'abandon', 'ability', 'able', 'about', 'above', 'absent',
                'absorb', 'abstract', 'absurd', 'abuse', 'access', 'accident',
                'account', 'accuse', 'achieve', 'acid', 'acoustic', 'acquire',
            ]
            mnemonic = ' '.join(secrets.choice(wordlist) for _ in range(12))
            
            # 生成地址和密鑰（模擬）
            private_key = '0x' + secrets.token_hex(32)
            public_key = '0x' + secrets.token_hex(32)
            address = '0x' + secrets.token_hex(32)
            
            # 加密私鑰
            encrypted = self.encrypt_private_key(private_key, password)
            
            return {
                'success': True,
                'address': address,
                'public_key': public_key,
                'encrypted_private_key': encrypted,
                'mnemonic': mnemonic,
            }
            
        except Exception as e:
            logger.error(f"創建錢包失敗: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }
    
    async def import_wallet(
        self,
        mnemonic: str,
        password: str
    ) -> Dict[str, Any]:
        """
        從助記詞導入錢包
        
        Args:
            mnemonic: 助記詞
            password: 加密密碼
            
        Returns:
            {
                'address': '0x...',
                'public_key': '0x...',
                'encrypted_private_key': {...},
            }
        """
        try:
            # TODO: 使用 pysui 從助記詞恢復錢包
            
            # 臨時模擬實現
            import hashlib
            
            # 從助記詞生成確定性的地址
            hash_obj = hashlib.sha256(mnemonic.encode())
            address = '0x' + hash_obj.hexdigest()[:64]
            
            private_key = '0x' + hashlib.sha256((mnemonic + 'private').encode()).hexdigest()
            public_key = '0x' + hashlib.sha256((mnemonic + 'public').encode()).hexdigest()
            
            # 加密私鑰
            encrypted = self.encrypt_private_key(private_key, password)
            
            return {
                'success': True,
                'address': address,
                'public_key': public_key,
                'encrypted_private_key': encrypted,
            }
            
        except Exception as e:
            logger.error(f"導入錢包失敗: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }
    
    async def get_balance(self, address: str) -> Dict[str, Any]:
        """查詢錢包餘額"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.node_url,
                    json={
                        'jsonrpc': '2.0',
                        'id': 1,
                        'method': 'suix_getBalance',
                        'params': [address],
                    },
                    headers={'Content-Type': 'application/json'},
                    timeout=10.0
                )
                response.raise_for_status()
                result = response.json()
            
            if 'error' in result:
                raise Exception(result['error'].get('message', 'Unknown error'))
            
            balance_mist = int(result['result']['totalBalance'])
            balance_sui = balance_mist / 1_000_000_000
            
            return {
                'success': True,
                'balance_mist': balance_mist,
                'balance_sui': balance_sui,
                'address': address,
            }
            
        except Exception as e:
            logger.error(f"查詢餘額失敗: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'balance_mist': 0,
                'balance_sui': 0.0,
            }
    
    async def sign_and_execute_transaction(
        self,
        encrypted_private_key: Dict[str, str],
        password: str,
        transaction_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        簽署並執行交易
        
        Args:
            encrypted_private_key: 加密的私鑰數據
            password: 解密密碼
            transaction_data: 交易數據
            
        Returns:
            {
                'success': bool,
                'transaction_digest': str,
                'effects': dict,
            }
        """
        try:
            # 解密私鑰
            private_key = self.decrypt_private_key(encrypted_private_key, password)
            
            # TODO: 使用 pysui 簽署並執行交易
            # 這裡需要實現實際的交易簽署邏輯
            
            # 臨時模擬實現
            import secrets
            transaction_digest = '0x' + secrets.token_hex(32)
            
            return {
                'success': True,
                'transaction_digest': transaction_digest,
                'effects': {
                    'status': 'success',
                    'gasUsed': 1000000,
                },
            }
            
        except ValueError as e:
            # 密碼錯誤
            return {
                'success': False,
                'error': '密碼錯誤'
            }
        except Exception as e:
            logger.error(f"簽署交易失敗: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }


# 創建全局實例
wallet_service = WalletService()
