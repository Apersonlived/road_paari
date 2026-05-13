import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:road_paari/presentation/widgets/poi_detail.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/poi_model.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/poi_provider.dart';
import '../../widgets/common/bottom_nav_bar.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushNamed(context, AppRoutes.map);
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.explore);
        break;
      case 2:
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  void _confirmClearAll(BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all notifications'),
        content: const Text(
          'This will permanently delete all notifications. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteAllNotifications();
            },
            child: const Text('Clear all', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Updates',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Nearby place alerts',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Mark all read button
                  Consumer<NotificationProvider>(
                    builder: (context, provider, _) {
                      final hasUnread = provider.notifications.any(
                        (n) => !n.isRead,
                      );
                      if (!hasUnread) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: provider.isLoading
                            ? null
                            : () => provider.markAllRead(),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(fontSize: 13),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (provider.notifications.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Existing mark all read button
                    if (provider.notifications.any((n) => !n.isRead))
                      TextButton(
                        onPressed: provider.isLoading
                            ? null
                            : provider.markAllRead,
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    // New clear all button
                    TextButton(
                      onPressed: provider.isLoading
                          ? null
                          : () => _confirmClearAll(context, provider),
                      child: const Text(
                        'Clear all',
                        style: TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Unread badge summary
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                final unread = provider.notifications
                    .where((n) => !n.isRead)
                    .length;
                if (unread == 0) return const SizedBox.shrink();
                return Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$unread unread',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Notification list
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (context, provider, _) {
                  // Loading
                  if (provider.isLoading && provider.notifications.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Error
                  if (provider.error != null &&
                      provider.notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => provider.loadNotifications(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Empty
                  if (provider.notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 56,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "You'll be alerted when you're near a place",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // List
                  return RefreshIndicator(
                    onRefresh: () => provider.loadNotifications(refresh: true),
                    child: ListView.separated(
                      itemCount: provider.notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notif = provider.notifications[index];
                        return Dismissible(
                          key: Key('notif_${notif.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) =>
                              provider.deleteNotification(notif.id),
                          child: _NotificationTile(
                            notif: notif,
                            onTap: () async {
                              // Mark as read
                              if (!notif.isRead) provider.markAsRead(notif.id);

                              // Navigate to POI detail if poiId exists
                              if (notif.poiId != null) {
                                final poiProvider = context.read<POIProvider>();

                                // Try to find POI in already loaded list first
                                POI? poi = poiProvider.pois
                                    .where((p) => p.id == notif.poiId)
                                    .firstOrNull;

                                // If not loaded yet, fetch it
                                if (poi == null) {
                                  await poiProvider.loadPOIById(notif.poiId!);
                                  poi = poiProvider.selectedPoi;
                                }

                                if (poi != null && context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          POIDetailScreen(poi: poi!),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

// Notification tile 

class _NotificationTile extends StatelessWidget {
  final dynamic notif; // AppNotification
  final VoidCallback onTap;

  const _NotificationTile({required this.notif, required this.onTap});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    return InkWell(
      onTap: isUnread ? onTap : null,
      child: Container(
        color: isUnread
            ? AppColors.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isUnread
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_rounded,
                size: 18,
                color: isUnread ? AppColors.primary : Colors.grey[400],
              ),
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.message,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _timeAgo(notif.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
