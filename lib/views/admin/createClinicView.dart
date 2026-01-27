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
      day: ClinicSchedule(isOpen: day != 'Sunday', startTime: "09:00", avgConsultationTimeMinutes: 15)
  };

  void _save() {
    if (_nameCtrl.text.isEmpty) return;

    final newClinic = Clinic(
      id: '',
      doctorId: '',
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
        title: const Text("Register Clinic", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Base
          Container(color: const Color(0xFF0F172A)),

          // Blurred Accents
          Positioned(
            top: -50,
            right: -100,
            child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.2), size: 300),
          ),
          Positioned(
            bottom: 50,
            left: -80,
            child: _BlurCircle(color: const Color(0xFFF43F5E).withOpacity(0.1), size: 250),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Container
                  _buildGlassSection(
                    title: "BASIC INFO",
                    child: Column(
                      children: [
                        _buildLabel("CLINIC NAME"),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(hintText: "Enter clinic name"),
                        ),
                        const SizedBox(height: 24),
                        _buildLabel("LOCATION"),
                        TextField(
                          controller: _addrCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(hintText: "Enter address"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Schedule Section
                  _buildLabel("WEEKLY SCHEDULE"),
                  const SizedBox(height: 12),
                  ..._schedule.keys.map((day) => _buildScheduleTile(day)),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text("CREATE CLINIC"),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSection({required String title, required Widget child}) {
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

  Widget _buildScheduleTile(String day) {
    final s = _schedule[day]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: s.isOpen ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: s.isOpen ? const Color(0xFF6366F1).withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: SwitchListTile(
        title: Text(day, style: TextStyle(
          fontWeight: FontWeight.bold,
          color: s.isOpen ? Colors.white : Colors.white38,
        )),
        subtitle: Text(
          s.isOpen ? "Available from ${s.startTime}" : "Closed",
          style: TextStyle(color: s.isOpen ? const Color(0xFF6366F1) : Colors.white24, fontSize: 12),
        ),
        value: s.isOpen,
        activeColor: const Color(0xFF6366F1),
        onChanged: (val) {
          setState(() {
            _schedule[day] = ClinicSchedule(
              isOpen: val,
              startTime: s.startTime,
              avgConsultationTimeMinutes: s.avgConsultationTimeMinutes,
            );
          });
        },
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
          letterSpacing: 1.5,
          color: Color(0xFF94A3B8),
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
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
    );
  }
}