import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// UI Components
import '../../widgets/appColors.dart';
import '../../widgets/backgroundBlur.dart';
import '../../widgets/glassCard.dart';
import '../../widgets/appointment.dart';

// Logic & Models
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../history.dart';
import '../unifiedBooking.dart';
import 'createClinic.dart';
import 'scheduledAppointments.dart';
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

  Future<void> _handleLogout(BuildContext context, QueueController queue) async {
    await queue.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthView()),
            (route) => false,
      );
    }
  }Future<void> _handleEmergency(
      BuildContext context,
      QueueController queue,
      ) async {
    if (queue.selectedClinic == null) return;
    final DateTime now = DateTime.now();

    // 1. Ask the assistant to pick a date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: AppColors.background,
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return; // Action cancelled
    if (!context.mounted) return;

    final dateStr = DateFormat('MMM dd, yyyy').format(pickedDate);
    final cleanPicked = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);

    // 2. CHECK STATUS: Is this date already closed?
    bool isAlreadyClosed = queue.selectedClinic!.emergencyClosedDates.any(
            (d) => d.year == cleanPicked.year && d.month == cleanPicked.month && d.day == cleanPicked.day
    );

    // 3. Show dynamic confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          isAlreadyClosed ? "Reopen Clinic on $dateStr?" : "Close Clinic on $dateStr?",
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isAlreadyClosed
              ? "This will remove the emergency block. Patients will immediately be able to book new appointments for $dateStr via the app.\n\nNote: Previously cancelled appointments will NOT be restored."
              : "This will CANCEL all pending appointments for $dateStr. Patients will not be able to book for this date via the app. This action cannot be undone.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isAlreadyClosed ? "CONFIRM REOPEN" : "CONFIRM CLOSE",
              style: TextStyle(
                color: isAlreadyClosed ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    // 4. Execute the chosen action
    if (confirm == true) {
      if (isAlreadyClosed) {
        await queue.reopenClinicForDate(pickedDate);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Clinic reopened for bookings on $dateStr."),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await queue.closeClinicForDate(pickedDate);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Clinic closed for $dateStr. Pending appointments cancelled."),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }


  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);
    final bool hasClinics = queue.clinics.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, queue),
      body: Stack(
        children: [
          // Background Layer
          Container(color: AppColors.background),
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

          // Content Layer
          SafeArea(
            child:
            !hasClinics
                ? _buildEmptyState()
                : Column(
              children: [
                _buildMetricsHeader(queue),
                _buildSearchBar(queue),
                _buildTabBar(queue),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAppointmentList(queue, queue.waitingList),
                      _buildAppointmentList(queue, queue.activeQueue),
                      _buildAppointmentList(queue, queue.skippedList),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
      hasClinics
          ? FloatingActionButton.extended(
        onPressed:
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const UnifiedBookingView(isAssistant: true),
          ),
        ),
        label: const Text(
          "WALK-IN",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primary,
      )
          : null,
    );
  }

  // --- APP BAR ---

  PreferredSizeWidget _buildAppBar(BuildContext context, QueueController queue) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title:
      queue.clinics.isEmpty
          ? const Text(
        "Dashboard",
        style: TextStyle(fontWeight: FontWeight.w900),
      )
          : Row(
        children: [
          Expanded(child: _buildClinicDropdown(queue)),
          IconButton(
            icon: const Icon(
              Icons.edit_note_rounded,
              color: Colors.white70,
            ),
            onPressed: () {
              if (queue.selectedClinic != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => CreateClinicView(
                      clinic: queue.selectedClinic,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_business_rounded, color: Colors.white70),
          onPressed:
              () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClinicView()),
          ),
        ),
        _buildPopupMenu(context, queue),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildClinicDropdown(QueueController queue) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: queue.selectedClinic?.id,
        dropdownColor: AppColors.surface,
        isExpanded: true,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        items:
        queue.clinics.map((clinic) {
          return DropdownMenuItem<String>(
            value: clinic.id,
            child: Text(
              clinic.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList(),
        onChanged: (clinicId) {
          if (clinicId != null) {
            final selected = queue.clinics.firstWhere((c) => c.id == clinicId);
            queue.selectClinic(selected);
          }
        },
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, QueueController queue) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        switch (value) {
          case 'schedule':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ScheduledAppointmentsView(),
              ),
            );
            break;
          case 'history':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HistoryView(isAdmin: true),
              ),
            );
            break;
          case 'close':
            _handleEmergency(context, queue);
            break;
          case 'logout':
            _handleLogout(context, queue);
            break;
        }
      },
      itemBuilder:
          (context) => [
        _buildPopupItem(
          'schedule',
          Icons.calendar_month,
          "Scheduled Appointments",
          AppColors.primary,
        ),
        _buildPopupItem(
          'history',
          Icons.work_history_outlined,
          "Consultation History",
          Colors.white,
        ),
        const PopupMenuDivider(height: 1),
        _buildPopupItem(
          'close',
          Icons.warning_outlined,
          "SOS",
          AppColors.error,
        ),
        _buildPopupItem(
          'logout',
          Icons.power_settings_new_rounded,
          "Logout",
          AppColors.error,
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      String value,
      IconData icon,
      String text,
      Color color,
      ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  // --- HEADER & METRICS ---

  Widget _buildMetricsHeader(QueueController queue) {
    // Calculate metrics strictly from history to avoid mismatches
    final completedCount =
        queue.history
            .where((e) => e.status == AppointmentStatus.completed)
            .length;
    final cancelledCount =
        queue.history
            .where((e) => e.status == AppointmentStatus.cancelled)
            .length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildMetricCard(
            "CANCELLED",
            cancelledCount.toString(),
            Icons.cancel_outlined,
            accentColor: AppColors.error,
          ),
          const SizedBox(width: 16),
          _buildMetricCard(
            "COMPLETED",
            completedCount.toString(),
            Icons.check_circle_outline_rounded,
            accentColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String label,
      String value,
      IconData icon, {
        required Color accentColor,
      }) {
    return Expanded(
      child: GlassCard(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 20),
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
    );
  }

  // --- SEARCH & TABS ---

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
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Search patient name or token...",
          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
          icon: Icon(Icons.search_rounded, color: Colors.white38, size: 20),
        ),
      ),
    );
  }

  Widget _buildTabBar(QueueController queue) {
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

  // --- APPOINTMENT LIST ---

  Widget _buildAppointmentList(QueueController queue, List<Appointment> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: AppColors.glassWhite),
            const SizedBox(height: 16),
            const Text(
              "No patients in this list",
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
          onStatusNext: () {
            // Intelligent status progression
            if (appt.status == AppointmentStatus.skipped) {
              queue.recallPatient(appt.id);
            } else if (appt.status == AppointmentStatus.waiting) {
              queue.updateStatus(appt.id, AppointmentStatus.active);
            } else if (appt.status == AppointmentStatus.active) {
              queue.updateStatus(appt.id, AppointmentStatus.completed);
            }
          },
          onSkip: () => queue.updateStatus(appt.id, AppointmentStatus.skipped),
          onCancel:
              () => queue.updateStatus(appt.id, AppointmentStatus.cancelled),
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
            color: AppColors.glassWhite,
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