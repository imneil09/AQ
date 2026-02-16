import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../../widgets/appColors.dart';
import '../../widgets/backgroundBlur.dart';
import '../../widgets/glassCard.dart';

class ScheduledAppointmentsView extends StatefulWidget {
  const ScheduledAppointmentsView({super.key});

  @override
  State<ScheduledAppointmentsView> createState() =>
      _ScheduledAppointmentsViewState();
}

class _ScheduledAppointmentsViewState extends State<ScheduledAppointmentsView> {
  DateTime? _selectedFilterDate;

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Scheduled Appointments",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _selectedFilterDate == null
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_off_rounded,
              color: AppColors.primary,
            ),
            onPressed: () async {
              // If filter is active, tap to clear it
              if (_selectedFilterDate != null) {
                setState(() => _selectedFilterDate = null);
                return;
              }

              // Otherwise, pick a date
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder:
                    (context, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.primary,
                      surface: AppColors.surface,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _selectedFilterDate = picked);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background & Blurs
          Container(color: AppColors.background),
          BackgroundBlur(
            color: AppColors.primary.withOpacity(0.15),
            size: 300,
            top: -50,
            right: -100,
          ),
          BackgroundBlur(
            color: AppColors.error.withOpacity(0.1),
            size: 250,
            bottom: 50,
            left: -50,
          ),

          // Main Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderInfo(),
                Expanded(
                  child: StreamBuilder<List<Appointment>>(
                    stream: queue.upcomingSchedule,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Error loading schedule",
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      List<Appointment> list = snapshot.data ?? [];

                      // Apply date filter if selected
                      if (_selectedFilterDate != null) {
                        list =
                            list.where((a) {
                              final d = a.appointmentDate;
                              return d.year == _selectedFilterDate!.year &&
                                  d.month == _selectedFilterDate!.month &&
                                  d.day == _selectedFilterDate!.day;
                            }).toList();
                      }

                      if (list.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          return _buildScheduledCard(list[index]);
                        },
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

  Widget _buildHeaderInfo() {
    final bool hasFilter = _selectedFilterDate != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
          hasFilter
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.glassWhite.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
            hasFilter
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFilter
                  ? Icons.event_available_rounded
                  : Icons.calendar_view_week_rounded,
              color: hasFilter ? AppColors.primary : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFilter ? "FILTER APPLIED" : "OVERVIEW",
                    style: TextStyle(
                      color: hasFilter ? AppColors.primary : Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasFilter
                        ? DateFormat(
                      'EEEE, MMMM dd, yyyy',
                    ).format(_selectedFilterDate!)
                        : "All scheduled appointments",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (hasFilter)
              InkWell(
                onTap: () => setState(() => _selectedFilterDate = null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.05),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilterDate == null
                ? "No upcoming appointments."
                : "No schedule on ${DateFormat('MMM dd').format(_selectedFilterDate!)}",
            style: const TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledCard(Appointment appt) {
    final bool isAppBooking = appt.type == 'app';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Date & Source Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: AppColors.primary.withOpacity(0.8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, MMM dd').format(appt.appointmentDate),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                _buildSourceBadge(isAppBooking),
              ],
            ),

            const SizedBox(height: 16),

            // Patient Name & Phone
            Text(
              appt.customerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  size: 14,
                  color: Colors.white38,
                ),
                const SizedBox(width: 6),
                Text(
                  appt.phoneNumber,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bottom Info Block (Service & Token)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildMiniStat(
                    Icons.medical_services_outlined,
                    "SERVICE",
                    appt.serviceType,
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.white12,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  _buildMiniStat(
                    Icons.confirmation_num_outlined,
                    "TOKEN",
                    "#${appt.tokenNumber}",
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge(bool isAppBooking) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isAppBooking ? AppColors.success : Colors.orange).withOpacity(
          0.1,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isAppBooking ? AppColors.success : Colors.orange).withOpacity(
            0.2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAppBooking
                ? Icons.smartphone_rounded
                : Icons.support_agent_rounded,
            size: 10,
            color: isAppBooking ? AppColors.success : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isAppBooking ? "App" : "Desk",
            style: TextStyle(
              color: isAppBooking ? AppColors.success : Colors.orange,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      IconData icon,
      String label,
      String value, {
        Color valueColor = Colors.white,
      }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
