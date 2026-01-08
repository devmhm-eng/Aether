import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aether_client/aether_client.dart';
import '../../core/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _controller = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;

  Future<void> _login() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final hwId = await AetherClient.getHardwareId();
      
      final payload = jsonEncode({
        "action": "register_device",
        "hardware_id": hwId,
        "user_uuid": key,
        "label": "Flutter Client"
      });

      final responseStr = await AetherClient.request("register_device", payload);
      debugPrint("LOGIN: Response: $responseStr");

      final response = jsonDecode(responseStr);
      if (response['status'] == 'ok') {
         await _storage.write(key: 'user_uuid', value: key);
         if (mounted) context.go('/home');
      } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['message'] ?? 'Login failed'), backgroundColor: AppColors.middleGradientNoInternet),
            );
         }
      }

    } catch (e) {
       debugPrint("LOGIN: Error $e");
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Connection Error: $e"), backgroundColor: AppColors.middleGradientNoInternet),
          );
       }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Welcome Back", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter Subscription Key",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: AppColors.secondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _login,
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Connect"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
