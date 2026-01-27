import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer/customerHomeView.dart';
import 'admin/adminHomeView.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});
  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
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

  void _redirectUser(User user) {
    if (user.email != null && user.email!.isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomeView()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerHomeView()));
    }
  }

  void _showAdminLogin() {
    final eCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: const Text("Doctor Login", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: eCtrl, decoration: const InputDecoration(labelText: "Email")),
              const SizedBox(height: 16),
              TextField(controller: pCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
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
              child: const Text("LOGIN"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _verifyPhone() async {
    if (_phoneController.text.length < 10) return;
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${_phoneController.text.trim()}",
      verificationCompleted: (c) async {
        await _auth.signInWithCredential(c);
        if (mounted) _handleSuccess();
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
      _handleSuccess();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  Future<void> _handleSuccess() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'phoneNumber': user.phoneNumber,
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp()
        });
      }
      if (mounted) _redirectUser(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Base
          Container(color: const Color(0xFF0F172A)),

          // Blurred Accents
          Positioned(
            top: -100,
            right: -50,
            child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.2), size: 300),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _BlurCircle(color: const Color(0xFFF43F5E).withOpacity(0.15), size: 250),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onLongPress: _showAdminLogin,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.local_hospital_rounded, size: 56, color: Color(0xFF6366F1)),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          "Clinic Portal",
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isOtpSent ? "Enter the code sent to your mobile" : "Enter your number to continue",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                        ),
                        const SizedBox(height: 48),
                        if (!_isOtpSent)
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              labelText: "Mobile Number",
                              prefixText: "+91 ",
                              prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                            ),
                          ),
                        if (_isOtpSent)
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                            decoration: const InputDecoration(hintText: "000000", hintStyle: TextStyle(letterSpacing: 8, color: Colors.white24)),
                          ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : (_isOtpSent ? _signInWithOTP : _verifyPhone),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                : Text(_isOtpSent ? "VERIFY OTP" : "GET SECURE OTP"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: Container(color: Colors.transparent)),
    );
  }
}