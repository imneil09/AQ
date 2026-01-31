import 'dart:ui';
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

class _AdminHomeViewState extends State<AdminHomeView>
    with SingleTickerProviderStateMixin {
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
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(queue),
      body: Stack(
        children: [
          // Background Base
          Container(color: const Color(0xFF0F172A)),

          // Blurred Accents
          Positioned(
            top: -50,
            right: -50,
            child: _BlurCircle(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              size: 300,
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _BlurCircle(
              color: const Color(0xFFF43F5E).withOpacity(0.1),
              size: 250,
            ),
          ),

          SafeArea(
            child: queue.clinics.isEmpty
                ? _buildEmptyState()
                : Column(
              children: [
                _buildMetricsHeader(queue),

                // NEW: Live Search Bar (Matches Design)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    onChanged: (val) => queue.updateLiveSearch(val),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    cursorColor: const Color(0xFF6366F1),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Search active queue...",
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
                      icon: Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                    ),
                  ),
                ),

                _buildCustomTabBar(),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(queue, queue.waitingList),
                      _buildList(queue, queue.activeQueue),
                      _buildList(queue, queue.skippedList), // Updated to skippedList
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: queue.clinics.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAddView()),
        ),
        label: const Text(
          "WALK-IN",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: const Color(0xFF6366F1),
      )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(QueueController queue) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: queue.clinics.isEmpty
          ? const Text(
        "Dashboard",
        style: TextStyle(fontWeight: FontWeight.w900),
      )
          : DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: queue.selectedClinic?.id,
          items: queue.clinics.map((clinic) {
            return DropdownMenuItem<String>(
              value: clinic.id,
              child: Text(clinic.name),
            );
          }).toList(),
          onChanged: (clinicId) {
            if (clinicId != null) {
              final selected = queue.clinics.firstWhere(
                    (c) => c.id == clinicId,
              );
              queue.selectClinic(selected);
            }
          },
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_business_rounded, color: Colors.white70),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClinicView()),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.receipt_long_rounded,
            color: Color(0xFF6366F1),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HistoryView(isAdmin: true),
            ),
          ),
        ),

        // NEW: Emergency Close Option
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.1))
          ),
          onSelected: (value) {
            if (value == 'close') queue.emergencyClose();
            if (value == 'logout') {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthView()));
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'close',
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E), size: 20),
                  SizedBox(width: 12),
                  Text("Emergency Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
                  SizedBox(width: 12),
                  Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMetricsHeader(QueueController queue) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildMetricCard(
            "TODAY",
            (queue.waitingList.length + queue.activeQueue.length).toString(),
            Icons.people_outline_rounded,
          ),
          const SizedBox(width: 16),
          _buildMetricCard(
            "WAITING",
            queue.waitingList.length.toString(),
            Icons.hourglass_empty_rounded,
            isAccent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String label,
      String value,
      IconData icon, {
        bool isAccent = false,
      }) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isAccent
                  ? const Color(0xFF6366F1).withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isAccent ? const Color(0xFF6366F1) : Colors.white54,
                  size: 20,
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white38,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 1,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "WAITING"),
          Tab(text: "ACTIVE"),
          Tab(text: "SKIPPED"), // UPDATED: Changed from MISSED to SKIPPED
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
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.05),
            ),
            const SizedBox(height: 16),
            const Text(
              "Queue is clear",
              style: TextStyle(
                color: Colors.white24,
                fontWeight: FontWeight.bold,
              ),
            ),
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
          // NEW: Updated Logic for Recall and Next
          onStatusNext: () {
            if (appt.status == AppointmentStatus.skipped) {
              queue.recallPatient(appt.id); // Skipped -> Waiting
            } else if (appt.status == AppointmentStatus.waiting) {
              queue.updateStatus(appt.id, AppointmentStatus.active);
            } else if (appt.status == AppointmentStatus.active) {
              queue.updateStatus(appt.id, AppointmentStatus.completed);
            }
          },
          onSkip: () => queue.updateStatus(appt.id, AppointmentStatus.skipped),
          onCancel: () => queue.updateStatus(appt.id, AppointmentStatus.cancelled),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_business_rounded,
            size: 80,
            color: Colors.white.withOpacity(0.05),
          ),
          const SizedBox(height: 16),
          const Text(
            "No clinics found. Create one to begin.",
            style: TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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