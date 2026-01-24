import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/queueController.dart';

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
  String _selectedService = 'New Consultation';
  final List<String> _services = ['New Consultation', 'Follow-up', 'Fracture Check', 'Post-Op Care'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.isBooking && _selectedDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a date"))); return; }
    setState(() => _isLoading = true);
    try {
      final ctrl = Provider.of<QueueController>(context, listen: false);
      if (widget.isBooking) await ctrl.bookFutureAppointment(_nameController.text, _phoneController.text, _selectedService, _selectedDate!);
      else await ctrl.joinQueueNow(_nameController.text, _phoneController.text, _selectedService);
      if(mounted) Navigator.pop(context);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if(mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isBooking ? "Schedule Visit" : "Join Queue")),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Patient Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline_rounded)),
                  validator: (v) => v!.isEmpty ? "Name is required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) => v!.isEmpty ? "Phone is required" : null,
                ),
                const SizedBox(height: 32),
                const Text("Visit Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 20),
                DropdownButtonFormField(
                  value: _selectedService,
                  decoration: const InputDecoration(labelText: "Purpose of Visit", prefixIcon: Icon(Icons.medical_services_outlined)),
                  items: _services.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedService = v!),
                ),
                const SizedBox(height: 16),
                if(widget.isBooking)
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(context: context, firstDate: DateTime.now(), initialDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                      if(d!=null) setState(()=>_selectedDate=d);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_rounded, color: Color(0xFF64748B)),
                        const SizedBox(width: 16),
                        Text(_selectedDate == null ? "Select Date" : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
              ])),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("CONFIRM APPOINTMENT"),
              ),
            ),
          )
        ]),
      ),
    );
  }
}