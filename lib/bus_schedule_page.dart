// ============================================================
// RUET Bus App — Bus Schedule Page (Fixed)
// ============================================================
// Fix: সব trip এ সকাল/দুপুর/বিকাল/রাত prefix যোগ করা হয়েছে
//      _parseTime সঠিকভাবে AM/PM detect করে
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

// ============================================================
// MODELS
// ============================================================

class BusTrip {
  final String depFromRuet;
  final String depFromDest;
  final String arriveRuet;
  final String destLabel;
  final bool isAdminAdded;

  const BusTrip({
    required this.depFromRuet,
    required this.depFromDest,
    required this.arriveRuet,
    required this.destLabel,
    this.isAdminAdded = false,
  });
}

class BusSchedule {
  final String busId;
  final String busName;
  final String routeBn;
  final Color color;
  final List<BusTrip> trips;
  final bool isGirlsOnly;

  const BusSchedule({
    required this.busId,
    required this.busName,
    required this.routeBn,
    required this.color,
    required this.trips,
    this.isGirlsOnly = false,
  });
}

// ============================================================
// SCHEDULE DATA — সব time এ proper prefix আছে
// সকাল = AM, দুপুর = 12pm-3pm, বিকাল = 3pm-6pm, রাত = 7pm+
// ============================================================

