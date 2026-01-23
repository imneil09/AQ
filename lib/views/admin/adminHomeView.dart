import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import 'adminAddView.dart';
import '../authView.dart'; // Required for Logout navigation

class AdminHomeView extends StatefulWidget {
  const AdminHomeView({super.key});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // --- LOGOUT FUNCTION ---
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthView()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dr. Tudu Dashboard"),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // LOGOUT BUTTON
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
            tooltip: "Logout",
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0055AA),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0055AA),
          tabs: [
            Tab(text: "Waiting (${queue.waitingQueue.length})"),
            Tab(text: "Active (${queue.activeQueue.length})"),
            Tab(text: "Skipped (${queue.skippedList.length})"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Waiting Queue
          _buildAppointmentList(queue.waitingQueue, isWaiting: true),

          // Tab 2: Active (In Cabin)
          _buildAppointmentList(queue.activeQueue, isActive: true),

          // Tab 3: Skipped (Recall)
          _buildAppointmentList(queue.skippedList, isSkipped: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddView())),
        label: const Text("Add Patient"),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF0055AA),
      ),
    );
  }

  Widget _buildAppointmentList(List<Appointment> list, {bool isWaiting = false, bool isSkipped = false, bool isActive = false}) {
    if (list.isEmpty) {
      return const Center(child: Text("No patients in this list", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final appt = list[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSkipped ? Colors.orange.withOpacity(0.1) : const Color(0xFF0055AA).withOpacity(0.1),
              child: Text(
                "${index + 1}",
                style: TextStyle(color: isSkipped ? Colors.orange : const Color(0xFF0055AA), fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(appt.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${appt.serviceType} • ${appt.phoneNumber}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isWaiting && index == 0) // Only show 'Call' for first in line
                  IconButton(
                    icon: const Icon(Icons.notifications_active, color: Colors.green),
                    onPressed: () => Provider.of<QueueController>(context, listen: false).updateStatus(appt.id, AppointmentStatus.inProgress),
                  ),
                if (isWaiting || isActive)
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.orange),
                    onPressed: () => Provider.of<QueueController>(context, listen: false).skipAppointment(appt.id),
                  ),
                if (isWaiting || isActive) // Complete Button
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.blue),
                    onPressed: () => Provider.of<QueueController>(context, listen: false).updateStatus(appt.id, AppointmentStatus.completed),
                  ),
                if (isSkipped)
                  ElevatedButton(
                    onPressed: () => Provider.of<QueueController>(context, listen: false).recallAppointment(appt.id),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: const Text("Recall"),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}