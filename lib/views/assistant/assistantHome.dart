import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// DRY Widgets & Constants
import '../../widgets/appColors.dart';
import '../../widgets/backgroundBlur.dart';
import '../../widgets/glassCard.dart';

import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../../widgets/appointment.dart';
import '../history.dart';
import '../unifiedBooking.dart';
import 'createClinic.dart';
import '../auth.dart';

class AssistantHomeView extends StatefulWidget {
  const AssistantHomeView({super.key});

  @override
  State<AssistantHomeView> createState() => _AssistantHomeViewState();
}

class _AssistantHomeViewState extends State<AssistantHomeView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  void _handleLogout(BuildContext context, QueueController queue) async {
    await queue.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthView()),
              (route) => false);
    }
  }

  void _handleEmergencyClose(BuildContext context, QueueController queue) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Emergency Close?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will CANCEL all waiting appointments for today. This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("CLOSE CLINIC", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await queue.emergencyCloseToday();
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(queue),
      body: Stack(
        children: [
          // 1. Background
          Container(color: AppColors.background),

          // 2. Ambient Blurs
          BackgroundBlur(
            color: AppColors.primary.withOpacity(0.2),
            size: 300,
            top: -50,
            right: -50,
          ),
          BackgroundBlur(
            color: AppColors.error.withOpacity(0.1),
            size: 250,
            bottom: 100,
            left: -80,
          ),

          // 3. Main Content
          SafeArea(
            child: queue.clinics.isEmpty
                ? _buildEmptyState()
                : Column(
              children: [
                _buildMetricsHeader(queue),
                _buildSearchBar(queue),
                _buildCustomTabBar(queue),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(queue, queue.waitingList), // Tab 1
                      _buildList(queue, queue.activeQueue), // Tab 2
                      _buildList(queue, queue.skippedList), // Tab 3
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
          MaterialPageRoute(
              builder: (_) =>
              const UnifiedBookingView(isAssistant: true)),
        ),
        label: const Text(
          "WALK-IN",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primary,
      )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(QueueController queue) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: queue.clinics.isEmpty
          ? const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.w900))
          : Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: queue.selectedClinic?.id,
                dropdownColor: AppColors.surface,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                items: queue.clinics.map((clinic) {
                  return DropdownMenuItem<String>(
                    value: clinic.id,
                    child: Text(clinic.name),
                  );
                }).toList(),
                onChanged: (clinicId) {
                  if (clinicId != null) {
                    final selected =
                    queue.clinics.firstWhere((c) => c.id == clinicId);
                    queue.selectClinic(selected);
                  }
                },
              ),
            ),
          ),
          // Edit Clinic
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white70),
            onPressed: () {
              if (queue.selectedClinic != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateClinicView(clinic: queue.selectedClinic),
                  ),
                );
              }
            },
          ),
        ],
      ),
      actions: [
        // Create New Clinic
        IconButton(
          icon: const Icon(Icons.add_business_rounded, color: Colors.white70),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClinicView()),
          ),
        ),
        // History
        IconButton(
          icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryView(isAdmin: true)),
          ),
        ),
        // Menu (Close/Logout)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
          color: AppColors.surface,
          onSelected: (value) {
            if (value == 'close') _handleEmergencyClose(context, queue);
            if (value == 'logout') _handleLogout(context, queue);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'close',
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 20),
                  SizedBox(width: 12),
                  Text("Emergency Close", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
                  SizedBox(width: 12),
                  Text("Logout", style: TextStyle(color: Colors.white)),
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
    // Metrics based on today's queue history
    final completedCount = queue.history
        .where((e) => e.status == AppointmentStatus.completed)
        .length;
    final cancelledCount = queue.history
        .where((e) => e.status == AppointmentStatus.cancelled)
        .length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildMetricCard(
            "COMPLETED",
            completedCount.toString(),
            Icons.check_circle_outline_rounded,
            accentColor: AppColors.success,
          ),
          const SizedBox(width: 16),
          _buildMetricCard(
            "CANCELLED",
            cancelledCount.toString(),
            Icons.cancel_outlined,
            accentColor: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon,
      {required Color accentColor}) {
    return Expanded(
      child: GlassCard(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white38,
                    letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(QueueController queue) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        onChanged: (val) => queue.updateLiveSearch(val),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Search waiting patients...",
          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
          icon: Icon(Icons.search_rounded, color: Colors.white38, size: 20),
        ),
      ),
    );
  }

  Widget _buildCustomTabBar(QueueController queue) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: "WAITING (${queue.waitingList.length})"),
          Tab(text: "ACTIVE (${queue.activeQueue.length})"),
          Tab(text: "SKIPPED (${queue.skippedList.length})"),
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
            Icon(Icons.inbox_rounded, size: 64, color: AppColors.glassWhite),
            const SizedBox(height: 16),
            const Text("No patients here",
                style: TextStyle(
                    color: Colors.white24, fontWeight: FontWeight.bold)),
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
          // --- BACKEND WIRING START ---
          onStatusNext: () {
            if (appt.status == AppointmentStatus.skipped) {
              // Skipped -> Waiting (Recall)
              queue.recallPatient(appt.id);
            } else if (appt.status == AppointmentStatus.waiting) {
              // Waiting -> Active (Call Next)
              queue.updateStatus(appt.id, AppointmentStatus.active);
            } else if (appt.status == AppointmentStatus.active) {
              // Active -> Completed (Finish)
              queue.updateStatus(appt.id, AppointmentStatus.completed);
            }
          },
          onSkip: () => queue.updateStatus(appt.id, AppointmentStatus.skipped),
          onCancel: () => queue.updateStatus(appt.id, AppointmentStatus.cancelled),
          // --- BACKEND WIRING END ---
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_business_rounded, size: 80, color: AppColors.glassWhite),
          const SizedBox(height: 16),
          const Text("No clinics found. Create one to begin.",
              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}