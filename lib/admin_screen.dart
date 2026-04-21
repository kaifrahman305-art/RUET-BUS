// ============================================================
// RUET Bus App — Admin Screen (Updated)
// ============================================================
// New: Change Log button + Notifications button (with badge)
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_assign_page.dart';
import 'admin_bus_control_page.dart';
import 'admin_map_page.dart';
import 'admin_change_log_page.dart';
import 'admin_notifications_page.dart';
import 'bus_history_page.dart';
import 'bus_schedule_page.dart';

// ============================================================
// CINEMATIC WELCOME SCREEN
// ============================================================

class AdminWelcomeScreen extends StatefulWidget {
  const AdminWelcomeScreen({super.key});

  @override
  State<AdminWelcomeScreen> createState() =>
      _AdminWelcomeScreenState();
}

class _AdminWelcomeScreenState extends State<AdminWelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl, _line1Ctrl, _line2Ctrl, _line3Ctrl, _dashCtrl;
  late Animation<double> _bgAnim, _line1Fade, _line2Fade, _line3Fade, _dashFade;
  late Animation<Offset> _line1Slide, _line2Slide, _dashSlide;
  bool _showDashboard = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _bgAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn));

    _line1Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _line1Fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _line1Ctrl, curve: Curves.easeIn));
    _line1Slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(CurvedAnimation(parent: _line1Ctrl, curve: Curves.easeOutCubic));

    _line2Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _line2Fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _line2Ctrl, curve: Curves.easeIn));
    _line2Slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(CurvedAnimation(parent: _line2Ctrl, curve: Curves.easeOutCubic));

    _line3Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _line3Fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _line3Ctrl, curve: Curves.easeIn));

    _dashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _dashFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _dashCtrl, curve: Curves.easeIn));
    _dashSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _dashCtrl, curve: Curves.easeOutCubic));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await _line1Ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _line2Ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _line3Ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await Future.wait([_line3Ctrl.reverse(), _line2Ctrl.reverse(), _line1Ctrl.reverse()]);
    if (!mounted) return;
    setState(() => _showDashboard = true);
    _dashCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _line1Ctrl.dispose(); _line2Ctrl.dispose();
    _line3Ctrl.dispose(); _dashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_bgCtrl, _line1Ctrl, _line2Ctrl, _line3Ctrl, _dashCtrl]),
        builder: (context, _) {
          return Stack(
            children: [
              Opacity(opacity: _bgAnim.value,
                child: Container(decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF050810), Color(0xFF0D0520), Color(0xFF050D1A)]),
                )),
              ),
              Positioned(top: 0, left: 0, right: 0,
                  child: Opacity(opacity: _bgAnim.value * 0.6,
                      child: Container(height: 1.5, decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.transparent, Color(0xFFFFD700), Colors.transparent]))))),
              Positioned(bottom: 0, left: 0, right: 0,
                  child: Opacity(opacity: _bgAnim.value * 0.6,
                      child: Container(height: 1.5, decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.transparent, Color(0xFFFFD700), Colors.transparent]))))),

              if (!_showDashboard)
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SlideTransition(position: _line1Slide, child: FadeTransition(opacity: _line1Fade,
                      child: const Text('WELCOME ADMIN', style: TextStyle(
                          color: Color(0xFFFFD700), fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 8),
                          textAlign: TextAlign.center))),
                  const SizedBox(height: 24),
                  FadeTransition(opacity: _line2Fade, child: Container(width: 200, height: 1,
                      decoration: const BoxDecoration(gradient: LinearGradient(
                          colors: [Colors.transparent, Color(0xFFFFD700), Colors.transparent])))),
                  const SizedBox(height: 24),
                  SlideTransition(position: _line2Slide, child: FadeTransition(opacity: _line2Fade,
                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text('You have the control of\nwhole bus tracking system',
                              style: TextStyle(color: Colors.white60, fontSize: 16, letterSpacing: 1.5, height: 1.7),
                              textAlign: TextAlign.center)))),
                  const SizedBox(height: 40),
                  FadeTransition(opacity: _line3Fade, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('RUET BUS', style: TextStyle(
                          color: Color(0xFF1565C0), fontSize: 12, letterSpacing: 5, fontWeight: FontWeight.w600)))),
                ])),

              if (_showDashboard)
                SlideTransition(position: _dashSlide, child: FadeTransition(
                    opacity: _dashFade, child: const AdminDashboard())),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// ADMIN DASHBOARD (Updated)
