import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aether_client/aether_client.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // 1. Check Local UUID
    final uuid = await _storage.read(key: 'user_uuid');
    
    if (uuid == null) {
      if (mounted) context.go('/login');
      return;
    }

    // 2. Verify with Backend Securely
    try {
       final payload = jsonEncode({
         "action": "get_config",
         "user_uuid": uuid
       });
       
       final responseStr = await AetherClient.request("get_config", payload);
       debugPrint("SPLASH: Auth Response: $responseStr");
       
       final response = jsonDecode(responseStr);
       
       // Check for actual auth failure vs other errors
       if (response['status'] == 'error') {
         if (response['message'] == 'User not found') {
           // Real authentication error - user doesn't exist
           await _storage.delete(key: 'user_uuid');
           if (mounted) context.go('/login');
         } else {
           // Other errors (No active nodes, etc) - user is still authenticated
           // Just go to home, they can see error there
           if (mounted) context.go('/home');
         }
       } else {
         // Success
         if (mounted) context.go('/home');
       }
    } catch (e) {
       debugPrint("SPLASH: Auth Error: $e");
       // On network error, fail safe to Login
       if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, size: 80, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text("AETHER", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 5)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
