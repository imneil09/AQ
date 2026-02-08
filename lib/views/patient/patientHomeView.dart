import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Imports for DRY widgets
import '../../widgets/app_colors.dart';
import '../../widgets/background_blur.dart';
import '../../widgets/glass_card.dart';

import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../historyView.dart';
import '../authView.dart';
import '../unifiedBookingView.dart';

class PatientHomeView extends StatefulWidget {
  const PatientHomeView({super.key});
  @override
  State<PatientHomeView> createState() => _PatientHomeViewState();
}

class _PatientHomeViewState extends State<PatientHomeView> with SingleTickerProviderStateMixin {
  late AnimationController _messageController;
  late Animation<double> _messageScale;
  int? _expandedIndex = 0; // Default to expanding the first item

  @override
  void initState() {
    super.initState();
    _messageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _messageScale = CurvedAnimation(parent: _messageController, curve: Curves.easeOutBack);
    _messageController.forward();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthView()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    // Using patientHistory stream to get all current and future appointments chronologically
    return StreamBuilder<List<Appointment>>(
        stream: queue.patientHistory,
        builder: (context, snapshot) {
          final appointments = snapshot.data ?? [];
          // Filter to show only active/waiting/skipped (current and future)
          final activeAppointments = appointments.where((a) =>
          a.status != AppointmentStatus.completed && a.status != AppointmentStatus.cancelled
          ).toList();

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                "WELLNESS SANCTUARY",
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2, fontSize: 14),
              ),
              leading: IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white70),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryView(isAdmin: false))),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.logout_rounded, color: AppColors.error), onPressed: _logout),
                const SizedBox(width: 8),
              ],
            ),
            body: Stack(
              children: [
                // 1. REFACTOR: Use AppColors.background
                Container(color: AppColors.background),

                // 2. REFACTOR: Use BackgroundBlur widget
                BackgroundBlur(
                  color: AppColors.primary.withOpacity(0.15),
                  size: 300,
                  top: -50,
                  right: -50,
                ),
                BackgroundBlur(
                  color: AppColors.success.withOpacity(0.1),
                  size: 250,
                  bottom: 100,
                  left: -80,
                ),

                SafeArea(
                  child: Column(
                    children: [
                      _buildAnimatedMessage(),
                      Expanded(
                        child: activeAppointments.isEmpty
                            ? _buildEmptyDashboard()
                            : _buildChronologicalList(activeAppointments, queue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnifiedBookingView(isAssistant: false))),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text("NEW", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          );
        }
    );
  }

  Widget _buildChronologicalList(List<Appointment> list, QueueController queue) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final appt = list[index];
        bool isExpanded = _expandedIndex == index;
        bool isLive = index == 0 && appt.appointmentDate.day == DateTime.now().day;

        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: GestureDetector(
            onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
            child: isExpanded ? _buildExpandedTicket(appt, queue, isLive) : _buildCollapsedCard(appt, isLive),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedCard(Appointment appt, bool isLive) {
    Color themeColor = isLive ? AppColors.primary : AppColors.success;

    // 3. REFACTOR: Use GlassCard widget
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        radius: 24,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Text("#${appt.tokenNumber}", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLive ? "LIVE NOW" : DateFormat('EEE, MMM dd').format(appt.appointmentDate),
                    style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                  ),
                  Text(appt.serviceType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            Icon(Icons.unfold_more_rounded, color: Colors.white.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedTicket(Appointment appt, QueueController queue, bool isLive) {
    Color themeColor = isLive ? AppColors.primary : AppColors.success;

    // Kept standard Container to maintain specific border/header design, but updated Colors
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: themeColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Row(
              children: [
                Icon(isLive ? Icons.bolt_rounded : Icons.calendar_today_rounded, color: themeColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  isLive ? "LIVE DETAILS" : "SCHEDULED VISIT",
                  style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5),
                ),
                const Spacer(),
                const Icon(Icons.expand_less_rounded, color: Colors.white24),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  "#${appt.tokenNumber}",
                  style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: themeColor.withOpacity(0.5), blurRadius: 15)]),
                ),
                const Text("QUEUE POSITION", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900)),
                const SizedBox(height: 24),
                _infoLine("Patient", appt.customerName),
                const Divider(height: 20, color: Colors.white10),
                _infoLine("Clinic", queue.selectedClinic?.name ?? "Main Hub"),
                const Divider(height: 20, color: Colors.white10),
                _infoLine("Status", appt.status.name.toUpperCase()),
                if (isLive) ...[
                  const Divider(height: 20, color: Colors.white10),
                  _infoLine("Est. Wait", appt.estimatedTime != null ? DateFormat('hh:mm a').format(appt.estimatedTime!) : "Calculating..."),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMessage() {
    return ScaleTransition(
      scale: _messageScale,
      // 4. REFACTOR: Use GlassCard widget
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          radius: 24,
          child: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.success, size: 28),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Your health is an investment, not an expense. Stay energized!",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDashboard() {
    return Center(
      child: Opacity(
        opacity: 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.spa_rounded, size: 80, color: Colors.white10),
            const SizedBox(height: 24),
            const Text("Your sanctuary is ready.", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text("Start your wellness journey today.", style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.w800, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}