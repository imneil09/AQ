import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // --- 1. HIDDEN ADMIN LOGIN (Long Press) ---
  void _showAdminLogin() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Admin Access"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 10),
            TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await _auth.signInWithEmailAndPassword(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text.trim()
                );
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomeView()));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Login"),
          )
        ],
      ),
    );
  }

  // --- 2. CUSTOMER PHONE AUTH ---
  Future<void> _verifyPhone() async {
    if (_phoneController.text.isEmpty) return;
    setState(() => _isLoading = true);

    String phone = "+91${_phoneController.text.trim()}";

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        if (mounted) _navigateToHome();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Failed")));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _signInWithOTP() async {
    if (_verificationId == null) return;
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      if (mounted) _navigateToHome();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerHomeView()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Header
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1C1E53), Color(0xFF2E3192)]),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60), bottomRight: Radius.circular(60)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // HIDDEN ADMIN TRIGGER
                  GestureDetector(
                    onLongPress: _showAdminLogin,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.store, size: 48, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("QUEUE PRO", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),

          // Login Card
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
                    child: Column(
                      children: [
                        Text(_isOtpSent ? "Enter OTP" : "Welcome", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),

                        if (!_isOtpSent)
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: "Phone Number", prefixText: "+91 "),
                          ),

                        if (_isOtpSent)
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "OTP"),
                          ),

                        const SizedBox(height: 20),

                        if (_isLoading)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                            onPressed: _isOtpSent ? _signInWithOTP : _verifyPhone,
                            child: Text(_isOtpSent ? "Verify" : "Get OTP"),
                          )
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}