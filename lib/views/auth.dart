import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Imports for your DRY widgets
import '../widgets/appColors.dart';
import '../widgets/backgroundBlur.dart';
import '../widgets/glassCard.dart';

import 'patient/patientHome.dart';
import 'assistant/assistantHome.dart';
import 'doctor/doctorDashboard.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});
  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  bool _isOtpSent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_auth.currentUser != null) {
        _redirectUser(_auth.currentUser!);
      }
    });
  }

  /// WEB-SAFE PLATFORM CHECK
  /// Used to separate Doctor/Staff (Desktop/Web) from Patients (Mobile)
  bool get _isDoctorPlatform {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// ROUTING LOGIC (RBAC)
  /// 1. Staff (Email Auth) -> Doctor Dashboard (Desktop) OR Assistant View (Mobile)
  /// 2. Patients (Phone Auth) -> Patient Home (Mobile only)
  void _redirectUser(User user) {
    if (user.email != null && user.email!.isNotEmpty) {
      // STAFF FLOW
      if (_isDoctorPlatform) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DoctorDashboard()));
      } else {
        // Assistants on mobile/tablet
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AssistantHomeView()));
      }
    } else {
      // PATIENT FLOW
      if (_isDoctorPlatform) {
        // Prevent patients from using the Web/Desktop Admin interface
        _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Patients must use the Mobile App.")));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PatientHomeView()));
      }
    }
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim()
      );
      if (mounted && cred.user != null) {
        _redirectUser(cred.user!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPhone() async {
    if (_phoneController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid 10-digit number")));
      return;
    }

    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${_phoneController.text.trim()}",
      verificationCompleted: (c) async {
        await _auth.signInWithCredential(c);
        if (mounted) _handleCustomerSuccess();
      },
      verificationFailed: (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Verification Failed")));
      },
      codeSent: (id, _) => setState(() {
        _verificationId = id;
        _isOtpSent = true;
        _isLoading = false;
      }),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _signInWithOTP() async {
    if (_otpController.text.length < 6) return;

    setState(() => _isLoading = true);
    try {
      await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: _otpController.text.trim()));
      _handleCustomerSuccess();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  /// FIRESTORE INTEGRATION
  /// Ensures the user exists in the 'users' collection with the correct schema
  Future<void> _handleCustomerSuccess() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await userRef.get();

      if (!doc.exists) {
        // Create new patient document strictly adhering to UserModel
        // NEW
        await userRef.set({
          'uid': user.uid,
          'phoneNumber': user.phoneNumber,
          'role': 'patient', // Ensures role is always set/refreshed
          'isShadowAccount': false,
        }, SetOptions(merge: true));
      }
      if (mounted) _redirectUser(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showDoctorUI = _isDoctorPlatform;

    return Scaffold(
      body: Stack(
        children: [
          // 1. REFACTOR: Use AppColors
          Container(color: AppColors.background),

          // 2. REFACTOR: Use BackgroundBlur widget
          BackgroundBlur(
            color: AppColors.primary.withOpacity(0.15),
            size: 400,
            top: -100,
            right: -50,
          ),
          BackgroundBlur(
            color: AppColors.error.withOpacity(0.1),
            size: 300,
            bottom: -50,
            left: -50,
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      // 3. REFACTOR: Use GlassCard widget
                      child: SizedBox(
                        // Constrain width for desktop/doctor view
                        width: showDoctorUI ? 380 : double.infinity,
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                          child: showDoctorUI ? _buildDesktopContent() : _buildMobileContent(),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
                  child: Text(
                    "Designed & Developed by Sagar Bhowmik • Proudly Made in India 🇮🇳",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 10,
                        fontWeight: FontWeight.w600
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.2))
          ),
          child: const Icon(Icons.medical_services_outlined, size: 40, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        const Text("Dr. Shankar Deb Roy", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.glassWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
          child: const Text("MS (Ortho) • Reg No. 1040 (TSMC)", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 32),
        _glassTextField(_emailController, "Email ID", false),
        const SizedBox(height: 12),
        _glassTextField(_passwordController, "Password", true),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: _isLoading ? null : _signInWithEmail,
            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("ACCESS DASHBOARD"),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPress: _showAssistantLoginDialog,
          child: Hero(
            tag: 'doctor_logo',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: const Icon(Icons.health_and_safety_rounded, size: 40, color: AppColors.success),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Dr. Shankar Deb Roy",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const Text(
          "MS (Ortho) • Specialist Surgeon",
          style: TextStyle(
            color: AppColors.success,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Agartala Govt. Medical College",
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              Expanded(child: Divider(color: AppColors.glassWhite)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text("PATIENT PORTAL",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.glassWhite)),
            ],
          ),
        ),

        const Text(
          "Hey !",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          _isOtpSent ? "Enter verification code" : "Sign in to manage your Appointments",
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        const SizedBox(height: 32),

        if (!_isOtpSent)
          _glassTextField(_phoneController, "Mobile Number", false, prefix: "+91 "),

        if (_isOtpSent)
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.white),
            decoration: const InputDecoration(
              hintText: "••••••",
              hintStyle: TextStyle(letterSpacing: 8, color: Colors.white12),
              border: InputBorder.none,
            ),
          ),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : (_isOtpSent ? _signInWithOTP : _verifyPhone),
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isOtpSent ? "VERIFY" : "GET OTP", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _glassTextField(TextEditingController ctrl, String label, bool obscure, {String? prefix}) {
    // 4. REFACTOR: Updated standard text field to use AppColors
    return Container(
      decoration: BoxDecoration(color: AppColors.glassWhite, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          prefixStyle: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  void _showAssistantLoginDialog() {
    final eCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppColors.surface.withOpacity(0.9),
          title: const Text("Access", style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [_glassTextField(eCtrl, "Email", false), const SizedBox(height: 10), _glassTextField(pCtrl, "Password", true)]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  try {
                    final cred = await _auth.signInWithEmailAndPassword(email: eCtrl.text.trim(), password: pCtrl.text.trim());
                    if (mounted && cred.user != null) {
                      Navigator.pop(context);
                      _redirectUser(cred.user!);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                child: const Text("GET IN")
            )
          ],
        ),
      ),
    );
  }
}