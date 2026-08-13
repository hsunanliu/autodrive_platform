/**
 * DID Resolver
 * 解析 DID 並獲取 DID 文檔
 *
 * 解析流程：
 * 1. 驗證 DID 格式
 * 2. 從區塊鏈讀取 DID 文檔
 * 3. 驗證文檔有效性
 * 4. 返回 DID 文檔
 */

import { SuiClient } from '@mysten/sui.js/client';
import type { DIDDocument } from './creator';

/**
 * DID 解析結果
 */
export interface DIDResolutionResult {
  didDocument: DIDDocument | null;
  didResolutionMetadata: DIDResolutionMetadata;
  didDocumentMetadata: DIDDocumentMetadata;
}

export interface DIDResolutionMetadata {
  contentType?: string;
  error?: 'invalidDid' | 'notFound' | 'representationNotSupported' | 'methodNotSupported';
  message?: string;
}

export interface DIDDocumentMetadata {
  created?: string;
  updated?: string;
  deactivated?: boolean;
  versionId?: string;
  nextUpdate?: string;
  nextVersionId?: string;
}

/**
 * DID 註冊表配置
 */
export interface DIDRegistryConfig {
  rpcUrl: string;
  packageId: string;  // DID Registry 智能合約包 ID
  registryObjectId: string;  // DID Registry 對象 ID
}

export class DIDResolver {
  private suiClient: SuiClient;
  private config: DIDRegistryConfig;
  private cache: Map<string, DIDDocument>;
  private cacheTTL: number = 5 * 60 * 1000;  // 5 分鐘緩存

  constructor(config: DIDRegistryConfig) {
    this.config = config;
    this.suiClient = new SuiClient({ url: config.rpcUrl });
    this.cache = new Map();
  }

  /**
   * 解析 DID
   * @param did DID 字符串（例如：did:sui:0x1a2b...）
   */
  async resolve(did: string): Promise<DIDResolutionResult> {
    // 1. 驗證 DID 格式
    if (!this.validateDID(did)) {
      return {
        didDocument: null,
        didResolutionMetadata: {
          error: 'invalidDid',
          message: 'Invalid DID format. Expected: did:sui:<address>'
        },
        didDocumentMetadata: {}
      };
    }

    // 2. 檢查緩存
    const cached = this.cache.get(did);
    if (cached) {
      console.log(`📦 從緩存獲取 DID 文檔: ${did}`);
      return {
        didDocument: cached,
        didResolutionMetadata: {
          contentType: 'application/did+ld+json'
        },
        didDocumentMetadata: {
          created: cached.created,
          updated: cached.updated
        }
      };
    }

    // 3. 從區塊鏈讀取 DID 文檔
    try {
      const didDocument = await this.fetchDIDDocumentFromChain(did);

      if (!didDocument) {
        return {
          didDocument: null,
          didResolutionMetadata: {
            error: 'notFound',
            message: `DID not found: ${did}`
          },
          didDocumentMetadata: {}
        };
      }

      // 4. 驗證文檔
      if (!this.validateDIDDocument(didDocument)) {
        return {
          didDocument: null,
          didResolutionMetadata: {
            error: 'representationNotSupported',
            message: 'Invalid DID document structure'
          },
          didDocumentMetadata: {}
        };
      }

      // 5. 緩存文檔
      this.cache.set(did, didDocument);
      setTimeout(() => this.cache.delete(did), this.cacheTTL);

      return {
        didDocument,
        didResolutionMetadata: {
          contentType: 'application/did+ld+json'
        },
        didDocumentMetadata: {
          created: didDocument.created,
          updated: didDocument.updated
        }
      };
    } catch (error) {
      console.error('❌ 解析 DID 失敗:', error);
      return {
        didDocument: null,
        didResolutionMetadata: {
          error: 'notFound',
          message: error instanceof Error ? error.message : '未知錯誤'
        },
        didDocumentMetadata: {}
      };
    }
  }

