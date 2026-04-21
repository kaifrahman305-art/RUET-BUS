// ============================================================
// RUET Bus App — About Page
// ============================================================
// App version, developer info, RUET contact
// Bus helper numbers (later add করা যাবে)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // ── Bus helper contacts ────────────────────────────────────

  static const List<_BusContact> busContacts = [
    _BusContact(busId: 'bus1', busName: 'BUS 1',
        color: Color(0xFFE53935),
        route: 'রুয়েট–আলুপট্টি–সাহেব বাজার–কোর্ট–ভদ্রা',
        helperName: 'Helper Name', phone: '01XXXXXXXXX'),
    _BusContact(busId: 'bus2', busName: 'BUS 2',
        color: Color(0xFF1E88E5),
        route: 'রুয়েট–ভদ্রা–রেলগেট–বাইপাস–চারখুটার মোড়',
        helperName: 'Helper Name', phone: '01XXXXXXXXX'),
    _BusContact(busId: 'bus3', busName: 'BUS 3',
        color: Color(0xFF43A047),
        route: 'রুয়েট–কাজলা–বিনোদপুর–বিহাস–কাটাখালী',
        helperName: 'Helper Name', phone: '01XXXXXXXXX'),
    _BusContact(busId: 'bus4', busName: 'BUS 4',
        color: Color(0xFFFB8C00),
        route: 'রুয়েট–আমচত্বর–রেলস্টেশন–সিরোইল–তালাইমারী',
        helperName: 'Helper Name', phone: '01XXXXXXXXX'),
    _BusContact(busId: 'bus5', busName: 'BUS 5 (Girls)',
        color: Color(0xFF8E24AA),
        route: 'মহিলা হল হতে',
        helperName: 'Helper Name', phone: '01XXXXXXXXX'),
    _BusContact(busId: 'bus6', busName: 'BUS 6',
        color: Color(0xFF00ACC1),
        route: 'রুয়েট–সিএন্ডবি–লক্ষীপুর–বন্ধগেট–ভদ্রা',
        helperName: 'Helper Name', phone: '01XXXXXXXXX'),
  ];

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
        title: const Text('About',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── App Info ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1565C0)
                        .withOpacity(isDark ? 0.3 : 0.15),
                    const Color(0xFF1E88E5)
                        .withOpacity(isDark ? 0.15 : 0.07),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF1565C0)
                        .withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF1565C0)
                                .withOpacity(0.3),
                            blurRadius: 20)
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                        'assets/images/ruet_logo.png'),
                  ),
                  const SizedBox(height: 16),
                  Text('RUET Bus',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Real-time Bus Tracking System',
                      style: TextStyle(
                          color: textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                          color: Color(0xFF90CAF9),
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── RUET Info ─────────────────────────────────────
            _AboutCard(
              isDark: isDark,
              cardBg: cardBg,
              title: 'RUET সম্পর্কে',
              textSecondary: textSecondary,
              children: [
                _InfoRow(
                  icon: Icons.school,
                  iconColor: const Color(0xFF1565C0),
                  label: 'বিশ্ববিদ্যালয়',
                  value: 'রাজশাহী প্রকৌশল ও প্রযুক্তি বিশ্ববিদ্যালয়',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
                _InfoRow(
                  icon: Icons.location_on,
                  iconColor: Colors.redAccent,
                  label: 'ঠিকানা',
                  value: 'কাজলা, রাজশাহী-৬২০৪, বাংলাদেশ',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
                _InfoRow(
                  icon: Icons.directions_bus,
                  iconColor: const Color(0xFF43A047),
                  label: 'মোট বাস',
                  value: '৬টি বাস চলাচল করে',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
                _InfoRow(
                  icon: Icons.phone,
                  iconColor: Colors.orange,
                  label: 'যানবাহন শাখা',
                  value: 'transport@ruet.ac.bd',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Bus Helper Contacts ───────────────────────────
            _AboutCard(
              isDark: isDark,
              cardBg: cardBg,
              title: 'বাসের Helper যোগাযোগ',
              textSecondary: textSecondary,
              children: [
                // Notice about placeholder numbers
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.amber, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Helper দের নম্বর পরে update করা হবে',
                          style: TextStyle(
                              color: textSecondary,
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...busContacts.map((contact) => _BusContactTile(
                  contact: contact,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                )),
              ],
            ),
            const SizedBox(height: 16),

            // ── Developer Info ────────────────────────────────
            _AboutCard(
              isDark: isDark,
              cardBg: cardBg,
              title: 'Developer',
              textSecondary: textSecondary,
              children: [
                _InfoRow(
                  icon: Icons.person,
                  iconColor: const Color(0xFF8E24AA),
                  label: 'Developed by',
                  value: 'RUET Student',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
                _InfoRow(
                  icon: Icons.code,
                  iconColor: const Color(0xFF00ACC1),
                  label: 'Tech Stack',
                  value: 'Flutter + Firebase',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
                _InfoRow(
                  icon: Icons.map,
                  iconColor: const Color(0xFF43A047),
                  label: 'Map',
                  value: 'OpenStreetMap (flutter_map)',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Working days notice ───────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.black12),
              ),
              child: Column(
                children: [
                  Text('বাস চলাচলের দিন',
                      style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceAround,
                    children: [
                      'শনি', 'রবি', 'সোম', 'মঙ্গল', 'বুধ'
                    ].map((day) => _DayBadge(
                      day: day,
                      isActive: true,
                      isDark: isDark,
                    )).toList()
                      ..addAll(['বৃহ', 'শুক্র'].map((day) =>
                          _DayBadge(
                            day: day,
                            isActive: false,
                            isDark: isDark,
                          ))),
                  ),
                  const SizedBox(height: 8),
                  Text('বৃহস্পতি ও শুক্রবার RUET বন্ধ',
                      style: TextStyle(
                          color: textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final String title;
  final Color textSecondary;
  final List<Widget> children;

  const _AboutCard({
    required this.isDark,
    required this.cardBg,
    required this.title,
    required this.textSecondary,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
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
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                Text(label,
                    style: TextStyle(
                        color: textSecondary, fontSize: 11)),
                Text(value,
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusContactTile extends StatelessWidget {
  final _BusContact contact;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const _BusContactTile({
    required this.contact,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: contact.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: contact.color.withOpacity(0.3)),
            ),
            child: Icon(Icons.directions_bus,
                color: contact.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.busName,
                    style: TextStyle(
                        color: contact.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(contact.route,
                    style: TextStyle(
                        color: textSecondary, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(contact.helperName,
                  style: TextStyle(
                      color: textPrimary, fontSize: 12)),
              Text(contact.phone,
                  style: TextStyle(
                      color: textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  final String day;
  final bool isActive;
  final bool isDark;

  const _DayBadge(
      {required this.day,
        required this.isActive,
        required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF43A047).withOpacity(0.15)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? const Color(0xFF43A047).withOpacity(0.3)
              : Colors.redAccent.withOpacity(0.3),
        ),
      ),
      child: Text(
        day,
        style: TextStyle(
          color: isActive
              ? const Color(0xFF43A047)
              : Colors.redAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _BusContact {
  final String busId;
  final String busName;
  final Color color;
  final String route;
  final String helperName;
  final String phone;

  const _BusContact({
    required this.busId,
    required this.busName,
    required this.color,
    required this.route,
    required this.helperName,
    required this.phone,
  });
}