const List<BusSchedule> allSchedules = [
  BusSchedule(
    busId: 'bus1', busName: 'BUS 1', color: Color(0xFFE53935),
    routeBn: 'রুয়েট → আলুপট্টি → সাহেব বাজার → সিএন্ডবি মোড় → কোর্ট → লক্ষীপুর → বর্ণালী → রেলগেট → ভদ্রা → রুয়েট',
    trips: [
      BusTrip(
        depFromRuet: 'সকাল ৭:০০',
        depFromDest: 'সকাল ৭:৩০',
        arriveRuet: 'সকাল ৮:০০',
        destLabel: 'কোর্ট',
      ),
      BusTrip(
        depFromRuet: 'সকাল ৯:৪৫',
        depFromDest: 'সকাল ১০:১০',
        arriveRuet: 'সকাল ১০:৩০',
        destLabel: 'কোর্ট',
      ),
      BusTrip(
        depFromRuet: 'দুপুর ১২:৪০',
        depFromDest: 'দুপুর ১:০৫',
        arriveRuet: 'দুপুর ১:২৫',
        destLabel: 'কোর্ট',
      ),
      BusTrip(
        depFromRuet: 'দুপুর ১:৩০',
        depFromDest: 'দুপুর ১:৫৫',
        arriveRuet: 'দুপুর ২:২০',
        destLabel: 'কোর্ট',
      ),
    ],
  ),

  BusSchedule(
    busId: 'bus2', busName: 'BUS 2', color: Color(0xFF1E88E5),
    routeBn: 'রুয়েট → ভদ্রা → রেলগেট → বাইপাস → চারখুটার মোড় → রুয়েট',
    trips: [
      BusTrip(
        depFromRuet: 'সকাল ৭:০০',
        depFromDest: 'সকাল ৭:৩০',
        arriveRuet: 'সকাল ৮:০০',
        destLabel: 'চারখুটার মোড়',
      ),
      BusTrip(
        depFromRuet: 'সকাল ৯:৪৫',
        depFromDest: 'সকাল ১০:১০',
        arriveRuet: 'সকাল ১০:৩০',
        destLabel: 'চারখুটার মোড়',
      ),
      BusTrip(
        depFromRuet: 'দুপুর ১:৩০',
        depFromDest: 'দুপুর ২:০০',
        arriveRuet: 'দুপুর ২:৩০',
        destLabel: 'চারখুটার মোড়',
      ),
    ],
  ),

  BusSchedule(
    busId: 'bus3', busName: 'BUS 3', color: Color(0xFF43A047),
    routeBn: 'রুয়েট → কাজলা → বিনোদপুর → বিহাস → কাটাখালী → রুয়েট',
    trips: [
      BusTrip(
        depFromRuet: 'সকাল ৭:০০',
        depFromDest: 'সকাল ৭:৪০',
        arriveRuet: 'সকাল ৮:০০',
        destLabel: 'কাটাখালী',
      ),
      BusTrip(
        depFromRuet: 'দুপুর ১:৩০',
        depFromDest: 'দুপুর ২:১০',
        arriveRuet: 'দুপুর ২:৩০',
        destLabel: 'কাটাখালী',
      ),
    ],
  ),

  BusSchedule(
    busId: 'bus4', busName: 'BUS 4', color: Color(0xFFFB8C00),
    routeBn: 'রুয়েট → আমচত্বর → রেলস্টেশন → সিরোইল → সাগরপাড়া → সুধুর মোড় → নর্দান → তালাইমারী → রুয়েট',
    trips: [
      BusTrip(
        depFromRuet: 'সকাল ৭:০০',
        depFromDest: 'সকাল ৭:২৫',
        arriveRuet: 'সকাল ৭:৪৫',
        destLabel: 'আমচত্বর',
      ),
    ],
  ),

  BusSchedule(
    busId: 'bus5', busName: 'BUS 5', color: Color(0xFF8E24AA),
    routeBn: 'মহিলা হল হতে (বিশ্ববিদ্যালয়ের ভিতরে)',
    isGirlsOnly: true,
    trips: [
      BusTrip(
        depFromRuet: 'সকাল ৭:৪৫',
        depFromDest: 'সকাল ৭:৫০',
        arriveRuet: 'সকাল ৮:০০',
        destLabel: 'হল',
      ),
      BusTrip(
        depFromRuet: 'সকাল ১০:৩০',
        depFromDest: 'সকাল ১০:৪০',
        arriveRuet: 'সকাল ১০:৫০',
        destLabel: 'হল',
      ),
      BusTrip(
        depFromRuet: 'দুপুর ১:৩০',
        depFromDest: 'দুপুর ১:৪০',
        arriveRuet: 'দুপুর ১:৫০',
        destLabel: 'হল',
      ),
      BusTrip(
        depFromRuet: 'দুপুর ২:১০',
        depFromDest: 'দুপুর ২:২০',
        arriveRuet: 'দুপুর ২:৩০',
        destLabel: 'হল',
      ),
    ],
  ),

  BusSchedule(
    busId: 'bus6', busName: 'BUS 6', color: Color(0xFF00ACC1),
    routeBn: 'ক্যাম্পাস ট্রিপ — রুয়েট → সিএন্ডবি → লক্ষীপুর → বন্ধগেট → রেলগেট → ভদ্রা → রুয়েট',
    trips: [
      BusTrip(
        depFromRuet: 'বিকাল ৪:১৫',
        depFromDest: 'বিকাল ৪:৩২',
        arriveRuet: 'বিকাল ৫:০০',
        destLabel: 'সিএন্ডবি',
      ),
      BusTrip(
        depFromRuet: 'বিকাল ৫:১৫',
        depFromDest: 'বিকাল ৫:৩৫',
        arriveRuet: 'বিকাল ৬:০০',
        destLabel: 'সিএন্ডবি',
      ),
      BusTrip(
        depFromRuet: 'বিকাল ৬:১৫',
        depFromDest: 'বিকাল ৬:৩৫',
        arriveRuet: 'সন্ধ্যা ৭:০০',
        destLabel: 'সিএন্ডবি',
      ),
    ],
  ),
];

// ============================================================
// HELPERS
// ============================================================

bool isRuetHoliday(DateTime date) =>
    date.weekday == DateTime.thursday || date.weekday == DateTime.friday;

String dayNameBn(int weekday) {
  const names = {
    DateTime.saturday: 'শনিবার', DateTime.sunday: 'রবিবার',
    DateTime.monday: 'সোমবার', DateTime.tuesday: 'মঙ্গলবার',
    DateTime.wednesday: 'বুধবার', DateTime.thursday: 'বৃহস্পতিবার',
    DateTime.friday: 'শুক্রবার',
  };
  return names[weekday] ?? '';
}

