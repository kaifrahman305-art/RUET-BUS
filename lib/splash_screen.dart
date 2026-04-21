// ============================================================
// RUET Bus App — Splash Screen
// ============================================================
// This screen is shown when the app first launches.
// It displays an animated intro sequence with a driving bus
// and then navigates to the AuthGate (login/home).
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Animation Controllers ──────────────────────────────────

  /// Fades + scales in the logo from center
  late final AnimationController _logoCtrl;

  /// Slides the title text up from below
  late final AnimationController _titleCtrl;

  /// Reveals the tagline with a fade
  late final AnimationController _taglineCtrl;

  /// Animates the progress bar at the bottom
  late final AnimationController _progressCtrl;

  /// Fades the entire screen out before navigation
  late final AnimationController _fadeOutCtrl;

  /// Continuously rotates the decorative ring behind the logo
  late final AnimationController _ringCtrl;

  /// Pulses the logo glow
  late final AnimationController _glowCtrl;

  /// Moves the bus from left to right across the bottom
  late final AnimationController _busCtrl;

  // ── Animations ─────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _progress;
  late final Animation<double> _fadeOut;
  late final Animation<double> _ringRotation;
  late final Animation<double> _glow;
  late final Animation<double> _busPosition;

  // ── Particles ──────────────────────────────────────────────
  /// Random floating particles in the background
  final List<_Particle> _particles = [];
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _generateParticles();
    _runSequence();
  }

  /// Creates all AnimationControllers and their Animations
  void _initAnimations() {

    // ── Logo ──────────────────────────────────────────────────
    // Scale from 0.3→1.0 with elastic bounce, fade in quickly
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // ── Title ─────────────────────────────────────────────────
    // Slides up from below and fades in
    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOutCubic));
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleCtrl, curve: Curves.easeIn),
    );

    // ── Tagline ───────────────────────────────────────────────
    // Simple fade in
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeIn),
    );

    // ── Progress bar ──────────────────────────────────────────
    // Fills from 0→1 over 2 seconds
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );

    // ── Fade out ──────────────────────────────────────────────
    // Covers screen with black before navigating away
    _fadeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeOut = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeOutCtrl);

    // ── Decorative ring ───────────────────────────────────────
    // Continuously rotates behind the logo
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _ringRotation =
        Tween<double>(begin: 0, end: 2 * pi).animate(_ringCtrl);

    // ── Glow pulse ────────────────────────────────────────────
    // Logo glow breathes in/out
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // ── Bus ───────────────────────────────────────────────────
    // Drives from left (-0.15) to right (1.15) — off screen on both sides
    _busCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _busPosition = Tween<double>(begin: -0.15, end: 1.15).animate(
      CurvedAnimation(parent: _busCtrl, curve: Curves.easeInOut),
    );
  }

  /// Generates random floating particle data
  void _generateParticles() {
    final rng = Random();
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 4 + 1,
        opacity: rng.nextDouble() * 0.5 + 0.1,
        speed: rng.nextDouble() * 0.3 + 0.1,
      ));
    }
  }

  /// Runs the animation sequence in order
  Future<void> _runSequence() async {
    // Small initial delay before anything appears
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Show particles
    setState(() => _showParticles = true);

    // Logo bounces in
    await _logoCtrl.forward();
    if (!mounted) return;

    // Title slides up
    await _titleCtrl.forward();
    if (!mounted) return;

    // Tagline fades in
    _taglineCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Bus drives across + progress bar fills simultaneously
    _busCtrl.forward();
    await _progressCtrl.forward();
    if (!mounted) return;

    // Brief pause at "Ready!"
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Fade out and navigate to AuthGate
    await _fadeOutCtrl.forward();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    _progressCtrl.dispose();
    _fadeOutCtrl.dispose();
    _ringCtrl.dispose();
    _glowCtrl.dispose();
    _busCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: AnimatedBuilder(
        // Rebuild on every animation tick
        animation: Listenable.merge([
          _logoCtrl,
          _titleCtrl,
          _taglineCtrl,
          _progressCtrl,
          _fadeOutCtrl,
          _ringCtrl,
          _glowCtrl,
          _busCtrl,
        ]),
        builder: (context, _) {
          return Stack(
            children: [

              // ── Layer 1: Gradient background ──────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A0E1A),
                      Color(0xFF0D1B2A),
                      Color(0xFF0A1628),
                    ],
                  ),
                ),
              ),

              // ── Layer 2: Floating particles ────────────────
              if (_showParticles)
                CustomPaint(
                  size: size,
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: _progressCtrl.value,
                  ),
                ),

              // ── Layer 3: Decorative circles ────────────────
              // Large faint outer circle
              Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                      const Color(0xFF1E3A5F).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // Rotating dashed ring
              Center(
                child: Transform.rotate(
                  angle: _ringRotation.value,
                  child: CustomPaint(
                    size: const Size(240, 240),
                    painter: _DashedRingPainter(
                      color: const Color(0xFF2196F3).withOpacity(0.25),
                    ),
                  ),
                ),
              ),

              // ── Layer 4: Main content ──────────────────────
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // ── Logo with glow ──────────────────────
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow circle behind logo
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3)
                                    .withOpacity(_glow.value * 0.4),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        // Logo with scale + fade animation
                        FadeTransition(
                          opacity: _logoOpacity,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2196F3)
                                        .withOpacity(0.4),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/images/ruet_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Title ───────────────────────────────
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleOpacity,
                        child: const Column(
                          children: [
                            Text(
                              'RUET BUS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'রাজশাহী প্রকৌশল ও প্রযুক্তি বিশ্ববিদ্যালয়',
                              style: TextStyle(
                                color: Color(0xFF90CAF9),
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Tagline ─────────────────────────────
                    FadeTransition(
                      opacity: _taglineOpacity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                            const Color(0xFF2196F3).withOpacity(0.4),
                          ),
                          color:
                          const Color(0xFF2196F3).withOpacity(0.08),
                        ),
                        child: const Text(
                          'Real-time Bus Tracking System',
                          style: TextStyle(
                            color: Color(0xFF64B5F6),
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // ── Bottom section ──────────────────────
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 48),
                      child: Column(
                        children: [
                          // Loading text
                          FadeTransition(
                            opacity: _taglineOpacity,
                            child: Text(
                              _getLoadingText(_progress.value),
                              style: const TextStyle(
                                color: Color(0xFF546E7A),
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── Animated bus on road ──────────
                          FadeTransition(
                            opacity: _taglineOpacity,
                            child: SizedBox(
                              height: 36,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Road line
                                  Positioned(
                                    bottom: 4,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 1,
                                      color: const Color(0xFF1E3A5F)
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                  // Small dashes on road
                                  Positioned(
                                    bottom: 7,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      children: List.generate(
                                        12,
                                            (i) => Expanded(
                                          child: Container(
                                            margin: const EdgeInsets
                                                .symmetric(horizontal: 4),
                                            height: 1,
                                            color:
                                            const Color(0xFF1E3A5F)
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bus moves left to right
                                  Positioned(
                                    bottom: 5,
                                    left: size.width *
                                        _busPosition.value *
                                        0.85 -
                                        24,
                                    child: CustomPaint(
                                      size: const Size(52, 26),
                                      painter: _BusPainter(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // ── Progress bar ──────────────────
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2D40),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _progress.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1565C0),
                                      Color(0xFF42A5F5),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),

              // ── Layer 5: Fade-out overlay ──────────────────
              // Black overlay that covers everything on exit
              if (_fadeOutCtrl.value > 0)
                Opacity(
                  opacity: _fadeOut.value,
                  child: Container(color: Colors.black),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Returns loading message based on progress value
  String _getLoadingText(double progress) {
    if (progress < 0.3) return 'Initializing...';
    if (progress < 0.6) return 'Loading map data...';
    if (progress < 0.9) return 'Connecting to buses...';
    return 'Ready!';
  }
}

// ============================================================
// Particle data model
// ============================================================
class _Particle {
  /// Normalized horizontal position (0.0 = left, 1.0 = right)
  final double x;

  /// Initial normalized vertical position (0.0 = top, 1.0 = bottom)
  final double y;

  /// Radius in logical pixels
  final double size;

  /// Opacity between 0.1 and 0.6
  final double opacity;

  /// Upward drift speed multiplier
  final double speed;

  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
  });
}

// ============================================================
// CustomPainter — draws floating background particles
// ============================================================
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  /// Animation progress (0.0–1.0) — particles drift upward
  final double progress;

  const _ParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color =
        const Color(0xFF2196F3).withOpacity(p.opacity * 0.6)
        ..style = PaintingStyle.fill;

      // Drift upward as progress increases, wrap around
      final dy = (p.y - progress * p.speed) % 1.0;

      canvas.drawCircle(
        Offset(p.x * size.width, dy * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress;
}

// ============================================================
// CustomPainter — draws a dashed decorative ring
// ============================================================
class _DashedRingPainter extends CustomPainter {
  final Color color;

  const _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 20 dashes evenly spaced around the circle
    const dashCount = 20;
    const dashAngle = 2 * pi / dashCount;
    const gapFraction = 0.4; // 40% gap between dashes

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => false;
}

// ============================================================
// CustomPainter — draws a small red bus icon
// ============================================================
class _BusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {

    // ── Bus body ───────────────────────────────────────────
    final bodyPaint = Paint()
      ..color = const Color(0xFFE53935) // Red
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 0, size.width - 4, size.height - 10),
        const Radius.circular(4),
      ),
      bodyPaint,
    );

    // ── Windows ────────────────────────────────────────────
    final windowPaint = Paint()
      ..color = const Color(0xFF90CAF9).withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // 3 evenly spaced windows
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(5 + i * 14.0, 4, 10, 6),
          const Radius.circular(2),
        ),
        windowPaint,
      );
    }

    // ── Headlight ──────────────────────────────────────────
    final lightPaint = Paint()
      ..color = const Color(0xFFFFF9C4)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width - 4, size.height - 14),
      2.5,
      lightPaint,
    );

    // ── Wheels ─────────────────────────────────────────────
    final wheelPaint = Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.fill;

    // Front wheel
    canvas.drawCircle(
      Offset(10, size.height - 5),
      5,
      wheelPaint,
    );
    // Rear wheel
    canvas.drawCircle(
      Offset(size.width - 12, size.height - 5),
      5,
      wheelPaint,
    );

    // ── Wheel hubs (white center) ──────────────────────────
    final hubPaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(10, size.height - 5), 2, hubPaint);
    canvas.drawCircle(
        Offset(size.width - 12, size.height - 5), 2, hubPaint);
  }

  @override
  bool shouldRepaint(_BusPainter old) => false;
}