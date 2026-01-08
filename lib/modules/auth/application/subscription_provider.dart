import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repository/auth_repository.dart';

class SubscriptionState {
  final SubscriptionItem current;
  final List<SubscriptionItem> otherSubscriptions;
  
  const SubscriptionState({
    required this.current,
    this.otherSubscriptions = const [],
  });
  
  SubscriptionState copyWith({
    SubscriptionItem? current,
    List<SubscriptionItem>? otherSubscriptions,
  }) {
    return SubscriptionState(
      current: current ?? this.current,
      otherSubscriptions: otherSubscriptions ?? this.otherSubscriptions,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(
      SubscriptionState(
        current: SubscriptionItem(
             id: 0, 
             name: 'Guest', 
             status: 'Inactive', 
             expiryDate: '', 
             activeDevices: 0, 
             maxDevices: 0
        )
      )
  );

  void setSubscriptionData(SubscriptionItem current, List<SubscriptionItem> otherSubs) {
    state = state.copyWith(
      current: current,
      otherSubscriptions: otherSubs,
    );
  }

  void updateCurrent(SubscriptionItem current) {
    // Check if meaningful change? For now always update to reflect expiry/status
    if (state.current.id == current.id) {
       state = state.copyWith(current: current);
    }
  }

  void updateOtherSubscriptions(List<SubscriptionItem> otherSubs) {
    // Always update to ensure metadata (name, expiry) changes are reflected
    state = state.copyWith(otherSubscriptions: otherSubs);
  }

  void clear() {
    state = SubscriptionState(
        current: SubscriptionItem(
             id: 0, 
             name: 'Guest', 
             status: 'Inactive', 
             expiryDate: '', 
             activeDevices: 0, 
             maxDevices: 0
        )
    );
  }
}

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});
