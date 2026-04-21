// ============================================================
// RUET Bus App — Admin Map Page
// ============================================================
// Admin এর নিজের location + সব বাসের live position দেখায়
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'bus_routes_data.dart';

class AdminMapPage extends StatefulWidget {
  const AdminMapPage({super.key});

  @override
  State<AdminMapPage> createState() => _AdminMapPageState();
}

class _AdminMapPageState extends State<AdminMapPage> {
  final MapController _mapController = MapController();
  LatLng? _myPos;
  Map<String, Map<String, dynamic>> _busData = {};
  StreamSubscription? _busSub;
  bool _didAutoCenter = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _listenBuses();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission =
      await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = p);
      if (!_didAutoCenter) {
        _didAutoCenter = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(p, 14);
        });
      }

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((pos) {
        if (!mounted) return;
        setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
      });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

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
      if (mounted) setState(() => _busData = data);
    });
  }

  @override
  void dispose() {
    _busSub?.cancel();
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
    final activeBuses = _busData.entries
        .where((e) => (e.value['isActive'] as bool?) == true &&
        e.value['lat'] != 0)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050810),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.map_outlined,
                color: Color(0xFF1565C0), size: 22),
            SizedBox(width: 8),
            Text('Live Map',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // Active bus count badge
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: activeBuses.isEmpty
                      ? Colors.grey.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activeBuses.isEmpty
                        ? Colors.white24
                        : Colors.green.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  '${activeBuses.length} Active',
                  style: TextStyle(
                    color: activeBuses.isEmpty
                        ? Colors.white38
                        : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myPos ?? ruetCampus,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ruet.bus_tracker',
              ),
              MarkerLayer(
                markers: [
                  // Active bus markers
                  ...activeBuses.map((e) {
                    final busId = e.key;
                    final color = _busColor(busId);
                    final num = busId.replaceAll('bus', '');
                    return Marker(
                      point: LatLng(
                          e.value['lat'], e.value['lng']),
                      width: 80, height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius:
                              BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8)
                              ],
                            ),
                            child: Text('BUS $num',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Icon(Icons.directions_bus,
                              size: 30, color: color),
                        ],
                      ),
                    );
                  }),

                  // Admin location — gold star marker
                  if (_myPos != null)
                    Marker(
                      point: _myPos!,
                      width: 50, height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFD700)
                              .withOpacity(0.2),
                          border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 2),
                        ),
                        child: const Icon(Icons.star,
                            size: 24,
                            color: Color(0xFFFFD700)),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // My location FAB
          Positioned(
            bottom: 20, right: 16,
            child: FloatingActionButton.small(
              heroTag: 'admin_fab',
              onPressed: () {
                if (_myPos != null) {
                  _mapController.move(_myPos!, 16);
                }
              },
              backgroundColor: const Color(0xFF1A1A2E),
              foregroundColor: const Color(0xFFFFD700),
              elevation: 4,
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}