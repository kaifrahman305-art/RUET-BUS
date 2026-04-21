// ============================================================
// RUET Bus App — Onboarding Screen
// ============================================================
// প্রথমবার app খুললে দেখায়।
// SharedPreferences এ mark করে রাখে যাতে পরে না দেখায়।
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      icon: Icons.directions_bus,
      color: Color(0xFF1565C0),
      title: 'স্বাগতম RUET Bus এ!',
      subtitle: 'রাজশাহী প্রকৌশল ও প্রযুক্তি বিশ্ববিদ্যালয়',
      description:
      'RUET এর ৬টি বাসের real-time location, সময়সূচি এবং আরো অনেক কিছু এক জায়গায় পাবেন।',
    ),
    _OnboardingData(
      icon: Icons.location_on,
      color: Color(0xFF43A047),
      title: 'লাইভ বাস ট্র্যাকিং',
      subtitle: 'Real-time GPS Location',
      description:
      'Map এ দেখতে পাবেন কোন বাস এখন কোথায় আছে। বাসের speed, দূরত্ব এবং আনুমানিক আগমনের সময় জানতে পারবেন।',
    ),
    _OnboardingData(
      icon: Icons.schedule,
      color: Color(0xFFFB8C00),
      title: 'বাসের সময়সূচি',
      subtitle: 'অফিসিয়াল RUET তফসিল',
      description:
      'প্রতিটি বাসের departure ও arrival time দেখতে পাবেন। বৃহস্পতি ও শুক্রবার ছুটি — app আপনাকে জানিয়ে দেবে।',
    ),
    _OnboardingData(
      icon: Icons.near_me,
      color: Color(0xFF8E24AA),
      title: 'কাছের বাস খুঁজুন',
      subtitle: 'Nearest Bus Finder',
      description:
      'আপনার location থেকে কোন বাস সবচেয়ে কাছে আছে সেটা দেখতে পাবেন। বাস কাছে আসলে notification পাবেন।',
    ),
    _OnboardingData(
      icon: Icons.notifications_active,
      color: Color(0xFFE53935),
      title: 'Notification',
      subtitle: 'বাস কাছে আসলে alert',
      description:
      'বাস আপনার কাছে আসলে automatically notification পাবেন। Distance threshold নিজে set করতে পারবেন।',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 14),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) =>
                    setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) =>
                    _OnboardingPage(data: _pages[i]),
              ),
            ),

            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                    (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin:
                  const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? _pages[_currentPage].color
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Next / Get Started button
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    _pages[_currentPage].color,
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'শুরু করুন 🚌'
                        : 'পরবর্তী →',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Single onboarding page ─────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.color.withOpacity(0.15),
              border: Border.all(
                  color: data.color.withOpacity(0.4), width: 2),
              boxShadow: [
                BoxShadow(
                    color: data.color.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 5),
              ],
            ),
            child: Icon(data.icon, color: data.color, size: 64),
          ),
          const SizedBox(height: 40),

          Text(
            data.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            data.subtitle,
            style: TextStyle(
              color: data.color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              data.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;

  const _OnboardingData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}