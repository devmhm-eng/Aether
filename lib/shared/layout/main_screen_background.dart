import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/animated_background.dart';

class MainScreenBackground extends StatelessWidget {
  final Widget child;
  final ConnectionStatus connectionStatus;

  const MainScreenBackground({
    super.key,
    required this.child,
    required this.connectionStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      appBar: connectionStatus == ConnectionStatus.connected
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              toolbarHeight: 0,
            )
          : null,
      body: Stack(
        children: [
          // Animated Aurora Background
          Positioned.fill(
            child: AnimatedBackground(connectionStatus: connectionStatus),
          ),
          
          // Content
          child,
        ],
      ),
    );
  }
}
