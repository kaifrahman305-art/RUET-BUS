// ============================================================
// RUET Bus App — Main Entry Point (Updated)
// ============================================================
// New: Admin routing — kaifrahman54@gmail.com → Admin Panel
// ============================================================

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'passenger_live_map_page.dart';
import 'driver_home_page.dart';
import 'admin_screen.dart';
import 'theme_provider.dart';

// ============================================================
// CONSTANTS
// ============================================================

/// Admin email — gets Admin Panel
const String adminEmail = 'kaifrahman54@gmail.com';

/// Driver emails — get Driver Panel
const List<String> driverEmails = [
  'kaifrahman305@gmail.com',
  'kaifrahman305305@gmail.com',
  'kaifrahman307@gmail.com',
  'kaifrahman2303015@gmail.com',
];

const Map<String, String> deptToCode = {
  'CE': '00', 'EEE': '01', 'ME': '02', 'CSE': '03',
  'ETE': '04', 'IPE': '05', 'CME': '06', 'URP': '07',
  'MTE': '08', 'Arch': '09', 'ECE': '10', 'ChE': '11',
  'BECM': '12', 'MSE': '13',
};

// ============================================================
// HELPERS
// ============================================================

bool isAdminEmail(String email) =>
    email.trim().toLowerCase() == adminEmail;

bool isRuetStudentEmail(String email) {
  final e = email.trim().toLowerCase();
  return RegExp(r'^[1-9]\d{6}@student\.ruet\.ac\.bd$').hasMatch(e);
}

bool isDriverEmail(String email) =>
    driverEmails.contains(email.trim().toLowerCase());

Future<String> getDeviceId() async {
  final info = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final a = await info.androidInfo;
    return a.id;
  }
  if (Platform.isIOS) {
    final i = await info.iosInfo;
    return i.identifierForVendor ?? 'ios-unknown';
  }
  return 'unknown-device';
}

// ============================================================
// ENTRY POINT
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  _initializeBuses();
  runApp(const MyApp());
}

Future<void> _initializeBuses() async {
  try {
    final collection =
    FirebaseFirestore.instance.collection('buses');
    final buses = ['bus1','bus2','bus3','bus4','bus5','bus6'];
    for (final busId in buses) {
      final doc = await collection.doc(busId).get();
      if (!doc.exists) {
        await collection.doc(busId).set({
          'isActive': false, 'lat': 0, 'lng': 0, 'speed': 0,
          'driverEmail': '', 'lastUpdated': FieldValue.serverTimestamp(),
          'adminOverride': false, 'offReason': '',
          'assignedDriver': '', 'assignedHelper': '',
        });
      }
    }
  } catch (e) {
    debugPrint('Bus init error: $e');
  }
}

// ============================================================
// ROOT WIDGET
// ============================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'RUET BUS',
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

// ============================================================
// AUTH GATE — onboarding + role routing
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          return FutureBuilder<bool>(
            future: _checkOnboardingDone(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(
                        child: CircularProgressIndicator()));
              }
              final done = snap.data ?? false;
              return done
                  ? const LoginPage()
                  : const OnboardingScreen();
            },
          );
        }
        return RoleRouter(user: user);
      },
    );
  }

  Future<bool> _checkOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  }
}

// ============================================================
// ROLE ROUTER — Admin / Driver / Student
// ============================================================

class RoleRouter extends StatefulWidget {
  final User user;
  const RoleRouter({super.key, required this.user});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  StreamSubscription<DocumentSnapshot>? _sessionSub;
  bool _kickedShown = false;

  @override
  void initState() {
    super.initState();
    _startSingleDeviceWatcher();
  }

  Future<void> _startSingleDeviceWatcher() async {
    final email = widget.user.email?.toLowerCase() ?? '';
    // Admin and drivers can use multiple devices
    if (isAdminEmail(email) || isDriverEmail(email)) return;

    final myDeviceId = await getDeviceId();
    final docRef = FirebaseFirestore.instance
        .collection('sessions').doc(email);

    await docRef.set({
      'deviceId': myDeviceId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _sessionSub = docRef.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final activeDevice = (data['deviceId'] as String?) ?? '';
      if (activeDevice.isNotEmpty && activeDevice != myDeviceId) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        if (!_kickedShown) {
          _kickedShown = true;
          _showKickedDialog();
        }
      }
    });
  }

  void _showKickedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Logged out'),
        content: const Text(
            'You have been logged in from another device.\n\n'
                'For security, this device has been logged out.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email?.toLowerCase() ?? '';

    // ── Admin → Admin Panel with cinematic welcome ───────────
    if (isAdminEmail(email)) return const AdminWelcomeScreen();

    // ── Driver → Driver Panel ────────────────────────────────
    if (isDriverEmail(email)) return const DriverHomePage();

    // ── Student → Passenger Map ──────────────────────────────
    if (isRuetStudentEmail(email)) return const PassengerLiveMapPage();

    // Unknown email
    FirebaseAuth.instance.signOut();
    return const LoginPage();
  }
}