// ============================================================

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Admin panel থেকে logout করবেন?',
            style: TextStyle(color: Colors.white70)),
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
    if (confirm == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050810),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
            ),
            child: const Icon(Icons.admin_panel_settings,
                color: Color(0xFFFFD700), size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Admin Panel', style: TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFFFFD700), fontSize: 18)),
        ]),
        actions: [
          // Schedule view
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BusSchedulePage())),
            icon: const Icon(Icons.schedule, color: Colors.white70),
            tooltip: 'Schedule দেখুন',
          ),
          // Notifications (with pending badge)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('driver_permission_requests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const AdminNotificationsPage())),
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white70),
                    tooltip: 'Notifications',
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                            color: Colors.orange, shape: BoxShape.circle),
                        child: Center(child: Text('$count',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 9, fontWeight: FontWeight.bold))),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, Color(0xFFFFD700), Colors.transparent]))),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25)),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.verified_user,
                      color: Color(0xFFFFD700), size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Verified Admin', style: TextStyle(
                      color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(FirebaseAuth.instance.currentUser?.email ?? '',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ]),
            ),
            const SizedBox(height: 28),

            const _SL('CONTROLS'),
            const SizedBox(height: 12),

            _C(icon: Icons.map_outlined, title: 'Live Map',
                subtitle: 'নিজের location সহ সব বাসের map দেখুন',
                color: const Color(0xFF1565C0),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminMapPage()))),
            const SizedBox(height: 10),

            _C(icon: Icons.people_alt_outlined, title: 'Driver & Helper Assign',
                subtitle: 'প্রতিটি বাসে driver ও helper assign করুন',
                color: const Color(0xFF43A047),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminAssignPage()))),
            const SizedBox(height: 10),

            _C(icon: Icons.toggle_on_outlined, title: 'Bus Control',
                subtitle: 'Extra trip যোগ / Bus বন্ধ করুন',
                color: const Color(0xFFE53935),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminBusControlPage()))),
            const SizedBox(height: 10),

            _C(icon: Icons.history_outlined, title: 'Trip History',
                subtitle: 'সব বাসের trip history দেখুন',
                color: const Color(0xFFFB8C00),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BusHistoryPage()))),
            const SizedBox(height: 10),

            // Change Log (NEW)
            _C(icon: Icons.change_history, title: 'Change Log',
                subtitle: 'কখন কী change হয়েছে — Revert করুন',
                color: const Color(0xFFFFD700),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminChangeLogPage()))),
            const SizedBox(height: 10),

            // Driver Requests (NEW)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('driver_permission_requests')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return _C(
                  icon: Icons.notifications_outlined,
                  title: 'Driver Requests${count > 0 ? ' ($count pending)' : ''}',
                  subtitle: 'Driver permission requests দেখুন',
                  color: Colors.orange,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const AdminNotificationsPage())),
                  badge: count > 0 ? '$count' : null,
                );
              },
            ),

            const SizedBox(height: 28),
            const _SL('BUS STATUS'),
            const SizedBox(height: 12),

            // Live bus status grid
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('buses').snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final Map<String, bool> status = {};
                final Map<String, bool> adminOff = {};
                for (final doc in docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  status[doc.id] = (d['isActive'] as bool?) ?? false;
                  adminOff[doc.id] = (d['adminOff'] as bool?) ?? false;
                }
                const ids = ['bus1','bus2','bus3','bus4','bus5','bus6'];
                const colors = {
                  'bus1': Color(0xFFE53935), 'bus2': Color(0xFF1E88E5),
                  'bus3': Color(0xFF43A047), 'bus4': Color(0xFFFB8C00),
                  'bus5': Color(0xFF8E24AA), 'bus6': Color(0xFF00ACC1),
                };
                return GridView.count(
                  crossAxisCount: 2, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10, mainAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: ids.map((id) {
                    final active = status[id] ?? false;
                    final off = adminOff[id] ?? false;
                    final color = colors[id] ?? Colors.blue;
                    final num = id.replaceAll('bus', '');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: off ? Colors.orange.withOpacity(0.08)
                            : active ? color.withOpacity(0.12)
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: off ? Colors.orange.withOpacity(0.4)
                              : active ? color.withOpacity(0.35)
                              : Colors.white12,
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.directions_bus,
                            color: off ? Colors.orange
                                : active ? color : Colors.white24,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('BUS $num', style: TextStyle(
                                color: off ? Colors.orange
                                    : active ? color : Colors.white38,
                                fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              off ? 'Admin Off' : active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                  color: off ? Colors.orange.withOpacity(0.7)
                                      : active ? Colors.greenAccent : Colors.white24,
                                  fontSize: 10),
                            ),
                          ],
                        )),
                      ]),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SL extends StatelessWidget {
  final String label;
  const _SL(this.label);
  @override
  Widget build(BuildContext context) => Text(label, style: const TextStyle(
      color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2));
}

class _C extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  final Color color; final VoidCallback onTap; final String? badge;

  const _C({required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(width: 46, height: 46,
              decoration: BoxDecoration(color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          )),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Text(badge!, style: const TextStyle(
                  color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          Icon(Icons.chevron_right, color: color, size: 18),
        ]),
      ),
    );
  }
}