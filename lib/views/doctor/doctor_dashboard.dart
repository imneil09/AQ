import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../../widgets/app_colors.dart'; // Import DRY Colors
import '../authView.dart';
import 'prescription_view.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;

  // Sidebar animation state
  bool _isWorkspaceHovered = false;
  static const double _sidebarExpandedWidth = 320.0;
  static const double _sidebarMinimizedWidth = 80.0;

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);
    final activePatient = queue.activeQueue.isNotEmpty ? queue.activeQueue.first : null;

    return Scaffold(
      backgroundColor: AppColors.background, // DRY: Standard Background
      appBar: _buildModernAppBar(context, queue),
      body: Row(
        children: [
          // 1. Left Sidebar: Live Queue Monitor with Animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isWorkspaceHovered ? _sidebarMinimizedWidth : _sidebarExpandedWidth,
            child: _buildLiveQueueSidebar(queue, activePatient),
          ),

          // 2. Right Content Area: Workspace wrapped in MouseRegion
          Expanded(
            flex: 4,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isWorkspaceHovered = true),
              onExit: (_) => setState(() => _isWorkspaceHovered = false),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface, // DRY: Standard Surface
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
              Text("Live Dashboard",
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
                decoration: const InputDecoration(hintText: "Search patient...", border: InputBorder.none, hintStyle: TextStyle(color: Colors.white24)),
                onChanged: (v) => queue.updateHistorySearch(v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveQueueSidebar(QueueController queue, Appointment? active) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isWorkspaceHovered)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text("UPCOMING QUEUE",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.5)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: queue.waitingList.length,
              itemBuilder: (context, index) {
                final appt = queue.waitingList[index];
                return _buildQueueCard(appt, false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueCard(Appointment appt, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isActive ? Colors.white24 : AppColors.primary.withOpacity(0.2),
            child: Text("${appt.tokenNumber}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (!_isWorkspaceHovered) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(appt.serviceType,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainWorkspace(QueueController queue, Appointment? active) {
    if (_isSearching && _searchCtrl.text.isNotEmpty) return _buildSearchResults(queue);

    if (active != null) {
      return PrescriptionView(
        patient: active,
        onFinish: () => queue.updateStatus(active.id, AppointmentStatus.completed),
      );
    }

    return _buildIdleState();
  }

  Widget _buildIdleState() {
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
          const Text("Workspace Ready", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text("Click 'Call Next' on the assistant panel to begin", style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _buildBreakToggle(QueueController queue) {
    // Note: Kept specific colors for Break/Active logic as they represent states,
    // but used AppColors.success/error where applicable logic aligns.
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
            Icon(onBreak ? Icons.coffee : Icons.play_circle_fill,
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
          const Icon(Icons.coffee_outlined, size: 80, color: Colors.amber),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
    );
  }

  Future<void> _handleLogout(BuildContext context, QueueController queue) async {
    await queue.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthView()), (route) => false);
    }
  }
}