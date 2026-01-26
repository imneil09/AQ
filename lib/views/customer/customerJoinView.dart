import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/queueController.dart';
import '../../models/clinicModel.dart';

class CustomerJoinView extends StatefulWidget {
  final bool isBooking; // true = Future, false = Today
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

  final List<String> _services = ['New Consultation', 'Follow-up', 'Fracture Check', 'Post-Op Care'];

  @override
  void initState() {
    super.initState();
    if (!widget.isBooking) {
      _selectedDate = DateTime.now(); // If "Join Now", date is strictly today
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClinic == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a clinic")));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a date")));
      return;
    }

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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // 1. Clinic Selection
                    const Text("Select Clinic", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Clinic>(
                      value: _selectedClinic,
                      hint: const Text("Choose a location..."),
                      items: queue.clinics.map((c) => DropdownMenuItem(value: c, child: Text("${c.name} (${c.address})"))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedClinic = val;
                          _selectedDate = widget.isBooking ? null : DateTime.now(); // Reset date if booking
                        });
                      },
                      validator: (v) => v == null ? "Required" : null,
                    ),
                    const SizedBox(height: 24),

                    // 2. Date Selection (Only if Booking Future)
                    if (widget.isBooking && _selectedClinic != null) ...[
                      const Text("Select Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          // Allow selection up to 30 days out
                          final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now().add(const Duration(days: 1)),
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                            selectableDayPredicate: (DateTime day) {
                              // Disable days where clinic is closed
                              String dayName = DateFormat('EEEE').format(day);
                              return _selectedClinic!.weeklySchedule[dayName]?.isOpen ?? false;
                            },
                          );
                          if (d != null) setState(() => _selectedDate = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_selectedDate == null
                                  ? "Tap to choose date"
                                  : DateFormat('EEE, MMM d, y').format(_selectedDate!)),
                              const Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 3. User Details
                    if (_selectedClinic != null) ...[
                      const Text("Patient Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: "Full Name"),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: "Phone Number"),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField(
                        value: _selectedService,
                        items: _services.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _selectedService = v!),
                        decoration: const InputDecoration(labelText: "Purpose"),
                      ),
                    ]
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: Text(_isLoading ? "PROCESSING..." : "CONFIRM BOOKING"),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}