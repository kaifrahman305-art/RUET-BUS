// ============================================================
// RUET Bus App — Driver Notifications Page
// ============================================================
// Admin broadcasts দেখায় drivers দের জন্য।
// Users এর notification history এর মতো কিন্তু admin changes দেখায়।
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

const Map<String, Color> _busColors = {
  'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
  'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
  'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
};

class DriverNotificationsPage extends StatelessWidget {
  const DriverNotificationsPage({super.key});

  String _formatTime(dynamic ts) {
    if (ts == null) return '--';
    try {
      final dt = (ts as Timestamp).toDate();
      final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day}/${dt.month}  $h:$m $period';
    } catch (_) { return '--'; }
  }

  Color _changeTypeColor(String type) {
    switch (type) {
      case 'bus_off': return Colors.redAccent;
      case 'bus_on': return Colors.greenAccent;
      case 'extra_trip': return const Color(0xFFFFD700);
      case 'revert': return Colors.blue;
      default: return Colors.blue;
    }
  }

  String _changeTypeEmoji(String type) {
    switch (type) {
      case 'bus_off': return '🚫';
      case 'bus_on': return '✅';
      case 'extra_trip': return '⭐';
      case 'revert': return '🔄';
      default: return '📢';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final bgColor = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF5F7FA);
    final cardBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF546E7A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Row(children: [
          Icon(Icons.notifications_outlined, size: 22),
          SizedBox(width: 8),
          Text('Admin Notifications',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            onPressed: () => themeProvider.toggleTheme(),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin_broadcasts')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_none, size: 64, color: textSecondary),
              const SizedBox(height: 16),
              Text('কোনো notification নেই',
                  style: TextStyle(color: textPrimary, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Admin কিছু change করলে এখানে দেখাবে',
                  style: TextStyle(color: textSecondary, fontSize: 13)),
            ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final busId = data['busId'] as String? ?? '';
              final title = data['title'] as String? ?? '';
              final body = data['body'] as String? ?? '';
              final changeType = data['changeType'] as String? ?? '';
              final color = _busColors[busId] ?? Colors.blue;
              final typeColor = _changeTypeColor(changeType);
              final emoji = _changeTypeEmoji(changeType);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: typeColor.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: typeColor.withOpacity(0.3)),
                    ),
                    child: Center(child: Text(emoji,
                        style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(
                          color: textPrimary, fontWeight: FontWeight.bold,
                          fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(body, style: TextStyle(
                          color: textSecondary, fontSize: 12),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  const SizedBox(width: 8),
                  Text(_formatTime(data['timestamp']),
                      style: TextStyle(color: textSecondary, fontSize: 10)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}