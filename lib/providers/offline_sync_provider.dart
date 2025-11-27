import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineSyncProvider with ChangeNotifier {
  int _pendingChanges = 0;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String _syncStatusMessage = "Checking connection...";
  bool _isOnline = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  int get pendingChanges => _pendingChanges;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get syncStatusMessage => _syncStatusMessage;
  bool get isOnline => _isOnline;

  OfflineSyncProvider() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi);
    if (_isOnline) {
      _syncStatusMessage = "Connected. Ready to sync.";
      if (!wasOnline && _pendingChanges > 0) {
        triggerSync(); // Auto-sync when coming online with pending changes
      }
    } else {
      _syncStatusMessage = "Offline. Changes will be synced when online.";
    }
    notifyListeners();
  }

  void addPendingChange() {
    _pendingChanges++;
    notifyListeners();
  }

  void removePendingChange() {
    if (_pendingChanges > 0) {
      _pendingChanges--;
      notifyListeners();
    }
  }

  Future<void> triggerSync() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    _syncStatusMessage = "Syncing in progress...";
    notifyListeners();

    // Simulate network delay and data transfer
    await Future.delayed(const Duration(seconds: 3));

    if (_pendingChanges > 0) {
      _pendingChanges = 0; // In a real app, this would happen after successful API calls
      _lastSyncTime = DateTime.now();
      _syncStatusMessage = "Sync complete. All changes uploaded.";
    } else {
      _syncStatusMessage = "No pending changes to sync.";
    }

    _isSyncing = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
