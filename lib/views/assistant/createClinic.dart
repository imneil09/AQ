import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Models
import '../../models/clinicModel.dart';

// DRY Widgets (Make sure these exist in your project as per previous steps)
import '../../widgets/appColors.dart';
import '../../widgets/backgroundBlur.dart';
import '../../widgets/glassCard.dart';

class CreateClinicView extends StatefulWidget {
  final Clinic? clinic;
  const CreateClinicView({super.key, this.clinic});

  @override
  State<CreateClinicView> createState() => _CreateClinicViewState();
}

class _CreateClinicViewState extends State<CreateClinicView> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addrCtrl;
  late Map<String, ClinicSchedule> _schedule;

  bool _isLoading = false; // Added for loading state

  // Fixed order to ensure Sunday is always last in the UI
  final List<String> _daysOrder = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.clinic?.name ?? "");
    _addrCtrl = TextEditingController(text: widget.clinic?.address ?? "");

    // Initialize schedule: Clone existing or create default
    _schedule = widget.clinic?.weeklySchedule != null
        ? Map.from(widget.clinic!.weeklySchedule)
        : {
      for (var day in _daysOrder)
        day: ClinicSchedule(
          isOpen: day != 'Sunday', // Default closed on Sunday
          startTime: "09:00",
          maxAppointmentsPerDay: 20,
          avgConsultationTimeMinutes: 10,
        )
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  // --- BACKEND LOGIC: SAVE TO FIRESTORE ---
  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _addrCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields"), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Doctor not logged in");

      // Construct the Clinic Object
      final clinicData = Clinic(
        id: widget.clinic?.id ?? '', // ID ignored during 'add', used during 'update'
        doctorId: user.uid,
        name: _nameCtrl.text,
        address: _addrCtrl.text,
        weeklySchedule: _schedule,
        emergencyClosedDates: widget.clinic?.emergencyClosedDates ?? [],
      );

      if (widget.clinic != null) {
        // UPDATE Existing Clinic
        await FirebaseFirestore.instance
            .collection('clinics')
            .doc(widget.clinic!.id)
            .update(clinicData.toMap());
      } else {
        // CREATE New Clinic
        await FirebaseFirestore.instance
            .collection('clinics')
            .add(clinicData.toMap());
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Clinic saved successfully!"), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.clinic != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isEditMode ? "Edit Clinic" : "Register Clinic",
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. App Background
          Container(color: AppColors.background),

          // 2. Background Blurs for Atmosphere
          BackgroundBlur(
            color: AppColors.primary.withOpacity(0.2),
            size: 300,
            top: -50,
            right: -100,
          ),
          BackgroundBlur(
            color: AppColors.error.withOpacity(0.1),
            size: 250,
            bottom: 50,
            left: -80,
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3. Basic Info Section (GlassCard)
                  GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("CLINIC NAME"),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          cursorColor: AppColors.primary,
                          decoration: _inputDecoration("Ex: City Ortho Care"),
                        ),
                        const SizedBox(height: 24),
                        _buildLabel("LOCATION / ADDRESS"),
                        TextField(
                          controller: _addrCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          cursorColor: AppColors.primary,
                          decoration: _inputDecoration("Ex: 123, Main Street, Agartala"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  _buildLabel("WEEKLY SCHEDULE"),

                  // 4. Schedule List
                  ..._daysOrder.map((day) => _buildScheduleTile(day)),

                  const SizedBox(height: 40),

                  // 5. Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                        isEditMode ? "UPDATE CLINIC" : "CREATE CLINIC",
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      isDense: true,
    );
  }

  Widget _buildScheduleTile(String day) {
    final s = _schedule[day]!;
    final bool isOpen = s.isOpen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.glassWhite : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOpen ? AppColors.primary.withOpacity(0.3) : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          // Toggle Switch
          SwitchListTile(
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white10,
            title: Text(
              day,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOpen ? Colors.white : Colors.white38,
              ),
            ),
            value: isOpen,
            onChanged: (val) => setState(() => _schedule[day] = ClinicSchedule(
              isOpen: val,
              startTime: s.startTime,
              maxAppointmentsPerDay: s.maxAppointmentsPerDay,
              avgConsultationTimeMinutes: s.avgConsultationTimeMinutes,
            )),
          ),

          // Time & Capacity Inputs (Only visible if Open)
          if (isOpen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 9, minute: 0),
                          builder: (context, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          // Format to HH:mm string
                          final formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                          setState(() => _schedule[day] = ClinicSchedule(
                            isOpen: true,
                            startTime: formatted,
                            maxAppointmentsPerDay: s.maxAppointmentsPerDay,
                            avgConsultationTimeMinutes: s.avgConsultationTimeMinutes,
                          ));
                        }
                      },
                      child: _buildTimeDisplay("OPENS AT", s.startTime),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: TextFormField(
                        initialValue: s.maxAppointmentsPerDay.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          labelText: "CAPACITY",
                          labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          // Update map safely
                          _schedule[day] = ClinicSchedule(
                            isOpen: true,
                            startTime: s.startTime,
                            maxAppointmentsPerDay: int.tryParse(val) ?? 20,
                            avgConsultationTimeMinutes: s.avgConsultationTimeMinutes,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildTimeDisplay(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
            ],
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}