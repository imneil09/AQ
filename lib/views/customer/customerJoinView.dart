import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/queueController.dart';
import '../../models/clinicModel.dart';

class CustomerJoinView extends StatefulWidget {
  final bool isBooking;
  const CustomerJoinView({super.key, required this.isBooking});

  @override
  State<CustomerJoinView> createState() => _CustomerJoinViewState();
}

class _CustomerJoinViewState extends State<CustomerJoinView> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Clinic? _selectedClinic;
  DateTime? _selectedDate;
  String _selectedService = 'New Consultation';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isBooking) {
      _selectedDate = DateTime.now();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedClinic == null || _selectedDate == null) return;
    setState(() => _isLoading = true);
    try {
      await Provider.of<QueueController>(context, listen: false).bookAppointment(
        name: _nameController.text,
        phone: _phoneController.text,
        service: _selectedService,
        date: _selectedDate!,
        clinicId: _selectedClinic!.id,
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
    final queue = Provider.of<QueueController>(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.isBooking ? "Book Future Visit" : "Join Live Queue")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<Clinic>(
              value: _selectedClinic,
              hint: const Text("Select Clinic"),
              items: queue.clinics.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedClinic = val;
                  if (widget.isBooking) _selectedDate = null;
                });
              },
            ),
            const SizedBox(height: 24),
            if (widget.isBooking && _selectedClinic != null) ...[
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    selectableDayPredicate: (d) => _selectedClinic!.weeklySchedule[DateFormat('EEEE').format(d)]?.isOpen ?? false,
                  );
                  if (d != null) setState(() => _selectedDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                  child: Text(_selectedDate == null ? "Select Date" : DateFormat('EEE, MMM d').format(_selectedDate!)),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_selectedClinic != null) ...[
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              DropdownButtonFormField(
                value: _selectedService,
                items: ['New Consultation', 'Follow-up'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _selectedService = v!),
              ),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: _isLoading ? null : _submit, child: const Text("CONFIRM"))
            ]
          ],
        ),
      ),
    );
  }
}