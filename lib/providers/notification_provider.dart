import 'package:flutter/material.dart';
import '../data/models/notif_model.dart';
import '../data/repositories/notif_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;

  NotificationProvider({required NotificationRepository repository})
      : _repository = repository;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Unread count — for a badge on the bottom nav bar.
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadNotifications({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    if (refresh) _notifications = [];
    notifyListeners();

    try {
      _notifications = await _repository.getNotifications();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    // Optimistic update
    _notifications = _notifications
        .map((n) => n.id == notificationId
            ? AppNotification(
                id: n.id,
                userId: n.userId,
                poiId: n.poiId,
                title: n.title,
                message: n.message,
                isRead: true,
                createdAt: n.createdAt,
              )
            : n)
        .toList();
    notifyListeners();

    try {
      await _repository.markAsRead(notificationId);
    } catch (e) {
      // Revert on failure
      await loadNotifications(refresh: true);
    }
  }

  Future<void> markAllRead() async {
    // Optimistic update
    _notifications = _notifications
        .map((n) => AppNotification(
              id: n.id,
              userId: n.userId,
              poiId: n.poiId,
              title: n.title,
              message: n.message,
              isRead: true,
              createdAt: n.createdAt,
            ))
        .toList();
    notifyListeners();

    try {
      await _repository.markAllRead();
    } catch (e) {
      await loadNotifications(refresh: true);
    }
  }

  Future<void> deleteNotification(int notificationId) async {
  // Optimistic update
  final previous = List<AppNotification>.from(_notifications);
  _notifications = _notifications
      .where((n) => n.id != notificationId)
      .toList();
  notifyListeners();

  try {
    await _repository.deleteNotification(notificationId);
  } catch (e) {
    _notifications = previous; // revert on failure
    _error = e.toString();
    notifyListeners();
  }
}

Future<void> deleteAllNotifications() async {
  final previous = List<AppNotification>.from(_notifications);
  _notifications = [];
  notifyListeners();

  try {
    await _repository.deleteAllNotifications();
  } catch (e) {
    _notifications = previous; // revert on failure
    _error = e.toString();
    notifyListeners();
  }
}

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
