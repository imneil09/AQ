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
  Stream<List<Appointment>>? _searchStream;

  String? _selectedPatientId;
  final Map<String, Map<String, dynamic>> _drafts = {};

  bool _isWorkspaceHovered = false;
  static const double _sidebarExpandedWidth = 330.0; // Slightly wider for action buttons
  static const double _sidebarMinimizedWidth = 90.0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- NEW: Vitals Popup Workflow ---
  Future<void> _showVitalsDialog(BuildContext context, Appointment appt, QueueController queue, {bool moveToActiveAfter = false}) async {
    final bpCtrl = TextEditingController(text: appt.vitals?['bp'] ?? '');
    final tempCtrl = TextEditingController(text: appt.vitals?['temp'] ?? '');
    final weightCtrl = TextEditingController(text: appt.vitals?['weight'] ?? '');
    final spo2Ctrl = TextEditingController(text: appt.vitals?['spo2'] ?? '');

    await showDialog(
        context: context,
        barrierDismissible: !moveToActiveAfter, // Prevent accidental dismissal during move
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.glassWhite)),
            title: Row(
              children: [
                const Icon(Icons.monitor_heart, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text("Vitals - ${appt.customerName}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildVitalInput(bpCtrl, "Blood Pressure", "e.g. 120/80 mmHg"),
                  const SizedBox(height: 12),
                  _buildVitalInput(tempCtrl, "Temperature", "e.g. 98.6 °F"),
                  const SizedBox(height: 12),
                  _buildVitalInput(weightCtrl, "Weight", "e.g. 70 kg"),
                  const SizedBox(height: 12),
                  _buildVitalInput(spo2Ctrl, "SpO2", "e.g. 98%"),
                ],
              ),
            ),
            actions: [
              if (moveToActiveAfter)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    queue.setPatientActive(appt.id); // SKIP & proceed to cabin
                  },
                  child: const Text("SKIP", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                )
              else
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: () async {
                  Map<String, dynamic> data = {};
                  if (bpCtrl.text.isNotEmpty) data['bp'] = bpCtrl.text.trim();
                  if (tempCtrl.text.isNotEmpty) data['temp'] = tempCtrl.text.trim();
                  if (weightCtrl.text.isNotEmpty) data['weight'] = weightCtrl.text.trim();
                  if (spo2Ctrl.text.isNotEmpty) data['spo2'] = spo2Ctrl.text.trim();

                  await queue.saveVitals(appt.id, data);
                  if (context.mounted) Navigator.pop(context);

                  if (moveToActiveAfter) {
                    queue.setPatientActive(appt.id); // Send to cabin after saving
                  }
                },
                child: Text(moveToActiveAfter ? "SAVE & SEND" : "SAVE VITALS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
    );
  }

  Widget _buildVitalInput(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // --- Smart Intercept Method ---
  void _handleMoveToCabin(BuildContext context, Appointment appt, QueueController queue) {
    if (appt.vitals == null || appt.vitals!.isEmpty) {
      // Intercept and ask for vitals first
      _showVitalsDialog(context, appt, queue, moveToActiveAfter: true);
    } else {
      // Proceed directly
      queue.setPatientActive(appt.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);

    final activeList = queue.activeQueue;
    Appointment? activePatient;

    if (activeList.isNotEmpty) {
      if (_selectedPatientId == null || !activeList.any((a) => a.id == _selectedPatientId)) {
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
            final bool isSmallScreen = constraints.maxWidth < 900;
            final double targetSidebarWidth = isSmallScreen
                ? _sidebarMinimizedWidth
                : (_isWorkspaceHovered ? _sidebarMinimizedWidth : _sidebarExpandedWidth);

            return Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: targetSidebarWidth,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final bool effectiveCollapsed = box.maxWidth < 180;
                      return _buildLiveQueueSidebar(queue, activePatient, effectiveCollapsed);
                    },
                  ),
                ),
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
        _buildSearchBox(context, queue),
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

  Widget _buildSearchBox(BuildContext context, QueueController queue) {
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
              if (_isSearching) {
                _searchStream = queue.getHistoryStream(
                  isAssistant: true,
                  startDate: DateTime.now().subtract(const Duration(days: 90)),
                  endDate: DateTime.now(),
                );
              } else {
                _searchCtrl.clear();
                _searchStream = null;
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
                onChanged: (_) => setState(() {}),
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
                  child: _buildQueueCard(appt, true, isCollapsed, queue, isSelected: isSelected),
                );
              },
            ),
            Divider(color: Colors.white.withOpacity(0.1), height: 32),
          ],

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
                return _buildQueueCard(appt, false, isCollapsed, queue);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- REFACTORED: Sidebar Cards Now Have Vitals Buttons ---
  Widget _buildQueueCard(Appointment appt, bool isActiveList, bool isCollapsed, QueueController queue, {bool isSelected = false}) {
    Color cardColor;
    if (isActiveList) {
      cardColor = isSelected ? AppColors.success : AppColors.success.withOpacity(0.2);
    } else {
      cardColor = Colors.white.withOpacity(0.03);
    }

    final hasVitals = appt.vitals != null && appt.vitals!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isCollapsed ? 12 : 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: AppColors.success, width: 2) : null,
      ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt.customerName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(isActiveList ? "In Cabin" : appt.serviceType, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),

            // 1. Vitals Button
            InkWell(
              onTap: () => _showVitalsDialog(context, appt, queue),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: hasVitals ? AppColors.success.withOpacity(0.15) : Colors.white10,
                    borderRadius: BorderRadius.circular(8)
                ),
                child: Icon(hasVitals ? Icons.monitor_heart : Icons.monitor_heart_outlined,
                    size: 18, color: hasVitals ? AppColors.success : Colors.white54),
              ),
            ),

            // 2. Direct "Move to Cabin" Button (Only for Waiting List)
            if (!isActiveList) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _handleMoveToCabin(context, appt, queue),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppColors.primary),
                ),
              ),
            ]
          ],
        ],
      ),
    );
  }

  Widget _buildMainWorkspace(QueueController queue, Appointment? active) {
    if (_isSearching) return _buildSearchResults(queue);

    if (active != null) {
      return PrescriptionView(
        key: ValueKey(active.id),
        patient: active,
        initialDraft: _drafts[active.id],
        onDraftChanged: (newData) {
          _drafts[active.id] = newData;
        },
        onFinish: () {
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
              // --- INTERCEPT CALL NEXT PATIENT ---
              onPressed: () {
                final nextAppt = queue.waitingList.first;
                _handleMoveToCabin(context, nextAppt, queue);
              },
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
    if (_searchStream == null) return const SizedBox.shrink();

    return StreamBuilder<List<Appointment>>(
      stream: _searchStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Error loading search data.", style: TextStyle(color: AppColors.error)));
        }

        final query = _searchCtrl.text.trim().toLowerCase();
        var results = snapshot.data ?? [];

        if (query.isNotEmpty) {
          results = results.where((a) =>
          a.customerName.toLowerCase().contains(query) ||
              a.phoneNumber.contains(query) ||
              a.tokenNumber.toString() == query
          ).toList();
        }

        if (results.isEmpty) {
          return const Center(
              child: Text("No patients found.", style: TextStyle(color: Colors.white38))
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(32),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildHistoryItem(results[i], queue),
        );
      },
    );
  }

  Widget _buildHistoryItem(Appointment appt, QueueController queue) {
    final bool isCompleted = appt.status == AppointmentStatus.completed;
    final hasVitals = appt.vitals != null && appt.vitals!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            height: 40, width: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appt.customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text("${appt.serviceType} • ${DateFormat('dd MMM yyyy, hh:mm a').format(appt.appointmentDate)}",
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),

          // History Search Vitals Button
          IconButton(
            icon: Icon(hasVitals ? Icons.monitor_heart : Icons.monitor_heart_outlined,
                color: hasVitals ? AppColors.success : Colors.white38, size: 20),
            tooltip: "View/Edit Vitals",
            onPressed: () => _showVitalsDialog(context, appt, queue),
          ),
          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: isCompleted ? AppColors.success.withOpacity(0.15) : Colors.white10,
                borderRadius: BorderRadius.circular(8)
            ),
            child: Text(
                appt.status.name.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? AppColors.success : Colors.white70
                )
            ),
          ),
        ],
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