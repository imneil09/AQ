import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/queueController.dart';
import '../../models/clinicModel.dart';

class CreateClinicView extends StatefulWidget {
  const CreateClinicView({super.key});
  @override
  State<CreateClinicView> createState() => _CreateClinicViewState();
}

class _CreateClinicViewState extends State<CreateClinicView> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();

  final Map<String, ClinicSchedule> _schedule = {
    for (var day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'])
      day: ClinicSchedule(
        isOpen: day != 'Sunday',
        startTime: "09:00",
        maxAppointmentsPerDay: 20,
        avgConsultationTimeMinutes: 10,
      )
  };

  void _save() {
    if (_nameCtrl.text.isEmpty) return;

    final newClinic = Clinic(
      id: '',
      doctorId: '', // Controller will fill this with the current user's ID
      name: _nameCtrl.text,
      address: _addrCtrl.text,
      weeklySchedule: _schedule,
    );

    Provider.of<QueueController>(context, listen: false).addClinic(newClinic);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Register Clinic", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFF0F172A)),

          // Blurred Accents for Depth
          Positioned(
            top: -50,
            right: -100,
            child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.25), size: 300),
          ),
          Positioned(
            bottom: 50,
            left: -80,
            child: _BlurCircle(color: const Color(0xFFF43F5E).withOpacity(0.15), size: 250),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlassSection(
                    child: Column(
                      children: [
                        _buildLabel("CLINIC NAME"),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          cursorColor: const Color(0xFF6366F1),
                          decoration: const InputDecoration(
                            hintText: "Enter clinic name",
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildLabel("LOCATION"),
                        TextField(
                          controller: _addrCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          cursorColor: const Color(0xFF6366F1),
                          decoration: const InputDecoration(
                            hintText: "Enter clinic address",
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildLabel("WEEKLY SCHEDULE"),
                  ..._schedule.keys.map((day) => _buildScheduleTile(day)),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text("CREATE CLINIC", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
        color: s.isOpen ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: s.isOpen ? const Color(0xFF6366F1).withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            activeColor: const Color(0xFF6366F1),
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
              avgConsultationTimeMinutes: s.avgConsultationTimeMinutes, // Preserve this
            )),
          ),
          if (s.isOpen) Padding(
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
                    initialValue: s.avgConsultationTimeMinutes.toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "AVG TIME (MIN)",
                      labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
                    ),
                    onChanged: (val) => _schedule[day] = ClinicSchedule(
                      isOpen: true,
                      startTime: s.startTime,
                      maxAppointmentsPerDay: s.maxAppointmentsPerDay,
                      avgConsultationTimeMinutes: int.tryParse(val) ?? 10,
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
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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

  Widget _buildGlassSection({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
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
          color: Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}