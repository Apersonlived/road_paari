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

  /// Unread count — useful for a badge on the bottom nav bar.
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

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
