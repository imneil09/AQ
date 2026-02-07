import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../authView.dart';
import 'prescription_view.dart'; // We will create this next

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  // We can use a local search controller if we want to search actively
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);
    // Logic: If there is an active patient in the queue, show them.
    // Otherwise, show the Search/Idle screen.
    final activePatient = queue.activeQueue.isNotEmpty ? queue.activeQueue.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: _isSearching
            ? TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Search patient by name or phone...",
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: (val) => queue.updateHistorySearch(val),
        )
            : const Text("Dr. Shankar Deb Roy", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          // --- Search Toggle ---
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                  queue.updateHistorySearch(""); // Reset search
                }
              });
            },
          ),
          const SizedBox(width: 10),

          // --- Break Button ---
          _buildBreakButton(queue),

          const SizedBox(width: 10),
          // --- Logout ---
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white54),
            tooltip: "Logout",
            onPressed: () => _handleLogout(context, queue),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: queue.isOnBreak
          ? _buildBreakScreen(queue)
          : _buildMainContent(queue, activePatient),
    );
  }

  Widget _buildBreakButton(QueueController queue) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: queue.isOnBreak ? const Color(0xFFF59E0B).withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: queue.isOnBreak ? Border.all(color: const Color(0xFFF59E0B)) : Border.all(color: Colors.white24),
      ),
      child: TextButton.icon(
        icon: Icon(Icons.coffee, size: 18, color: queue.isOnBreak ? const Color(0xFFF59E0B) : Colors.white70),
        label: Text(queue.isOnBreak ? "RESUME" : "BREAK",
            style: TextStyle(color: queue.isOnBreak ? const Color(0xFFF59E0B) : Colors.white70, fontSize: 12)),
        onPressed: () => queue.toggleBreak(),
      ),
    );
  }

  Widget _buildBreakScreen(QueueController queue) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.coffee_outlined, size: 80, color: Color(0xFFF59E0B)),
          const SizedBox(height: 20),
          const Text("Session Paused", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          TextButton(
              onPressed: () => queue.toggleBreak(),
              child: const Text("Resume Consultation", style: TextStyle(color: Color(0xFF10B981), fontSize: 18))
          )
        ],
      ),
    );
  }

  Widget _buildMainContent(QueueController queue, Appointment? activePatient) {
    // 1. If searching, show search results
    if (_isSearching && _searchCtrl.text.isNotEmpty) {
      return StreamBuilder<List<Appointment>>(
        stream: queue.assistantFullHistory, // Assuming this searches all records
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final results = snapshot.data!;
          if (results.isEmpty) return const Center(child: Text("No patients found.", style: TextStyle(color: Colors.white54)));

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: results.length,
            itemBuilder: (ctx, i) {
              final appt = results[i];
              return Card(
                color: Colors.white.withOpacity(0.05),
                child: ListTile(
                  title: Text(appt.customerName, style: const TextStyle(color: Colors.white)),
                  subtitle: Text("${appt.serviceType} • ${appt.phoneNumber}", style: const TextStyle(color: Colors.white54)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                  onTap: () {
                    // Logic to view old prescription or load this patient
                    // For now, we'll just show a snackbar or implement a "View Only" mode later
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("History viewing not fully connected in demo.")));
                  },
                ),
              );
            },
          );
        },
      );
    }

    // 2. If Active Patient exists, show the FULL Prescription View
    if (activePatient != null) {
      return PrescriptionView(
          patient: activePatient,
          onFinish: () => queue.updateStatus(activePatient.id, AppointmentStatus.completed)
      );
    }

    // 3. Idle State
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          Text("No Active Patient", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 20)),
          const SizedBox(height: 10),
          const Text("Ask assistant to send the next patient in.", style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, QueueController queue) async {
    await queue.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthView()), (route) => false
      );
    }
  }
}