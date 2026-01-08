// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'متاکور';

  @override
  String get appSubtitle => '';

  @override
  String get appSlogan => 'پروکسی امن و سریع';

  @override
  String get speedTestReady => 'آماده تست سرعت';

  @override
  String get speedTestTesting => 'در حال تست...';

  @override
  String get loginEnterKey => 'کلید اشتراک خود را وارد کنید';

  @override
  String get loginConnect => 'اتصال';

  @override
  String get loginFindKey => 'کلید را از کجا پیدا کنم؟';

  @override
  String get loginPaste => 'جایگذاری';

  @override
  String userId(Object id) {
    return 'شناسه: $id';
  }

  @override
  String get settingsTitle => 'اشتراک‌های شما';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsNoSubs => 'هیچ اشتراک فعالی ندارید';

  @override
  String get settingsAddSub => 'اتصال اشتراک جدید';

  @override
  String get subActive => 'فعال';

  @override
  String get subExpired => 'منقضی شده';

  @override
  String subDevices(Object active, Object max) {
    return 'دستگاه‌ها: $active/$max';
  }

  @override
  String get subManage => 'مدیریت';

  @override
  String get dialogAddTitle => 'افزودن اشتراک';

  @override
  String get dialogEnterToken => 'کد اشتراک را وارد کنید';

  @override
  String get dialogConnect => 'اتصال';

  @override
  String get statusTitleNormal => 'است';

  @override
  String get statusTitleFailed => 'شکست خورد.';

  @override
  String get statusTitleNoInternet => 'اینترنت';

  @override
  String get statusTitleDisconnecting => 'در حال';

  @override
  String get statusTitleDefault => 'در حال';

  @override
  String get statusDescLoading => 'اتصال ...';

  @override
  String get statusDescConnected => 'قدرتمند شد';

  @override
  String get statusDescAnalyzing => 'چیزهای علمی ...';

  @override
  String get statusDescNoInternet => 'قطع شد';

  @override
  String get statusDescError => 'متاسفیم :(';

  @override
  String get statusDescDisconnecting => 'بازگشت به حالت آماده.';

  @override
  String get statusDescDefault => 'استراحت.';

  @override
  String get privacyTitle => 'حریم خصوصی';

  @override
  String get privacyBody =>
      'این برنامه هیچ اطلاعات شخصی را جمع‌آوری، ذخیره یا ارسال نمی‌کند.\n\nتنها مقدار کمی داده غیر شخصی (مانند نام تامین‌کننده اینترنت) ممکن است برای بهبود عملکرد اتصال به صورت محلی در دستگاه شما ذخیره شود.\n\nبا ادامه،\nشما با نصب پروفایل VPN موافقت می‌کنید.';

  @override
  String get privacyButton => 'متوجه شدم';

  @override
  String get updateAvailable => 'بروزرسانی موجود است';

  @override
  String get updateRequired => 'بروزرسانی الزامی است';

  @override
  String get updateOptionalDesc =>
      'برای استفاده از آخرین امکانات و بهبودهای برنامه، لطفا به نسخه جدید بروزرسانی کنید.';

  @override
  String get updateRequiredDesc =>
      'برای ادامه استفاده، لطفا برنامه را بروزرسانی کنید. این نسخه شامل تغییرات مهم و ضروری است.';

  @override
  String get updateButton => 'بروزرسانی';

  @override
  String get updateNotNow => 'فعلا نه';

  @override
  String switchSuccess(Object name) {
    return 'اشتراک با موفقیت به $name تغییر یافت';
  }

  @override
  String get speedTestDownload => 'دانلود';

  @override
  String get speedTestUpload => 'آپلود';

  @override
  String get speedTestPing => 'پینگ';

  @override
  String get speedTestJitter => 'جیتر';

  @override
  String get speedTestLoss => 'اتلاف';

  @override
  String get speedTestLatency => 'تاخیر';
}
