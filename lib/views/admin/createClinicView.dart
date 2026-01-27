// lib/views/admin/createClinicView.dart

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
      doctorId: '', // Set automatically in QueueController.addClinic
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
          Container(color: const Color(0xFF0F172A)),
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
                        TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: "Enter clinic name")),
                        const SizedBox(height: 24),
                        _buildLabel("LOCATION"),
                        TextField(controller: _addrCtrl, decoration: const InputDecoration(hintText: "Enter address")),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel("WEEKLY SCHEDULE"),
                  ..._schedule.keys.map((day) => _buildScheduleTile(day)),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _save, child: const Text("CREATE CLINIC")),
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
        border: Border.all(color: s.isOpen ? const Color(0xFF6366F1).withOpacity(0.3) : Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(day, style: TextStyle(fontWeight: FontWeight.bold, color: s.isOpen ? Colors.white : Colors.white38)),
            value: s.isOpen,
            onChanged: (val) => setState(() => _schedule[day] = ClinicSchedule(isOpen: val, startTime: s.startTime, maxAppointmentsPerDay: s.maxAppointmentsPerDay)),
          ),
          if (s.isOpen) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      TimeOfDay? picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                      if (picked != null) {
                        setState(() => _schedule[day] = ClinicSchedule(isOpen: true, startTime: "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}", maxAppointmentsPerDay: s.maxAppointmentsPerDay));
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
                    decoration: const InputDecoration(labelText: "MAX APPT"),
                    onChanged: (val) => _schedule[day] = ClinicSchedule(isOpen: true, startTime: s.startTime, maxAppointmentsPerDay: int.tryParse(val) ?? 20),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGlassSection({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: child,
    );
  }

  Widget _buildLabel(String text) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8))));
  }
}