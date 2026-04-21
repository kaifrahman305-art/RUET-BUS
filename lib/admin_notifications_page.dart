// ============================================================
// RUET Bus App — Admin Notifications Page
// ============================================================
// Admin দেখবে:
// - Driver permission requests (bus off এ চালাতে চাইলে)
// - Approve / Deny করতে পারবে
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

class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

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

  Future<void> _handleRequest(
      BuildContext context, String docId,
      Map<String, dynamic> data, bool approved) async {
    final busId = data['busId'] as String? ?? '';
    final busName = data['busName'] as String? ?? busId;
    final driverName = data['driverEmail'] as String? ?? 'Driver';
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    try {
      // Update request status
      await FirebaseFirestore.instance
          .collection('driver_permission_requests')
          .doc(docId)
          .update({
        'status': approved ? 'approved' : 'denied',
        'handledBy': adminEmail,
        'handledAt': FieldValue.serverTimestamp(),
      });

      if (approved) {
        // Remove bus off for today
        final today = _dateKey(DateTime.now());
        await FirebaseFirestore.instance
            .collection('bus_off_overrides')
            .doc('${busId}_$today')
            .delete();
        await FirebaseFirestore.instance
            .collection('buses').doc(busId).update({
          'adminOff': false, 'adminOffReason': '', 'adminOffDate': '',
        });

        // Log the approval
        await FirebaseFirestore.instance.collection('admin_change_log').add({
          'changeType': 'bus_on', 'busId': busId, 'busName': busName,
          'title': '$busName — Driver Permission Approved',
          'body': '$driverName এর জন্য bus on করা হয়েছে',
          'doneBy': adminEmail, 'timestamp': FieldValue.serverTimestamp(),
          'extraData': {'date': today},
        });

        // Broadcast
        await NotificationService.saveAdminBroadcast(
          title: '✅ $busName — চালু হচ্ছে',
          body: 'Driver permission দেওয়া হয়েছে। আজ $busName চলবে।',
          changeType: 'bus_on', busId: busId, busName: busName,
        );
      } else {
        // Notify driver of denial via broadcast
        await NotificationService.saveAdminBroadcast(
          title: '❌ $busName — Permission Denied',
          body: 'Admin permission দেননি। আজ $busName চলবে না।',
          changeType: 'bus_off', busId: busId, busName: busName,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approved
              ? '$busName — Permission approved ✅'
              : '$busName — Permission denied ❌'),
          backgroundColor: approved ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050810),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.notifications_outlined,
              color: Color(0xFFFFD700), size: 22),
          SizedBox(width: 8),
          Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white10),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('driver_permission_requests')
            .orderBy('requestedAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final pending = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == 'pending';
          }).toList();
          final handled = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] != 'pending';
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.notifications_none,
                    size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                const Text('কোনো notification নেই',
                    style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Driver permission চাইলে এখানে দেখাবে',
                    style: TextStyle(color: Colors.white30, fontSize: 12)),
              ]),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Pending requests
              if (pending.isNotEmpty) ...[
                Row(children: [
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.orange),
                  ),
                  const Text('Pending Requests',
                      style: TextStyle(color: Colors.white54, fontSize: 12,
                          fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${pending.length}',
                        style: const TextStyle(color: Colors.orange,
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 10),
                ...pending.map((doc) => _RequestCard(
                  docId: doc.id,
                  data: doc.data() as Map<String, dynamic>,
                  isPending: true,
                  formatTime: _formatTime,
                  onHandle: (approved) =>
                      _handleRequest(context, doc.id,
                          doc.data() as Map<String, dynamic>, approved),
                )),
                const SizedBox(height: 20),
              ],

              // Handled requests
              if (handled.isNotEmpty) ...[
                const Text('Handled',
                    style: TextStyle(color: Colors.white38, fontSize: 12,
                        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                ...handled.map((doc) => _RequestCard(
                  docId: doc.id,
                  data: doc.data() as Map<String, dynamic>,
                  isPending: false,
                  formatTime: _formatTime,
                  onHandle: null,
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isPending;
  final String Function(dynamic) formatTime;
  final Function(bool)? onHandle;

  const _RequestCard({
    required this.docId, required this.data,
    required this.isPending, required this.formatTime,
    required this.onHandle,
  });

  @override
  Widget build(BuildContext context) {
    final busId = data['busId'] as String? ?? '';
    final busName = data['busName'] as String? ?? busId;
    final driverEmail = data['driverEmail'] as String? ?? '';
    final reason = data['reason'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';
    final color = _busColors[busId] ?? Colors.blue;

    Color statusColor;
    String statusText;
    if (status == 'approved') {
      statusColor = Colors.green; statusText = 'Approved ✅';
    } else if (status == 'denied') {
      statusColor = Colors.red; statusText = 'Denied ❌';
    } else {
      statusColor = Colors.orange; statusText = 'Pending ⏳';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending ? color.withOpacity(0.35) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.directions_bus, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(busName, style: TextStyle(color: color,
                    fontWeight: FontWeight.bold, fontSize: 14)),
                Text(formatTime(data['requestedAt']),
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(statusText, style: TextStyle(
                  color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 10),

          // Driver info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.drive_eta, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(driverEmail,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
                ]),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.message_outlined,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(reason,
                        style: const TextStyle(color: Colors.white54, fontSize: 11))),
                  ]),
                ],
              ],
            ),
          ),

          // Approve/Deny buttons (pending only)
          if (isPending && onHandle != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onHandle!(true),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onHandle!(false),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('Deny'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 0.8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}