String monthNameBn(int month) {
  const names = {
    1: 'জানুয়ারি', 2: 'ফেব্রুয়ারি', 3: 'মার্চ', 4: 'এপ্রিল',
    5: 'মে', 6: 'জুন', 7: 'জুলাই', 8: 'আগস্ট', 9: 'সেপ্টেম্বর',
    10: 'অক্টোবর', 11: 'নভেম্বর', 12: 'ডিসেম্বর',
  };
  return names[month] ?? '';
}

String formatDateBn(DateTime date) =>
    '${dayNameBn(date.weekday)}, ${_bnDigit(date.day)} ${monthNameBn(date.month)} ${_bnDigit(date.year)}';

String _bnDigit(int n) {
  const bn = ['০','১','২','৩','৪','৫','৬','৭','৮','৯'];
  return n.toString().split('').map((c) => bn[int.parse(c)]).join();
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';

// ============================================================
// TIME PARSING — Fixed with proper prefix handling
// সকাল = AM (hour as-is)
// দুপুর = hour 12 stays 12, hour 1-5 → +12
// বিকাল = hour < 12 → +12
// সন্ধ্যা/রাত = hour < 12 → +12
// no prefix → hour >= 7 treated as AM, else PM
// ============================================================

TimeOfDay? parseScheduleTime(String timeStr) {
  final str = timeStr.trim();

  // Detect prefix
  bool isSokal = str.startsWith('সকাল');
  bool isDupur = str.startsWith('দুপুর');
  bool isBikal = str.startsWith('বিকাল');
  bool isSondha = str.startsWith('সন্ধ্যা');
  bool isRat = str.startsWith('রাত');

  // Strip prefix
  final stripped = str
      .replaceAll('সকাল', '').replaceAll('দুপুর', '')
      .replaceAll('বিকাল', '').replaceAll('সন্ধ্যা', '')
      .replaceAll('রাত', '').trim();

  // Convert Bengali digits to ASCII
  final ascii = stripped
      .replaceAll('০','0').replaceAll('১','1').replaceAll('২','2')
      .replaceAll('৩','3').replaceAll('৪','4').replaceAll('৫','5')
      .replaceAll('৬','6').replaceAll('৭','7').replaceAll('৮','8')
      .replaceAll('৯','9');

  final parts = ascii.split(':');
  if (parts.length != 2) return null;

  int? hour = int.tryParse(parts[0].trim());
  int? minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) return null;

  if (isSokal) {
    // সকাল = AM, no change (7:00 = 7, 10:30 = 10)
    // কিন্তু সকাল ১২ = 12 (noon)
  } else if (isDupur) {
    // দুপুর: 12:xx = 12 (noon), 1:xx-5:xx = +12
    if (hour != 12 && hour < 12) hour += 12;
  } else if (isBikal || isSondha || isRat) {
    // বিকাল/সন্ধ্যা/রাত = PM
    if (hour < 12) hour += 12;
  } else {
    // No prefix: hours 7-11 = AM, 12 = noon, 1-6 = PM
    if (hour >= 1 && hour <= 6) hour += 12;
    // 7-11 stays as AM, 12 stays as 12
  }

  return TimeOfDay(hour: hour, minute: minute);
}

// ============================================================
// BUS SCHEDULE PAGE
// ============================================================

class BusSchedulePage extends StatefulWidget {
  const BusSchedulePage({super.key});

  @override
  State<BusSchedulePage> createState() => _BusSchedulePageState();
}

