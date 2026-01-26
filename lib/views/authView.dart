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
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Doctor Login"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: eCtrl, decoration: const InputDecoration(labelText: "Email")),
        const SizedBox(height: 12),
        TextField(controller: pCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          try {
            final cred = await _auth.signInWithEmailAndPassword(email: eCtrl.text.trim(), password: pCtrl.text.trim());
            if (mounted && cred.user != null) { Navigator.pop(context); _redirectUser(cred.user!); }
          } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
        }, child: const Text("Login"))
      ],
    ));
  }

  Future<void> _verifyPhone() async {
    if (_phoneController.text.length < 10) return;
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${_phoneController.text.trim()}",
      verificationCompleted: (c) async { await _auth.signInWithCredential(c); if(mounted) _handleSuccess(); },
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              GestureDetector(
                onLongPress: _showAdminLogin,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.local_hospital_rounded, size: 64, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(height: 24),
              const Text("Clinic Portal", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              if (!_isOtpSent)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Mobile Number", prefixText: "+91 "),
                ),
              if (_isOtpSent)
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: "000000"),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_isOtpSent ? _signInWithOTP : _verifyPhone),
                  child: Text(_isOtpSent ? "VERIFY" : "GET OTP"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}