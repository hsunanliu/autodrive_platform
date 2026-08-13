/// 應用配置
///
/// 開發時可以創建 app_config.local.dart 來覆蓋這些設置
/// app_config.local.dart 不會被提交到 git

// 嘗試導入本地配置
import 'app_config.local.dart' as local;

class AppConfig {
  // 後端 API 配置
  static String get backendUrl {
    // 嘗試從本地配置讀取（如果存在）
    try {
      return local.localBackendUrl;
    } catch (e) {
      // 本地配置不存在，使用默認值
      print('⚠️ 未找到本地配置，使用默認 URL: $defaultBackendUrl');
      return defaultBackendUrl;
    }
  }

  // 默認後端 URL（提交到 git 的版本）
  static const String defaultBackendUrl = 'http://localhost:8000/api/v1';

  // WebSocket URL
  static String get websocketUrl {
    final baseUrl = backendUrl.replaceAll('/api/v1', '');
    return baseUrl;
  }

  // OSM 地圖配置
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // ---- 鏈上合約（單一事實來源）----
  // 當前已加固部署（testnet，含 dispute/agent-cap/pool-refund）。與後端 .env
  // CONTRACT_PACKAGE_ID 一致，已用 RPC 驗證此 package 具 raise_dispute/resolve_dispute。
  // 注意：舊碼中的 0xa6232c…380b、0xda64…542f 為過期 package（無爭議函式），屬死值，
  // 隨 payment_dialog / sui_*_service（Phase 4/9）移除後淘汰，新流程一律引用此處。
  static const String contractPackageId =
      '0xb761c6f5681e5f46533a52840dcd9e8f7bcb2a6f749dcc6a3e7646e37867e23f';

  // 平台收費地址（與後端 .env PLATFORM_WALLET_ADDRESS 一致）
  static const String platformAddress =
      '0x013a90ee08199af4cdb1158fec0eca54e1174b93492180a33ea8298e94f3af36';

  // ---- zkLogin（Google OAuth）----
  // 需在 Google Cloud 建立 OAuth Client（iOS/Android/Web），並在 Enoki Portal
  // 註冊同一個 client id 為 Google Auth Provider。填好後 zkLogin 即可端到端運作。
  // 可在 app_config.local.dart 以 localGoogleOAuthClientId 覆蓋。
  static String get googleOAuthClientId {
    try {
      return local.localGoogleOAuthClientId;
    } catch (_) {
      return defaultGoogleOAuthClientId;
    }
  }

  static const String defaultGoogleOAuthClientId = ''; // TODO: 填入 Google OAuth Client ID

  // AppAuth redirect：iOS/Android 原生 client 慣例為反轉的 client id
  // 例：com.googleusercontent.apps.<CLIENT_ID_不含.apps...>:/oauth2redirect
  static String get googleOAuthRedirectUrl {
    try {
      return local.localGoogleOAuthRedirectUrl;
    } catch (_) {
      return defaultGoogleOAuthRedirectUrl;
    }
  }

  static const String defaultGoogleOAuthRedirectUrl = '';
}