class _BusSchedulePageState extends State<BusSchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Timer _clockTimer;
  late DateTime _now;

  Map<String, List<BusTrip>> _extraTrips = {};
  Map<String, String> _busOffReasons = {};
  Map<String, String> _driverNames = {};
  Map<String, String> _helperNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: allSchedules.length, vsync: this);
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadFirestoreData();
    _listenBusStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _loadFirestoreData() async {
    final today = _dateKey(DateTime.now());

    // Extra trips
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bus_extra_trips')
          .where('date', isEqualTo: today)
          .get();
      final Map<String, List<BusTrip>> extra = {};
      for (final doc in snap.docs) {
        final d = doc.data();
        final busId = d['busId'] as String;
        extra.putIfAbsent(busId, () => []);
        extra[busId]!.add(BusTrip(
          depFromRuet: d['depFromRuet'] as String? ?? '',
          depFromDest: d['depFromDest'] as String? ?? '',
          arriveRuet: d['arriveRuet'] as String? ?? '',
          destLabel: d['destLabel'] as String? ?? 'গন্তব্য',
          isAdminAdded: true,
        ));
      }
      if (mounted) setState(() => _extraTrips = extra);
    } catch (_) {}

    // Bus off overrides
    try {
      for (final busId in allSchedules.map((s) => s.busId)) {
        final doc = await FirebaseFirestore.instance
            .collection('bus_off_overrides')
            .doc('${busId}_$today')
            .get();
        if (doc.exists) {
          final reason = doc.data()?['reason'] as String? ?? '';
          if (mounted) setState(() => _busOffReasons[busId] = reason);
        }
      }
    } catch (_) {}

    // Assignments
    try {
      for (final busId in allSchedules.map((s) => s.busId)) {
        final doc = await FirebaseFirestore.instance
            .collection('bus_assignments')
            .doc('${busId}_$today')
            .get();
        if (doc.exists) {
          final d = doc.data()!;
          if (mounted) {
            setState(() {
              _driverNames[busId] = d['driverName'] as String? ?? '';
              _helperNames[busId] = d['helperName'] as String? ?? '';
            });
          }
        }
      }
    } catch (_) {}
  }

  void _listenBusStatus() {
    FirebaseFirestore.instance
        .collection('buses')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      for (final doc in snap.docs) {
        final d = doc.data();
        final busId = doc.id;
        final adminOff = (d['adminOff'] as bool?) ?? false;
        final offReason = d['adminOffReason'] as String? ?? '';
        final driverName = d['assignedDriver'] as String? ?? '';
        final helperName = d['assignedHelper'] as String? ?? '';
        setState(() {
          if (adminOff && offReason.isNotEmpty) {
            _busOffReasons[busId] = offReason;
          }
          if (driverName.isNotEmpty) _driverNames[busId] = driverName;
          if (helperName.isNotEmpty) _helperNames[busId] = helperName;
        });
      }
    });
  }

  bool _isBusOff(String busId) {
    if (_busOffReasons.containsKey(busId)) return true;
    return isRuetHoliday(_now);
  }

  String _busOffReason(String busId) {
    if (_busOffReasons.containsKey(busId)) return _busOffReasons[busId]!;
    if (isRuetHoliday(_now)) return 'আজ ছুটির দিন — বাস চলছে না';
    return '';
  }

  List<BusTrip> _allTrips(String busId) {
    final def = allSchedules.firstWhere((s) => s.busId == busId).trips;
    final extra = _extraTrips[busId] ?? [];
    return [...def, ...extra];
  }

  // ── Time helpers ───────────────────────────────────────────

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  int _nowMin() => _toMin(TimeOfDay.fromDateTime(_now));

  int _nextTripIndex(String busId) {
    if (_isBusOff(busId)) return -1;
    final trips = _allTrips(busId);
    final nowMin = _nowMin();
    for (int i = 0; i < trips.length; i++) {
      final dep = parseScheduleTime(trips[i].depFromRuet);
      if (dep != null && _toMin(dep) > nowMin) return i;
    }
    return -1;
  }

  bool _inProgress(BusTrip trip, String busId) {
    if (_isBusOff(busId)) return false;
    final dep = parseScheduleTime(trip.depFromRuet);
    final arr = parseScheduleTime(trip.arriveRuet);
    if (dep == null || arr == null) return false;
    final nowMin = _nowMin();
    return nowMin >= _toMin(dep) && nowMin <= _toMin(arr);
  }

  String _countdown(String timeStr) {
    final dep = parseScheduleTime(timeStr);
    if (dep == null) return '';
    final diff = _toMin(dep) - _nowMin();
    if (diff <= 0) return '';
    if (diff < 60) return '$diff মিনিট পরে';
    return '${diff ~/ 60}ঘ ${diff % 60}ম পরে';
  }

  String _timeStr() {
    final h = _now.hour > 12 ? _now.hour - 12 : (_now.hour == 0 ? 12 : _now.hour);
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h:$m ${_now.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final isHoliday = isRuetHoliday(_now);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Row(children: [
          Icon(Icons.schedule, size: 22),
          SizedBox(width: 8),
          Text('বাস সময়সূচি',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            onPressed: () => themeProvider.toggleTheme(),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_timeStr(), style: const TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorWeight: 3,
          tabs: allSchedules.map((s) {
            final isOff = _isBusOff(s.busId);
            final hasExtra = (_extraTrips[s.busId]?.isNotEmpty ?? false);
            final nextIdx = _nextTripIndex(s.busId);
            final trips = _allTrips(s.busId);
            return Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOff ? Colors.red.withOpacity(0.7) : s.color,
                  ),
                ),
                Text(s.busName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (isOff) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('বন্ধ', style: TextStyle(
                        fontSize: 8, color: Colors.white,
                        fontWeight: FontWeight.bold)),
                  ),
                ] else if (hasExtra) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('+', style: TextStyle(
                        fontSize: 9, color: Colors.black,
                        fontWeight: FontWeight.bold)),
                  ),
                ] else if (nextIdx >= 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${trips.length - nextIdx}',
                        style: const TextStyle(fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          _DateBanner(now: _now, isHoliday: isHoliday, isDark: isDark),
          if (isHoliday)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'আজ ছুটির দিন — বাস চলবে না। তবে সময়সূচি দেখতে পাবেন।',
                  style: TextStyle(
                    color: isDark
                        ? Colors.orange.shade200
                        : Colors.orange.shade800,
                    fontSize: 12, height: 1.4,
                  ),
                )),
              ]),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: allSchedules.map((s) {
                final allTrips = _allTrips(s.busId);
                final isOff = _isBusOff(s.busId);
                final offReason = _busOffReason(s.busId);
                final nextIdx = _nextTripIndex(s.busId);
                return _BusTab(
                  schedule: s,
                  allTrips: allTrips,
                  isDark: isDark,
                  isHoliday: isHoliday,
                  isBusOff: isOff,
                  busOffReason: offReason,
                  driverName: _driverNames[s.busId] ?? '',
                  helperName: _helperNames[s.busId] ?? '',
                  nextTripIndex: nextIdx,
                  inProgress: (trip) => _inProgress(trip, s.busId),
                  countdownTo: _countdown,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DATE BANNER
// ============================================================

class _DateBanner extends StatelessWidget {
  final DateTime now;
  final bool isHoliday;
  final bool isDark;
  const _DateBanner(
      {required this.now, required this.isHoliday, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isHoliday
            ? (isDark
            ? Colors.red.withOpacity(0.12)
            : Colors.red.withOpacity(0.06))
            : (isDark
            ? Colors.green.withOpacity(0.10)
            : Colors.green.withOpacity(0.06)),
        border: Border(
            bottom: BorderSide(
              color: isHoliday
                  ? Colors.red.withOpacity(0.25)
                  : Colors.green.withOpacity(0.25),
            )),
      ),
      child: Row(children: [
        Icon(isHoliday ? Icons.event_busy : Icons.calendar_today,
            color: isHoliday ? Colors.redAccent : Colors.green, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDateBn(now),
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  isHoliday
                      ? 'আজ ছুটির দিন — বাস চলবে না'
                      : 'আজ ক্লাস আছে — বাস চলবে',
                  style: TextStyle(
                      color: isHoliday ? Colors.redAccent : Colors.green,
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isHoliday
                ? Colors.red.withOpacity(0.15)
                : Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isHoliday
                    ? Colors.redAccent.withOpacity(0.3)
                    : Colors.green.withOpacity(0.3)),
          ),
          child: Text(isHoliday ? 'ছুটি' : 'ক্লাস',
              style: TextStyle(
                  color: isHoliday ? Colors.redAccent : Colors.green,
                  fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ============================================================
// BUS TAB
// ============================================================

class _BusTab extends StatelessWidget {
  final BusSchedule schedule;
  final List<BusTrip> allTrips;
  final bool isDark;
  final bool isHoliday;
  final bool isBusOff;
  final String busOffReason;
  final String driverName;
  final String helperName;
  final int nextTripIndex;
  final bool Function(BusTrip) inProgress;
  final String Function(String) countdownTo;

  const _BusTab({
    required this.schedule,
    required this.allTrips,
    required this.isDark,
    required this.isHoliday,
    required this.isBusOff,
    required this.busOffReason,
    required this.driverName,
    required this.helperName,
    required this.nextTripIndex,
    required this.inProgress,
    required this.countdownTo,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary =
    isDark ? Colors.white60 : const Color(0xFF546E7A);
    final bgColor =
    isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF5F7FA);
    final hasExtraTrips = allTrips.any((t) => t.isAdminAdded);

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bus off notice
            if (isBusOff && busOffReason.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(isDark ? 0.15 : 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cancel_outlined,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('আজ এই বাস চলছে না',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(busOffReason,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.red.shade200
                                        : Colors.red.shade700,
                                    fontSize: 12, height: 1.4)),
                          ],
                        )),
                  ],
                ),
              ),
            ],

            // Route info card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: schedule.color
                    .withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: schedule.color.withOpacity(0.4),
                    width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: schedule.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.directions_bus,
                          color: schedule.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Row(children: [
                      Text(schedule.busName,
                          style: TextStyle(
                              color: schedule.color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      if (schedule.isGirlsOnly) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.pink.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.pink.withOpacity(0.5)),
                          ),
                          child: const Text('♀ Girls Only',
                              style: TextStyle(
                                  color: Colors.pink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ])),
                    Text('${allTrips.length} ট্রিপ/দিন',
                        style: TextStyle(
                            color: textSecondary, fontSize: 11)),
                  ]),
                  const SizedBox(height: 10),

                  // Route
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
                            size: 14,
                            color: schedule.color.withOpacity(0.8)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(schedule.routeBn,
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 12, height: 1.5))),
                      ],
                    ),
                  ),

                  // Driver & Helper
                  if (driverName.isNotEmpty ||
                      helperName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF43A047)
                            .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF43A047)
                                .withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        if (driverName.isNotEmpty) ...[
                          const Icon(Icons.drive_eta,
                              color: Color(0xFF43A047), size: 15),
                          const SizedBox(width: 6),
                          Text('Driver: $driverName',
                              style: const TextStyle(
                                  color: Color(0xFF43A047),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                        if (driverName.isNotEmpty &&
                            helperName.isNotEmpty)
                          const Text('   ·   ',
                              style:
                              TextStyle(color: Colors.grey)),
                        if (helperName.isNotEmpty) ...[
                          const Icon(Icons.support_agent,
                              color: Color(0xFF43A047), size: 15),
                          const SizedBox(width: 6),
                          Text('Helper: $helperName',
                              style: const TextStyle(
                                  color: Color(0xFF43A047),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ]),
                    ),
                  ] else if (!isBusOff) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.people_outline,
                            color: textSecondary, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          'আজকের Driver ও Helper এখনো assign হয়নি',
                          style: TextStyle(
                              color: textSecondary, fontSize: 11),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),

            // Admin added trips notice
            if (hasExtraTrips) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFFD700)
                          .withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.star,
                      color: Color(0xFFFFD700), size: 14),
                  SizedBox(width: 8),
                  Text('⭐ চিহ্নিত trips আজ admin যোগ করেছেন',
                      style: TextStyle(
                          color: Color(0xFFFFD700), fontSize: 11)),
                ]),
              ),
            ],

            // Next trip banner
            if (!isBusOff && nextTripIndex >= 0) ...[
              _NextTripBanner(
                trip: allTrips[nextTripIndex],
                tripNumber: nextTripIndex + 1,
                color: schedule.color,
                countdown: countdownTo(
                    allTrips[nextTripIndex].depFromRuet),
                isDark: isDark,
              ),
              const SizedBox(height: 16),
            ] else if (!isBusOff) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey
                      .withOpacity(isDark ? 0.1 : 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.nightlight_round,
                        size: 16, color: textSecondary),
                    const SizedBox(width: 8),
                    Text('আজকের সব ট্রিপ শেষ',
                        style: TextStyle(
                            color: textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],

            // Column headers
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 8),
              child: Row(children: [
                _HCell(label: 'ট্রিপ', flex: 1, color: textSecondary),
                _HCell(
                    label: 'রুয়েট থেকে',
                    flex: 3,
                    color: textSecondary),
                _HCell(
                    label: allTrips.isNotEmpty
                        ? allTrips[0].destLabel
                        : 'গন্তব্য',
                    flex: 3,
                    color: textSecondary),
                _HCell(
                    label: 'রুয়েট পৌঁছানো',
                    flex: 3,
                    color: textSecondary),
              ]),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Trips
            ...allTrips.asMap().entries.map((entry) {
              final index = entry.key;
              final trip = entry.value;
              final prog = inProgress(trip);
              final isNext =
                  !isBusOff && index == nextTripIndex;
              final isPast = isBusOff
                  ? false
                  : (nextTripIndex >= 0
                  ? index < nextTripIndex
                  : true);

              return _TripCard(
                tripNumber: index + 1,
                trip: trip,
                color: schedule.color,
                isDark: isDark,
                isNext: isNext,
                inProgress: prog,
                isPast: isPast,
                isBusOff: isBusOff,
                countdown:
                isNext ? countdownTo(trip.depFromRuet) : '',
              );
            }),

            // Notice
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber
                    .withOpacity(isDark ? 0.08 : 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'সময়সূচি পরিবর্তনযোগ্য। অফিসিয়াল নোটিশের জন্য যানবাহন শাখা, RUET যোগাযোগ করুন।',
                    style: TextStyle(
                        color: textSecondary,
                        fontSize: 11, height: 1.5),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NEXT TRIP BANNER
// ============================================================

class _NextTripBanner extends StatelessWidget {
  final BusTrip trip;
  final int tripNumber;
  final Color color;
  final String countdown;
  final bool isDark;

  const _NextTripBanner({
    required this.trip,
    required this.tripNumber,
    required this.color,
    required this.countdown,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withOpacity(isDark ? 0.25 : 0.15),
          color.withOpacity(isDark ? 0.12 : 0.07),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle),
          child: Icon(Icons.access_time, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('পরবর্তী ট্রিপ #$tripNumber',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              if (trip.isAdminAdded) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFFFFD700).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('⭐ Admin Added',
                      style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 9)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              'রুয়েট ছাড়বে ${trip.depFromRuet} — পৌঁছাবে ${trip.arriveRuet}',
              style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF1A1A2E),
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ],
        )),
        if (countdown.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10)),
            child: Text(countdown,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }
}

