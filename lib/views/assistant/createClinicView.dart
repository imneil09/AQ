import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/queueController.dart';
import '../../models/clinicModel.dart';

// DRY Imports
import '../../widgets/app_colors.dart';
import '../../widgets/background_blur.dart';
import '../../widgets/glass_card.dart';

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

    _schedule = widget.clinic?.weeklySchedule != null
        ? Map.from(widget.clinic!.weeklySchedule)
        : {
      for (var day in _daysOrder)
        day: ClinicSchedule(
          isOpen: day != 'Sunday',
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

  void _save() {
    if (_nameCtrl.text.isEmpty) return;

    final clinicData = Clinic(
      id: widget.clinic?.id ?? '',
      doctorId: widget.clinic?.doctorId ?? '',
      name: _nameCtrl.text,
      address: _addrCtrl.text,
      weeklySchedule: _schedule,
    );

    final controller = Provider.of<QueueController>(context, listen: false);

    if (widget.clinic != null) {
      controller.updateClinic(clinicData);
    } else {
      controller.addClinic(clinicData);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.clinic != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isEditMode ? "Edit Clinic" : "Register Clinic",
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. REFACTOR: Use AppColors background
          Container(color: AppColors.background),

          // 2. REFACTOR: Use BackgroundBlur widget
          BackgroundBlur(
            color: AppColors.primary.withOpacity(0.25),
            size: 300,
            top: -50,
            right: -100,
          ),
          BackgroundBlur(
            color: AppColors.error.withOpacity(0.15),
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
                  // 3. REFACTOR: Use GlassCard instead of _buildGlassSection
                  GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        _buildLabel("CLINIC NAME"),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          cursorColor: AppColors.primary,
                          decoration: const InputDecoration(hintText: "Enter clinic name"),
                        ),
                        const SizedBox(height: 24),
                        _buildLabel("LOCATION"),
                        TextField(
                          controller: _addrCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          cursorColor: AppColors.primary,
                          decoration: const InputDecoration(hintText: "Enter clinic address"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  _buildLabel("WEEKLY SCHEDULE"),

                  // Iterate over _daysOrder
                  ..._daysOrder.map((day) => _buildScheduleTile(day)),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        isEditMode ? "UPDATE CLINIC" : "CREATE CLINIC",
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(String day) {
    final s = _schedule[day]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: s.isOpen ? AppColors.glassWhite : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: s.isOpen ? AppColors.primary.withOpacity(0.3) : AppColors.glassWhite,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            activeColor: AppColors.primary,
            title: Text(
              day,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: s.isOpen ? Colors.white : Colors.white38,
              ),
            ),
            value: s.isOpen,
            onChanged: (val) => setState(() => _schedule[day] = ClinicSchedule(
              isOpen: val,
              startTime: s.startTime,
              maxAppointmentsPerDay: s.maxAppointmentsPerDay,
              avgConsultationTimeMinutes: s.avgConsultationTimeMinutes,
            )),
          ),
          if (s.isOpen)
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
                        );
                        if (picked != null) {
                          setState(() => _schedule[day] = ClinicSchedule(
                            isOpen: true,
                            startTime: "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}",
                            maxAppointmentsPerDay: s.maxAppointmentsPerDay,
                            avgConsultationTimeMinutes: s.avgConsultationTimeMinutes,
                          ));
                        }
                      },
                      child: _buildTimeDisplay("START TIME", s.startTime),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: s.maxAppointmentsPerDay.toString(),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "MAX PATIENTS",
                        labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                      onChanged: (val) => _schedule[day] = ClinicSchedule(
                        isOpen: true,
                        startTime: s.startTime,
                        maxAppointmentsPerDay: int.tryParse(val) ?? 20,
                        avgConsultationTimeMinutes: s.avgConsultationTimeMinutes,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8), // Keeping specific slate color for labels
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}