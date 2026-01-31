import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/queueController.dart';

class AdminAddView extends StatefulWidget {
  const AdminAddView({super.key});

  @override
  State<AdminAddView> createState() => _AdminAddViewState();
}

class _AdminAddViewState extends State<AdminAddView> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedService = 'New Consultation';
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Calls the controller to add a patient to TODAY's queue
      await Provider.of<QueueController>(context, listen: false).adminAddWalkIn(
          _nameController.text,
          _phoneController.text,
          _selectedService
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Walk-In Patient", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Base
          Container(color: const Color(0xFF0F172A)),

          // Blurred Accents for Depth
          Positioned(
            top: -50,
            right: -100,
            child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.25), size: 300),
          ),
          Positioned(
            bottom: 50,
            left: -80,
            child: _BlurCircle(color: const Color(0xFFF43F5E).withOpacity(0.15), size: 250),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Patient Details",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Fill in the information to add a walk-in patient to today's queue.",
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          ),
                          const SizedBox(height: 32),

                          // Name Input
                          _buildLabel("NAME"),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            cursorColor: const Color(0xFF6366F1),
                            decoration: const InputDecoration(hintText: "Enter full name"),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 24),

                          // Phone Input
                          _buildLabel("PHONE NUMBER"),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            cursorColor: const Color(0xFF6366F1),
                            decoration: const InputDecoration(
                              hintText: "00000 00000",
                              prefixText: "+91 ",
                              prefixStyle: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                            ),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 24),

                          // Purpose Dropdown
                          _buildLabel("VISIT PURPOSE"),
                          DropdownButtonFormField<String>(
                            value: _selectedService,
                            dropdownColor: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            items: ['New Consultation', 'Follow-up', 'Reports Show', 'General Inquiry']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white))))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedService = v!),
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                          ),
                          const SizedBox(height: 48),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                  : const Text("ADD TO QUEUE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            ),
                          )
                        ],
                      ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF94A3B8)),
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