import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/providers/notification_provider.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  @override
  void initState() {
    super.initState();
    Provider.of<NotificationProvider>(context, listen: false).loadNotifications();
  }

  Color _getNotificationColor(String type, bool isRead) {
    if (isRead) return Colors.grey.shade200;
    switch (type) {
      case 'warning':
        return Colors.orange.shade100;
      case 'info':
        return Colors.blue.shade100;
      case 'alert':
        return Colors.red.shade100;
      case 'success':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getNotificationIconColor(String type, bool isRead) {
    if (isRead) return Colors.grey;
    switch (type) {
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'alert':
        return Colors.red;
      case 'success':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      case 'alert':
        return Icons.error;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              if (notificationProvider.notifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.clear_all),
                tooltip: 'Clear All Notifications',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear All Notifications?'),
                      content: const Text('This will delete all notifications. This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            notificationProvider.clearAllNotifications();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All notifications cleared.')),
                            );
                          },
                          child: const Text('Clear', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          final notifications = notificationProvider.notifications;
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                color: _getNotificationColor(notification.type, notification.isRead),
                child: ListTile(
                  leading: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationIconColor(notification.type, notification.isRead),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      color: notification.isRead ? Colors.grey.shade700 : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    notification.message,
                    style: TextStyle(
                      color: notification.isRead ? Colors.grey.shade600 : Colors.black87,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${notification.date.day}/${notification.date.month}',
                        style: TextStyle(
                          fontSize: 12,
                          color: notification.isRead ? Colors.grey.shade600 : Colors.black54,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          notificationProvider.dismissNotification(notification);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Notification "${notification.title}" dismissed.')),
                          );
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!notification.isRead) {
                      notificationProvider.markAsRead(notification);
                    }
                    // TODO: Implement logic for tapping a notification (e.g., navigate to relevant page)
                    print('Tapped on notification: ${notification.title}');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
