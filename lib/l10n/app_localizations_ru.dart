// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'MetaCore';

  @override
  String get appSubtitle => '';

  @override
  String get appSlogan => 'Быстрый и безопасный прокси';

  @override
  String get speedTestReady => 'Готов к тесту';

  @override
  String get speedTestTesting => 'Тестирование...';

  @override
  String get loginEnterKey => 'Введите код подписки';

  @override
  String get loginConnect => 'Подключить';

  @override
  String get loginFindKey => 'Где найти ключ?';

  @override
  String get loginPaste => 'Вставить';

  @override
  String userId(Object id) {
    return 'ID: $id';
  }

  @override
  String get settingsTitle => 'ВАШИ ПОДПИСКИ';

  @override
  String get settingsLanguage => 'ЯЗЫК';

  @override
  String get settingsNoSubs => 'Нет активных подписок';

  @override
  String get settingsAddSub => 'Привязать новую подписку';

  @override
  String get subActive => 'Активна';

  @override
  String get subExpired => 'Истекла';

  @override
  String subDevices(Object active, Object max) {
    return 'Устройства: $active/$max';
  }

  @override
  String get subManage => 'Управление';

  @override
  String get dialogAddTitle => 'Добавить подписку';

  @override
  String get dialogEnterToken => 'Введите токен подписки';

  @override
  String get dialogConnect => 'Подключить';

  @override
  String get statusTitleNormal => 'работает';

  @override
  String get statusTitleFailed => 'ошибка.';

  @override
  String get statusTitleNoInternet => 'нет сети';

  @override
  String get statusTitleDisconnecting => 'отключается';

  @override
  String get statusTitleDefault => 'в режиме ожидания.';

  @override
  String get statusDescLoading => 'подключение ...';

  @override
  String get statusDescConnected => 'подключено';

  @override
  String get statusDescAnalyzing => 'анализ ...';

  @override
  String get statusDescNoInternet => 'нет интернета';

  @override
  String get statusDescError => 'произошла ошибка :(';

  @override
  String get statusDescDisconnecting => 'отключение.';

  @override
  String get statusDescDefault => 'Нажмите для подключения';

  @override
  String get privacyTitle => 'Уведомление о конфиденциальности';

  @override
  String get privacyBody =>
      'Это приложение не собирает, не хранит и не передает личную информацию на свои серверы.\n\nТолько небольшой объем неперсональных данных (таких как имя вашего интернет-провайдера) может храниться локально на вашем устройстве для улучшения качества соединения.\n\nПродолжая,\nвы соглашаетесь установить VPN-профиль.';

  @override
  String get privacyButton => 'Понятно';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String get updateRequired => 'Требуется обновление';

  @override
  String get updateOptionalDesc =>
      'Чтобы использовать все возможности приложения, обновите его до последней версии.';

  @override
  String get updateRequiredDesc =>
      'Для продолжения использования обновите приложение до последней версии. Это обновление содержит важные исправления.';

  @override
  String get updateButton => 'Обновить';

  @override
  String get updateNotNow => 'Позже';

  @override
  String switchSuccess(Object name) {
    return 'Переключено на $name';
  }

  @override
  String get speedTestDownload => 'СКАЧИВАНИЕ';

  @override
  String get speedTestUpload => 'ЗАГРУЗКА';

  @override
  String get speedTestPing => 'ПИНГ';

  @override
  String get speedTestJitter => 'ДЖИТТЕР';

  @override
  String get speedTestLoss => 'ПОТЕРИ';

  @override
  String get speedTestLatency => 'ЗАДЕРЖКА';
}
