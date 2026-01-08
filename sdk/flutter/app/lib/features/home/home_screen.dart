import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:aether_client/aether_client.dart';
import 'dart:convert';
import '../../core/constants/api_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnected = false;
  bool _isConnecting = false;

  Future<void> _toggleVpn() async {
    if (_isConnecting) return;

    setState(() => _isConnecting = true);

    try {
      if (_isConnected) {
        // Stop VPN
        await AetherClient.stop();
        setState(() => _isConnected = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('VPN Disconnected'), backgroundColor: Colors.red),
          );
        }
      } else {
        // Start VPN - need config
        final config = json.encode({
          'client_uuid': '550e8400-e29b-41d4-a716-446655440000', // Should come from storage
          'server_addr': ApiConstants.vpnAddress,
          'servers': [],
        });
        
        await AetherClient.start(config);
        setState(() => _isConnected = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('VPN Connected'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Icon(Icons.menu, color: Colors.white),
                   const Text("Aether", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                   const Icon(Icons.person, color: Colors.white),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Connect Button (Big Circle)
            GestureDetector(
              onTap: _toggleVpn,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? Colors.green.shade700 : AppColors.secondary,
                  boxShadow: [
                    BoxShadow(
                      color: (_isConnected ? Colors.green : AppColors.primary).withOpacity(0.3), 
                      blurRadius: 20, 
                      spreadRadius: 5
                    )
                  ],
                  border: Border.all(
                    color: _isConnected ? Colors.green : AppColors.primary, 
                    width: 2
                  )
                ),
                child: _isConnecting
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : Center(
                        child: Icon(
                          _isConnected ? Icons.check : Icons.power_settings_new, 
                          size: 80, 
                          color: Colors.white
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            Text(
              _isConnected ? "Connected" : "Tap to Connect", 
              style: TextStyle(
                color: _isConnected ? Colors.green : Colors.white54,
                fontWeight: _isConnected ? FontWeight.bold : FontWeight.normal,
              )
            ),

            const Spacer(),
            
            // Stats / Info
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _buildStat("Download", "0 KB/s", AppColors.downloadColor),
                   _buildStat("Upload", "0 KB/s", AppColors.uploadColor),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