// ============================================================
// LOGIN PAGE
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String error = '';
  bool loading = false;
  bool showForgot = false;
  bool _obscurePassword = true;
  static const double fieldWidth = 420;

  InputDecoration _deco(String label, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white30)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white)),
        suffixIcon: suffix,
      );

  Future<void> login() async {
    final email = emailCtrl.text.trim().toLowerCase();
    final pass = passCtrl.text.trim();
    setState(() { error = ''; loading = true; showForgot = false; });
    try {
      if (!isRuetStudentEmail(email) &&
          !isDriverEmail(email) &&
          !isAdminEmail(email)) {
        setState(() {
          error = 'Only RUET student, driver, or admin email allowed';
          loading = false;
        });
        return;
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: pass);
    } on FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase();
      if (code == 'wrong-password' || code == 'invalid-credential' ||
          code == 'invalid-login-credentials') {
        setState(() { error = 'Wrong email or password'; showForgot = true; });
      } else if (code == 'user-not-found') {
        setState(() => error = 'Account not found. Please register.');
      } else {
        setState(() => error = e.message ?? e.code);
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(child: Image.asset(
              'assets/images/ruet_gate.jpg', fit: BoxFit.cover)),
          Container(color: Colors.black.withOpacity(0.65)),
          Positioned(top: 48, right: 16,
            child: GestureDetector(
              onTap: () => themeProvider.toggleTheme(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(
                    themeProvider.isDark ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/ruet_logo.png', height: 110),
                    const SizedBox(height: 22),
                    const Text('RUET Bus', style: TextStyle(
                        fontSize: 26, color: Colors.white,
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    const Text('Real-time Bus Tracking',
                        style: TextStyle(fontSize: 13, color: Colors.white60)),
                    const SizedBox(height: 32),
                    SizedBox(width: fieldWidth, child: TextField(
                        controller: emailCtrl,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: _deco('Email'))),
                    const SizedBox(height: 14),
                    SizedBox(width: fieldWidth, child: TextField(
                        controller: passCtrl,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _deco('Password', suffix: IconButton(
                          icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54, size: 20),
                          onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                        )),
                        onSubmitted: (_) => login())),
                    const SizedBox(height: 20),
                    if (error.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: Text(error, style: const TextStyle(
                            color: Colors.redAccent, fontWeight: FontWeight.w600,
                            fontSize: 13), textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12, runSpacing: 10,
                      children: [
                        ElevatedButton(
                          onPressed: loading ? null : login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            backgroundColor: const Color(0xFF1565C0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(loading ? 'Please wait...' : 'Login',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const RegisterPage())),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            backgroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Register',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        if (showForgot)
                          ElevatedButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => ForgotPasswordPage(
                                    prefillEmail: emailCtrl.text.trim().toLowerCase()))),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              backgroundColor: Colors.orange.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Forgot Password',
                                style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// REGISTER PAGE
// ============================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameCtrl = TextEditingController();
  final rollCtrl = TextEditingController();
  final seriesCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? selectedDept;
  String error = '';
  bool loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  static const double fieldWidth = 420;

  InputDecoration _deco(String label, {Widget? suffix}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
    suffixIcon: suffix,
  );

  String? _validate() {
    final name = nameCtrl.text.trim();
    final roll = rollCtrl.text.trim();
    final series = seriesCtrl.text.trim();
    final dept = selectedDept;
    final email = emailCtrl.text.trim().toLowerCase();
    final pass = passCtrl.text.trim();
    final confirm = confirmCtrl.text.trim();

    if (name.isEmpty) return 'Name is required';
    if (!RegExp(r'^\d{7}$').hasMatch(roll)) return 'Roll Number must be 7 digits';
    if (!RegExp(r'^\d{2}$').hasMatch(series)) return 'Series must be 2 digits';
    if (dept == null) return 'Please select department';
    if (!isRuetStudentEmail(email)) return 'Invalid RUET student email';
    if (series != roll.substring(0, 2)) return 'Series must match roll number';
    final last3 = int.tryParse(roll.substring(4, 7)) ?? 0;
    if (last3 < 1 || last3 > 190) return 'Roll Number is incorrect';
    if (roll.substring(2, 4) != deptToCode[dept]!) return 'Roll Number does not match department';
    if (email != '$roll@student.ruet.ac.bd') return 'Email must match roll number';
    if (pass.length < 6) return 'Password must be at least 6 characters';
    if (pass != confirm) return 'Passwords do not match';
    return null;
  }

  Future<void> register() async {
    setState(() { error = ''; loading = true; });
    try {
      final msg = _validate();
      if (msg != null) { setState(() { error = msg; loading = false; }); return; }
      final email = emailCtrl.text.trim().toLowerCase();
      final pass = passCtrl.text.trim();
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      await FirebaseFirestore.instance.collection('students').doc(email).set({
        'name': nameCtrl.text.trim(), 'roll': rollCtrl.text.trim(),
        'series': seriesCtrl.text.trim(), 'department': selectedDept,
        'departmentCode': deptToCode[selectedDept!], 'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? e.code);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose(); rollCtrl.dispose(); seriesCtrl.dispose();
    emailCtrl.dispose(); passCtrl.dispose(); confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(child: Image.asset('assets/images/ruet_gate.jpg', fit: BoxFit.cover)),
          Container(color: Colors.black.withOpacity(0.65)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/ruet_logo.png', height: 90),
                    const SizedBox(height: 18),
                    const Text('Register', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 18),
                    SizedBox(width: fieldWidth, child: TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: _deco('Full Name'))),
                    const SizedBox(height: 14),
                    SizedBox(width: fieldWidth, child: TextField(controller: rollCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _deco('Roll Number (7 digits)'))),
                    const SizedBox(height: 14),
                    SizedBox(width: fieldWidth, child: DropdownButtonFormField<String>(
                      value: selectedDept, dropdownColor: const Color(0xFF1A1A2E),
                      decoration: _deco('Department'), style: const TextStyle(color: Colors.white),
                      items: deptToCode.keys.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setState(() => selectedDept = v),
                    )),
                    const SizedBox(height: 14),
                    SizedBox(width: fieldWidth, child: TextField(controller: seriesCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _deco('Series (e.g. 23)'))),
                    const SizedBox(height: 14),
                    SizedBox(width: fieldWidth, child: TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: _deco('Edu Email (roll@student.ruet.ac.bd)'))),
                    const SizedBox(height: 14),
                    SizedBox(width: fieldWidth, child: TextField(controller: passCtrl, obscureText: _obscurePass, style: const TextStyle(color: Colors.white), decoration: _deco('Password', suffix: IconButton(icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 20), onPressed: () => setState(() => _obscurePass = !_obscurePass))))),
                    const SizedBox(height: 14),
                    SizedBox(width: fieldWidth, child: TextField(controller: confirmCtrl, obscureText: _obscureConfirm, style: const TextStyle(color: Colors.white), decoration: _deco('Confirm Password', suffix: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 20), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm))))),
                    const SizedBox(height: 20),
                    if (error.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.4))),
                        child: Text(error, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: 20),
                    Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 10, children: [
                      ElevatedButton(
                        onPressed: loading ? null : register,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text(loading ? 'Please wait...' : 'Register', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Back'),
                      ),
                    ]),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FORGOT PASSWORD PAGE
// ============================================================

class ForgotPasswordPage extends StatefulWidget {
  final String prefillEmail;
  const ForgotPasswordPage({super.key, required this.prefillEmail});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController emailCtrl;
  String msg = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    emailCtrl = TextEditingController(text: widget.prefillEmail);
  }

  Future<void> sendReset() async {
    final email = emailCtrl.text.trim().toLowerCase();
    if (!isRuetStudentEmail(email)) {
      setState(() => msg = 'Please use your RUET student email');
      return;
    }
    setState(() { loading = true; msg = ''; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() => msg = 'Reset email sent ✅ Check your inbox & spam');
    } on FirebaseAuthException catch (e) {
      setState(() => msg = e.message ?? e.code);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() { emailCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(child: Image.asset('assets/images/ruet_gate.jpg', fit: BoxFit.cover)),
          Container(color: Colors.black.withOpacity(0.65)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/ruet_logo.png', height: 90),
                    const SizedBox(height: 18),
                    const Text('Forgot Password', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Enter your RUET email to receive a reset link', style: TextStyle(color: Colors.white60, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    SizedBox(width: 420, child: TextField(controller: emailCtrl, style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'RUET Email', labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white))))),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: loading ? null : sendReset,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), backgroundColor: Colors.orange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(loading ? 'Sending...' : 'Send Reset Email', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    if (msg.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: msg.contains('✅') ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: msg.contains('✅') ? Colors.greenAccent.withOpacity(0.4) : Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: Text(msg, style: TextStyle(color: msg.contains('✅') ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: 16),
                    TextButton(onPressed: () => Navigator.pop(context),
                        child: const Text('Back to Login', style: TextStyle(color: Colors.white60))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}