import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;

  // Real Ad Unit ID from user
  final String _adUnitId = 'ca-app-pub-1192581640949974/3765534275';

  // Test Ad Unit ID (always use this when debugging to avoid ban)
  // Android Test ID: ca-app-pub-3940256099942544/1033173712
  // We use kDebugMode to switch automatically
  String get adUnitId {
    if (kDebugMode) {
      return Platform.isAndroid 
          ? 'ca-app-pub-3940256099942544/1033173712' 
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    return _adUnitId;
  }

  void loadInterstitialAd() {
    if (_isAdLoading || _interstitialAd != null) return;

    _isAdLoading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('AdService: Interstitial Ad loaded');
          _interstitialAd = ad;
          _isAdLoading = false;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdService: Interstitial Ad failed to load: $error');
          _interstitialAd = null;
          _isAdLoading = false;
          // Retry logic could go here, but avoiding loops for now
        },
      ),
    );
  }

  void showInterstitialAd({VoidCallback? onAdDismissed}) {
    debugPrint('AdService: showInterstitialAd called. Ad object: ${_interstitialAd == null ? "NULL" : "READY"}');
    if (_interstitialAd == null) {
      debugPrint('AdService: Warning: Attempted to show ad before it was loaded.');
      loadInterstitialAd(); // Load for next time
      onAdDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        debugPrint('AdService: Ad showed fullscreen content.');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        debugPrint('AdService: Ad dismissed fullscreen content.');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload the next one
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('AdService: Ad failed to show fullscreen content: $error');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Load for next time
        onAdDismissed?.call();
      },
    );

    _interstitialAd!.show();
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
