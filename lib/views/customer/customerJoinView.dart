import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/queueController.dart';

// FIX: Ensure class name is PascalCase (Capital C, Capital J, Capital V)
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
  DateTime? _selectedDate;
  bool _isLoading = false;

  // Added service selection for Dr. Tudu
  String _selectedService = 'New Consultation';
  final List<String> _serviceOptions = [
    'New Consultation',
    'Follow-up / Review',
    'Fracture / Trauma',
    'Reports Collection',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isBooking ? "Book Appointment" : "Join Live Queue")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Patient Name", prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone)),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedService,
                decoration: const InputDecoration(labelText: "Reason", prefixIcon: Icon(Icons.medical_services)),
                items: _serviceOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _selectedService = val!),
              ),

              const SizedBox(height: 16),
              if (widget.isBooking)
                ListTile(
                  title: Text(_selectedDate == null ? "Select Date & Time" : _selectedDate.toString()),
                  leading: const Icon(Icons.calendar_month),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.grey)),
                  onTap: () async {
                    final d = await showDatePicker(context: context, firstDate: DateTime.now(), initialDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                    if (d != null) {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (t != null) {
                        setState(() {
                          _selectedDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        });
                      }
                    }
                  },
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _submit(),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Confirm"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.isBooking && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a date")));
      return;
    }

    setState(() => _isLoading = true);
    final ctrl = Provider.of<QueueController>(context, listen: false);

    try {
      if (widget.isBooking) {
        await ctrl.bookFutureAppointment(_nameController.text, _phoneController.text, _selectedService, _selectedDate!);
      } else {
        await ctrl.joinQueueNow(_nameController.text, _phoneController.text, _selectedService);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}