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
      await Provider.of<QueueController>(context, listen: false).adminAddWalkIn(
          _nameController.text,
          _phoneController.text,
          _selectedService
      );
      if(mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Walk-In Patient")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Name"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: "Phone"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              DropdownButtonFormField(
                value: _selectedService,
                items: ['New Consultation', 'Follow-up'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _selectedService = v!),
                decoration: const InputDecoration(labelText: "Purpose"),
              ),
              const Spacer(),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isLoading ? null : _submit, child: const Text("ADD TO QUEUE")))
            ],
          ),
        ),
      ),
    );
  }
}