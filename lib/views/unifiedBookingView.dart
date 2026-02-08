import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Imports for DRY widgets
import '../widgets/app_colors.dart';
import '../widgets/background_blur.dart';
import '../widgets/glass_card.dart';

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
  DateTime _selectedDate = DateTime.now();
  String _selectedService = 'New Consultation';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final queue = Provider.of<QueueController>(context, listen: false);

    if (widget.isAssistant) {
      _selectedClinic = queue.selectedClinic;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: widget.isAssistant ? DateTime.now() : DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: _selectedClinic == null
          ? null
          : (d) => _selectedClinic!.weeklySchedule[DateFormat('EEEE').format(d)]?.isOpen ?? false,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary, // DRY: Use AppColors
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: AppColors.background,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedClinic == null) return;

    setState(() => _isLoading = true);
    try {
      await Provider.of<QueueController>(context, listen: false).bookAppointment(
        name: _nameController.text,
        phone: _phoneController.text,
        service: _selectedService,
        date: _selectedDate,
        clinicId: _selectedClinic!.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
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
            widget.isAssistant ? "WALK-IN APPOINTMENT" : "NEW APPOINTMENT",
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. REFACTOR: Use AppColors
          Container(color: AppColors.background),

          // 2. REFACTOR: Use BackgroundBlur widget
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
                  // 3. REFACTOR: Use GlassCard widget
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
                        _buildTextField(
                            _phoneController,
                            "Phone Number",
                            isPhone: true,
                            icon: Icons.phone_iphone_rounded
                        ),
                        const SizedBox(height: 16),
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

  // --- UI Component Helpers ---

  Widget _buildTextField(TextEditingController controller, String hint, {bool isPhone = false, required IconData icon}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      decoration: _inputStyle(hint, icon).copyWith(
        prefixText: isPhone ? "+91 " : null,
        prefixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      validator: (v) => v!.isEmpty ? "This field is required" : null,
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
      onChanged: (val) => setState(() => _selectedClinic = val),
      decoration: _inputStyle("Select preferred clinic", Icons.medical_services_outlined),
      validator: (v) => v == null ? "Please select a clinic" : null,
    );
  }

  Widget _buildServiceDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedService,
      dropdownColor: AppColors.surface,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
      items: ['New Consultation', 'Follow-up', 'Reports Show', 'Emergency']
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
            : const Text(
            "CONFIRM APPOINTMENT",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)
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
              color: Color(0xFF94A3B8), // Slate-400 equivalent
              letterSpacing: 1.8
          )
      ),
    );
  }
}