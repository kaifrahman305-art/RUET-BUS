// ============================================================
// RUET Bus App — Admin Bus Control Page
// ============================================================
// New:
// - Change করলে notification যায় সব users/drivers কে
// - Change log Firestore এ save হয়
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'bus_schedule_page.dart';

const Map<String, String> _busNames = {
  'bus1': 'BUS 1', 'bus2': 'BUS 2', 'bus3': 'BUS 3',
  'bus4': 'BUS 4', 'bus5': 'BUS 5', 'bus6': 'BUS 6',
};

const Map<String, Color> _busColors = {
  'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
  'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
  'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
};

class AdminBusControlPage extends StatefulWidget {
  const AdminBusControlPage({super.key});

  @override
  State<AdminBusControlPage> createState() => _AdminBusControlPageState();
}

class _AdminBusControlPageState extends State<AdminBusControlPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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
          Icon(Icons.toggle_on_outlined, color: Color(0xFFE53935), size: 24),
          SizedBox(width: 8),
          Text('Bus Control', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFFFFD700),
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Extra Trip যোগ'),
            Tab(icon: Icon(Icons.cancel_outlined), text: 'Bus বন্ধ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _AddExtraTripTab(),
          _BusOffTab(),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1: ADD EXTRA TRIP
// ============================================================

class _AddExtraTripTab extends StatefulWidget {
  const _AddExtraTripTab();
  @override
  State<_AddExtraTripTab> createState() => _AddExtraTripTabState();
}

class _AddExtraTripTabState extends State<_AddExtraTripTab> {
  String _selectedBus = 'bus1';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _depRuetCtrl = TextEditingController();
  final TextEditingController _depDestCtrl = TextEditingController();
  final TextEditingController _arrRuetCtrl = TextEditingController();
  final TextEditingController _destLabelCtrl = TextEditingController();
  bool _saving = false;
  List<Map<String, dynamic>> _existingTrips = [];

  @override
  void initState() { super.initState(); _loadExistingTrips(); }

  @override
  void dispose() {
    _depRuetCtrl.dispose(); _depDestCtrl.dispose();
    _arrRuetCtrl.dispose(); _destLabelCtrl.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';

  Future<void> _loadExistingTrips() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bus_extra_trips')
          .where('busId', isEqualTo: _selectedBus)
          .where('date', isEqualTo: _dateKey(_selectedDate))
          .get();
      if (mounted) {
        setState(() {
          _existingTrips = snap.docs
              .map((d) => {...d.data(), 'docId': d.id}).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 31)),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700), surface: Color(0xFF1A1A2E))),
          child: child!),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadExistingTrips();
    }
  }

  Future<void> _saveTrip() async {
    if (_depRuetCtrl.text.isEmpty || _arrRuetCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('রুয়েট থেকে ছাড়ার সময় ও পৌঁছানোর সময় দিন'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final depRuet = _depRuetCtrl.text.trim();
      final arrRuet = _arrRuetCtrl.text.trim();
      final busName = _busNames[_selectedBus]!;
      final dateKey = _dateKey(_selectedDate);

      final docRef = await FirebaseFirestore.instance
          .collection('bus_extra_trips').add({
        'busId': _selectedBus, 'busName': busName, 'date': dateKey,
        'depFromRuet': depRuet, 'depFromDest': _depDestCtrl.text.trim(),
        'arriveRuet': arrRuet,
        'destLabel': _destLabelCtrl.text.trim().isEmpty
            ? 'গন্তব্য' : _destLabelCtrl.text.trim(),
        'isAdminAdded': true, 'addedBy': adminEmail,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // ── Save change log ─────────────────────────────────
      await FirebaseFirestore.instance.collection('admin_change_log').add({
        'changeType': 'extra_trip', 'busId': _selectedBus, 'busName': busName,
        'title': '$busName — Extra Trip Added',
        'body': 'রুয়েট ছাড়বে $depRuet — পৌঁছাবে $arrRuet',
        'doneBy': adminEmail, 'timestamp': FieldValue.serverTimestamp(),
        'extraData': {
          'date': dateKey, 'tripDocId': docRef.id,
          'depFromRuet': depRuet, 'arriveRuet': arrRuet,
        },
      });

      // ── Broadcast notification ──────────────────────────
      await NotificationService.saveAdminBroadcast(
        title: '🚌 $busName — Extra Trip Added',
        body: '$dateKey তারিখে extra trip: রুয়েট $depRuet → পৌঁছাবে $arrRuet',
        changeType: 'extra_trip', busId: _selectedBus, busName: busName,
        extraData: {'date': dateKey, 'depFromRuet': depRuet},
      );

      _depRuetCtrl.clear(); _depDestCtrl.clear();
      _arrRuetCtrl.clear(); _destLabelCtrl.clear();
      _loadExistingTrips();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$busName — Extra trip যোগ হয়েছে ✅'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteTrip(String docId, String depRuet) async {
    await FirebaseFirestore.instance
        .collection('bus_extra_trips').doc(docId).delete();

    // Log deletion
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final busName = _busNames[_selectedBus]!;
    await FirebaseFirestore.instance.collection('admin_change_log').add({
      'changeType': 'revert', 'busId': _selectedBus, 'busName': busName,
      'title': '$busName — Extra Trip Removed',
      'body': '$depRuet এর extra trip সরানো হয়েছে',
      'doneBy': adminEmail, 'timestamp': FieldValue.serverTimestamp(),
    });

    await NotificationService.saveAdminBroadcast(
      title: '❌ $busName — Trip Cancelled',
      body: '$depRuet এর extra trip cancel করা হয়েছে',
      changeType: 'revert', busId: _selectedBus, busName: busName,
    );

    _loadExistingTrips();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Trip মুছে ফেলা হয়েছে'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _formatDate(DateTime date) {
    const months = ['','Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final isToday = _dateKey(date) == _dateKey(DateTime.now());
    if (isToday) return 'Today';
    return '${days[date.weekday]}, ${date.day} ${months[date.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _busColors[_selectedBus] ?? Colors.blue;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Extra trip যোগ করলে সাথে সাথে schedule এ দেখাবে '
                    'এবং সব users/drivers notification পাবে।',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // Bus selector
          const Text('বাস select করুন', style: TextStyle(
              color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _busNames.entries.map((entry) {
                final c = _busColors[entry.key] ?? Colors.blue;
                final isSelected = _selectedBus == entry.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedBus = entry.key);
                    _loadExistingTrips();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? c : c.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected ? c : c.withOpacity(0.3)),
                    ),
                    child: Text(entry.value, style: TextStyle(
                        color: isSelected ? Colors.white : c,
                        fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                const SizedBox(width: 10),
                Text(_formatDate(_selectedDate),
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const Spacer(),
                const Icon(Icons.arrow_drop_down, color: Colors.white38),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Add trip form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.add_circle, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text('নতুন Trip — ${_busNames[_selectedBus]}',
                      style: TextStyle(color: color,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                const SizedBox(height: 14),
                _TF(ctrl: _depRuetCtrl, label: 'রুয়েট থেকে ছাড়ার সময়',
                    hint: 'যেমন: রাত ৮:০০', color: color),
                const SizedBox(height: 10),
                _TF(ctrl: _depDestCtrl, label: 'গন্তব্য থেকে ছাড়ার সময়',
                    hint: 'যেমন: রাত ৮:৩০', color: color),
                const SizedBox(height: 10),
                _TF(ctrl: _arrRuetCtrl, label: 'রুয়েট পৌঁছানোর সময়',
                    hint: 'যেমন: রাত ৯:০০', color: color),
                const SizedBox(height: 10),
                _TF(ctrl: _destLabelCtrl, label: 'গন্তব্যের নাম',
                    hint: 'যেমন: ভদ্রা (optional)', color: color),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveTrip,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Trip যোগ করুন'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Existing extra trips
          if (_existingTrips.isNotEmpty) ...[
            Text('যোগ করা Extra Trips — ${_busNames[_selectedBus]}',
                style: const TextStyle(color: Colors.white54, fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ..._existingTrips.map((trip) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.directions_bus, color: color, size: 14),
                      const SizedBox(width: 6),
                      Text('রুয়েট → ${trip['depFromRuet'] ?? '--'}',
                          style: TextStyle(color: color,
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('⭐ Admin',
                            style: TextStyle(
                                color: Color(0xFFFFD700), fontSize: 9)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${trip['destLabel'] ?? 'গন্তব্য'}: '
                          '${trip['depFromDest'] ?? '--'} → রুয়েট: ${trip['arriveRuet'] ?? '--'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                )),
                IconButton(
                  onPressed: () => _deleteTrip(
                      trip['docId'] as String,
                      trip['depFromRuet'] as String? ?? ''),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                ),
              ]),
            )),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Center(child: Text('এই তারিখে কোনো extra trip নেই',
                  style: TextStyle(color: Colors.white38, fontSize: 12))),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 2: BUS OFF
// ============================================================

class _BusOffTab extends StatefulWidget {
  const _BusOffTab();
  @override
  State<_BusOffTab> createState() => _BusOffTabState();
}

class _BusOffTabState extends State<_BusOffTab> {
  final Map<String, DateTime> _selectedDate = {};
  final Map<String, TextEditingController> _reasonCtrl = {};
  Map<String, Map<String, dynamic>> _offOverrides = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final id in _busNames.keys) {
      _selectedDate[id] = DateTime.now();
      _reasonCtrl[id] = TextEditingController();
    }
    _loadOverrides();
  }

  @override
  void dispose() {
    for (final ctrl in _reasonCtrl.values) ctrl.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';

  Future<void> _loadOverrides() async {
    final today = _dateKey(DateTime.now());
    for (final busId in _busNames.keys) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('bus_off_overrides')
            .doc('${busId}_$today')
            .get();
        if (doc.exists) setState(() => _offOverrides[busId] = doc.data()!);
      } catch (_) {}
    }
  }

  Future<void> _setBusOff(String busId) async {
    final date = _selectedDate[busId] ?? DateTime.now();
    final reason = _reasonCtrl[busId]?.text.trim() ?? '';
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('কারণ লিখুন'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final dateKey = _dateKey(date);
      final docId = '${busId}_$dateKey';
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final busName = _busNames[busId]!;

      await FirebaseFirestore.instance
          .collection('bus_off_overrides').doc(docId).set({
        'busId': busId, 'busName': busName, 'date': dateKey,
        'reason': reason, 'setBy': adminEmail,
        'setAt': FieldValue.serverTimestamp(),
      });

      final today = _dateKey(DateTime.now());
      if (dateKey == today) {
        await FirebaseFirestore.instance
            .collection('buses').doc(busId).update({
          'adminOff': true, 'adminOffReason': reason, 'adminOffDate': dateKey,
        });
      }

      // ── Save change log ─────────────────────────────────
      await FirebaseFirestore.instance.collection('admin_change_log').add({
        'changeType': 'bus_off', 'busId': busId, 'busName': busName,
        'title': '$busName — বন্ধ করা হয়েছে',
        'body': reason,
        'doneBy': adminEmail, 'timestamp': FieldValue.serverTimestamp(),
        'extraData': {'date': dateKey, 'reason': reason},
      });

      // ── Broadcast notification to all users/drivers ─────
      await NotificationService.saveAdminBroadcast(
        title: '🚫 $busName — আজ বন্ধ',
        body: reason,
        changeType: 'bus_off', busId: busId, busName: busName,
        extraData: {'date': dateKey},
      );

      setState(() => _offOverrides[busId] = {'date': dateKey, 'reason': reason});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$busName বন্ধ করা হয়েছে ✅'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeBusOff(String busId) async {
    final date = _selectedDate[busId] ?? DateTime.now();
    final dateKey = _dateKey(date);
    final busName = _busNames[busId]!;
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    await FirebaseFirestore.instance
        .collection('bus_off_overrides')
        .doc('${busId}_$dateKey')
        .delete();

    final today = _dateKey(DateTime.now());
    if (dateKey == today) {
      await FirebaseFirestore.instance
          .collection('buses').doc(busId).update({
        'adminOff': false, 'adminOffReason': '', 'adminOffDate': '',
      });
    }

    // ── Log ─────────────────────────────────────────────
    await FirebaseFirestore.instance.collection('admin_change_log').add({
      'changeType': 'bus_on', 'busId': busId, 'busName': busName,
      'title': '$busName — বন্ধ তুলে নেওয়া হয়েছে',
      'body': 'আজ $busName আবার চলবে',
      'doneBy': adminEmail, 'timestamp': FieldValue.serverTimestamp(),
      'extraData': {'date': dateKey},
    });

    // ── Broadcast ────────────────────────────────────────
    await NotificationService.saveAdminBroadcast(
      title: '✅ $busName — আবার চলবে',
      body: 'Bus বন্ধ তুলে নেওয়া হয়েছে। আজ $busName চলবে।',
      changeType: 'bus_on', busId: busId, busName: busName,
    );

    setState(() => _offOverrides.remove(busId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$busName — বন্ধ তুলে নেওয়া হয়েছে'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _pickDate(String busId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate[busId] ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700), surface: Color(0xFF1A1A2E))),
          child: child!),
    );
    if (picked != null) {
      setState(() {
        _selectedDate[busId] = picked;
        _offOverrides.remove(busId);
      });
      try {
        final doc = await FirebaseFirestore.instance
            .collection('bus_off_overrides')
            .doc('${busId}_${_dateKey(picked)}')
            .get();
        if (doc.exists) setState(() => _offOverrides[busId] = doc.data()!);
      } catch (_) {}
    }
  }

  String _formatDate(DateTime date) {
    const months = ['','Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final isToday = _dateKey(date) == _dateKey(DateTime.now());
    if (isToday) return 'Today';
    return '${days[date.weekday]}, ${date.day} ${months[date.month]}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Bus বন্ধ করলে সাথে সাথে সব users ও drivers notification পাবে। '
                  'Driver চালাতে পারবে না।',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
            )),
          ]),
        ),

        ..._busNames.entries.map((entry) {
          final busId = entry.key;
          final busName = entry.value;
          final color = _busColors[busId] ?? Colors.blue;
          final date = _selectedDate[busId] ?? DateTime.now();
          final isOff = _offOverrides[busId] != null;
          final offReason = _offOverrides[busId]?['reason'] as String? ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isOff ? Colors.red.withOpacity(0.08) : color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOff ? Colors.redAccent.withOpacity(0.4) : color.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isOff ? Colors.red : color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.directions_bus,
                        color: isOff ? Colors.redAccent : color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(busName, style: TextStyle(
                      color: isOff ? Colors.redAccent : color,
                      fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOff
                          ? Colors.red.withOpacity(0.15)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isOff
                              ? Colors.red.withOpacity(0.4)
                              : Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(isOff ? 'বন্ধ আছে' : 'চলছে',
                        style: TextStyle(
                            color: isOff ? Colors.redAccent : Colors.green,
                            fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ]),

                if (isOff && offReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(offReason,
                          style: const TextStyle(color: Colors.orange, fontSize: 12))),
                    ]),
                  ),
                ],

                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () => _pickDate(busId),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                      const SizedBox(width: 10),
                      Text(_formatDate(date),
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Colors.white38),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _reasonCtrl[busId],
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'কারণ লিখুন (users ও drivers দেখতে পাবে)',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: color.withOpacity(0.5))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : () => _setBusOff(busId),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('বন্ধ করুন'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (isOff) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => _removeBusOff(busId),
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('বন্ধ তুলুন'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green, width: 0.8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Helper ─────────────────────────────────────────────────

class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final Color color;
  const _TF({required this.ctrl, required this.label,
    required this.hint, required this.color});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
      filled: true, fillColor: Colors.white.withOpacity(0.04),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withOpacity(0.5))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  );
}