  /**
   * 從區塊鏈讀取 DID 文檔
   */
  private async fetchDIDDocumentFromChain(did: string): Promise<DIDDocument | null> {
    try {
      // 提取地址
      const address = did.split(':')[2];

      // 查詢 DID Registry 智能合約
      // 注意：這裡需要根據實際的合約結構調整
      const result = await this.suiClient.getDynamicFieldObject({
        parentId: this.config.registryObjectId,
        name: {
          type: '0x1::string::String',
          value: did
        }
      });

      if (!result.data) {
        console.log(`⚠️ 鏈上未找到 DID: ${did}`);
        return null;
      }

      // 解析鏈上數據為 DID 文檔
      const fields = (result.data.content as any).fields;
      const didDocument: DIDDocument = {
        '@context': JSON.parse(fields.context),
        id: did,
        controller: fields.controller,
        verificationMethod: JSON.parse(fields.verification_methods),
        authentication: JSON.parse(fields.authentication || '[]'),
        assertionMethod: JSON.parse(fields.assertion_method || '[]'),
        created: fields.created_at,
        updated: fields.updated_at
      };

      return didDocument;
    } catch (error) {
      console.error('❌ 從鏈上讀取 DID 文檔失敗:', error);
      return null;
    }
  }

  /**
   * 驗證 DID 格式
   */
  private validateDID(did: string): boolean {
    const didRegex = /^did:sui:0x[a-fA-F0-9]{64}$/;
    return didRegex.test(did);
  }

  /**
   * 驗證 DID 文檔結構
   */
  private validateDIDDocument(doc: DIDDocument): boolean {
    return (
      doc &&
      typeof doc.id === 'string' &&
      this.validateDID(doc.id) &&
      Array.isArray(doc.verificationMethod) &&
      doc.verificationMethod.length > 0
    );
  }

  /**
   * 獲取 DID 的公鑰
   */
  async getPublicKey(did: string): Promise<Uint8Array | null> {
    const result = await this.resolve(did);

    if (!result.didDocument || result.didResolutionMetadata.error) {
      return null;
    }

    const verificationMethod = result.didDocument.verificationMethod[0];
    if (!verificationMethod.publicKeyHex) {
      return null;
    }

    return Buffer.from(verificationMethod.publicKeyHex, 'hex');
  }

  /**
   * 驗證 DID 控制權
   * @param did DID 字符串
   * @param signature 簽名
   * @param message 原始消息
   */
  async verifyControl(did: string, signature: Uint8Array, message: Uint8Array): Promise<boolean> {
    const publicKey = await this.getPublicKey(did);
    if (!publicKey) {
      return false;
    }

    // 使用 Ed25519 驗證簽名
    const { Ed25519PublicKey } = await import('@mysten/sui.js/keypairs/ed25519');
    const pubKey = new Ed25519PublicKey(publicKey);

    try {
      return await pubKey.verify(message, signature);
    } catch (error) {
      console.error('❌ 簽名驗證失敗:', error);
      return false;
    }
  }

  /**
   * 清除緩存
   */
  clearCache(): void {
    this.cache.clear();
  }
}

/**
 * 示例使用
 */
async function example() {
  const resolver = new DIDResolver({
    rpcUrl: 'https://fullnode.testnet.sui.io:443',
    packageId: '0x...', // 替換為實際的包 ID
    registryObjectId: '0x...'  // 替換為實際的註冊表對象 ID
  });

  const did = 'did:sui:0x1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7a8b9c0d';

  console.log('🔍 解析 DID:', did);
  const result = await resolver.resolve(did);

  if (result.didResolutionMetadata.error) {
    console.error('❌ 解析失敗:', result.didResolutionMetadata.message);
  } else {
    console.log('✅ DID 文檔:');
    console.log(JSON.stringify(result.didDocument, null, 2));
  }

  // 獲取公鑰
  const publicKey = await resolver.getPublicKey(did);
  if (publicKey) {
    console.log('📋 公鑰:', Buffer.from(publicKey).toString('hex'));
  }
}

// 如果直接運行此文件
if (require.main === module) {
  example().catch(console.error);
}

export default DIDResolver;
