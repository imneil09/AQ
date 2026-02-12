import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Imports for DRY widgets
import '../widgets/appColors.dart';
import '../widgets/backgroundBlur.dart';
import '../widgets/glassCard.dart';

import '../../controllers/queueController.dart';
import '../../models/clinicModel.dart';

class UnifiedBookingView extends StatefulWidget {
  final bool isAssistant;
  const UnifiedBookingView({super.key, required this.isAssistant});

  @override
  State<UnifiedBookingView> createState() => _UnifiedBookingViewState();
}

class _UnifiedBookingViewState extends State<UnifiedBookingView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  Clinic? _selectedClinic;
  late DateTime _selectedDate;
  String _selectedService = 'New Consultation';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final queue = Provider.of<QueueController>(context, listen: false);

    // Default to current time for everyone
    _selectedDate = DateTime.now();

    if (widget.isAssistant) {
      _selectedClinic = queue.selectedClinic;
    }
    // If a clinic is already selected (Assistant) or auto-selected,
    // adjust the date to the first valid opening immediately.
    if (_selectedClinic != null) {
      _selectedDate = _getInitialValidDate(_selectedClinic!, DateTime.now());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Helper: Finds the first day the clinic is actually open starting from 'startDate'
  DateTime _getInitialValidDate(Clinic clinic, DateTime startDate) {
    DateTime date = startDate;
    // Look ahead up to 30 days to find the next open slot
    for (int i = 0; i < 30; i++) {
      String dayName = DateFormat('EEEE').format(date);
      bool isOpen = clinic.weeklySchedule[dayName]?.isOpen ?? false;

      // Check for emergency closure
      bool isEmergencyClosed = clinic.emergencyClosedDates.any((d) =>
      d.year == date.year && d.month == date.month && d.day == date.day);

      // If it's open and not emergency closed, this is our date!
      if (isOpen && !isEmergencyClosed) {
        return date;
      }
      // Otherwise, check the next day
      date = date.add(const Duration(days: 1));
    }
    return startDate; // Fallback
  }

  Future<void> _pickDate() async {
    if (!widget.isAssistant && _selectedClinic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a clinic first"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final DateTime now = DateTime.now();

    // UPDATED: Patients can now book starting from Today (if open/not full)
    final DateTime firstDate = now;

    // Ensure our picker doesn't start in the past
    DateTime initialDate = _selectedDate;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    // Smartly jump to the first open day to avoid crashing the picker if Today is closed
    if (_selectedClinic != null) {
      // We start checking availability from 'initialDate' (which is usually Today)
      initialDate = _getInitialValidDate(_selectedClinic!, initialDate);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: (DateTime d) {
        if (_selectedClinic == null) return true;

        // 1. Emergency Closure Check
        bool isEmergencyClosed = _selectedClinic!.emergencyClosedDates.any((closedDate) =>
        closedDate.year == d.year &&
            closedDate.month == d.month &&
            closedDate.day == d.day);

        if (isEmergencyClosed) return false;

        // 2. Weekly Schedule Check
        String dayName = DateFormat('EEEE').format(d);
        return _selectedClinic!.weeklySchedule[dayName]?.isOpen ?? false;
      },
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: AppColors.background,
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedClinic == null) return;

    setState(() => _isLoading = true);
    final queue = Provider.of<QueueController>(context, listen: false);

    try {
      if (widget.isAssistant) {
        // --- BACKEND: ASSISTANT LOGIC (SHADOW ACCOUNTS) ---
        // Assistant privilege is handled in QueueController:
        // They bypass the "Max Patients" check automatically.

        final phone = "+91${_phoneController.text.trim()}";
        final name = _nameController.text.trim();

        // 1. Check if user already exists
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: phone)
            .limit(1)
            .get();

        String targetPatientId;
        if (usersSnapshot.docs.isNotEmpty) {
          targetPatientId = usersSnapshot.docs.first.id;
        } else {
          final newDocRef = FirebaseFirestore.instance.collection('users').doc();
          targetPatientId = newDocRef.id;

          await newDocRef.set({
            'uid': targetPatientId,
            'phoneNumber': phone,
            'name': name,
            'role': 'patient',
            'isShadowAccount': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await queue.bookAppointment(
          name: name,
          phone: phone,
          service: _selectedService,
          date: _selectedDate,
          clinicId: _selectedClinic!.id,
          patientId: targetPatientId,
        );

      } else {
        // --- BACKEND: PATIENT LOGIC ---
        // Patients are subject to the "Max Patients" check in QueueController.

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) throw Exception("User not logged in");

        await queue.bookAppointment(
          name: _nameController.text.trim(),
          phone: currentUser.phoneNumber ?? "",
          service: _selectedService,
          date: _selectedDate,
          clinicId: _selectedClinic!.id,
          patientId: currentUser.uid,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(widget.isAssistant ? "Appointment Assigned!" : "Appointment Requested!"),
                backgroundColor: AppColors.success
            )
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // Logic: If QueueController throws "Fully Booked", it is caught here
      // and displayed to the user as a red error message.
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error)
      );
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
            widget.isAssistant ? "WALK-IN / NEW APPOINTMENT" : "NEW APPOINTMENT",
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(color: AppColors.background),
          BackgroundBlur(
            color: AppColors.primary.withOpacity(0.12),
            size: 320,
            top: -60,
            right: -100,
          ),
          BackgroundBlur(
            color: AppColors.error.withOpacity(0.12),
            size: 280,
            bottom: 40,
            left: -80,
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: GlassCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.isAssistant) ...[
                          _buildSectionHeader("CLINIC SELECTION"),
                          _buildClinicDropdown(queue),
                          const SizedBox(height: 24),
                        ],

                        _buildSectionHeader("PATIENT DETAILS"),
                        if (widget.isAssistant) ...[
                          _buildTextField(
                              _phoneController,
                              "Phone Number",
                              isPhone: true,
                              icon: Icons.phone_iphone_rounded
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildTextField(
                            _nameController,
                            "Patient Full Name",
                            icon: Icons.person_outline_rounded
                        ),
                        const SizedBox(height: 24),

                        _buildSectionHeader("VISIT INFORMATION"),
                        _buildServiceDropdown(),
                        const SizedBox(height: 16),

                        _buildDatePickerTile(),

                        const SizedBox(height: 40),
                        _buildSubmitButton(),
                      ],
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

  Widget _buildTextField(TextEditingController controller, String hint, {bool isPhone = false, required IconData icon}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      decoration: _inputStyle(hint, icon).copyWith(
        prefixText: isPhone ? "+91 " : null,
        prefixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "This field is required";
        if (isPhone && v.length != 10) return "Enter valid 10-digit number";
        return null;
      },
    );
  }

  Widget _buildClinicDropdown(QueueController queue) {
    return DropdownButtonFormField<Clinic>(
      value: _selectedClinic,
      dropdownColor: AppColors.surface,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
      items: queue.clinics.map((c) => DropdownMenuItem(
          value: c,
          child: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 15))
      )).toList(),
      onChanged: (val) {
        setState(() {
          _selectedClinic = val;
          // When a patient changes the clinic, we immediately recalculate the date.
          // If "Today" is open for this new clinic, select Today.
          // If closed, select the next open day.
          if (val != null) {
            _selectedDate = _getInitialValidDate(val, DateTime.now());
          }
        });
      },
      decoration: _inputStyle("Select preferred clinic", Icons.medical_services_outlined),
      validator: (v) => v == null ? "Please select a clinic" : null,
    );
  }

  Widget _buildServiceDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedService,
      dropdownColor: AppColors.surface,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
      items: ['New Consultation', 'Follow-up', 'Reports Show', 'Post-OP', 'Emergency']
          .map((s) => DropdownMenuItem(
          value: s,
          child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 15))
      )).toList(),
      onChanged: (v) => setState(() => _selectedService = v!),
      decoration: _inputStyle("Purpose of visit", Icons.assignment_outlined),
    );
  }

  Widget _buildDatePickerTile() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.glassWhite.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Date", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(
                  DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit_calendar_outlined, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(
            widget.isAssistant ? "CONFIRM APPOINTMENT" : "CONFIRM APPOINTMENT",
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.glassWhite.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.glassBorder)
      ),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.glassBorder)
      ),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
          text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.8
          )
      ),
    );
  }
}