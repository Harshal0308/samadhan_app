import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';
import 'package:samadhan_app/services/database_service.dart';

class AppNotification {
  final int id;
  final String title;
  final String message;
  final String type; // e.g., 'warning', 'info', 'alert', 'success'
  final DateTime date;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.date,
    this.isRead = false,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, int id) {
    return AppNotification(
      id: id,
      title: map['title'] as String,
      message: map['message'] as String,
      type: map['type'] as String,
      date: DateTime.parse(map['date'] as String),
      isRead: map['isRead'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'date': date.toIso8601String(),
      'isRead': isRead,
    };
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    DateTime? date,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
    );
  }
}

class NotificationProvider with ChangeNotifier {
  final _notificationStore = intMapStoreFactory.store('notifications');
  final DatabaseService _dbService = DatabaseService();

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadNotifications() async {
    final db = await _dbService.database;
    final snapshots = await _notificationStore.find(db, finder: Finder(sortOrders: [SortOrder('date', false)]));
    _notifications = snapshots.map((snapshot) {
      return AppNotification.fromMap(snapshot.value, snapshot.key);
    }).toList();
    notifyListeners();
  }

  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
  }) async {
    final db = await _dbService.database;
    final newNotification = AppNotification(
      id: 0, // Sembast generates ID
      title: title,
      message: message,
      type: type,
      date: DateTime.now(),
    );
    await _notificationStore.add(db, newNotification.toMap());
    await loadNotifications();
  }

  Future<void> markAsRead(AppNotification notification) async {
    final db = await _dbService.database;
    final updatedNotification = notification.copyWith(isRead: true);
    await _notificationStore.update(db, updatedNotification.toMap(), finder: Finder(filter: Filter.byKey(notification.id)));
    await loadNotifications();
  }

  Future<void> dismissNotification(AppNotification notification) async {
    final db = await _dbService.database;
    await _notificationStore.delete(db, finder: Finder(filter: Filter.byKey(notification.id)));
    await loadNotifications();
  }

  Future<void> clearAllNotifications() async {
    final db = await _dbService.database;
    await _notificationStore.delete(db);
    await loadNotifications();
  }
}
