/**
 * DID Creator
 * 創建符合 W3C DID 規範的去中心化身份標識符
 *
 * DID 格式：did:sui:<address>
 * 例如：did:sui:0x1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p
 */

import * as crypto from 'crypto';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';

/**
 * DID 文檔接口（符合 W3C DID Core 1.0）
 */
export interface DIDDocument {
  '@context': string | string[];
  id: string;  // DID 字符串
  controller?: string | string[];
  verificationMethod: VerificationMethod[];
  authentication?: string[];
  assertionMethod?: string[];
  keyAgreement?: string[];
  capabilityInvocation?: string[];
  capabilityDelegation?: string[];
  service?: ServiceEndpoint[];
  created?: string;
  updated?: string;
}

export interface VerificationMethod {
  id: string;
  type: string;
  controller: string;
  publicKeyMultibase?: string;
  publicKeyJwk?: JsonWebKey;
  publicKeyHex?: string;
}

export interface ServiceEndpoint {
  id: string;
  type: string;
  serviceEndpoint: string | object;
}

/**
 * DID 創建結果
 */
export interface DIDCreationResult {
  did: string;
  didDocument: DIDDocument;
  privateKey: Uint8Array;
  publicKey: Uint8Array;
  address: string;
}

export class DIDCreator {
  private static readonly DID_METHOD = 'sui';
  private static readonly DID_CONTEXT = [
    'https://www.w3.org/ns/did/v1',
    'https://w3id.org/security/suites/ed25519-2020/v1'
  ];

  /**
   * 創建新的 DID
   * @returns DID 創建結果（包含私鑰，需要安全存儲）
   */
  static async create(): Promise<DIDCreationResult> {
    // 1. 生成 Ed25519 密鑰對
    const keypair = new Ed25519Keypair();

    // 2. 獲取地址（Sui 格式）
    const address = keypair.getPublicKey().toSuiAddress();

    // 3. 構建 DID 字符串
    const did = `did:${this.DID_METHOD}:${address}`;

    // 4. 獲取公私鑰
    const publicKey = keypair.getPublicKey().toBytes();
    const privateKey = keypair.export().privateKey;

    // 5. 構建 DID 文檔
    const didDocument = this.createDIDDocument(did, address, publicKey);

    return {
      did,
      didDocument,
      privateKey,
      publicKey,
      address
    };
  }

  /**
   * 從現有密鑰對創建 DID
   * @param privateKey 私鑰（Ed25519）
   */
  static async fromPrivateKey(privateKey: Uint8Array): Promise<DIDCreationResult> {
    // 1. 從私鑰恢復密鑰對
    const keypair = Ed25519Keypair.fromSecretKey(privateKey);

    // 2. 獲取地址
    const address = keypair.getPublicKey().toSuiAddress();

    // 3. 構建 DID
    const did = `did:${this.DID_METHOD}:${address}`;

    // 4. 獲取公鑰
    const publicKey = keypair.getPublicKey().toBytes();

    // 5. 構建 DID 文檔
    const didDocument = this.createDIDDocument(did, address, publicKey);

    return {
      did,
      didDocument,
      privateKey,
      publicKey,
      address
    };
  }

  /**
   * 創建 DID 文檔
   */
  private static createDIDDocument(
    did: string,
    address: string,
    publicKey: Uint8Array
  ): DIDDocument {
    const verificationMethodId = `${did}#key-1`;

    return {
      '@context': this.DID_CONTEXT,
      id: did,
      controller: did,
      verificationMethod: [{
        id: verificationMethodId,
        type: 'Ed25519VerificationKey2020',
        controller: did,
        publicKeyHex: Buffer.from(publicKey).toString('hex')
      }],
      authentication: [verificationMethodId],
      assertionMethod: [verificationMethodId],
      capabilityInvocation: [verificationMethodId],
      capabilityDelegation: [verificationMethodId],
      created: new Date().toISOString(),
      updated: new Date().toISOString()
    };
  }

  /**
   * 驗證 DID 格式
   */
  static validateDID(did: string): boolean {
    const didRegex = /^did:sui:0x[a-fA-F0-9]{64}$/;
    return didRegex.test(did);
  }

  /**
   * 從 DID 提取地址
   */
  static extractAddress(did: string): string | null {
    if (!this.validateDID(did)) {
      return null;
    }
    return did.split(':')[2];
  }
}

/**
 * 示例使用
 */
async function example() {
  // 創建新 DID
  const result = await DIDCreator.create();

  console.log('✅ DID 創建成功：');
  console.log('DID:', result.did);
  console.log('地址:', result.address);
  console.log('DID 文檔:', JSON.stringify(result.didDocument, null, 2));
  console.log('⚠️ 私鑰需要安全存儲！');

  // 驗證 DID
  const isValid = DIDCreator.validateDID(result.did);
  console.log('DID 有效性:', isValid);

  // 提取地址
  const address = DIDCreator.extractAddress(result.did);
  console.log('提取地址:', address);
}

// 如果直接運行此文件
if (require.main === module) {
  example().catch(console.error);
}

export default DIDCreator;
