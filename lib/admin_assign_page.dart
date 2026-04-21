// ============================================================
// RUET Bus App — Admin Assign Page (Updated)
// ============================================================
// New: Clear assignment button
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const List<String> driverNames = ['A','B','C','D','E','F','G','H','I','J'];
const List<String> helperNames = ['K','L','M','N','O','P','Q','R','S','T'];

const Map<String, String> busNames = {
  'bus1': 'BUS 1', 'bus2': 'BUS 2', 'bus3': 'BUS 3',
  'bus4': 'BUS 4', 'bus5': 'BUS 5', 'bus6': 'BUS 6',
};

const Map<String, Color> busColors = {
  'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
  'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
  'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
};

class AdminAssignPage extends StatefulWidget {
  const AdminAssignPage({super.key});

  @override
  State<AdminAssignPage> createState() => _AdminAssignPageState();
}

class _AdminAssignPageState extends State<AdminAssignPage> {
  final Map<String, String?> _selectedDriver = {};
  final Map<String, String?> _selectedHelper = {};
  final Map<String, DateTime> _selectedDate = {};
  bool _saving = false;
  Map<String, Map<String, dynamic>> _assignments = {};

  @override
  void initState() {
    super.initState();
    for (final id in busNames.keys) {
      _selectedDate[id] = DateTime.now();
    }
    _loadAssignments();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';

  Future<void> _loadAssignments() async {
    final today = _dateKey(DateTime.now());
    for (final busId in busNames.keys) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('bus_assignments')
            .doc('${busId}_$today')
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _assignments[busId] = data;
            _selectedDriver[busId] = data['driverName'] as String?;
            _selectedHelper[busId] = data['helperName'] as String?;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _saveAssignment(String busId) async {
    final driver = _selectedDriver[busId];
    final helper = _selectedHelper[busId];
    final date = _selectedDate[busId] ?? DateTime.now();

    if (driver == null || helper == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Driver এবং Helper দুটোই select করুন'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final docId = '${busId}_${_dateKey(date)}';
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';

      await FirebaseFirestore.instance
          .collection('bus_assignments').doc(docId).set({
        'busId': busId, 'busName': busNames[busId],
        'driverName': driver, 'helperName': helper,
        'date': _dateKey(date), 'assignedBy': adminEmail,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      // Today হলে buses collection ও update করো
      final today = _dateKey(DateTime.now());
      if (_dateKey(date) == today) {
        await FirebaseFirestore.instance
            .collection('buses').doc(busId).update({
          'assignedDriver': driver,
          'assignedHelper': helper,
          'assignedDate': today,
        });
      }

      setState(() => _assignments[busId] = {
        'driverName': driver, 'helperName': helper, 'date': _dateKey(date),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${busNames[busId]} — Driver: $driver, Helper: $helper ✅'),
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

  // ── Clear assignment (NEW) ─────────────────────────────────
  Future<void> _clearAssignment(String busId) async {
    final date = _selectedDate[busId] ?? DateTime.now();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${busNames[busId]} Assignment Clear করবেন?',
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        content: const Text('Driver ও Helper assignment সরিয়ে দেওয়া হবে।',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final docId = '${busId}_${_dateKey(date)}';
      await FirebaseFirestore.instance
          .collection('bus_assignments').doc(docId).delete();

      final today = _dateKey(DateTime.now());
      if (_dateKey(date) == today) {
        await FirebaseFirestore.instance
            .collection('buses').doc(busId).update({
          'assignedDriver': '',
          'assignedHelper': '',
          'assignedDate': '',
        });
      }

      setState(() {
        _assignments.remove(busId);
        _selectedDriver[busId] = null;
        _selectedHelper[busId] = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${busNames[busId]} assignment clear হয়েছে'),
        behavior: SnackBarBehavior.floating,
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

  Future<void> _pickDate(String busId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate[busId] ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700), surface: Color(0xFF1A1A2E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate[busId] = picked;
        _assignments.remove(busId);
        _selectedDriver[busId] = null;
        _selectedHelper[busId] = null;
      });
      // Load assignment for new date
      try {
        final doc = await FirebaseFirestore.instance
            .collection('bus_assignments')
            .doc('${busId}_${_dateKey(picked)}')
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _assignments[busId] = data;
            _selectedDriver[busId] = data['driverName'] as String?;
            _selectedHelper[busId] = data['helperName'] as String?;
          });
        }
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
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050810),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.people_alt, color: Color(0xFF43A047), size: 22),
          SizedBox(width: 8),
          Text('Driver & Helper Assign',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white10),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF43A047).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF43A047).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFF43A047), size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Assignment না করলে driver bus mode চালু করতে পারবে না। '
                    'প্রতিটি বাসের জন্য date, driver ও helper select করুন।',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
              )),
            ]),
          ),

          // Bus cards
          ...busNames.entries.map((entry) {
            final busId = entry.key;
            final busName = entry.value;
            final color = busColors[busId] ?? Colors.blue;
            final date = _selectedDate[busId] ?? DateTime.now();
            final isToday = _dateKey(date) == _dateKey(DateTime.now());
            final hasAssignment = _assignments[busId] != null;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.directions_bus, color: color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(busName, style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    if (hasAssignment && isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: const Text('Assigned ✓',
                            style: TextStyle(color: Colors.green,
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ]),
                  const SizedBox(height: 14),

                  // Date picker
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
                        Text(_formatDate(date), style: TextStyle(
                          color: isToday ? Colors.greenAccent : Colors.white70,
                          fontSize: 14, fontWeight: FontWeight.w500,
                        )),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.white38),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Driver dropdown
                  _DropdownRow(
                    label: 'Driver', icon: Icons.drive_eta, color: color,
                    value: _selectedDriver[busId], items: driverNames,
                    onChanged: (val) => setState(() => _selectedDriver[busId] = val),
                  ),
                  const SizedBox(height: 8),

                  // Helper dropdown
                  _DropdownRow(
                    label: 'Helper', icon: Icons.support_agent, color: color,
                    value: _selectedHelper[busId], items: helperNames,
                    onChanged: (val) => setState(() => _selectedHelper[busId] = val),
                  ),
                  const SizedBox(height: 14),

                  // Save + Clear buttons
                  Row(children: [
                    // Save button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : () => _saveAssignment(busId),
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Assign করুন'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Clear button (NEW)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: (_saving || !hasAssignment)
                            ? null
                            : () => _clearAssignment(busId),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 0.8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          disabledForegroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownRow({
    required this.label, required this.icon, required this.color,
    required this.value, required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text('Select $label',
                  style: const TextStyle(color: Colors.white38, fontSize: 13)),
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white38),
              items: items.map((name) => DropdownMenuItem(
                  value: name, child: Text(name))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }
}