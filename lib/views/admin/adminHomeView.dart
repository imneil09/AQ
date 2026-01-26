import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../../models/clinicModel.dart';
import '../../widgets/appointment.dart';
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthView()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: queue.clinics.isEmpty
            ? const Text("Doctor Dashboard", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
            : DropdownButtonHideUnderline(
          child: DropdownButton<Clinic>(
            value: queue.selectedClinic,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18),
            items: queue.clinics.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (Clinic? newClinic) {
              if (newClinic != null) {
                queue.selectClinic(newClinic);
              }
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_rounded, color: Colors.blue),
            tooltip: "Create New Clinic",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateClinicView())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
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
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: "WAITING (${queue.waitingList.length})"),
                Tab(text: "ACTIVE (${queue.activeQueue.length})"),
                Tab(text: "HISTORY (${queue.skippedList.length})"),
              ],
            ),
          ),
        ),
      ),
      body: queue.clinics.isEmpty
          ? _buildNoClinicState()
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
        icon: const Icon(Icons.add_rounded),
        backgroundColor: const Color(0xFF2563EB),
      ) : null,
    );
  }

  Widget _buildNoClinicState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No Clinics Found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Create your first clinic to start.", style: TextStyle(color: Colors.grey)),
        ],
      ),
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
      padding: const EdgeInsets.only(top: 16, bottom: 100),
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