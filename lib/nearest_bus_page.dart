// ============================================================
// RUET Bus App — Nearest Bus Finder Page
// ============================================================
// সব ৬টা বাস সবসময় দেখায়।
// Active buses → distance অনুযায়ী sort করে উপরে
// Inactive buses → নিচে greyed out
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'notification_service.dart';

// সব ৬টা bus এর list — সবসময় দেখাবে
const List<String> allBusIds = [
  'bus1', 'bus2', 'bus3', 'bus4', 'bus5', 'bus6'
];

class NearestBusPage extends StatefulWidget {
  const NearestBusPage({super.key});

  @override
  State<NearestBusPage> createState() => _NearestBusPageState();
}

class _NearestBusPageState extends State<NearestBusPage> {
  // ── State ──────────────────────────────────────────────────
  Map<String, Map<String, dynamic>> _busData = {};
  LatLngSimple? _myPos;
  bool _loading = true;
  bool _locationError = false;

  /// Active buses sorted by distance: [busId, distanceKm]
  List<MapEntry<String, double>> _sortedByDistance = [];

  StreamSubscription? _busSub;
  Timer? _refreshTimer;

  double _thresholdKm = 1.0;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _listenBuses();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_myPos != null) _sortBuses();
    });
  }

  // ── Location ───────────────────────────────────────────────
  Future<void> _getLocation() async {
    try {
      bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = true);
        return;
      }
      LocationPermission permission =
      await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationError = true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _myPos = LatLngSimple(pos.latitude, pos.longitude));
      _sortBuses();

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(
                () => _myPos = LatLngSimple(pos.latitude, pos.longitude));
        _sortBuses();
      });
    } catch (e) {
      setState(() => _locationError = true);
    }
  }

  // ── Firestore ──────────────────────────────────────────────
  void _listenBuses() {
    _busSub = FirebaseFirestore.instance
        .collection('buses')
        .snapshots()
        .listen((snap) {
      final Map<String, Map<String, dynamic>> data = {};
      for (final doc in snap.docs) {
        final d = doc.data();
        data[doc.id] = {
          'isActive': d['isActive'] ?? false,
          'lat': (d['lat'] as num?)?.toDouble() ?? 0,
          'lng': (d['lng'] as num?)?.toDouble() ?? 0,
          'speed': (d['speed'] as num?)?.toDouble() ?? 0,
        };
      }
      if (mounted) {
        setState(() {
          _busData = data;
          _loading = false;
        });
        _sortBuses();
      }
    });
  }

  // ── Sort active buses by distance ──────────────────────────
  void _sortBuses() {
    if (_myPos == null) return;
    final List<MapEntry<String, double>> distances = [];

    for (final busId in allBusIds) {
      final bus = _busData[busId];
      final isActive = (bus?['isActive'] as bool?) ?? false;
      final lat = (bus?['lat'] as double?) ?? 0;
      final lng = (bus?['lng'] as double?) ?? 0;

      if (!isActive || lat == 0 || lng == 0) continue;

      final dist = _calcDistance(_myPos!.lat, _myPos!.lng, lat, lng);
      distances.add(MapEntry(busId, dist));
    }

    distances.sort((a, b) => a.value.compareTo(b.value));
    if (mounted) setState(() => _sortedByDistance = distances);
  }

  // ── Distance ───────────────────────────────────────────────
  double _calcDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  int? _calcETA(String busId, double distKm) {
    final speed =
        (_busData[busId]?['speed'] as double?) ?? 0;
    if (speed < 1) return null;
    return (distKm / speed * 60).round();
  }

  // ── Helpers ────────────────────────────────────────────────
  String _busName(String busId) {
    const names = {
      'bus1': 'BUS 1', 'bus2': 'BUS 2', 'bus3': 'BUS 3',
      'bus4': 'BUS 4', 'bus5': 'BUS 5', 'bus6': 'BUS 6',
    };
    return names[busId] ?? busId.toUpperCase();
  }

  String _busRoute(String busId) {
    const routes = {
      'bus1': 'রুয়েট → আলুপট্টি → সাহেব বাজার → কোর্ট → ভদ্রা → রুয়েট',
      'bus2': 'রুয়েট → ভদ্রা → রেলগেট → বাইপাস → চারখুটার মোড় → রুয়েট',
      'bus3': 'রুয়েট → কাজলা → বিনোদপুর → বিহাস → কাটাখালী → রুয়েট',
      'bus4': 'রুয়েট → আমচত্বর → রেলস্টেশন → সিরোইল → তালাইমারী → রুয়েট',
      'bus5': 'মহিলা হল হতে (Girls Only)',
      'bus6': 'রুয়েট → সিএন্ডবি → লক্ষীপুর → বন্ধগেট → ভদ্রা → রুয়েট',
    };
    return routes[busId] ?? '';
  }

  Color _busColor(String busId) {
    const colors = {
      'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
      'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
      'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
    };
    return colors[busId] ?? Colors.blue;
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} মি';
    return '${km.toStringAsFixed(1)} কিমি';
  }

  String _formatETA(int? minutes) {
    if (minutes == null) return '--';
    if (minutes < 1) return 'এখনই!';
    if (minutes < 60) return '$minutes মিনিট';
    return '${minutes ~/ 60}ঘ ${minutes % 60}ম';
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final bgColor =
    isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF5F7FA);
    final cardBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textPrimary =
    isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary =
    isDark ? Colors.white60 : const Color(0xFF546E7A);

    // Active buses যেগুলো sort হয়েছে
    final activeBusIds =
    _sortedByDistance.map((e) => e.key).toSet();

    // Inactive buses = সব ৬টার মধ্যে যেগুলো active না
    final inactiveBusIds = allBusIds
        .where((id) => !activeBusIds.contains(id))
        .toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF1A1A2E)
            : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.near_me, size: 22),
            SizedBox(width: 8),
            Text('কাছের বাস',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => themeProvider.toggleTheme(),
            icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Location status ──────────────────────────
            _LocationBar(
              myPos: _myPos,
              locationError: _locationError,
              isDark: isDark,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 16),

            // ── Notification settings ────────────────────
            _NotificationSettingsCard(
              isDark: isDark,
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              thresholdKm: _thresholdKm,
              notificationsEnabled: _notificationsEnabled,
              onThresholdChanged: (val) {
                setState(() => _thresholdKm = val);
                NotificationService().setThreshold(val);
              },
              onToggleNotifications: (val) =>
                  setState(() => _notificationsEnabled = val),
            ),
            const SizedBox(height: 20),

            // ── Active buses ─────────────────────────────
            if (_myPos == null && !_locationError)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('GPS লোকেশন পাচ্ছি...',
                        style:
                        TextStyle(color: textSecondary)),
                  ],
                ),
              )
            else if (_sortedByDistance.isNotEmpty) ...[
              // ── Nearest bus — featured ─────────────────
              Text('সবচেয়ে কাছের বাস',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 10),
              _NearestBusCard(
                busId: _sortedByDistance[0].key,
                distanceKm: _sortedByDistance[0].value,
                speed: (_busData[_sortedByDistance[0].key]
                ?['speed'] as double?) ??
                    0,
                eta: _calcETA(_sortedByDistance[0].key,
                    _sortedByDistance[0].value),
                busName: _busName(_sortedByDistance[0].key),
                busRoute: _busRoute(_sortedByDistance[0].key),
                color: _busColor(_sortedByDistance[0].key),
                isDark: isDark,
                thresholdKm: _thresholdKm,
                formatDistance: _formatDistance,
                formatETA: _formatETA,
              ),

              // ── Other active buses ─────────────────────
              if (_sortedByDistance.length > 1) ...[
                const SizedBox(height: 20),
                Text('অন্যান্য সক্রিয় বাস',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 10),
                ..._sortedByDistance.skip(1).map(
                      (entry) => _OtherBusCard(
                    busId: entry.key,
                    distanceKm: entry.value,
                    speed: (_busData[entry.key]
                    ?['speed'] as double?) ??
                        0,
                    eta: _calcETA(entry.key, entry.value),
                    busName: _busName(entry.key),
                    busRoute: _busRoute(entry.key),
                    color: _busColor(entry.key),
                    isDark: isDark,
                    cardBg: cardBg,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    formatDistance: _formatDistance,
                    formatETA: _formatETA,
                  ),
                ),
              ],
            ],

            // ── Inactive buses — সবসময় সব ৬টা দেখাবে ────
            if (inactiveBusIds.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _sortedByDistance.isEmpty
                    ? 'সব বাস (এখন কোনো বাস চলছে না)'
                    : 'এখন চলছে না',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ...inactiveBusIds.map((busId) {
                final color = _busColor(busId);
                return Opacity(
                  opacity: 0.5,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
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
                        // Bus color icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius:
                            BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                color.withOpacity(0.25)),
                          ),
                          child: Icon(
                              Icons.directions_bus_outlined,
                              color: color,
                              size: 22),
                        ),
                        const SizedBox(width: 12),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                _busName(busId),
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _busRoute(busId),
                                style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius:
                            BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.grey
                                    .withOpacity(0.3)),
                          ),
                          child: Text(
                            'বন্ধ',
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NEAREST BUS CARD — Featured large card
// ============================================================

class _NearestBusCard extends StatelessWidget {
  final String busId;
  final double distanceKm;
  final double speed;
  final int? eta;
  final String busName;
  final String busRoute;
  final Color color;
  final bool isDark;
  final double thresholdKm;
  final String Function(double) formatDistance;
  final String Function(int?) formatETA;

  const _NearestBusCard({
    required this.busId,
    required this.distanceKm,
    required this.speed,
    required this.eta,
    required this.busName,
    required this.busRoute,
    required this.color,
    required this.isDark,
    required this.thresholdKm,
    required this.formatDistance,
    required this.formatETA,
  });

  @override
  Widget build(BuildContext context) {
    final isVeryClose = distanceKm <= thresholdKm;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.3 : 0.15),
            color.withOpacity(isDark ? 0.15 : 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(isVeryClose ? 0.8 : 0.4),
          width: isVeryClose ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 16,
              spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child:
                Icon(Icons.directions_bus, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(busName,
                        style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        )),
                    if (isVeryClose)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.5)),
                        ),
                        child: const Text('⚡ খুব কাছে!',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatDistance(distanceKm),
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('দূরত্ব',
                      style: TextStyle(
                          color: color.withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _BigStat(
                icon: Icons.access_time,
                value: formatETA(eta),
                label: 'আনুমানিক সময়',
                color: color,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _BigStat(
                icon: Icons.speed,
                value: speed > 0
                    ? '${speed.toStringAsFixed(0)} km/h'
                    : '--',
                label: 'গতি',
                color: color,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.route,
                    color: color.withOpacity(0.7), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(busRoute,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white60
                            : Colors.black54,
                        fontSize: 11,
                        height: 1.5,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// OTHER BUS CARD
// ============================================================

class _OtherBusCard extends StatelessWidget {
  final String busId;
  final double distanceKm;
  final double speed;
  final int? eta;
  final String busName;
  final String busRoute;
  final Color color;
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final String Function(double) formatDistance;
  final String Function(int?) formatETA;

  const _OtherBusCard({
    required this.busId,
    required this.distanceKm,
    required this.speed,
    required this.eta,
    required this.busName,
    required this.busRoute,
    required this.color,
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.formatDistance,
    required this.formatETA,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child:
            Icon(Icons.directions_bus, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(busName,
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(busRoute,
                    style: TextStyle(
                        color: textSecondary, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatDistance(distanceKm),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text(formatETA(eta),
                  style:
                  TextStyle(color: textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NOTIFICATION SETTINGS CARD
// ============================================================

class _NotificationSettingsCard extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final double thresholdKm;
  final bool notificationsEnabled;
  final ValueChanged<double> onThresholdChanged;
  final ValueChanged<bool> onToggleNotifications;

  const _NotificationSettingsCard({
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.thresholdKm,
    required this.notificationsEnabled,
    required this.onThresholdChanged,
    required this.onToggleNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text('নোটিফিকেশন সেটিংস',
                  style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const Spacer(),
              Switch(
                value: notificationsEnabled,
                onChanged: onToggleNotifications,
                activeColor: Colors.orange,
              ),
            ],
          ),
          if (notificationsEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.my_location,
                    size: 14, color: textSecondary),
                const SizedBox(width: 6),
                Text('বাস এই দূরত্বে এলে notify করবে:',
                    style: TextStyle(
                        color: textSecondary, fontSize: 12)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    thresholdKm < 1
                        ? '${(thresholdKm * 1000).round()} মি'
                        : '${thresholdKm.toStringAsFixed(1)} কিমি',
                    style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            Slider(
              value: thresholdKm,
              min: 0.2,
              max: 3.0,
              divisions: 14,
              activeColor: Colors.orange,
              inactiveColor: Colors.orange.withOpacity(0.2),
              onChanged: onThresholdChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('২০০ মি',
                    style: TextStyle(
                        color: textSecondary, fontSize: 10)),
                Text('৩ কিমি',
                    style: TextStyle(
                        color: textSecondary, fontSize: 10)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// LOCATION BAR
// ============================================================

class _LocationBar extends StatelessWidget {
  final LatLngSimple? myPos;
  final bool locationError;
  final bool isDark;
  final Color textSecondary;

  const _LocationBar({
    required this.myPos,
    required this.locationError,
    required this.isDark,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: locationError
              ? Colors.red.withOpacity(0.3)
              : myPos != null
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            locationError
                ? Icons.location_off
                : myPos != null
                ? Icons.location_on
                : Icons.location_searching,
            color: locationError
                ? Colors.red
                : myPos != null
                ? Colors.green
                : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locationError
                  ? 'লোকেশন পাওয়া যাচ্ছে না — GPS চালু করুন'
                  : myPos != null
                  ? 'আপনার লোকেশন পাওয়া গেছে ✓'
                  : 'GPS লোকেশন খুঁজছি...',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BIG STAT WIDGET
// ============================================================

class _BigStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _BigStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color:
                    isDark ? Colors.white54 : Colors.black45,
                    fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Simple LatLng model ────────────────────────────────────
class LatLngSimple {
  final double lat;
  final double lng;
  const LatLngSimple(this.lat, this.lng);
}