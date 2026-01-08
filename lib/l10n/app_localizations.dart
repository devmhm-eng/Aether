import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
    Locale('ru'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MetaCore'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **''**
  String get appSubtitle;

  /// No description provided for @appSlogan.
  ///
  /// In en, this message translates to:
  /// **'Secure & Fast Proxy'**
  String get appSlogan;

  /// No description provided for @speedTestReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to Test'**
  String get speedTestReady;

  /// No description provided for @speedTestTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing Speed...'**
  String get speedTestTesting;

  /// No description provided for @loginEnterKey.
  ///
  /// In en, this message translates to:
  /// **'Enter your subscription key'**
  String get loginEnterKey;

  /// No description provided for @loginConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get loginConnect;

  /// No description provided for @loginFindKey.
  ///
  /// In en, this message translates to:
  /// **'Where to find key?'**
  String get loginFindKey;

  /// No description provided for @loginPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get loginPaste;

  /// No description provided for @userId.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String userId(Object id);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR SUBSCRIPTIONS'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguage;

  /// No description provided for @settingsNoSubs.
  ///
  /// In en, this message translates to:
  /// **'No Active Subscriptions'**
  String get settingsNoSubs;

  /// No description provided for @settingsAddSub.
  ///
  /// In en, this message translates to:
  /// **'Link New Subscription'**
  String get settingsAddSub;

  /// No description provided for @subActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subActive;

  /// No description provided for @subExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get subExpired;

  /// No description provided for @subDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices: ‎{active}/{max}'**
  String subDevices(Object active, Object max);

  /// No description provided for @subManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get subManage;

  /// No description provided for @dialogAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Subscription'**
  String get dialogAddTitle;

  /// No description provided for @dialogEnterToken.
  ///
  /// In en, this message translates to:
  /// **'Enter Subscription Token'**
  String get dialogEnterToken;

  /// No description provided for @dialogConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get dialogConnect;

  /// No description provided for @statusTitleNormal.
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get statusTitleNormal;

  /// No description provided for @statusTitleFailed.
  ///
  /// In en, this message translates to:
  /// **'is failed.'**
  String get statusTitleFailed;

  /// No description provided for @statusTitleNoInternet.
  ///
  /// In en, this message translates to:
  /// **'has'**
  String get statusTitleNoInternet;

  /// No description provided for @statusTitleDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'is returning'**
  String get statusTitleDisconnecting;

  /// No description provided for @statusTitleDefault.
  ///
  /// In en, this message translates to:
  /// **'is chilling.'**
  String get statusTitleDefault;

  /// No description provided for @statusDescLoading.
  ///
  /// In en, this message translates to:
  /// **'plugging in ...'**
  String get statusDescLoading;

  /// No description provided for @statusDescConnected.
  ///
  /// In en, this message translates to:
  /// **'powered up'**
  String get statusDescConnected;

  /// No description provided for @statusDescAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'doing science ...'**
  String get statusDescAnalyzing;

  /// No description provided for @statusDescNoInternet.
  ///
  /// In en, this message translates to:
  /// **'exited the matrix'**
  String get statusDescNoInternet;

  /// No description provided for @statusDescError.
  ///
  /// In en, this message translates to:
  /// **'we\'re sorry :('**
  String get statusDescError;

  /// No description provided for @statusDescDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'to standby mode.'**
  String get statusDescDisconnecting;

  /// No description provided for @statusDescDefault.
  ///
  /// In en, this message translates to:
  /// **'Connect already'**
  String get statusDescDefault;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Notice'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'This app does not collect, store, or transmit any personal information to its servers.\n\nOnly a small amount of non-personal data (such as your internet provider’s name) may be stored locally on your device to improve connection performance for future sessions.\n\nBy continuing,\nyou agree to install the VPN profile.'**
  String get privacyBody;

  /// No description provided for @privacyButton.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get privacyButton;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequired;

  /// No description provided for @updateOptionalDesc.
  ///
  /// In en, this message translates to:
  /// **'To get the most out of the app and enjoy the latest improvements, please update to the newest version.'**
  String get updateOptionalDesc;

  /// No description provided for @updateRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'To continue using MetaCore, please update to the latest version. This update includes critical improvements and is required for app functionality.'**
  String get updateRequiredDesc;

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateButton;

  /// No description provided for @updateNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get updateNotNow;

  /// No description provided for @switchSuccess.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String switchSuccess(Object name);

  /// No description provided for @speedTestDownload.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD'**
  String get speedTestDownload;

  /// No description provided for @speedTestUpload.
  ///
  /// In en, this message translates to:
  /// **'UPLOAD'**
  String get speedTestUpload;

  /// No description provided for @speedTestPing.
  ///
  /// In en, this message translates to:
  /// **'PING'**
  String get speedTestPing;

  /// No description provided for @speedTestJitter.
  ///
  /// In en, this message translates to:
  /// **'JITTER'**
  String get speedTestJitter;

  /// No description provided for @speedTestLoss.
  ///
  /// In en, this message translates to:
  /// **'LOSS'**
  String get speedTestLoss;

  /// No description provided for @speedTestLatency.
  ///
  /// In en, this message translates to:
  /// **'LATENCY'**
  String get speedTestLatency;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
