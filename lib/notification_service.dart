// ============================================================
// RUET Bus App — Notification Service (Updated)
// ============================================================
// New: Admin broadcast notifications
// ============================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_history_page.dart';

class NotificationService {
  static final NotificationService _instance =
  NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Map<String, DateTime> _lastNotified = {};
  double notificationThresholdKm = 1.0;
  static const Duration _cooldown = Duration(minutes: 5);

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true);
    await _plugin.initialize(const InitializationSettings(
        android: androidSettings, iOS: iosSettings));
    _initialized = true;
  }

  Future<void> requestPermission() async {
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await impl?.requestNotificationsPermission();
  }

  // ── Channel details ────────────────────────────────────────
  static const _nearbyChannel = AndroidNotificationDetails(
    'bus_nearby_channel', 'বাস কাছে আসছে',
    channelDescription: 'RUET বাস কাছে আসলে notification',
    importance: Importance.high, priority: Priority.high,
    icon: '@mipmap/ic_launcher', playSound: true, enableVibration: true,
  );

  static const _tripEndChannel = AndroidNotificationDetails(
    'trip_end_channel', 'Trip শেষ হয়েছে',
    channelDescription: 'বাসের trip শেষ হলে notification',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher', playSound: false,
  );

  // ── Admin broadcast channel (NEW) ─────────────────────────
  static const _adminChannel = AndroidNotificationDetails(
    'admin_broadcast_channel', 'Admin Notice',
    channelDescription: 'Admin এর গুরুত্বপূর্ণ notice',
    importance: Importance.high, priority: Priority.high,
    icon: '@mipmap/ic_launcher', playSound: true, enableVibration: true,
    color: null,
  );

  static const _permissionChannel = AndroidNotificationDetails(
    'permission_channel', 'Permission Request',
    channelDescription: 'Driver permission request',
    importance: Importance.high, priority: Priority.high,
    icon: '@mipmap/ic_launcher', playSound: true,
  );

  // ── Bus nearby ─────────────────────────────────────────────
  Future<void> showBusNearbyNotification({
    required String busId, required String busName,
    required double distanceKm, int? etaMin, required String route,
  }) async {
    if (!_initialized) await init();
    final distStr = distanceKm < 1
        ? '${(distanceKm * 1000).round()} মিটার'
        : '${distanceKm.toStringAsFixed(1)} কিমি';
    final etaStr = etaMin != null
        ? (etaMin < 1 ? 'এখনই আসছে!' : '$etaMin মিনিটে আসবে')
        : 'কাছে আসছে';

    await _plugin.show(
      int.parse(busId.replaceAll('bus', '')),
      '🚌 $busName কাছে আসছে!',
      '$etaStr — দূরত্ব $distStr\n$route',
      const NotificationDetails(android: _nearbyChannel,
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)),
    );

    _lastNotified[busId] = DateTime.now();
    await saveNotificationHistory(busId: busId, busName: busName,
        message: '$etaStr — দূরত্ব $distStr', distanceKm: distanceKm);
  }

  // ── Trip ended ─────────────────────────────────────────────
  Future<void> showTripEndedNotification({
    required String busId, required String busName, required String route,
  }) async {
    if (!_initialized) await init();
    final busNum = int.tryParse(busId.replaceAll('bus', '')) ?? 1;
    await _plugin.show(10 + busNum, '🏁 $busName এর trip শেষ',
        'আজকের trip শেষ হয়েছে।\n$route',
        const NotificationDetails(android: _tripEndChannel,
            iOS: DarwinNotificationDetails(presentAlert: true)));
  }

  // ── Admin broadcast notification (NEW) ────────────────────
  /// Admin কিছু change করলে সব users ও drivers পাবে
  Future<void> showAdminBroadcast({
    required String title, required String body, int id = 100,
  }) async {
    if (!_initialized) await init();
    await _plugin.show(id, title, body,
        const NotificationDetails(android: _adminChannel,
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)));
  }

  // ── Permission request notification (NEW) ──────────────────
  /// Driver admin এর কাছে permission চাইলে admin পাবে
  Future<void> showPermissionRequest({
    required String driverName, required String busName,
  }) async {
    if (!_initialized) await init();
    await _plugin.show(200,
        '🔔 Permission Request',
        '$driverName — $busName চালাতে চান',
        const NotificationDetails(android: _permissionChannel,
            iOS: DarwinNotificationDetails(presentAlert: true)));
  }

  // ── Save + broadcast admin change to Firestore (NEW) ───────
  /// Admin change করলে Firestore এ save করে
  /// App open থাকলে users/drivers real-time এ পাবে
  static Future<void> saveAdminBroadcast({
    required String title, required String body,
    required String changeType, // 'bus_off', 'bus_on', 'extra_trip', 'revert'
    required String busId, String? busName,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_broadcasts')
          .add({
        'title': title, 'body': body,
        'changeType': changeType, 'busId': busId,
        'busName': busName ?? busId.toUpperCase(),
        'extraData': extraData ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      debugPrint('Admin broadcast save error: $e');
    }
  }

  // ── Check and notify nearby ────────────────────────────────
  Future<void> checkAndNotify({
    required Map<String, Map<String, dynamic>> busDataMap,
    required double userLat, required double userLng,
    required Map<String, int> etaMinutes,
    required String Function(String) busNameFn,
    required String Function(String) busRouteFn,
    required double Function(double, double, double, double) calcDistance,
  }) async {
    for (final entry in busDataMap.entries) {
      final busId = entry.key;
      final bus = entry.value;
      if (bus['isActive'] != true) continue;
      final lat = (bus['lat'] as double?) ?? 0;
      final lng = (bus['lng'] as double?) ?? 0;
      if (lat == 0 || lng == 0) continue;

      final distKm = calcDistance(userLat, userLng, lat, lng);
      if (distKm > notificationThresholdKm) continue;

      final lastTime = _lastNotified[busId];
      if (lastTime != null &&
          DateTime.now().difference(lastTime) < _cooldown) continue;

      await showBusNearbyNotification(
        busId: busId, busName: busNameFn(busId),
        distanceKm: distKm, etaMin: etaMinutes[busId],
        route: busRouteFn(busId),
      );
    }
  }

  // ── Trip end detection ─────────────────────────────────────
  Future<void> checkTripEnded({
    required Map<String, Map<String, dynamic>> previousData,
    required Map<String, Map<String, dynamic>> currentData,
    required String Function(String) busNameFn,
    required String Function(String) busRouteFn,
  }) async {
    for (final busId in currentData.keys) {
      final prev = previousData[busId];
      final curr = currentData[busId];
      if (prev == null || curr == null) continue;
      final wasActive = (prev['isActive'] as bool?) ?? false;
      final isNowInactive = (curr['isActive'] as bool?) != true;
      if (wasActive && isNowInactive) {
        await showTripEndedNotification(
          busId: busId, busName: busNameFn(busId),
          route: busRouteFn(busId),
        );
      }
    }
  }

  Future<void> cancelAll() async => _plugin.cancelAll();
  Future<void> cancelBus(String busId) async =>
      _plugin.cancel(int.parse(busId.replaceAll('bus', '')));
  void setThreshold(double km) => notificationThresholdKm = km;
  void resetCooldowns() => _lastNotified.clear();
}

// ignore: avoid_print
void debugPrint(String msg) => print(msg);