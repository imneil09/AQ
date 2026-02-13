import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../../widgets/appColors.dart';
import '../auth.dart';
import 'prescription.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;

  // --- NEW: Track selected patient and their drafts ---
  String? _selectedPatientId;
  final Map<String, Map<String, dynamic>> _drafts = {};

  // Sidebar animation constants
  bool _isWorkspaceHovered = false;
  static const double _sidebarExpandedWidth = 320.0;
  static const double _sidebarMinimizedWidth = 90.0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    // --- NEW: Auto-select active patient logic ---
    final activeList = queue.activeQueue;
    Appointment? activePatient;

    if (activeList.isNotEmpty) {
      if (_selectedPatientId == null || !activeList.any((a) => a.id == _selectedPatientId)) {
        // If selection is invalid, default to the first active person
        _selectedPatientId = activeList.first.id;
      }
      activePatient = activeList.firstWhere((a) => a.id == _selectedPatientId);
    } else {
      _selectedPatientId = null;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildModernAppBar(context, queue),
      body: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive: Force minimize on small screens
            final bool isSmallScreen = constraints.maxWidth < 900;
            final double targetSidebarWidth = isSmallScreen
                ? _sidebarMinimizedWidth
                : (_isWorkspaceHovered ? _sidebarMinimizedWidth : _sidebarExpandedWidth);

            return Row(
              children: [
                // 1. Left Sidebar with Smart Layout Handling
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: targetSidebarWidth,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // Switch to expanded view only when we have enough space (e.g., > 180px)
                      final bool effectiveCollapsed = box.maxWidth < 180;
                      return _buildLiveQueueSidebar(queue, activePatient, effectiveCollapsed);
                    },
                  ),
                ),

                // 2. Right Content Area
                Expanded(
                  flex: 4,
                  child: MouseRegion(
                    onEnter: isSmallScreen ? null : (_) => setState(() => _isWorkspaceHovered = true),
                    onExit: isSmallScreen ? null : (_) => setState(() => _isWorkspaceHovered = false),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.glassWhite),
                      ),
                      child: queue.isOnBreak
                          ? _buildBreakScreen(queue)
                          : _buildMainWorkspace(queue, activePatient),
                    ),
                  ),
                ),
              ],
            );
          }
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(BuildContext context, QueueController queue) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      toolbarHeight: 80,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.monitor_heart, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dr. Shankar Deb Roy",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
              Text(queue.selectedClinic?.name ?? "Live Dashboard",
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4), letterSpacing: 1.2)),
            ],
          ),
        ],
      ),
      actions: [
        _buildSearchBox(queue),
        const SizedBox(width: 20),
        _buildBreakToggle(queue),
        const SizedBox(width: 20),
        IconButton(
          onPressed: () => _handleLogout(context, queue),
          icon: const Icon(Icons.power_settings_new_rounded, color: AppColors.error),
          tooltip: "Logout",
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildSearchBox(QueueController queue) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSearching ? 300 : 45,
      height: 45,
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isSearching ? AppColors.primary : Colors.transparent),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, size: 20, color: Colors.white54),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchCtrl.clear();
                queue.updateHistorySearch("");
              }
            }),
          ),
          if (_isSearching)
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                    hintText: "Search patient...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.white24)
                ),
                onChanged: (v) => queue.updateHistorySearch(v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveQueueSidebar(QueueController queue, Appointment? selected, bool isCollapsed) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- NEW: SECTION 1: ACTIVE PATIENTS (TOGGLE LIST) ---
          if (queue.activeQueue.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: isCollapsed
                  ? const Center(child: Icon(Icons.meeting_room_rounded, color: AppColors.success))
                  : const Text("IN CABIN (ACTIVE)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 1.5)),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
              itemCount: queue.activeQueue.length,
              itemBuilder: (context, index) {
                final appt = queue.activeQueue[index];
                final isSelected = appt.id == selected?.id;

                return InkWell(
                  onTap: () => setState(() => _selectedPatientId = appt.id),
                  child: _buildQueueCard(appt, true, isCollapsed, isSelected: isSelected),
                );
              },
            ),
            Divider(color: Colors.white.withOpacity(0.1), height: 32),
          ],

          // --- SECTION 2: WAITING LIST ---
          Padding(
            padding: EdgeInsets.fromLTRB(24, queue.activeQueue.isNotEmpty ? 8 : 24, 24, 16),
            child: isCollapsed
                ? const Center(child: Icon(Icons.people_alt_rounded, color: AppColors.primary))
                : const Text("IN QUEUE(WAITING)",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.5)),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
              itemCount: queue.waitingList.length,
              itemBuilder: (context, index) {
                final appt = queue.waitingList[index];
                return _buildQueueCard(appt, false, isCollapsed);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- MODIFIED: Added isSelected logic for styling ---
  Widget _buildQueueCard(Appointment appt, bool isActiveList, bool isCollapsed, {bool isSelected = false}) {
    Color cardColor;
    if (isActiveList) {
      cardColor = isSelected ? AppColors.success : AppColors.success.withOpacity(0.2);
    } else {
      cardColor = Colors.white.withOpacity(0.03);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isCollapsed ? 12 : 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: AppColors.success, width: 2) : null,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: isActiveList ? Colors.white24 : AppColors.primary.withOpacity(0.2),
              radius: isCollapsed ? 16 : 20,
              child: Text("${appt.tokenNumber}",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isCollapsed ? 12 : 14)),
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt.customerName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(isActiveList ? "In Cabin" : appt.serviceType,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainWorkspace(QueueController queue, Appointment? active) {
    if (_isSearching && _searchCtrl.text.isNotEmpty) return _buildSearchResults(queue);

    if (active != null) {
      // --- NEW: Using Drafts and ValueKey ---
      return PrescriptionView(
        key: ValueKey(active.id), // Forces rebuild when switching patients
        patient: active,
        initialDraft: _drafts[active.id],
        onDraftChanged: (newData) {
          // Save draft to local memory immediately
          _drafts[active.id] = newData;
        },
        onFinish: () {
          // Clear draft when finished
          _drafts.remove(active.id);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Consultation Completed Successfully"),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              )
          );
        },
      );
    }

    return _buildIdleState(queue);
  }

  Widget _buildIdleState(QueueController queue) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.02)),
            child: Icon(Icons.person_search_rounded, size: 80, color: Colors.white.withOpacity(0.05)),
          ),
          const SizedBox(height: 24),
          const Text("Ready for Patient", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),

          if (queue.waitingList.isNotEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => queue.callNextPatient(),
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text("CALL NEXT PATIENT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          ] else
            const Text("No patients waiting in queue.", style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _buildBreakToggle(QueueController queue) {
    final bool onBreak = queue.isOnBreak;
    final color = onBreak ? Colors.amber : AppColors.success;

    return InkWell(
      onTap: () => queue.toggleBreak(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(onBreak ? Icons.airline_seat_legroom_extra_sharp : Icons.play_circle_fill,
                size: 16, color: color),
            const SizedBox(width: 8),
            Text(onBreak ? "ON BREAK" : "ACTIVE",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakScreen(QueueController queue) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pause_circle_filled, size: 80, color: Colors.amber),
          const SizedBox(height: 24),
          const Text("Consultation Paused", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => queue.toggleBreak(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
            child: const Text("RESUME SESSION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          )
        ],
      ),
    );
  }

  Widget _buildSearchResults(QueueController queue) {
    return StreamBuilder<List<Appointment>>(
      stream: queue.assistantFullHistory,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text("No patients found.", style: TextStyle(color: Colors.white38))
          );
        }

        final results = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(32),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildHistoryItem(results[i]),
        );
      },
    );
  }

  Widget _buildHistoryItem(Appointment appt) {
    return ListTile(
      tileColor: Colors.white.withOpacity(0.02),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: const Icon(Icons.history, color: Colors.white24),
      title: Text(appt.customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text("${appt.serviceType} • ${DateFormat('dd MMM yyyy').format(appt.appointmentDate)}", style: const TextStyle(color: Colors.white38)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: appt.status == AppointmentStatus.completed ? AppColors.success.withOpacity(0.2) : Colors.white10,
            borderRadius: BorderRadius.circular(8)
        ),
        child: Text(appt.status.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, QueueController queue) async {
    await queue.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthView()), (route) => false);
    }
  }
}