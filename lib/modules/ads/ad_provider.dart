import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/modules/ads/ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});