// ============================================================
// TRIP CARD
// ============================================================

class _TripCard extends StatelessWidget {
  final int tripNumber;
  final BusTrip trip;
  final Color color;
  final bool isDark;
  final bool isNext;
  final bool inProgress;
  final bool isPast;
  final bool isBusOff;
  final String countdown;

  const _TripCard({
    required this.tripNumber,
    required this.trip,
    required this.color,
    required this.isDark,
    required this.isNext,
    required this.inProgress,
    required this.isPast,
    required this.isBusOff,
    required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    Color cardBg;
    Color borderColor;
    double opacity;

    if (isBusOff) {
      cardBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
      borderColor = isDark ? Colors.white12 : Colors.black12;
      opacity = 0.45;
    } else if (inProgress) {
      cardBg = color.withOpacity(isDark ? 0.2 : 0.1);
      borderColor = color;
      opacity = 1.0;
    } else if (isNext) {
      cardBg = color.withOpacity(isDark ? 0.12 : 0.06);
      borderColor = color.withOpacity(0.6);
      opacity = 1.0;
    } else if (isPast) {
      cardBg = isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.grey.withOpacity(0.04);
      borderColor =
      isDark ? Colors.white10 : Colors.black.withOpacity(0.06);
      opacity = 0.4;
    } else {
      cardBg = trip.isAdminAdded
          ? const Color(0xFFFFD700)
          .withOpacity(isDark ? 0.08 : 0.05)
          : isDark
          ? const Color(0xFF1A1A2E)
          : Colors.white;
      borderColor = trip.isAdminAdded
          ? const Color(0xFFFFD700).withOpacity(0.3)
          : isDark
          ? Colors.white12
          : Colors.black12;
      opacity = 1.0;
    }

    final textSecondary =
    isDark ? Colors.white54 : const Color(0xFF546E7A);

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: borderColor, width: inProgress ? 1.5 : 1),
          boxShadow: inProgress
              ? [
            BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 12,
                spreadRadius: 1)
          ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Center(
                child: inProgress
                    ? _PulsingDot(color: color)
                    : trip.isAdminAdded
                    ? const Icon(Icons.star,
                    color: Color(0xFFFFD700), size: 16)
                    : Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isNext ? color : Colors.grey)
                        .withOpacity(0.15),
                    border: Border.all(
                        color:
                        (isNext ? color : Colors.grey)
                            .withOpacity(0.3)),
                  ),
                  child: Center(
                      child: Text('$tripNumber',
                          style: TextStyle(
                              color: isNext
                                  ? color
                                  : Colors.grey,
                              fontSize: 10,
                              fontWeight:
                              FontWeight.bold))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
                flex: 3,
                child: _TCell(
                  time: trip.depFromRuet,
                  label: inProgress
                      ? 'চলমান'
                      : (isNext ? 'পরের ট্রিপ' : ''),
                  color: (inProgress || isNext) ? color : null,
                  isDark: isDark,
                  countdown: isNext ? countdown : '',
                )),
            Expanded(
                flex: 3,
                child: _TCell(
                    time: trip.depFromDest,
                    subLabel: trip.destLabel,
                    isDark: isDark)),
            Expanded(
                flex: 3,
                child: _TCell(
                    time: trip.arriveRuet, isDark: isDark)),
          ]),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────

class _HCell extends StatelessWidget {
  final String label;
  final int flex;
  final Color color;
  const _HCell(
      {required this.label, required this.flex, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(label,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3),
        textAlign:
        flex == 1 ? TextAlign.center : TextAlign.start),
  );
}

class _TCell extends StatelessWidget {
  final String time;
  final String? label;
  final String? subLabel;
  final Color? color;
  final bool isDark;
  final String? countdown;

  const _TCell({
    required this.time,
    this.label,
    this.subLabel,
    this.color,
    required this.isDark,
    this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    final dc =
    isDark ? Colors.white : const Color(0xFF1A1A2E);
    final sc =
    isDark ? Colors.white54 : const Color(0xFF546E7A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(time,
            style: TextStyle(
                color: color ?? dc,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        if (label != null && label!.isNotEmpty)
          Text(label!,
              style: TextStyle(
                  color: color ?? sc,
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
        if (countdown != null && countdown!.isNotEmpty)
          Text(countdown!,
              style: TextStyle(color: color ?? sc, fontSize: 9)),
        if (subLabel != null)
          Text(subLabel!,
              style: TextStyle(color: sc, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim =
        Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(_anim.value)),
    ),
  );
}