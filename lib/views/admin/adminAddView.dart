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
  final List<String> _services = ['New Consultation', 'Follow-up', 'Fracture Check', 'Post-Op Care'];
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await Provider.of<QueueController>(context, listen: false).adminAddWalkIn(
          _nameController.text,
          _phoneController.text,
          _selectedService
      );
      if(mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Patient Added Successfully"),
                backgroundColor: Color(0xFF10B981)
            )
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        title: const Text("Add Walk-In", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle("Patient Details"),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                labelText: "Full Name",
                                prefixIcon: Icon(Icons.person_rounded),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                              ),
                              validator: (v) => v!.isEmpty ? "Name is required" : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                labelText: "Phone Number",
                                prefixIcon: Icon(Icons.phone_iphone_rounded),
                              ),
                              validator: (v) => v!.isEmpty ? "Phone is required" : null,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      _sectionTitle("Visit Information"),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedService,
                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 16),
                          decoration: const InputDecoration(
                            labelText: "Purpose of Visit",
                            prefixIcon: Icon(Icons.medical_services_rounded),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: _services.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _selectedService = v!),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add_circle_outline_rounded),
                  label: Text(_isLoading ? "PROCESSING..." : "ADD TO QUEUE"),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 1.2
        ),
      ),
    );
  }
}