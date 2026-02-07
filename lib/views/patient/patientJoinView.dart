import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/queueController.dart';
import '../../models/clinicModel.dart';

class PatientJoinView extends StatefulWidget {
  final bool isBooking;
  const PatientJoinView({super.key, required this.isBooking});

  @override
  State<PatientJoinView> createState() => _PatientJoinViewState();
}

class _PatientJoinViewState extends State<PatientJoinView> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Clinic? _selectedClinic;
  DateTime? _selectedDate;
  String _selectedService = 'New Consultation';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();

    if (!widget.isBooking) {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.isBooking ? "ADD APPOINTMENT" : "JOIN QUEUE",
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFF0F172A)),
          Positioned(
            top: -50,
            right: -100,
            child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.15), size: 300),
          ),
          Positioned(
            bottom: 50,
            left: -80,
            child: _BlurCircle(color: const Color(0xFF10B981).withOpacity(0.1), size: 250),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildFormContainer(queue),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContainer(QueueController queue) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("SELECT CLINIC"),
          DropdownButtonFormField<Clinic>(
            value: _selectedClinic,
            dropdownColor: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            items: queue.clinics.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: (val) {
              setState(() {
                _selectedClinic = val;
                if (widget.isBooking) _selectedDate = null;
              });
            },
            decoration: _inputDecoration("Select specialized clinic"),
            validator: (v) => v == null ? "Required" : null,
          ),
          const SizedBox(height: 24),

          if (_selectedClinic != null) ...[
            _buildLabel("CONTACT NUMBER"),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              decoration: _inputDecoration("00000 00000").copyWith(
                prefixText: "+91 ",
                prefixStyle: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
              ),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 24),

            _buildLabel("FULL NAME"),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              decoration: _inputDecoration("Enter patient name"),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 24),

            _buildLabel("PURPOSE OF VISIT"),
            DropdownButtonFormField<String>(
              value: _selectedService,
              dropdownColor: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              items: ['New Consultation', 'Follow-up', 'Reports Show', 'General Inquiry']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedService = v!),
              decoration: _inputDecoration("Select service type"),
            ),
            const SizedBox(height: 24),

            if (widget.isBooking) ...[
              _buildLabel("APPOINTMENT DATE"),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    selectableDayPredicate: (d) => _selectedClinic!.weeklySchedule[DateFormat('EEEE').format(d)]?.isOpen ?? false,
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFF6366F1),
                            onPrimary: Colors.white,
                            surface: Color(0xFF1E293B),
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: const Color(0xFF0F172A),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (d != null) setState(() => _selectedDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _selectedDate != null ? const Color(0xFF6366F1).withOpacity(0.5) : Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 18, color: _selectedDate != null ? const Color(0xFF6366F1) : Colors.white38),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate == null ? "Select Date" : DateFormat('EEEE, MMM dd').format(_selectedDate!),
                        style: TextStyle(fontWeight: FontWeight.bold, color: _selectedDate != null ? Colors.white : Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                    : const Text(
                  "CONFIRM APPOINTMENT",
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
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