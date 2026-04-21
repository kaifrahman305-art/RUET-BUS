// ============================================================
// RUET Bus App — Passenger Live Map Page (Updated)
// ============================================================
// New: Admin broadcast listener — admin change করলে
//      users সাথে সাথে notification পাবে
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'bus_routes_data.dart';
import 'bus_schedule_page.dart';
import 'nearest_bus_page.dart';
import 'notification_service.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'bus_history_page.dart';
import 'notification_history_page.dart';
import 'driver_notifications_page.dart';

class PassengerLiveMapPage extends StatefulWidget {
  const PassengerLiveMapPage({super.key});

  @override
  State<PassengerLiveMapPage> createState() =>
      _PassengerLiveMapPageState();
}

class _PassengerLiveMapPageState extends State<PassengerLiveMapPage>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  Map<String, Map<String, dynamic>> _busData = {};
  Map<String, Map<String, dynamic>> _prevBusData = {};
  LatLng? _myPos;
  bool _loading = true;
  StreamSubscription? _busSub;
  StreamSubscription? _broadcastSub;
  String? _selectedBusId;
  Timer? _etaTimer;
  final Map<String, int> _etaMinutes = {};
  bool _showRoutes = false;
  bool _didAutoCenter = false;

  // Unread admin broadcast count
  int _unreadBroadcasts = 0;
  DateTime _lastReadTime = DateTime.now().subtract(const Duration(hours: 24));

  final _notifService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notifService.init();
    _initPermissionsAndLocation();
    _listenBuses();
    _listenAdminBroadcasts(); // NEW
    _etaTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => _updateETAs());
  }

  Future<void> _initPermissionsAndLocation() async {
    await _startMyLocation();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _notifService.requestPermission();
  }

  // ── Firestore bus listener ─────────────────────────────────
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
          'lastUpdated': d['lastUpdated'],
          'adminOff': d['adminOff'] ?? false,
          'adminOffReason': d['adminOffReason'] ?? '',
          'assignedDriver': d['assignedDriver'] ?? '',
          'assignedHelper': d['assignedHelper'] ?? '',
        };
      }
      if (mounted) {
        if (_prevBusData.isNotEmpty) {
          _notifService.checkTripEnded(
            previousData: _prevBusData,
            currentData: data,
            busNameFn: _busName,
            busRouteFn: _busRoute,
          );
        }
        setState(() {
          _prevBusData = Map.from(_busData);
          _busData = data;
          _loading = false;
        });
        _updateETAs();
        _checkNearbyBuses();
      }
    });
  }

  // ── Admin broadcast listener (NEW) ────────────────────────
  /// Admin কিছু change করলে users সাথে সাথে notification পাবে
  void _listenAdminBroadcasts() {
    _broadcastSub = FirebaseFirestore.instance
        .collection('admin_broadcasts')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((snap) {
      if (!mounted || snap.docs.isEmpty) return;

      int unread = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        if (ts == null) continue;
        if (ts.toDate().isAfter(_lastReadTime)) unread++;
      }

      if (mounted) setState(() => _unreadBroadcasts = unread);

      // Latest broadcast — 30 সেকেন্ডের মধ্যে হলে notification দেখাও
      final latest = snap.docs.first.data();
      final ts = latest['timestamp'] as Timestamp?;
      if (ts != null) {
        final age = DateTime.now().difference(ts.toDate()).inSeconds;
        if (age <= 30) {
          final title = latest['title'] as String? ?? '';
          final body = latest['body'] as String? ?? '';
          if (title.isNotEmpty) {
            _notifService.showAdminBroadcast(
              title: title,
              body: body,
              id: 150 + (snap.docs.first.id.hashCode % 50).abs(),
            );
          }
        }
      }
    });
  }

  // ── GPS ────────────────────────────────────────────────────
  Future<void> _startMyLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      final firstPos = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = firstPos);
      _autoCenterMap(firstPos);

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((pos) {
        if (!mounted) return;
        final updated = LatLng(pos.latitude, pos.longitude);
        setState(() => _myPos = updated);
        _updateETAs();
        _checkNearbyBuses();
        _autoCenterMap(updated);
      });
    } catch (e) {
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
        if (!mounted) return;
        final p = LatLng(pos.latitude, pos.longitude);
        setState(() => _myPos = p);
        _autoCenterMap(p);
      } catch (_) {}
    }
  }

  void _autoCenterMap(LatLng pos) {
    if (_didAutoCenter) return;
    _didAutoCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try { _mapController.move(pos, 16); } catch (_) {}
    });
  }

  void _checkNearbyBuses() {
    if (_myPos == null) return;
    _notifService.checkAndNotify(
      busDataMap: _busData,
      userLat: _myPos!.latitude,
      userLng: _myPos!.longitude,
      etaMinutes: _etaMinutes,
      busNameFn: _busName,
      busRouteFn: _busRoute,
      calcDistance: _calcDistance,
    );
  }

  void _updateETAs() {
    if (_myPos == null) return;
    final Map<String, int> newETAs = {};
    for (final entry in _busData.entries) {
      final bus = entry.value;
      if (bus['isActive'] != true) continue;
      final lat = bus['lat'] as double;
      final lng = bus['lng'] as double;
      final speed = bus['speed'] as double;
      if (lat == 0 || lng == 0 || speed < 1) continue;
      final dist =
      _calcDistance(_myPos!.latitude, _myPos!.longitude, lat, lng);
      newETAs[entry.key] = (dist / speed * 60).round();
    }
    if (mounted) setState(() => _etaMinutes.addAll(newETAs));
  }

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

  String _formatETA(int minutes) {
    if (minutes < 1) return 'Arriving';
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  String _busName(String busId) {
    const names = {
      'bus1': 'BUS 1', 'bus2': 'BUS 2', 'bus3': 'BUS 3',
      'bus4': 'BUS 4', 'bus5': 'BUS 5', 'bus6': 'BUS 6',
    };
    return names[busId] ?? busId.toUpperCase();
  }

  String _busRoute(String busId) {
    const routes = {
      'bus1': 'রুয়েট-আলুপট্টি-সাহেব বাজার-সিএন্ডবি-কোর্ট-লক্ষীপুর-বর্ণালী-রেলগেট-ভদ্রা-রুয়েট',
      'bus2': 'রুয়েট-ভদ্রা-রেলগেট-বাইপাস-চারখুটার মোড়-রুয়েট',
      'bus3': 'রুয়েট-কাজলা-বিনোদপুর-বিহাস-কাটাখালী-রুয়েট',
      'bus4': 'রুয়েট-আমচত্বর-রেলস্টেশন-সিরোইল-সাগরপাড়া-নর্দান-তালাইমারী-রুয়েট',
      'bus5': 'Girls only - মহিলা হল হতে',
      'bus6': 'Campus Trip - রুয়েট-সিএন্ডবি-লক্ষীপুর-বন্ধগেট-রেলগেট-ভদ্রা-রুয়েট',
    };
    return routes[busId] ?? '';
  }

  Color _busColor(String busId) {
    const colors = {
      'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
      'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
      'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
    };
    return colors[busId] ?? Colors.red;
  }

  void _onBusButtonTap(String busId) {
    setState(() => _selectedBusId = busId);
    final bus = _busData[busId];
    final isActive = (bus?['isActive'] as bool?) ?? false;
    final lat = (bus?['lat'] as double?) ?? 0.0;
    final lng = (bus?['lng'] as double?) ?? 0.0;
    if (isActive && lat != 0 && lng != 0) {
      _mapController.move(LatLng(lat, lng), 15);
    } else {
      final routePoints = busRoutes[busId];
      if (routePoints != null && routePoints.isNotEmpty) {
        _mapController.move(routePoints[0], 13);
      }
    }
    _showBusDetails(busId);
  }

  void _showBusDetails(String busId) {
    final bus = _busData[busId];
    final isActive = (bus?['isActive'] as bool?) ?? false;
    final lat = (bus?['lat'] as double?) ?? 0.0;
    final lng = (bus?['lng'] as double?) ?? 0.0;
    final speed = (bus?['speed'] as double?) ?? 0.0;
    final color = _busColor(busId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Admin off info
    final adminOff = (bus?['adminOff'] as bool?) ?? false;
    final offReason = (bus?['adminOffReason'] as String?) ?? '';

    // Assignment info
    final driverName = (bus?['assignedDriver'] as String?) ?? '';
    final helperName = (bus?['assignedHelper'] as String?) ?? '';

    double? distance;
    if (_myPos != null && lat != 0 && lng != 0) {
      distance =
          _calcDistance(_myPos!.latitude, _myPos!.longitude, lat, lng);
    }
    final etaMin = _etaMinutes[busId];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),

            // Bus header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(Icons.directions_bus, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_busName(busId), style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _PulseIndicator(
                        color: isActive ? Colors.greenAccent : Colors.redAccent,
                        animate: isActive),
                    const SizedBox(width: 6),
                    Text(
                      adminOff ? 'Admin বন্ধ' : isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                          color: adminOff ? Colors.orange
                              : isActive ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ],
              )),
              IconButton(
                onPressed: () {
                  setState(() => _showRoutes = !_showRoutes);
                  Navigator.pop(context);
                },
                icon: Icon(
                    _showRoutes ? Icons.route : Icons.route_outlined,
                    color: color),
              ),
            ]),
            const SizedBox(height: 14),

            // Route
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.route,
                      color: isDark ? Colors.white54 : Colors.black45, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_busRoute(busId),
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12))),
                ],
              ),
            ),

            // Driver & Helper
            if (driverName.isNotEmpty || helperName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF43A047).withOpacity(0.3)),
                ),
                child: Row(children: [
                  if (driverName.isNotEmpty) ...[
                    const Icon(Icons.drive_eta,
                        color: Color(0xFF43A047), size: 16),
                    const SizedBox(width: 6),
                    Text('Driver: $driverName',
                        style: const TextStyle(color: Color(0xFF43A047),
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                  if (driverName.isNotEmpty && helperName.isNotEmpty)
                    const Text('   ·   ', style: TextStyle(color: Colors.grey)),
                  if (helperName.isNotEmpty) ...[
                    const Icon(Icons.support_agent,
                        color: Color(0xFF43A047), size: 16),
                    const SizedBox(width: 6),
                    Text('Helper: $helperName',
                        style: const TextStyle(color: Color(0xFF43A047),
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ],

            // Admin off reason
            if (adminOff && offReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(offReason,
                        style: const TextStyle(color: Colors.orange,
                            fontSize: 12, height: 1.4))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            if (isActive && !adminOff) ...[
              Row(children: [
                _statCard(icon: Icons.speed, label: 'Speed',
                    value: '${speed.toStringAsFixed(1)} km/h',
                    color: color, isDark: isDark),
                const SizedBox(width: 10),
                _statCard(icon: Icons.social_distance, label: 'Distance',
                    value: distance != null ? '${distance.toStringAsFixed(2)} km' : '--',
                    color: color, isDark: isDark),
                const SizedBox(width: 10),
                _statCard(icon: Icons.access_time, label: 'ETA',
                    value: etaMin != null ? _formatETA(etaMin) : '--',
                    color: color, isDark: isDark),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    if (lat != 0 && lng != 0) {
                      _mapController.move(LatLng(lat, lng), 16);
                    }
                  },
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Focus on Bus'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _showRoutes = true);
                    final r = busRoutes[busId];
                    if (r != null && r.isNotEmpty) _mapController.move(r[0], 13);
                  },
                  icon: const Icon(Icons.route),
                  label: const Text('Show Route on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      adminOff && offReason.isNotEmpty
                          ? offReason
                          : 'Bus is not currently running',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _statCard({required IconData icon, required String label,
    required String value, required Color color, required bool isDark}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 12,
              fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45, fontSize: 10)),
        ]),
      ),
    );
  }

  Future<void> _logout() async {
    _notifService.cancelAll();
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _broadcastSub?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final bgColor = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF5F7FA);
    final barColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF546E7A);
    final initialCenter = _myPos ?? ruetCampus;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/ruet_logo.png', height: 32),
          const SizedBox(width: 8),
          const Text('RUET Bus', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        actions: [
          // Schedule
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BusSchedulePage())),
            icon: const Icon(Icons.schedule, size: 22),
            tooltip: 'সময়সূচি',
          ),
          // Nearest Bus
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NearestBusPage())),
            icon: const Icon(Icons.near_me, size: 22),
            tooltip: 'কাছের বাস',
          ),
          // Admin Broadcast Notification Bell (NEW)
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _lastReadTime = DateTime.now();
                    _unreadBroadcasts = 0;
                  });
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const DriverNotificationsPage()));
                },
                icon: const Icon(Icons.notifications_outlined, size: 22),
                tooltip: 'Admin Notifications',
              ),
              if (_unreadBroadcasts > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle),
                    child: Center(child: Text('$_unreadBroadcasts',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 9, fontWeight: FontWeight.bold))),
                  ),
                ),
            ],
          ),
          // ⋮ menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              switch (value) {
                case 'routes': setState(() => _showRoutes = !_showRoutes); break;
                case 'profile': Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())); break;
                case 'history': Navigator.push(context, MaterialPageRoute(builder: (_) => const BusHistoryPage())); break;
                case 'notif_history': Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationHistoryPage())); break;
                case 'settings': Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())); break;
                case 'about': Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())); break;
                case 'theme': themeProvider.toggleTheme(); break;
                case 'logout': await _logout(); break;
              }
            },
            itemBuilder: (_) => [
              _mi('routes', _showRoutes ? Icons.route : Icons.route_outlined,
                  _showRoutes ? 'রুট লুকাও' : 'রুট দেখাও', isDark),
              const PopupMenuDivider(),
              _mi('profile', Icons.person, 'আমার প্রোফাইল', isDark),
              _mi('history', Icons.history, 'Trip History', isDark),
              _mi('notif_history', Icons.notifications_active_outlined,
                  'Notification History', isDark),
              _mi('settings', Icons.settings, 'সেটিংস', isDark),
              _mi('about', Icons.info_outline, 'About', isDark),
              const PopupMenuDivider(),
              _mi('theme', isDark ? Icons.light_mode : Icons.dark_mode,
                  isDark ? 'লাইট মোড' : 'ডার্ক মোড', isDark),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout',
                  child: const Row(children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    SizedBox(width: 12),
                    Text('লগআউট', style: TextStyle(color: Colors.redAccent)),
                  ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Bus buttons
          Container(
            color: barColor,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['bus1','bus2','bus3','bus4','bus5','bus6'].map((busId) {
                  final bus = _busData[busId];
                  final isActive = (bus?['isActive'] as bool?) ?? false;
                  final isSelected = _selectedBusId == busId;
                  final color = _busColor(busId);
                  final etaMin = _etaMinutes[busId];
                  final adminOff = (bus?['adminOff'] as bool?) ?? false;

                  return GestureDetector(
                    onTap: () => _onBusButtonTap(busId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color
                            : adminOff ? Colors.orange.withOpacity(0.1)
                            : isActive ? color.withOpacity(isDark ? 0.25 : 0.15)
                            : isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: adminOff ? Colors.orange.withOpacity(0.5)
                              : isActive ? color : isDark ? Colors.white24 : Colors.black12,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 10, spreadRadius: 1)] : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (adminOff)
                              const Icon(Icons.lock, color: Colors.orange, size: 7)
                            else if (isActive)
                              _PulseIndicator(color: color, animate: true)
                            else
                              Container(width: 7, height: 7,
                                  decoration: BoxDecoration(shape: BoxShape.circle,
                                      color: isDark ? Colors.white30 : Colors.black26)),
                            const SizedBox(width: 5),
                            Icon(Icons.directions_bus,
                                color: isSelected ? Colors.white
                                    : adminOff ? Colors.orange
                                    : isActive ? color
                                    : isDark ? Colors.white38 : Colors.black38,
                                size: 16),
                          ]),
                          const SizedBox(height: 3),
                          Text(_busName(busId), style: TextStyle(
                              color: isSelected ? Colors.white
                                  : adminOff ? Colors.orange
                                  : isActive ? color
                                  : isDark ? Colors.white38 : Colors.black38,
                              fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(
                            adminOff ? 'বন্ধ'
                                : isActive && etaMin != null ? _formatETA(etaMin)
                                : isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                                color: isSelected ? Colors.white70
                                    : adminOff ? Colors.orange.withOpacity(0.7)
                                    : isActive ? color.withOpacity(0.8)
                                    : isDark ? Colors.white24 : Colors.black26,
                                fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: initialCenter, initialZoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate: isDark
                          ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ruet.bus_tracker',
                    ),
                    if (_showRoutes)
                      PolylineLayer(
                        polylines: busRoutes.entries.map((entry) {
                          final busId = entry.key;
                          final color = _busColor(busId);
                          final isSelected = _selectedBusId == busId;
                          final isActive = (_busData[busId]?['isActive'] as bool?) ?? false;
                          return Polyline(
                            points: entry.value,
                            color: isSelected ? color : isActive ? color.withOpacity(0.7) : color.withOpacity(0.25),
                            strokeWidth: isSelected ? 4.0 : 2.5,
                            isDotted: !isActive && !isSelected,
                          );
                        }).toList(),
                      ),
                    MarkerLayer(
                      markers: [
                        ..._busData.entries
                            .where((e) => (e.value['isActive'] as bool?) == true && e.value['lat'] != 0)
                            .map((e) {
                          final busId = e.key;
                          final color = _busColor(busId);
                          final isSelected = _selectedBusId == busId;
                          return Marker(
                            point: LatLng(e.value['lat'], e.value['lng']),
                            width: 80, height: 80,
                            child: GestureDetector(
                              onTap: () => _onBusButtonTap(busId),
                              child: Column(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: color,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]),
                                  child: Text(_busName(busId), style: const TextStyle(
                                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                                Icon(Icons.directions_bus,
                                    size: isSelected ? 38 : 30, color: color),
                              ]),
                            ),
                          );
                        }),
                        if (_myPos != null)
                          Marker(
                            point: _myPos!, width: 50, height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.withOpacity(0.2),
                                  border: Border.all(color: Colors.blue, width: 2.5)),
                              child: const Icon(Icons.person_pin_circle,
                                  size: 28, color: Colors.blue),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // My Location FAB
                Positioned(
                  bottom: (_selectedBusId != null) ? 72 : 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'fab_location',
                    onPressed: () {
                      if (_myPos != null) {
                        _mapController.move(_myPos!, 16);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📍 GPS পাচ্ছি...'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating),
                        );
                      }
                    },
                    backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    foregroundColor: _myPos != null ? const Color(0xFF1565C0) : Colors.grey,
                    elevation: 4,
                    child: Icon(_myPos != null ? Icons.my_location : Icons.location_searching, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Selected bus info panel
          if (_selectedBusId != null)
            Builder(builder: (context) {
              final bus = _busData[_selectedBusId!];
              final isActive = (bus?['isActive'] as bool?) ?? false;
              final speed = (bus?['speed'] as double?) ?? 0.0;
              final lat = (bus?['lat'] as double?) ?? 0.0;
              final lng = (bus?['lng'] as double?) ?? 0.0;
              final color = _busColor(_selectedBusId!);
              final etaMin = _etaMinutes[_selectedBusId!];
              double? distance;
              if (_myPos != null && lat != 0 && lng != 0) {
                distance = _calcDistance(
                    _myPos!.latitude, _myPos!.longitude, lat, lng);
              }
              return Container(
                color: barColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(Icons.directions_bus, color: color, size: 26),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_busName(_selectedBusId!), style: TextStyle(
                          color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        isActive
                            ? '${speed.toStringAsFixed(1)} km/h'
                            '${distance != null ? ' · ${distance.toStringAsFixed(1)} km' : ''}'
                            '${etaMin != null ? ' · ETA ${_formatETA(etaMin)}' : ''}'
                            : 'Not running',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  )),
                  TextButton(
                    onPressed: () => _showBusDetails(_selectedBusId!),
                    child: Text('Details', style: TextStyle(color: color, fontSize: 13)),
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }

  PopupMenuItem<String> _mi(String value, IconData icon, String label, bool isDark) {
    return PopupMenuItem(value: value,
        child: Row(children: [
          Icon(icon, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0), size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        ]));
  }
}

// ── Pulse Indicator ────────────────────────────────────────

class _PulseIndicator extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulseIndicator({required this.color, required this.animate});

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: widget.color.withOpacity(widget.animate ? _anim.value : 0.5)),
      ),
    );
  }
}