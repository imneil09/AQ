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
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _verificationId;
  bool _isOtpSent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 1. AUTO-LOGIN CHECK: If user is already logged in, redirect immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = _auth.currentUser;
      if (user != null) {
        _redirectUser(user);
      }
    });
  }

  // --- Helper: Redirect based on Login Type ---
  void _redirectUser(User user) {
    // If user has an email, they are the Admin (Manual setup)
    if (user.email != null && user.email!.isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomeView()));
    } else {
      // If no email (Phone Auth), they are a Customer
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerHomeView()));
    }
  }

  // --- 2. ADMIN LOGIN (Manual Email/Pass) ---
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
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                  labelText: "Admin Email",
                  hintText: "admin@queue.com",
                  prefixIcon: Icon(Icons.email)
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Admin login just checks credentials
                final cred = await _auth.signInWithEmailAndPassword(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text.trim()
                );
                if (mounted && cred.user != null) {
                  Navigator.pop(context); // Close dialog
                  _redirectUser(cred.user!);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Access Denied: ${e.toString()}")));
              }
            },
            child: const Text("Login"),
          )
        ],
      ),
    );
  }

  // --- 3. CUSTOMER OTP LOGIC ---

  // A. Send OTP
  Future<void> _verifyPhone() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter phone number")));
      return;
    }
    setState(() => _isLoading = true);

    String phone = "+91${_phoneController.text.trim()}"; // Assuming India (+91)

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      // Android Auto-Resolve: Automatically signs in if SMS is read
      verificationCompleted: (PhoneAuthCredential credential) async {
        final cred = await _auth.signInWithCredential(credential);
        if (mounted && cred.user != null) await _handleCustomerLoginSuccess(cred.user!);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Verification Failed")));
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

  // B. Verify OTP & Login
  Future<void> _signInWithOTP() async {
    if (_verificationId == null) return;
    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      final cred = await _auth.signInWithCredential(credential);
      if (mounted && cred.user != null) await _handleCustomerLoginSuccess(cred.user!);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  // C. Profile Check & Creation
  Future<void> _handleCustomerLoginSuccess(User user) async {
    final userRef = _db.collection('users').doc(user.uid);

    // Check if this user is already in our database
    final docSnapshot = await userRef.get();

    if (!docSnapshot.exists) {
      // NEW USER: Create the profile (Just phone number, no name required)
      await userRef.set({
        'uid': user.uid,
        'phoneNumber': user.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'customer',
      });
    }
    // EXISTING USER: Do nothing, just proceed

    if (mounted) {
      _redirectUser(user);
    }
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
                  // HIDDEN ADMIN TRIGGER (Long Press the Icon)
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
                  const Text("Customer Login", style: TextStyle(color: Colors.white70)),
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
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]
                    ),
                    child: Column(
                      children: [
                        Text(_isOtpSent ? "Enter OTP" : "Welcome", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),

                        if (!_isOtpSent)
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                                labelText: "Phone Number",
                                prefixText: "+91 ",
                                hintText: "9876543210"
                            ),
                          ),

                        if (_isOtpSent)
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "OTP Code"),
                          ),

                        const SizedBox(height: 20),

                        if (_isLoading)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                            onPressed: _isOtpSent ? _signInWithOTP : _verifyPhone,
                            child: Text(_isOtpSent ? "Verify & Login" : "Get OTP"),
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