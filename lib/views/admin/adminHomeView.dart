import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import 'adminAddView.dart';
import '../authView.dart';

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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthView()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        title: const Text("Dr. Tudu Dashboard", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            onPressed: _logout,
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: "WAITING (${queue.waitingQueue.length})"),
                Tab(text: "ACTIVE (${queue.activeQueue.length})"),
                Tab(text: "SKIPPED (${queue.skippedList.length})"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(queue.waitingQueue, isWaiting: true),
          _buildList(queue.activeQueue, isActive: true),
          _buildList(queue.skippedList, isSkipped: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddView())),
        label: const Text("ADD PATIENT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildList(List<Appointment> list, {bool isWaiting = false, bool isSkipped = false, bool isActive = false}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No patients in this list", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final appt = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  width: 40, height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSkipped ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(fontWeight: FontWeight.bold, color: isSkipped ? const Color(0xFFEF4444) : const Color(0xFF2563EB)),
                  ),
                ),
                title: Text(appt.customerName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                subtitle: Text("${appt.serviceType} • ${appt.phoneNumber}", style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ),

              // Action Bar
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    if (isWaiting && index == 0) // Call Button
                      Expanded(
                          child: _actionBtn("CALL IN", Icons.notifications_active_rounded, const Color(0xFF10B981),
                                  () => Provider.of<QueueController>(context, listen: false).updateStatus(appt.id, AppointmentStatus.inProgress))
                      ),

                    if (isSkipped) // Recall Button
                      Expanded(
                          child: _actionBtn("RECALL", Icons.replay_rounded, const Color(0xFF2563EB),
                                  () => Provider.of<QueueController>(context, listen: false).recallAppointment(appt.id))
                      ),

                    if (isWaiting || isActive) ...[
                      // Skip Button
                      Expanded(
                          child: _actionBtn("SKIP", Icons.skip_next_rounded, const Color(0xFFF59E0B),
                                  () => Provider.of<QueueController>(context, listen: false).skipAppointment(appt.id))
                      ),
                      // Complete Button
                      Expanded(
                          child: _actionBtn("DONE", Icons.check_circle_rounded, const Color(0xFF2563EB),
                                  () => Provider.of<QueueController>(context, listen: false).updateStatus(appt.id, AppointmentStatus.completed),
                              isPrimary: true)
                      ),
                    ]
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap, {bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: isPrimary ? color : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isPrimary ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
                label,
                style: TextStyle(
                    color: isPrimary ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5
                )
            ),
          ],
        ),
      ),
    );
  }
}