// ============================================================
// RUET Bus App — Notification History Page
// ============================================================
// Last 1 month এর notification history দেখায়।
// SharedPreferences এ locally store করা হয়।
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class NotificationHistoryItem {
  final String busId;
  final String busName;
  final String message;
  final DateTime time;
  final double distanceKm;

  const NotificationHistoryItem({
    required this.busId,
    required this.busName,
    required this.message,
    required this.time,
    required this.distanceKm,
  });

  Map<String, dynamic> toJson() => {
    'busId': busId,
    'busName': busName,
    'message': message,
    'time': time.toIso8601String(),
    'distanceKm': distanceKm,
  };

  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) =>
      NotificationHistoryItem(
        busId: json['busId'] as String,
        busName: json['busName'] as String,
        message: json['message'] as String,
        time: DateTime.parse(json['time'] as String),
        distanceKm: (json['distanceKm'] as num).toDouble(),
      );
}

// ── Static helper to save notification ─────────────────────

Future<void> saveNotificationHistory({
  required String busId,
  required String busName,
  required String message,
  required double distanceKm,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notif_history';
    final existing = prefs.getString(key);
    List<Map<String, dynamic>> list = [];

    if (existing != null) {
      list = (jsonDecode(existing) as List)
          .cast<Map<String, dynamic>>();
    }

    // Add new item
    list.add(NotificationHistoryItem(
      busId: busId,
      busName: busName,
      message: message,
      time: DateTime.now(),
      distanceKm: distanceKm,
    ).toJson());

    // Keep only last 1 month
    final oneMonthAgo =
    DateTime.now().subtract(const Duration(days: 30));
    list = list.where((item) {
      final t = DateTime.parse(item['time'] as String);
      return t.isAfter(oneMonthAgo);
    }).toList();

    await prefs.setString(key, jsonEncode(list));
  } catch (e) {
    debugPrint('Notification history save error: $e');
  }
}

// ── Notification History Page ───────────────────────────────

class NotificationHistoryPage extends StatefulWidget {
  const NotificationHistoryPage({super.key});

  @override
  State<NotificationHistoryPage> createState() =>
      _NotificationHistoryPageState();
}

class _NotificationHistoryPageState
    extends State<NotificationHistoryPage> {
  List<NotificationHistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'notif_history';
      final existing = prefs.getString(key);
      if (existing != null) {
        final list = (jsonDecode(existing) as List)
            .cast<Map<String, dynamic>>();
        final items = list
            .map((e) => NotificationHistoryItem.fromJson(e))
            .toList();
        // Sort newest first
        items.sort((a, b) => b.time.compareTo(a.time));
        setState(() => _items = items);
      }
    } catch (e) {
      debugPrint('Load history error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('History মুছে ফেলবেন?'),
        content: const Text(
            'সব notification history মুছে যাবে। আর ফিরে পাবেন না।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('মুছুন',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notif_history');
      setState(() => _items = []);
    }
  }

  Color _busColor(String busId) {
    const colors = {
      'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
      'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
      'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
    };
    return colors[busId] ?? Colors.blue;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'এইমাত্র';
    if (diff.inMinutes < 60) return '${diff.inMinutes} মিনিট আগে';
    if (diff.inHours < 24) return '${diff.inHours} ঘন্টা আগে';
    if (diff.inDays < 7) return '${diff.inDays} দিন আগে';

    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${time.day} ${months[time.month]}';
  }

  String _formatFullTime(DateTime time) {
    final h = time.hour > 12 ? time.hour - 12 : time.hour;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final bgColor =
    isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF5F7FA);
    final cardBg =
    isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textPrimary =
    isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary =
    isDark ? Colors.white60 : const Color(0xFF546E7A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF1A1A2E)
            : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.notifications_outlined, size: 22),
            SizedBox(width: 8),
            Text('Notification History',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear History',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 64, color: textSecondary),
            const SizedBox(height: 16),
            Text('কোনো notification নেই',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'বাস আপনার notification range এ এলে\nএখানে record থাকবে (১ মাস)',
              style: TextStyle(
                  color: textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final color = _busColor(item.busId);
          final distStr = item.distanceKm < 1
              ? '${(item.distanceKm * 1000).round()} মি'
              : '${item.distanceKm.toStringAsFixed(1)} কিমি';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white12
                    : Colors.black12,
              ),
            ),
            child: Row(
              children: [
                // Bus icon
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius:
                    BorderRadius.circular(10),
                    border: Border.all(
                        color: color.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.directions_bus,
                      color: color, size: 20),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚌 ${item.busName} কাছে ছিল',
                        style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'দূরত্ব: $distStr',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFullTime(item.time),
                        style: TextStyle(
                            color: textSecondary,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Time ago
                Text(
                  _formatTime(item.time),
                  style: TextStyle(
                      color: textSecondary,
                      fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}