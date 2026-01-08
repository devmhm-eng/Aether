import 'dart:io';
import 'package:defyx_vpn/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('App starting...');
  try {
    await dotenv.load();
    debugPrint('DotEnv loaded');
  } catch (e) {
    debugPrint('DotEnv load failed: $e');
  }
  
  // Initialize Google Mobile Ads
  try {
    MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('AdMob init failed: $e');
  }

  // Initialize Firebase using the platform options
  if (!Platform.isWindows) {
    try {
      await Firebase.initializeApp(
        name: "defyx-vpn",
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: App()));
}
