// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'MetaCore';

  @override
  String get appSubtitle => '';

  @override
  String get appSlogan => '安全快速代理';

  @override
  String get speedTestReady => '准备测试';

  @override
  String get speedTestTesting => '测试速度...';

  @override
  String get loginEnterKey => '输入订阅密钥';

  @override
  String get loginConnect => '连接';

  @override
  String get loginFindKey => '哪里可以找到密钥？';

  @override
  String get loginPaste => '粘贴';

  @override
  String userId(Object id) {
    return 'ID: $id';
  }

  @override
  String get settingsTitle => '您的订阅';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsNoSubs => '没有激活的订阅';

  @override
  String get settingsAddSub => '绑定新订阅';

  @override
  String get subActive => '活跃';

  @override
  String get subExpired => '已过期';

  @override
  String subDevices(Object active, Object max) {
    return '设备: $active/$max';
  }

  @override
  String get subManage => '管理';

  @override
  String get dialogAddTitle => '添加订阅';

  @override
  String get dialogEnterToken => '输入订阅令牌';

  @override
  String get dialogConnect => '连接';

  @override
  String get statusTitleNormal => '正常';

  @override
  String get statusTitleFailed => '连接失败';

  @override
  String get statusTitleNoInternet => '无网络';

  @override
  String get statusTitleDisconnecting => '正在断开';

  @override
  String get statusTitleDefault => '待机中';

  @override
  String get statusDescLoading => '正在连接...';

  @override
  String get statusDescConnected => '已连接';

  @override
  String get statusDescAnalyzing => '正在分析...';

  @override
  String get statusDescNoInternet => '无法上网';

  @override
  String get statusDescError => '出错了 :(';

  @override
  String get statusDescDisconnecting => '正在断开连接';

  @override
  String get statusDescDefault => '点击连接';

  @override
  String get privacyTitle => '隐私声明';

  @override
  String get privacyBody =>
      '本应用不会收集、存储或向服务器传输任何个人信息。\n\n仅会在本地存储少量非个人数据（如您的网络运营商名称）以改善连接性能。\n\n继续使用即表示您同意安装VPN配置文件。';

  @override
  String get privacyButton => '我知道了';

  @override
  String get updateAvailable => '有新版本';

  @override
  String get updateRequired => '需要更新';

  @override
  String get updateOptionalDesc => '为了获得最佳体验，请更新到最新版本。';

  @override
  String get updateRequiredDesc => '需要更新才能继续使用。此更新包含重要修复。';

  @override
  String get updateButton => '立即更新';

  @override
  String get updateNotNow => '稍后再说';

  @override
  String switchSuccess(Object name) {
    return '已切换到 $name';
  }

  @override
  String get speedTestDownload => '下载';

  @override
  String get speedTestUpload => '上传';

  @override
  String get speedTestPing => '延迟';

  @override
  String get speedTestJitter => '抖动';

  @override
  String get speedTestLoss => '丢包';

  @override
  String get speedTestLatency => '延迟';
}
