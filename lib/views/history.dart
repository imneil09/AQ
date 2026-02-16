import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// UI Components
import '../widgets/appColors.dart';
import '../widgets/backgroundBlur.dart';
import '../widgets/glassCard.dart';

// Logic & Models
import '../controllers/queueController.dart';
import '../models/appoinmentModel.dart';

class HistoryView extends StatefulWidget {
  final bool isAdmin;
  const HistoryView({super.key, required this.isAdmin});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  // Local State
  String _activeFilter = 'ALL';
  String _searchQuery = '';
  final List<String> _filters = ['ALL', 'COMPLETED', 'CANCELLED'];

  // --- UNIFIED DATE RANGE STATE ---
  late DateTime _startDate;
  late DateTime _endDate;

  // Stream Management
  Stream<List<Appointment>>? _stableStream;
  String? _streamIdentity; // Used to detect if we need to reconnect

  @override
  void initState() {
    super.initState();
    // Default: Exactly 4 months ago from today
    final now = DateTime.now();
    _endDate = now;
    _startDate = DateTime(now.year, now.month - 4, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeStream();
  }

  void _initializeStream() {
    final queue = Provider.of<QueueController>(context, listen: false);

    // Identity includes dates so the stream reconnects if dates change
    String newIdentity = widget.isAdmin
        ? "admin_${queue.selectedClinic?.id}_${_startDate.toIso8601String()}_${_endDate.toIso8601String()}"
        : "patient_${queue.currentUserId}_${_startDate.toIso8601String()}_${_endDate.toIso8601String()}";

    // Only reconnect if the identity has changed (prevents loop)
    if (_streamIdentity != newIdentity) {
      setState(() {
        _streamIdentity = newIdentity;
        // Call the unified backend method
        _stableStream = queue.getHistoryStream(
          isAssistant: widget.isAdmin,
          startDate: _startDate,
          endDate: _endDate,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure stream is valid on every build
    _initializeStream();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
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
                _buildSearchBar(),
                _buildFilterChips(),

                // --- NEW CALENDAR UI COMPONENT ---
                _buildDateRangeSelector(),
                const SizedBox(height: 8),

                Expanded(
                  child: StreamBuilder<List<Appointment>>(
                    stream: _stableStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState(snapshot.error.toString());
                      }

                      // 1. Get Raw Data
                      var list = snapshot.data ?? [];

                      // 2. Strict Filter: ONLY Completed or Cancelled
                      // (We intentionally hide 'waiting', 'active', 'skipped' from History)
                      list = list.where((a) =>
                      a.status == AppointmentStatus.completed ||
                          a.status == AppointmentStatus.cancelled)
                          .toList();

                      // 3. Apply Tab Filter
                      if (_activeFilter != 'ALL') {
                        list = list.where((a) {
                          if (_activeFilter == 'COMPLETED') {
                            return a.status == AppointmentStatus.completed;
                          }
                          if (_activeFilter == 'CANCELLED') {
                            return a.status == AppointmentStatus.cancelled;
                          }
                          return true;
                        }).toList();
                      }

                      // 4. Apply Search Filter
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        list = list.where((a) =>
                        a.customerName.toLowerCase().contains(q) ||
                            a.serviceType.toLowerCase().contains(q) ||
                            a.tokenNumber.toString().contains(q) ||
                            a.phoneNumber.contains(q))
                            .toList();
                      }

                      if (list.isEmpty) return _buildEmptyState();

                      return _buildGroupedList(list);
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.isAdmin ? "Patient Records" : "My History",
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: TextField(
          // Updates local state instantly (No database call)
          onChanged: (val) => setState(() => _searchQuery = val),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "Search by Name, Service or Token...",
            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
            icon: Icon(Icons.search_rounded, color: Colors.white38, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_filters.length, (index) {
          final filter = _filters[index];
          final isActive = _activeFilter == filter;

          return Expanded(
            child: Padding(
              // Add spacing between items (except the last one)
              padding: EdgeInsets.only(
                right: index == _filters.length - 1 ? 0 : 8,
              ),
              child: GestureDetector(
                onTap: () => setState(() => _activeFilter = filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.glassWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? Colors.transparent : AppColors.glassBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- NEW DATE RANGE SELECTOR WIDGET ---
  Widget _buildDateRangeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${DateFormat('MMM dd, yyyy').format(_startDate)}  -  ${DateFormat('MMM dd, yyyy').format(_endDate)}",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                firstDate: DateTime(2020), // Can go back to any historical date
                lastDate: DateTime.now(), // Cannot look into the future
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        surface: AppColors.surface,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                // UI Rule: Maximum 4 months (approx 124 days) selection allowed
                if (picked.end.difference(picked.start).inDays > 124) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Maximum allowed date range is 4 months."),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  return; // Abort update
                }

                setState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                  _streamIdentity = null; // Forces stream to rebuild
                });
                _initializeStream();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Text(
                    "Filter Dates",
                    style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<Appointment> appointments) {
    Map<String, List<Appointment>> grouped = {};

    for (var appt in appointments) {
      String dateKey = DateFormat('yyyy-MM-dd').format(appt.appointmentDate);
      if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
      grouped[dateKey]!.add(appt);
    }

    List<String> sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        String dateKey = sortedKeys[index];
        List<Appointment> dayList = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(dateKey),
            ...dayList.map(
                  (appt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryCard(appt: appt, showDetails: widget.isAdmin),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(String dateKey) {
    DateTime date = DateTime.parse(dateKey);
    DateTime now = DateTime.now();
    String label;

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = "Today";
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      label = "Yesterday";
    } else {
      label = DateFormat('MMMM dd, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Opacity(
        opacity: 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.history_toggle_off_rounded,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            const Text(
              "No history found",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Database Index Required",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Check your IDE Debug Console and click the Firebase link to build the Composite Index.\n\n$error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Appointment appt;
  final bool showDetails;
  const _HistoryCard({required this.appt, required this.showDetails});

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = appt.status == AppointmentStatus.completed;
    final Color statusColor = isCompleted ? AppColors.success : AppColors.error;

    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : Icons.close_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.customerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (showDetails)
                  Text(
                    appt.phoneNumber,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('hh:mm a').format(appt.appointmentDate),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "#${appt.tokenNumber}",
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  appt.serviceType,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}