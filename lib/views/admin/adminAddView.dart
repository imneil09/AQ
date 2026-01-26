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

    final queue = Provider.of<QueueController>(context, listen: false);
    if (queue.selectedClinic == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No clinic selected!")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await queue.adminAddWalkIn(
          _nameController.text,
          _phoneController.text,
          _selectedService
      );
      if(mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Patient Added Successfully"), backgroundColor: Color(0xFF10B981))
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
    // Show which clinic we are adding to
    final clinicName = Provider.of<QueueController>(context).selectedClinic?.name ?? "Unknown Clinic";

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        title: const Text("Add Walk-In Patient"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Clinic Indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              color: Colors.blue.withOpacity(0.1),
              child: Text("Adding to: $clinicName",
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center
              ),
            ),

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
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person)),
                              validator: (v) => v!.isEmpty ? "Name is required" : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone)),
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
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedService,
                          decoration: const InputDecoration(labelText: "Purpose", prefixIcon: Icon(Icons.medical_services)),
                          items: _services.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _selectedService = v!),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
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
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
    );
  }
}