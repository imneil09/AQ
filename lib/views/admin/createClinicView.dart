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
      appBar: AppBar(title: const Text("Add New Clinic")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Clinic Name")),
            const SizedBox(height: 10),
            TextField(controller: _addrCtrl, decoration: const InputDecoration(labelText: "Location/Address")),
            const SizedBox(height: 20),
            const Text("Weekly Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ..._schedule.keys.map((day) {
              final s = _schedule[day]!;
              return SwitchListTile(
                title: Text(day),
                subtitle: Text(s.isOpen ? "Opens: ${s.startTime}" : "Closed"),
                value: s.isOpen,
                onChanged: (val) {
                  setState(() {
                    _schedule[day] = ClinicSchedule(
                        isOpen: val,
                        startTime: s.startTime,
                        avgConsultationTimeMinutes: s.avgConsultationTimeMinutes
                    );
                  });
                },
              );
            }),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text("CREATE CLINIC"))
          ],
        ),
      ),
    );
  }
}