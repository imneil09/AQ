import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Imports for DRY widgets
import '../widgets/appColors.dart';
import '../widgets/backgroundBlur.dart';
import '../widgets/glassCard.dart';

import '../controllers/queueController.dart';
import '../models/appoinmentModel.dart';

class HistoryView extends StatefulWidget {
  final bool isAdmin;
  const HistoryView({super.key, required this.isAdmin});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  // Filter State: 'ALL', 'COMPLETED', 'CANCELLED'
  String _activeFilter = 'ALL';
  final List<String> _filters = ['ALL', 'COMPLETED', 'CANCELLED'];

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    // 1. Backend Logic: Select the correct stream based on Role
    final historyStream = widget.isAdmin ? queue.assistantFullHistory : queue.patientHistory;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? "Patient's Records" : "My History",
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Layer
          Container(color: AppColors.background),
          BackgroundBlur(
            color: AppColors.primary.withOpacity(0.15),
            size: 400,
            top: -100,
            right: -100,
          ),
          BackgroundBlur(
            color: AppColors.error.withOpacity(0.1),
            size: 350,
            bottom: -50,
            left: -100,
          ),

          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(queue),
                _buildFilterChips(),

                // 2. Backend Logic: StreamBuilder for Real-time Updates
                Expanded(
                  child: StreamBuilder<List<Appointment>>(
                    stream: historyStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }

                      var appointments = snapshot.data ?? [];

                      // 3. Client-Side Filtering (Status Chips)
                      if (_activeFilter != 'ALL') {
                        appointments = appointments.where((a) {
                          if (_activeFilter == 'COMPLETED') return a.status == AppointmentStatus.completed;
                          if (_activeFilter == 'CANCELLED') return a.status == AppointmentStatus.cancelled;
                          return true;
                        }).toList();
                      }

                      if (appointments.isEmpty) return _buildEmptyState();

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GlassCard(
                            radius: 24,
                            padding: const EdgeInsets.all(20),
                            child: _HistoryItemContent(
                              appt: appointments[index],
                              showDetails: widget.isAdmin,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(QueueController queue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          // 4. Backend Logic: Updates the Controller's search query state
          onChanged: (val) => queue.updateHistorySearch(val),
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "Search by Name, Service or ID...",
            hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
            icon: Icon(Icons.search_rounded, color: Colors.white24, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          bool isActive = _activeFilter == _filters[index];
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = _filters[index]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.glassWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isActive ? Colors.transparent : AppColors.glassBorder),
              ),
              child: Center(
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 60, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
              "No records found",
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}

class _HistoryItemContent extends StatelessWidget {
  final Appointment appt;
  final bool showDetails;
  const _HistoryItemContent({required this.appt, required this.showDetails});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appt.status);
    final isCancelled = appt.status == AppointmentStatus.cancelled;

    return Row(
      children: [
        // Status Icon
        Container(
          height: 48, width: 48,
          decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16)
          ),
          child: Icon(_getStatusIcon(appt.status), color: statusColor, size: 24),
        ),
        const SizedBox(width: 16),

        // Info Column
        Expanded(
          child: Opacity(
            opacity: isCancelled ? 0.6 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    appt.customerName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)
                ),
                const SizedBox(height: 4),

                // Show Phone number only for Admin/Assistant
                if (showDetails)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                        appt.phoneNumber,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)
                    ),
                  ),

                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(appt.appointmentDate),
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Token & Service
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
                "#${appt.tokenNumber}",
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 24)
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6)
              ),
              child: Text(
                appt.serviceType,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed: return AppColors.success;
      case AppointmentStatus.cancelled: return AppColors.error;
      case AppointmentStatus.skipped: return Colors.amber;
      default: return AppColors.primary;
    }
  }

  IconData _getStatusIcon(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed: return Icons.check_circle_outline_rounded;
      case AppointmentStatus.cancelled: return Icons.cancel_outlined;
      case AppointmentStatus.skipped: return Icons.u_turn_right_rounded;
      default: return Icons.access_time_rounded;
    }
  }
}