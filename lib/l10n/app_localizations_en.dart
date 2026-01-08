// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MetaCore';

  @override
  String get appSubtitle => '';

  @override
  String get appSlogan => 'Secure & Fast Proxy';

  @override
  String get speedTestReady => 'Ready to Test';

  @override
  String get speedTestTesting => 'Testing Speed...';

  @override
  String get loginEnterKey => 'Enter your subscription key';

  @override
  String get loginConnect => 'Connect';

  @override
  String get loginFindKey => 'Where to find key?';

  @override
  String get loginPaste => 'Paste';

  @override
  String userId(Object id) {
    return 'ID: $id';
  }

  @override
  String get settingsTitle => 'YOUR SUBSCRIPTIONS';

  @override
  String get settingsLanguage => 'LANGUAGE';

  @override
  String get settingsNoSubs => 'No Active Subscriptions';

  @override
  String get settingsAddSub => 'Link New Subscription';

  @override
  String get subActive => 'Active';

  @override
  String get subExpired => 'Expired';

  @override
  String subDevices(Object active, Object max) {
    return 'Devices: ‎$active/$max';
  }

  @override
  String get subManage => 'Manage';

  @override
  String get dialogAddTitle => 'Add Subscription';

  @override
  String get dialogEnterToken => 'Enter Subscription Token';

  @override
  String get dialogConnect => 'Connect';

  @override
  String get statusTitleNormal => 'is';

  @override
  String get statusTitleFailed => 'is failed.';

  @override
  String get statusTitleNoInternet => 'has';

  @override
  String get statusTitleDisconnecting => 'is returning';

  @override
  String get statusTitleDefault => 'is chilling.';

  @override
  String get statusDescLoading => 'plugging in ...';

  @override
  String get statusDescConnected => 'powered up';

  @override
  String get statusDescAnalyzing => 'doing science ...';

  @override
  String get statusDescNoInternet => 'exited the matrix';

  @override
  String get statusDescError => 'we\'re sorry :(';

  @override
  String get statusDescDisconnecting => 'to standby mode.';

  @override
  String get statusDescDefault => 'Connect already';

  @override
  String get privacyTitle => 'Privacy Notice';

  @override
  String get privacyBody =>
      'This app does not collect, store, or transmit any personal information to its servers.\n\nOnly a small amount of non-personal data (such as your internet provider’s name) may be stored locally on your device to improve connection performance for future sessions.\n\nBy continuing,\nyou agree to install the VPN profile.';

  @override
  String get privacyButton => 'Got it';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get updateRequired => 'Update required';

  @override
  String get updateOptionalDesc =>
      'To get the most out of the app and enjoy the latest improvements, please update to the newest version.';

  @override
  String get updateRequiredDesc =>
      'To continue using MetaCore, please update to the latest version. This update includes critical improvements and is required for app functionality.';

  @override
  String get updateButton => 'Update now';

  @override
  String get updateNotNow => 'Not now';

  @override
  String switchSuccess(Object name) {
    return 'Switched to $name';
  }

  @override
  String get speedTestDownload => 'DOWNLOAD';

  @override
  String get speedTestUpload => 'UPLOAD';

  @override
  String get speedTestPing => 'PING';

  @override
  String get speedTestJitter => 'JITTER';

  @override
  String get speedTestLoss => 'LOSS';

  @override
  String get speedTestLatency => 'LATENCY';
}
