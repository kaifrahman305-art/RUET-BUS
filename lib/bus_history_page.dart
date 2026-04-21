// ============================================================
// RUET Bus App — Bus History Page (Updated)
// ============================================================
// - Email দেখায় না (privacy)
// - শুধু ১ মাসের history
// - Admin দেখলে সব history, Student দেখলে last 1 month
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class BusHistoryPage extends StatefulWidget {
  const BusHistoryPage({super.key});

  @override
  State<BusHistoryPage> createState() => _BusHistoryPageState();
}

class _BusHistoryPageState extends State<BusHistoryPage> {
  String _selectedFilter = 'all';

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
        title: const Text('Trip History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => themeProvider.toggleTheme(),
            icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Chip(label: 'সব', busId: 'all',
                      color: const Color(0xFF1565C0),
                      isSelected: _selectedFilter == 'all',
                      isDark: isDark,
                      onTap: () =>
                          setState(() => _selectedFilter = 'all')),
                  ...['bus1','bus2','bus3','bus4','bus5','bus6']
                      .map((id) => _Chip(
                    label: id.replaceAll('bus', 'BUS '),
                    busId: id,
                    color: _busColor(id),
                    isSelected: _selectedFilter == id,
                    isDark: isDark,
                    onTap: () => setState(
                            () => _selectedFilter = id),
                  )),
                ],
              ),
            ),
          ),

          // History list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 64, color: textSecondary),
                        const SizedBox(height: 16),
                        Text('এখনো কোনো trip নেই',
                            style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          'Driver trip শেষ করলে এখানে দেখাবে',
                          style: TextStyle(
                              color: textSecondary,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data()
                    as Map<String, dynamic>;
                    return _TripCard(
                      data: data,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    // 1 month ago
    final oneMonthAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30)));

    Query query = FirebaseFirestore.instance
        .collection('trip_history')
        .where('createdAt', isGreaterThan: oneMonthAgo)
        .orderBy('createdAt', descending: true)
        .limit(100);

    if (_selectedFilter != 'all') {
      query = FirebaseFirestore.instance
          .collection('trip_history')
          .where('busId', isEqualTo: _selectedFilter)
          .where('createdAt', isGreaterThan: oneMonthAgo)
          .orderBy('createdAt', descending: true)
          .limit(100);
    }

    return query.snapshots();
  }

  Color _busColor(String busId) {
    const colors = {
      'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
      'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
      'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
    };
    return colors[busId] ?? Colors.blue;
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  const _TripCard({
    required this.data,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  Color _busColor(String busId) {
    const colors = {
      'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
      'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
      'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
    };
    return colors[busId] ?? Colors.blue;
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '--';
    try {
      final dt = (ts as Timestamp).toDate();
      final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day}/${dt.month}/${dt.year}  $h:$m $period';
    } catch (_) { return '--'; }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}ঘ ${m}মি';
    return '${m}মি';
  }

  @override
  Widget build(BuildContext context) {
    final busId = data['busId'] as String? ?? 'bus1';
    final busName = data['busName'] as String? ?? 'BUS';
    final color = _busColor(busId);
    final cardBg =
    isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final distance =
        (data['distanceKm'] as num?)?.toDouble() ?? 0;
    final duration = data['durationSeconds'] as int?;
    final avgSpeed =
        (data['avgSpeedKmh'] as num?)?.toDouble() ?? 0;

    // Driver/Helper name (from assignment — no email)
    final driverName = data['driverName'] as String?;
    final helperName = data['helperName'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: color.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.directions_bus,
                      color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(busName,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      // Driver & Helper (no email)
                      if (driverName != null ||
                          helperName != null)
                        Text(
                          [
                            if (driverName != null)
                              'Driver: $driverName',
                            if (helperName != null)
                              'Helper: $helperName',
                          ].join(' · '),
                          style: TextStyle(
                              color: textSecondary,
                              fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text('Completed',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Time
            Row(children: [
              Icon(Icons.access_time, size: 13, color: textSecondary),
              const SizedBox(width: 4),
              Text('শুরু: ${_formatTimestamp(data['startTime'])}',
                  style: TextStyle(color: textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.flag, size: 13, color: textSecondary),
              const SizedBox(width: 4),
              Text('শেষ: ${_formatTimestamp(data['endTime'])}',
                  style: TextStyle(color: textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 10),

            // Stats
            Row(
              children: [
                _StatBadge(icon: Icons.route,
                    value: '${distance.toStringAsFixed(1)} কিমি',
                    color: color),
                const SizedBox(width: 8),
                _StatBadge(icon: Icons.timer,
                    value: _formatDuration(duration),
                    color: Colors.orange),
                const SizedBox(width: 8),
                _StatBadge(icon: Icons.speed,
                    value: '${avgSpeed.toStringAsFixed(0)} km/h',
                    color: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _StatBadge({required this.icon, required this.value,
    required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(value,
                  style: TextStyle(color: color, fontSize: 11,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String busId;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.busId,
    required this.color, required this.isSelected,
    required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? color
                  : color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}