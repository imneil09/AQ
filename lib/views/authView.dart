import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient/patientHomeView.dart';
import 'assistant/assistantHomeView.dart';
import 'doctor/doctor_dashboard.dart';

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
  bool get _isDoctorPlatform {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void _redirectUser(User user) {
    if (user.email != null && user.email!.isNotEmpty) {
      if (_isDoctorPlatform) {
        // Using pushReplacement is fine here as it swaps the route
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DoctorDashboard()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AssistantHomeView()));
      }
    } else {
      if (_isDoctorPlatform) {
        _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Patients must use the Mobile App.")));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PatientHomeView()));
      }
    }
  }

  Future<void> _signInWithEmail() async {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPhone() async {
    if (_phoneController.text.length < 10) return;
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${_phoneController.text.trim()}",
      verificationCompleted: (c) async {
        await _auth.signInWithCredential(c);
        if (mounted) _handleCustomerSuccess();
      },
      verificationFailed: (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message!)));
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
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: _otpController.text.trim()));
      _handleCustomerSuccess();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  Future<void> _handleCustomerSuccess() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'phoneNumber': user.phoneNumber,
          'role': 'patient',
          'createdAt': FieldValue.serverTimestamp()
        });
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
          Container(color: const Color(0xFF0F172A)),
          Positioned(top: -100, right: -50, child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.15), size: 400)),
          Positioned(bottom: -50, left: -50, child: _BlurCircle(color: const Color(0xFFF43F5E).withOpacity(0.1), size: 300)),

          Center(
            child: SingleChildScrollView(
              // Added padding at bottom to prevent card from overlapping footer on small screens
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 80),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    // REDUCED WIDTH from 450 to 380 ("Little Small")
                    width: showDoctorUI ? 380 : double.infinity,
                    // REDUCED PADDING from 56 to 40
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))],
                    ),
                    child: showDoctorUI ? _buildDesktopContent() : _buildMobileContent(),
                  ),
                ),
              ),
            ),
          ),

          // FOOTER: Positioned at bottom, but safe due to ScrollView padding
          Positioned(
            bottom: 22, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Designed & Developed by Sagar Bhowmik • Proudly Made in India 🇮🇳",
                  style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDesktopContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16), // Reduced padding
          decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2))
          ),
          child: const Icon(Icons.medical_services_outlined, size: 40, color: Color(0xFF6366F1)), // Reduced Icon Size
        ),
        const SizedBox(height: 24),

        // --- DOCTOR INFORMATION HEADER ---
        const Text(
            "Dr. Shankar Deb Roy",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white)
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12)
          ),
          child: const Text("MS (Ortho) • Reg No. 1040 (TSMC)", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Text(
            "Assoc. Professor, Dept. of Orthopaedics",
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)
        ),
        Text(
            "Agartala Govt. Medical College",
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)
        ),
        // ---------------------------------

        const SizedBox(height: 32), // Reduced spacing
        _glassTextField(_emailController, "Email ID", false),
        const SizedBox(height: 12),
        _glassTextField(_passwordController, "Password", true),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            ),
            onPressed: _isLoading ? null : _signInWithEmail,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("ACCESS DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13)),
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
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))),
            child: const Icon(Icons.local_hospital_rounded, size: 48, color: Color(0xFF10B981)),
          ),
        ),
        const SizedBox(height: 32),
        const Text("Welcome", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white)),
        const SizedBox(height: 12),
        Text(_isOtpSent ? "Enter verification code" : "Sign in to join queue", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
        const SizedBox(height: 48),
        if (!_isOtpSent)
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Mobile Number",
                  labelStyle: TextStyle(color: Colors.white38),
                  prefixText: "+91 ",
                  prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16)
              ),
            ),
          ),
        if (_isOtpSent)
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.white),
            decoration: const InputDecoration(hintText: "••••••", hintStyle: TextStyle(letterSpacing: 8, color: Colors.white12), border: InputBorder.none),
          ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: _isLoading ? null : (_isOtpSent ? _signInWithOTP : _verifyPhone),
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isOtpSent ? "VERIFY" : "GET OTP", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _glassTextField(TextEditingController ctrl, String label, bool obscure) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(fontSize: 14, color: Colors.white), // Slightly smaller text
        decoration: InputDecoration(
          labelText: label,
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
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.9),
          title: const Text("Assistant Access", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _glassTextField(eCtrl, "Email", false),
              const SizedBox(height: 10),
              _glassTextField(pCtrl, "Password", true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
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
                child: const Text("LOGIN")
            )
          ],
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _BlurCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
    );
  }
}