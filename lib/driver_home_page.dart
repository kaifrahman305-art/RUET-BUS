// ============================================================
// RUET Bus App — Driver Home Page (Updated)
// ============================================================
// New:
// - Notification bell (admin broadcasts দেখাবে)
// - Admin off bus → "Request Permission" button
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'bus_history_page.dart';
import 'bus_schedule_page.dart';
import 'driver_notifications_page.dart';

const List<Map<String, String>> busList = [
  {'id': 'bus1', 'name': 'BUS 1',
    'route': 'রুয়েট-আলুপট্টি-সাহেব বাজার-সিএন্ডবি মোড়-কোর্ট-লক্ষীপুর-বর্ণালী-রেলগেট-ভদ্রা-রুয়েট'},
  {'id': 'bus2', 'name': 'BUS 2', 'route': 'রুয়েট-ভদ্রা-রেলগেট-বাইপাস-চারখুটার মোড়-রুয়েট'},
  {'id': 'bus3', 'name': 'BUS 3', 'route': 'রুয়েট-কাজলা-বিনোদপুর-বিহাস-কাটাখালী-রুয়েট'},
  {'id': 'bus4', 'name': 'BUS 4',
    'route': 'রুয়েট-আমচত্বর-রেলস্টেশন-সিরোইল-সাগরপাড়া-সুধুর মোড়-নর্দান-তালাইমারী-রুয়েট'},
  {'id': 'bus5', 'name': 'BUS 5', 'route': 'Girls only - মহিলা হল হতে'},
  {'id': 'bus6', 'name': 'BUS 6',
    'route': 'Campus Trip - রুয়েট-সিএন্ডবি-লক্ষীপুর-বন্ধগেট-রেলগেট-ভদ্রা-রুয়েট'},
];

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  Map<String, bool> busActiveStatus = {};
  Map<String, bool> busAdminOff = {};
  Map<String, String> busAdminOffReason = {};
  String? myActiveBusId;
  bool loading = true;
  StreamSubscription? _busSub;

  // Unread broadcast count
  int _unreadBroadcasts = 0;
  StreamSubscription? _broadcastSub;
  DateTime? _lastReadTime;

  @override
  void initState() {
    super.initState();
    _listenBusStatus();
    _listenBroadcasts();
  }

  void _listenBusStatus() {
    _busSub = FirebaseFirestore.instance
        .collection('buses').snapshots().listen((snap) {
      final Map<String, bool> active = {};
      final Map<String, bool> adminOff = {};
      final Map<String, String> offReason = {};
      String? myBus;
      final myEmail =
          FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';

      for (final doc in snap.docs) {
        final data = doc.data();
        active[doc.id] = data['isActive'] == true;
        adminOff[doc.id] = (data['adminOff'] as bool?) ?? false;
        offReason[doc.id] = data['adminOffReason'] as String? ?? '';
        if ((data['driverEmail'] as String? ?? '').toLowerCase() == myEmail &&
            data['isActive'] == true) {
          myBus = doc.id;
        }
      }

      if (mounted) {
        setState(() {
          busActiveStatus = active;
          busAdminOff = adminOff;
          busAdminOffReason = offReason;
          myActiveBusId = myBus;
          loading = false;
        });
      }
    });
  }

  void _listenBroadcasts() {
    _lastReadTime = DateTime.now().subtract(const Duration(hours: 24));
    _broadcastSub = FirebaseFirestore.instance
        .collection('admin_broadcasts')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final unread = snap.docs.where((doc) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        if (ts == null) return false;
        return ts.toDate().isAfter(_lastReadTime ?? DateTime.now());
      }).length;
      setState(() => _unreadBroadcasts = unread);
    });
  }

  Future<void> _selectBus(Map<String, String> bus) async {
    final busId = bus['id']!;
    final isActive = busActiveStatus[busId] ?? false;
    final isAdminOff = busAdminOff[busId] ?? false;
    final offReason = busAdminOffReason[busId] ?? '';

    // Admin off → show permission request dialog
    if (isAdminOff) {
      _showPermissionRequestDialog(bus, offReason);
      return;
    }

    if (isActive && myActiveBusId != busId) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${bus['name']} is already active by another driver'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    if (myActiveBusId == busId) {
      _goToDriverMap(busId, bus['name']!);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(bus['name']!),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Start driving this bus?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(bus['route']!, style: const TextStyle(fontSize: 13)),
            ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Start Driving', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final myEmail =
        FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    if (myActiveBusId != null) {
      await FirebaseFirestore.instance.collection('buses')
          .doc(myActiveBusId).update({'isActive': false, 'driverEmail': ''});
    }
    await FirebaseFirestore.instance.collection('buses').doc(busId).set({
      'isActive': true, 'driverEmail': myEmail,
      'lat': 0, 'lng': 0, 'speed': 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    _goToDriverMap(busId, bus['name']!);
  }

  // ── Permission request dialog (NEW) ──────────────────────
  void _showPermissionRequestDialog(
      Map<String, String> bus, String offReason) {
    final reasonCtrl = TextEditingController();
    final busId = bus['id']!;
    final busName = bus['name']!;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.admin_panel_settings,
              color: Color(0xFFFFD700), size: 22),
          SizedBox(width: 8),
          Text('Permission Request',
              style: TextStyle(color: Colors.white, fontSize: 15)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$busName আজ admin বন্ধ করেছেন।',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (offReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(offReason,
                    style: const TextStyle(color: Colors.orange, fontSize: 12)),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Admin এর কাছে permission চাইতে পারেন।\nকারণ লিখুন:',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'কারণ লিখুন...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFFFD700))),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendPermissionRequest(
                  busId, busName, reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Request পাঠান',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPermissionRequest(
      String busId, String busName, String reason) async {
    final myEmail =
        FirebaseAuth.instance.currentUser?.email ?? '';
    try {
      await FirebaseFirestore.instance
          .collection('driver_permission_requests').add({
        'busId': busId, 'busName': busName,
        'driverEmail': myEmail, 'reason': reason,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$busName — Permission request পাঠানো হয়েছে ✅'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _goToDriverMap(String busId, String busName) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => DriverMapPage(busId: busId, busName: busName)));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (myActiveBusId != null) {
      await FirebaseFirestore.instance.collection('buses')
          .doc(myActiveBusId).update({'isActive': false, 'driverEmail': ''});
    }
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _broadcastSub?.cancel();
    super.dispose();
  }

  Color _busColor(String busId) {
    const colors = {
      'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
      'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
      'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
    };
    return colors[busId] ?? Colors.blue;
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
        title: Row(children: [
          Image.asset('assets/images/ruet_logo.png', height: 32),
          const SizedBox(width: 10),
          const Text('Driver Panel', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          // Schedule
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BusSchedulePage())),
            icon: const Icon(Icons.schedule),
            tooltip: 'সময়সূচি',
          ),
          // Notifications bell with badge (NEW)
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
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
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
          IconButton(onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BusHistoryPage())),
              icon: const Icon(Icons.history)),
          IconButton(onPressed: () => themeProvider.toggleTheme(),
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity, color: cardBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.drive_eta, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Your Bus', style: TextStyle(
                      color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    myActiveBusId != null
                        ? 'Currently driving: ${busList.firstWhere((b) => b['id'] == myActiveBusId)['name']}'
                        : 'Tap a bus to start driving',
                    style: TextStyle(
                      color: myActiveBusId != null ? Colors.greenAccent : textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              )),
            ]),
          ),
          const Divider(height: 1),
          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: busList.length,
                itemBuilder: (context, index) {
                  final bus = busList[index];
                  final busId = bus['id']!;
                  final isActive = busActiveStatus[busId] ?? false;
                  final isMyBus = myActiveBusId == busId;
                  final isAdminOff = busAdminOff[busId] ?? false;
                  final busColor = _busColor(busId);

                  Color cardColor; Color borderColor;
                  String statusText; IconData statusIcon; Color statusColor;

                  if (isAdminOff) {
                    cardColor = isDark ? Colors.orange.withOpacity(0.08) : Colors.orange.withOpacity(0.05);
                    borderColor = Colors.orange.withOpacity(0.4);
                    statusText = 'Admin বন্ধ করেছেন — Tap to Request';
                    statusIcon = Icons.admin_panel_settings;
                    statusColor = Colors.orange;
                  } else if (isMyBus) {
                    cardColor = isDark ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.08);
                    borderColor = Colors.green;
                    statusText = 'Active — You are driving';
                    statusIcon = Icons.directions_bus;
                    statusColor = Colors.greenAccent;
                  } else if (isActive) {
                    cardColor = isDark ? Colors.red.withOpacity(0.12) : Colors.red.withOpacity(0.06);
                    borderColor = Colors.redAccent;
                    statusText = 'Active — Another driver';
                    statusIcon = Icons.block;
                    statusColor = Colors.redAccent;
                  } else {
                    cardColor = cardBg;
                    borderColor = isDark ? Colors.white12 : Colors.black12;
                    statusText = 'Inactive — Tap to drive';
                    statusIcon = Icons.directions_bus_outlined;
                    statusColor = textSecondary;
                  }

                  return GestureDetector(
                    onTap: () => _selectBus(bus),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1.5),
                        boxShadow: isMyBus ? [BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 12, spreadRadius: 1)] : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: busColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: busColor.withOpacity(0.4)),
                            ),
                            child: Icon(statusIcon,
                                color: isAdminOff ? Colors.orange
                                    : isMyBus ? Colors.greenAccent
                                    : isActive ? Colors.redAccent : busColor,
                                size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bus['name']!, style: TextStyle(
                                  color: textPrimary, fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(bus['route']!, style: TextStyle(
                                  color: textSecondary, fontSize: 11),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Row(children: [
                                Container(width: 7, height: 7,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle, color: statusColor)),
                                const SizedBox(width: 6),
                                Flexible(child: Text(statusText,
                                    style: TextStyle(color: statusColor,
                                        fontSize: 11, fontWeight: FontWeight.w600),
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ]),
                              if (isAdminOff && busAdminOffReason[busId]?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text(busAdminOffReason[busId]!,
                                    style: const TextStyle(color: Colors.orange, fontSize: 10),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ],
                          )),
                          Icon(
                            isAdminOff ? Icons.send_outlined
                                : isMyBus ? Icons.play_arrow_rounded
                                : isActive ? Icons.lock_outline
                                : Icons.arrow_forward_ios,
                            color: isAdminOff ? Colors.orange
                                : isMyBus ? Colors.greenAccent
                                : isActive ? Colors.redAccent : textSecondary,
                            size: isMyBus ? 28 : 18,
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// DRIVER MAP PAGE (same as before)
// ============================================================

class DriverMapPage extends StatefulWidget {
  final String busId, busName;
  const DriverMapPage({super.key, required this.busId, required this.busName});
  @override
  State<DriverMapPage> createState() => _DriverMapPageState();
}

class _DriverMapPageState extends State<DriverMapPage> {
  final MapController _mapController = MapController();
  LatLng? _myPos;
  bool _didInitialMove = false;
  double _speed = 0;
  DateTime? _lastUpdated;
  double _totalDistance = 0;
  LatLng? _prevPos;
  Timer? _timer;
  DateTime? _tripStart;
  final List<double> _speedHistory = [];

  @override
  void initState() {
    super.initState();
    _tripStart = DateTime.now();
    _startTracking();
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      if (_prevPos != null) {
        _totalDistance += Geolocator.distanceBetween(
            _prevPos!.latitude, _prevPos!.longitude,
            newPos.latitude, newPos.longitude) / 1000;
      }
      _prevPos = newPos;
      final currentSpeed = pos.speed * 3.6;
      if (currentSpeed > 0) _speedHistory.add(currentSpeed);
      setState(() { _myPos = newPos; _speed = currentSpeed; _lastUpdated = DateTime.now(); });
      await FirebaseFirestore.instance.collection('buses').doc(widget.busId).update({
        'lat': pos.latitude, 'lng': pos.longitude,
        'speed': currentSpeed, 'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      if (!_didInitialMove) {
        _didInitialMove = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _mapController.move(newPos, 16));
      }
    });
  }

  Future<void> _saveTripHistory() async {
    try {
      final endTime = DateTime.now();
      final durationSeconds = _tripStart != null
          ? endTime.difference(_tripStart!).inSeconds : 0;
      final avgSpeed = _speedHistory.isNotEmpty
          ? _speedHistory.reduce((a, b) => a + b) / _speedHistory.length : 0.0;
      await FirebaseFirestore.instance.collection('trip_history').add({
        'busId': widget.busId, 'busName': widget.busName,
        'driverEmail': FirebaseAuth.instance.currentUser?.email ?? '',
        'startTime': Timestamp.fromDate(_tripStart ?? DateTime.now()),
        'endTime': Timestamp.fromDate(endTime),
        'durationSeconds': durationSeconds,
        'distanceKm': double.parse(_totalDistance.toStringAsFixed(2)),
        'avgSpeedKmh': double.parse(avgSpeed.toStringAsFixed(1)),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) { print('Trip history save error: $e'); }
  }

  Future<void> _stopDriving() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Trip?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This will mark the bus as inactive.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: Column(children: [
              _stat('Distance', '${_totalDistance.toStringAsFixed(2)} km'),
              _stat('Duration', _duration()),
              _stat('Speed', '${_speed.toStringAsFixed(1)} km/h'),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continue')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('End Trip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _timer?.cancel();
    await _saveTripHistory();
    await FirebaseFirestore.instance.collection('buses').doc(widget.busId).update({
      'isActive': false, 'driverEmail': '', 'speed': 0,
    });
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.green)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ]),
  );

  String _duration() {
    if (_tripStart == null) return '--';
    final diff = DateTime.now().difference(_tripStart!);
    return diff.inHours > 0 ? '${diff.inHours}h ${diff.inMinutes % 60}m' : '${diff.inMinutes}m';
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF546E7A);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: Row(children: [
          const Icon(Icons.directions_bus, size: 20),
          const SizedBox(width: 8),
          Text(widget.busName, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(onPressed: () => themeProvider.toggleTheme(),
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode)),
          TextButton.icon(onPressed: _stopDriving,
              icon: const Icon(Icons.stop_circle, color: Colors.white),
              label: const Text('Stop', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Column(children: [
        Container(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            _LiveDot(),
            const SizedBox(width: 8),
            Text('Live Tracking', style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            _Chip(icon: Icons.speed, value: '${_speed.toStringAsFixed(1)} km/h', color: Colors.green),
            const SizedBox(width: 8),
            _Chip(icon: Icons.route, value: '${_totalDistance.toStringAsFixed(2)} km', color: Colors.blue),
            const SizedBox(width: 8),
            _Chip(icon: Icons.timer, value: _duration(), color: Colors.orange),
          ]),
        ),
        Container(
          color: isDark ? const Color(0xFF0F1420) : const Color(0xFFEEF2F7),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.location_on, color: Colors.green, size: 16),
            const SizedBox(width: 6),
            Text(
              _myPos == null ? 'Getting GPS signal...'
                  : '${_myPos!.latitude.toStringAsFixed(6)}, ${_myPos!.longitude.toStringAsFixed(6)}',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ]),
        ),
        Expanded(
          child: _myPos == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 16),
            Text('Getting GPS signal...', style: TextStyle(color: textSecondary)),
          ]))
              : FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _myPos!, initialZoom: 16),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ruet.bus_tracker'),
              MarkerLayer(markers: [
                if (_myPos != null)
                  Marker(point: _myPos!, width: 80, height: 80,
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 8)]),
                          child: Text(widget.busName, style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const Icon(Icons.directions_bus, size: 40, color: Colors.green),
                      ])),
              ]),
            ],
          ),
        ),
      ]),
      floatingActionButton: _myPos != null
          ? FloatingActionButton(
          onPressed: () => _mapController.move(_myPos!, 16),
          backgroundColor: Colors.green,
          child: const Icon(Icons.my_location, color: Colors.white))
          : null,
    );
  }
}

class _LiveDot extends StatefulWidget {
  @override State<_LiveDot> createState() => _LiveDotState();
}
class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true); _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _anim, builder: (_, __) => Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent.withOpacity(_anim.value))));
}

class _Chip extends StatelessWidget {
  final IconData icon; final String value; final Color color;
  const _Chip({required this.icon, required this.value, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 12), const SizedBox(width: 4), Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))]),
  );
}