// ============================================================
// RUET Bus App — Profile Page
// ============================================================
// Student এর নাম, roll, department দেখায়।
// Firestore থেকে data load করে।
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _studentData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final email =
      FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      if (email == null) {
        setState(() {
          _error = 'Login করা নেই';
          _loading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(email)
          .get();

      if (doc.exists) {
        setState(() {
          _studentData = doc.data();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Profile পাওয়া যায়নি';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

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
        title: const Text('আমার প্রোফাইল',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => themeProvider.toggleTheme(),
            icon:
            Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
          child: Text(_error!,
              style: TextStyle(color: textSecondary)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Avatar ───────────────────────────────
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1565C0)
                    .withOpacity(0.15),
                border: Border.all(
                    color: const Color(0xFF1565C0),
                    width: 2.5),
              ),
              child: const Icon(Icons.person,
                  size: 52,
                  color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              _studentData?['name'] ?? '--',
              style: TextStyle(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _studentData?['email'] ?? '',
              style: TextStyle(
                  color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // ── Info cards ───────────────────────────
            _InfoCard(
              isDark: isDark,
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              items: [
                _InfoItem(
                  icon: Icons.badge,
                  label: 'Roll Number',
                  value:
                  _studentData?['roll'] ?? '--',
                  color: const Color(0xFF1565C0),
                ),
                _InfoItem(
                  icon: Icons.school,
                  label: 'Department',
                  value:
                  _studentData?['department'] ??
                      '--',
                  color: const Color(0xFF43A047),
                ),
                _InfoItem(
                  icon: Icons.calendar_today,
                  label: 'Series',
                  value:
                  _studentData?['series'] ?? '--',
                  color: const Color(0xFFFB8C00),
                ),
                _InfoItem(
                  icon: Icons.code,
                  label: 'Department Code',
                  value: _studentData?[
                  'departmentCode'] ??
                      '--',
                  color: const Color(0xFF8E24AA),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Account info ─────────────────────────
            _InfoCard(
              isDark: isDark,
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              title: 'Account',
              items: [
                _InfoItem(
                  icon: Icons.email,
                  label: 'Email',
                  value:
                  _studentData?['email'] ?? '--',
                  color: const Color(0xFF00ACC1),
                ),
                _InfoItem(
                  icon: Icons.verified_user,
                  label: 'Student Type',
                  value: 'RUET Student',
                  color: const Color(0xFF43A047),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Change password button ────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final email = FirebaseAuth
                      .instance.currentUser?.email;
                  if (email != null) {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(
                        email: email);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Password reset email পাঠানো হয়েছে ✅'),
                          behavior:
                          SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.lock_reset),
                label: const Text('Password Change করো'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                  const Color(0xFF1565C0),
                  side: const BorderSide(
                      color: Color(0xFF1565C0)),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final List<_InfoItem> items;
  final String? title;

  const _InfoCard({
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.items,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(title!,
                  style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (i > 0 || title != null)
                  Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white12
                          : Colors.black12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item.icon,
                            color: item.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(item.label,
                                style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(item.value,
                                style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 15,
                                    fontWeight:
                                    FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}