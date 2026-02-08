import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Imports for DRY widgets
import '../widgets/app_colors.dart';
import '../widgets/background_blur.dart';
import '../widgets/glass_card.dart';

import '../controllers/queueController.dart';
import '../models/appoinmentModel.dart';

class HistoryView extends StatefulWidget {
  final bool isAdmin;
  const HistoryView({super.key, required this.isAdmin});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  String _activeFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);
    final historyStream = widget.isAdmin ? queue.assistantFullHistory : queue.patientHistory;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? "Patient's Records" : "Records",
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. REFACTOR: Use AppColors.background
          Container(color: AppColors.background),

          // 2. REFACTOR: Use BackgroundBlur widget
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
                _buildFilters(),
                Expanded(
                  child: StreamBuilder<List<Appointment>>(
                    stream: historyStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }

                      var appointments = snapshot.data ?? [];

                      // Apply Client-side filtering
                      if (_activeFilter != 'ALL') {
                        // Normalize the filter string to match Enum names
                        String filterStatus = _activeFilter == 'COMPLETED' ? 'COMPLETED' : 'CANCELLED';
                        appointments = appointments.where((a) => a.status.name.toUpperCase() == filterStatus).toList();
                      }

                      if (appointments.isEmpty) return _buildEmptyState();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        physics: const BouncingScrollPhysics(),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          // 3. REFACTOR: Use GlassCard wrapper
                          child: GlassCard(
                            radius: 24,
                            padding: const EdgeInsets.all(20),
                            child: _HistoryItemContent(
                              appt: appointments[index],
                              showPhone: widget.isAdmin,
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
      // 4. REFACTOR: Use GlassCard for Search Bar
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          onChanged: (val) => queue.updateHistorySearch(val),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "Search records...",
            hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
            icon: Icon(Icons.search_rounded, color: Colors.white24, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['ALL', 'COMPLETED', 'CANCELLED'];
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          bool isActive = _activeFilter == filters[index];
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filters[index]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.glassWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? Colors.transparent : AppColors.glassBorder),
              ),
              child: Center(
                child: Text(
                  filters[index],
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white38,
                    fontSize: 12,
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
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text("No records found", style: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _HistoryItemContent extends StatelessWidget {
  final Appointment appt;
  final bool showPhone;
  const _HistoryItemContent({required this.appt, required this.showPhone});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appt.status);

    return Row(
      children: [
        // Status Icon
        Container(
          height: 46, width: 46,
          decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
          child: Icon(_getStatusIcon(appt.status), color: statusColor, size: 22),
        ),
        const SizedBox(width: 16),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(appt.customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 4),
              if (showPhone)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(appt.phoneNumber, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              Text(
                "${appt.serviceType} • ${DateFormat('MMM dd, yyyy').format(appt.appointmentDate)}",
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Token & Status Text
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("#${appt.tokenNumber}", style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 2),
            Text(
              appt.status.name.toUpperCase(),
              style: TextStyle(color: statusColor.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
      default: return AppColors.primary;
    }
  }

  IconData _getStatusIcon(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed: return Icons.check_rounded;
      case AppointmentStatus.cancelled: return Icons.close_rounded;
      default: return Icons.history_rounded;
    }
  }
}