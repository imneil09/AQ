import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/queueController.dart';
import '../../models/clinicModel.dart';

class PatientJoinView extends StatefulWidget { // UPDATED: Class Name
  final bool isBooking;
  const PatientJoinView({super.key, required this.isBooking});

  @override
  State<PatientJoinView> createState() => _PatientJoinViewState();
}

class _PatientJoinViewState extends State<PatientJoinView> { // UPDATED: State Name
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
    // If joining "Live", the date is automatically Today
    if (!widget.isBooking) {
      _selectedDate = DateTime.now();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedClinic == null || _selectedDate == null) return;
    setState(() => _isLoading = true);
    try {
      // CONTROLLER HOOK: Calls the central bookAppointment method
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.isBooking ? "Book Visit" : "Join Queue",
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Base
          Container(color: const Color(0xFF0F172A)),

          // Blurred Accents for Depth
          Positioned(
            top: -50,
            right: -100,
            child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.2), size: 300),
          ),
          Positioned(
            bottom: 50,
            left: -80,
            child: _BlurCircle(color: const Color(0xFF10B981).withOpacity(0.1), size: 250),
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
                            "Appointment Info",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isBooking ? "Schedule your visit for a future date." : "Secure your spot in today's live queue.",
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          ),
                          const SizedBox(height: 32),

                          // Clinic Dropdown
                          _buildLabel("SELECT CLINIC"),
                          DropdownButtonFormField<Clinic>(
                            value: _selectedClinic,
                            dropdownColor: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            items: queue.clinics.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(color: Colors.white)))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClinic = val;
                                // Reset date if switching clinics (as availability might differ, though simplified here)
                                if (widget.isBooking) _selectedDate = null;
                              });
                            },
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                            validator: (v) => v == null ? "Please select a clinic" : null,
                          ),
                          const SizedBox(height: 24),

                          // Date Picker for Booking (Only shown if booking future)
                          if (widget.isBooking && _selectedClinic != null) ...[
                            _buildLabel("APPOINTMENT DATE"),
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
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _selectedDate != null ? const Color(0xFF6366F1).withOpacity(0.5) : Colors.white.withOpacity(0.08)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded, size: 18, color: _selectedDate != null ? const Color(0xFF6366F1) : Colors.white38),
                                    const SizedBox(width: 12),
                                    Text(
                                      _selectedDate == null ? "Choose Date" : DateFormat('EEEE, MMM dd').format(_selectedDate!),
                                      style: TextStyle(fontWeight: FontWeight.bold, color: _selectedDate != null ? Colors.white : Colors.white38),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          if (_selectedClinic != null) ...[
                            // Name Input
                            _buildLabel("FULL NAME"),
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(hintText: "Enter your name"),
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 24),

                            // Phone Input
                            _buildLabel("CONTACT NUMBER"),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                hintText: "00000 00000",
                                prefixText: "+91 ",
                                prefixStyle: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                              ),
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 24),

                            // Service Dropdown
                            _buildLabel("PURPOSE OF VISIT"),
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

                            // Confirm Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                    : const Text("CONFIRM APPOINTMENT"),
                              ),
                            )
                          ]
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