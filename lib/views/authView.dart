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
      if (_auth.currentUser != null) _redirectUser(_auth.currentUser!);
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
    // Keep admin login simple but styled
    final eCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Admin Portal"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: eCtrl, decoration: const InputDecoration(labelText: "Email ID", prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 12),
        TextField(controller: pCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Secure Password", prefixIcon: Icon(Icons.lock_outline))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          try {
            final cred = await _auth.signInWithEmailAndPassword(email: eCtrl.text.trim(), password: pCtrl.text.trim());
            if (mounted && cred.user != null) { Navigator.pop(context); _redirectUser(cred.user!); }
          } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
        }, child: const Text("Access Dashboard"))
      ],
    ));
  }

  Future<void> _verifyPhone() async {
    if (_phoneController.text.length < 10) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Phone Number"))); return; }
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${_phoneController.text.trim()}",
      verificationCompleted: (c) async { await _auth.signInWithCredential(c); if(mounted)_handleSuccess(); },
      verificationFailed: (e) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message!))); },
      codeSent: (id, _) => setState(() { _verificationId = id; _isOtpSent = true; _isLoading = false; }),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _signInWithOTP() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: _otpController.text.trim()));
      _handleSuccess();
    } catch (e) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP"))); }
  }

  Future<void> _handleSuccess() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid, 'phoneNumber': user.phoneNumber, 'role': 'customer', 'createdAt': FieldValue.serverTimestamp()
        });
      }
      if(mounted) _redirectUser(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Stack(children: [
        // Top Curve Design
        Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)]
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(80), bottomRight: Radius.circular(80)),
          ),
          child: SafeArea(
            child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onLongPress: _showAdminLogin,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.medical_services_rounded, size: 64, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                const Text("DR. TUSHAR TUDU", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: const Text("ORTHOPEDIC SURGEON • INDRANAGAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1)),
                ),
                const SizedBox(height: 60), // Spacing for card
              ],
            )),
          ),
        ),

        // Floating Login Card
        Align(alignment: Alignment.bottomCenter, child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Column(children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.40),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20)),
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ]
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isOtpSent ? "Secure Verification" : "Patient Portal", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Text(_isOtpSent ? "Enter the code sent to your mobile" : "Log in to manage your appointments", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 32),

                if (!_isOtpSent)
                  TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      decoration: const InputDecoration(labelText: "Mobile Number", prefixText: "+91 ", prefixIcon: Icon(Icons.phone_iphone_rounded))
                  ),

                if (_isOtpSent)
                  TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 8),
                      decoration: const InputDecoration(hintText: "• • • • • •")
                  ),

                const SizedBox(height: 32),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isOtpSent ? _signInWithOTP : _verifyPhone,
                    child: Text(_isOtpSent ? "VERIFY & ACCESS" : "GET SECURE CODE"),
                  ),
                ),
              ]),
            )
          ]),
        ))
      ]),
    );
  }
}