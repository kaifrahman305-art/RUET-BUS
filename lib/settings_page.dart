// ============================================================
// RUET Bus App — Settings Page
// ============================================================
// সব settings এক জায়গায়:
// - Notification on/off
// - Notification threshold distance
// - Theme (light/dark)
// - Trip end notification
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import 'notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ── Settings state ─────────────────────────────────────────
  bool _notifEnabled = true;
  bool _tripEndNotif = true;
  double _thresholdKm = 1.0;
  bool _loading = true;

  static const String _keyNotif = 'setting_notif_enabled';
  static const String _keyTripEnd = 'setting_trip_end_notif';
  static const String _keyThreshold = 'setting_threshold_km';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool(_keyNotif) ?? true;
      _tripEndNotif = prefs.getBool(_keyTripEnd) ?? true;
      _thresholdKm = prefs.getDouble(_keyThreshold) ?? 1.0;
      _loading = false;
    });
    NotificationService().setThreshold(_thresholdKm);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
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
        title: const Text('সেটিংস',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Appearance ──────────────────────────────
            _SectionTitle(
                title: 'চেহারা', textSecondary: textSecondary),
            _SettingsCard(
              isDark: isDark,
              cardBg: cardBg,
              children: [
                _SwitchTile(
                  icon: isDark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  iconColor: const Color(0xFF1565C0),
                  title: 'ডার্ক মোড',
                  subtitle: isDark
                      ? 'চালু আছে'
                      : 'বন্ধ আছে',
                  value: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                  onChanged: (val) =>
                      themeProvider.toggleTheme(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Notifications ────────────────────────────
            _SectionTitle(
                title: 'নোটিফিকেশন',
                textSecondary: textSecondary),
            _SettingsCard(
              isDark: isDark,
              cardBg: cardBg,
              children: [
                // Master notification toggle
                _SwitchTile(
                  icon: Icons.notifications,
                  iconColor: Colors.orange,
                  title: 'নোটিফিকেশন চালু',
                  subtitle:
                  'বাস কাছে আসলে alert পাবে',
                  value: _notifEnabled,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                  onChanged: (val) {
                    setState(() => _notifEnabled = val);
                    _saveBool(_keyNotif, val);
                  },
                ),
                Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white12
                        : Colors.black12),

                // Trip end notification
                _SwitchTile(
                  icon: Icons.directions_bus_outlined,
                  iconColor: Colors.redAccent,
                  title: 'Trip শেষের notification',
                  subtitle:
                  'Driver trip শেষ করলে জানাবে',
                  value: _tripEndNotif,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                  enabled: _notifEnabled,
                  onChanged: _notifEnabled
                      ? (val) {
                    setState(
                            () => _tripEndNotif = val);
                    _saveBool(_keyTripEnd, val);
                  }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Threshold slider card
            if (_notifEnabled) ...[
              _SettingsCard(
                isDark: isDark,
                cardBg: cardBg,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.orange
                                    .withOpacity(0.12),
                                borderRadius:
                                BorderRadius.circular(
                                    8),
                              ),
                              child: const Icon(
                                  Icons.my_location,
                                  color: Colors.orange,
                                  size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notification দূরত্ব',
                                    style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 15,
                                        fontWeight:
                                        FontWeight.w600),
                                  ),
                                  Text(
                                    'বাস এই দূরত্বে এলে notify করবে',
                                    style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange
                                    .withOpacity(0.15),
                                borderRadius:
                                BorderRadius.circular(
                                    10),
                                border: Border.all(
                                    color: Colors.orange
                                        .withOpacity(0.3)),
                              ),
                              child: Text(
                                _thresholdKm < 1
                                    ? '${(_thresholdKm * 1000).round()} মি'
                                    : '${_thresholdKm.toStringAsFixed(1)} কিমি',
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight:
                                    FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _thresholdKm,
                          min: 0.2,
                          max: 3.0,
                          divisions: 14,
                          activeColor: Colors.orange,
                          inactiveColor:
                          Colors.orange.withOpacity(0.2),
                          onChanged: (val) {
                            setState(
                                    () => _thresholdKm = val);
                            NotificationService()
                                .setThreshold(val);
                            _saveDouble(_keyThreshold, val);
                          },
                        ),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text('২০০ মি',
                                style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11)),
                            Text('৩ কিমি',
                                style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // ── Data ────────────────────────────────────
            _SectionTitle(
                title: 'Data', textSecondary: textSecondary),
            _SettingsCard(
              isDark: isDark,
              cardBg: cardBg,
              children: [
                _ActionTile(
                  icon: Icons.refresh,
                  iconColor: const Color(0xFF43A047),
                  title: 'Notification Cooldown রিসেট',
                  subtitle:
                  'আবার notification পেতে এটা চাপো',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                  onTap: () {
                    NotificationService().resetCooldowns();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Notification cooldown রিসেট হয়েছে ✅'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Helper Widgets
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color textSecondary;

  const _SectionTitle(
      {required this.title, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final List<Widget> children;

  const _SettingsCard({
    required this.isDark,
    required this.cardBg,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          color: textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          color: textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}