import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

class TrafficStats {
  final int uploadSpeed;   // Bytes per second
  final int downloadSpeed; // Bytes per second
  final int totalUpload;
  final int totalDownload;
  final List<int> uploadHistory;
  final List<int> downloadHistory;

  const TrafficStats({
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.totalUpload = 0,
    this.totalDownload = 0,
    this.uploadHistory = const [],
    this.downloadHistory = const [],
  });
  
  String get formattedUpload => _formatSpeed(uploadSpeed);
  String get formattedDownload => _formatSpeed(downloadSpeed);

  String _formatSpeed(int bytes) {
    if (bytes < 1024) return "$bytes B/s";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB/s";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s";
  }
}

class TrafficStatsNotifier extends StateNotifier<TrafficStats> {
  final Ref ref;
  Timer? _timer;
  final Random _random = Random();
  
  TrafficStatsNotifier(this.ref) : super(const TrafficStats()) {
    // Listen to connection state changes
    ref.listen<ConnectionState>(connectionStateProvider, (previous, next) {
       if (next.status == ConnectionStatus.connected) {
         _startSimulation();
       } else if (next.status == ConnectionStatus.disconnected || next.status == ConnectionStatus.error) {
         _stopSimulation();
       }
    });
  }

  void _startSimulation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
       if (!mounted) return;
       
       // Simulate realistic fluctuation
       // Base activity + random spikes
       int up = 50 * 1024 + _random.nextInt(150 * 1024); // 50-200 KB/s
       int down = 200 * 1024 + _random.nextInt(1800 * 1024); // 200KB - 2MB/s
       
       // Occasionally spike download
       if (_random.nextDouble() > 0.8) {
         down += 2 * 1024 * 1024; // +2MB
       }
       
       // Update History
       final newUpHist = List<int>.from(state.uploadHistory)..add(up);
       if (newUpHist.length > 40) newUpHist.removeAt(0); // Keep last 40 seconds
       
       final newDownHist = List<int>.from(state.downloadHistory)..add(down);
       if (newDownHist.length > 40) newDownHist.removeAt(0);

       state = TrafficStats(
         uploadSpeed: up,
         downloadSpeed: down,
         totalUpload: state.totalUpload + up,
         totalDownload: state.totalDownload + down,
         uploadHistory: newUpHist,
         downloadHistory: newDownHist,
       );
    });
  }

  void _stopSimulation() {
    _timer?.cancel();
    state = const TrafficStats(); // Reset
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final trafficStatsProvider = StateNotifierProvider<TrafficStatsNotifier, TrafficStats>((ref) {
  return TrafficStatsNotifier(ref);
});
