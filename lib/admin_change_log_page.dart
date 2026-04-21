// ============================================================
// RUET Bus App — Admin Change Log Page
// ============================================================
// Admin এর সব change এর history দেখায়।
// প্রতিটা change থেকে default এ revert করা যায়।
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

const Map<String, Color> _busColors = {
  'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
  'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
  'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
};

class AdminChangeLogPage extends StatelessWidget {
  const AdminChangeLogPage({super.key});

  Color _typeColor(String type) {
    switch (type) {
      case 'bus_off': return Colors.redAccent;
      case 'bus_on':
      case 'extra_trip': return Colors.greenAccent;
      case 'revert': return const Color(0xFFFFD700);
      default: return Colors.blue;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'bus_off': return Icons.cancel_outlined;
      case 'bus_on': return Icons.check_circle_outline;
      case 'extra_trip': return Icons.add_circle_outline;
      case 'revert': return Icons.restore;
      default: return Icons.info_outline;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'bus_off': return 'Bus বন্ধ';
      case 'bus_on': return 'Bus চালু';
      case 'extra_trip': return 'Extra Trip';
      case 'revert': return 'Revert';
      default: return type;
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '--';
    try {
      final dt = (ts as Timestamp).toDate();
      final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day}/${dt.month}/${dt.year}  $h:$m $period';
    } catch (_) { return '--'; }
  }

  Future<void> _revertChange(
      BuildContext context, Map<String, dynamic> data, String docId) async {
    final changeType = data['changeType'] as String? ?? '';
    final busId = data['busId'] as String? ?? '';
    final busName = data['busName'] as String? ?? busId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Revert করবেন?',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Text(
          'এই change টা undo করা হবে। $busName default এ ফিরে যাবে।',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Revert', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';

      if (changeType == 'bus_off') {
        // Remove bus off
        final date = data['extraData']?['date'] as String? ?? '';
        if (date.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('bus_off_overrides')
              .doc('${busId}_$date')
              .delete();
          await FirebaseFirestore.instance
              .collection('buses').doc(busId).update({
            'adminOff': false, 'adminOffReason': '', 'adminOffDate': '',
          });
        }
      } else if (changeType == 'extra_trip') {
        // Remove extra trip
        final tripDocId = data['extraData']?['tripDocId'] as String?;
        if (tripDocId != null) {
          await FirebaseFirestore.instance
              .collection('bus_extra_trips').doc(tripDocId).delete();
        }
      }

      // Save revert log
      final dateKey = DateTime.now();
      await FirebaseFirestore.instance.collection('admin_change_log').add({
        'changeType': 'revert', 'busId': busId, 'busName': busName,
        'title': 'Revert: $busName',
        'body': '${_typeLabel(changeType)} revert করা হয়েছে',
        'revertedChangeId': docId, 'doneBy': adminEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Broadcast to users/drivers
      await NotificationService.saveAdminBroadcast(
        title: '🔄 $busName — Revert',
        body: '${_typeLabel(changeType)} cancel করা হয়েছে। Default এ ফিরে গেছে।',
        changeType: 'revert', busId: busId, busName: busName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Revert সফল হয়েছে ✅'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050810),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.history, color: Color(0xFFFFD700), size: 22),
          SizedBox(width: 8),
          Text('Change Log', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white10),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin_change_log')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                const Text('কোনো change log নেই',
                    style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Admin কিছু change করলে এখানে দেখাবে',
                    style: TextStyle(color: Colors.white30, fontSize: 12)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final changeType = data['changeType'] as String? ?? '';
              final busId = data['busId'] as String? ?? '';
              final busName = data['busName'] as String? ?? busId;
              final title = data['title'] as String? ?? '';
              final body = data['body'] as String? ?? '';
              final doneBy = data['doneBy'] as String? ?? '';
              final color = _busColors[busId] ?? Colors.blue;
              final typeColor = _typeColor(changeType);
              final isRevert = changeType == 'revert';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: typeColor.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // Bus color dot
                      Container(
                        width: 10, height: 10,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: color),
                      ),
                      // Change type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: typeColor.withOpacity(0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_typeIcon(changeType), color: typeColor, size: 12),
                          const SizedBox(width: 4),
                          Text(_typeLabel(changeType),
                              style: TextStyle(color: typeColor,
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text(busName, style: TextStyle(
                          color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Text(_formatTime(data['timestamp']),
                          style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ]),
                    const SizedBox(height: 8),
                    Text(body.isNotEmpty ? body : title,
                        style: const TextStyle(color: Colors.white70, fontSize: 12,
                            height: 1.4)),
                    if (doneBy.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('By: $doneBy',
                          style: const TextStyle(color: Colors.white30, fontSize: 10)),
                    ],

                    // Revert button (not for revert entries themselves)
                    if (!isRevert &&
                        (changeType == 'bus_off' || changeType == 'extra_trip')) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _revertChange(context, data, docId),
                          icon: const Icon(Icons.restore, size: 14),
                          label: const Text('Revert (Default এ ফিরুন)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFD700),
                            side: const BorderSide(
                                color: Color(0xFFFFD700), width: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}