import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../../models/clinicModel.dart';
import '../../widgets/appointment.dart';
import '../historyView.dart';
import 'adminAddView.dart';
import 'createClinicView.dart';
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

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        title: queue.clinics.isEmpty
            ? const Text("Doctor Dashboard")
            : DropdownButtonHideUnderline(
          child: DropdownButton<Clinic>(
            value: queue.selectedClinic,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F172A)),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 18),
            items: queue.clinics.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (Clinic? newClinic) {
              if (newClinic != null) {
                queue.selectClinic(newClinic);
              }
            },
          ),
        ),
        actions: [
          // Add Clinic Button
          IconButton(
            icon: const Icon(Icons.add_business_rounded, color: Colors.blue),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateClinicView())),
          ),
          // NEW: Professional History Button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 20),
            ),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryView(isAdmin: true))
            ),
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthView()));
            },
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
              indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
              ),
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: "WAITING (${queue.waitingList.length})"),
                Tab(text: "ACTIVE (${queue.activeQueue.length})"),
                Tab(text: "MISSED (${queue.skippedList.length})"),
              ],
            ),
          ),
        ),
      ),
      body: queue.clinics.isEmpty
          ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_business_outlined, size: 80, color: Colors.indigo.withOpacity(0.1)),
              const SizedBox(height: 16),
              const Text("Create a clinic to start managing appointments",
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          )
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildList(queue, queue.waitingList),
          _buildList(queue, queue.activeQueue),
          _buildList(queue, queue.skippedList),
        ],
      ),
      floatingActionButton: queue.clinics.isNotEmpty ? FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddView())),
        label: const Text("WALK-IN"),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF6366F1),
      ) : null,
    );
  }

  Widget _buildList(QueueController queue, List<Appointment> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text("List is empty", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final appt = list[index];
        return AppointmentCard(
          appointment: appt,
          isAdmin: true,
          onStatusNext: () {
            if (appt.status == AppointmentStatus.waiting) {
              queue.updateStatus(appt.id, AppointmentStatus.inProgress);
            } else if (appt.status == AppointmentStatus.inProgress) {
              queue.updateStatus(appt.id, AppointmentStatus.completed);
            }
          },
          onSkip: () => queue.updateStatus(appt.id, AppointmentStatus.missed),
          onCancel: () => queue.updateStatus(appt.id, AppointmentStatus.cancelled),
        );
      },
    );
  }
}