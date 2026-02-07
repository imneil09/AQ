import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
      // Standard App Bar to match other pages
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? "Patient's Records" : "My Visits",
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFF0F172A)),

          // Background Accents
          Positioned(top: -100, right: -100, child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.15), size: 400)),
          Positioned(bottom: -50, left: -100, child: _BlurCircle(color: const Color(0xFFF43F5E).withOpacity(0.1), size: 350)),

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
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                      }

                      var appointments = snapshot.data ?? [];

                      if (_activeFilter != 'ALL') {
                        appointments = appointments.where((a) => a.status.name.toUpperCase() == _activeFilter).toList();
                      }

                      if (appointments.isEmpty) return _buildEmptyState();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        physics: const BouncingScrollPhysics(),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) => _GlassHistoryCard(
                            appt: appointments[index],
                            showPhone: widget.isAdmin
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
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
    );
  }

  Widget _buildFilters() {
    final filters = ['ALL', 'COMPLETED', 'CANCELLED'];
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          bool isActive = _activeFilter == filters[index];
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filters[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? Colors.transparent : Colors.white.withOpacity(0.07)),
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

class _GlassHistoryCard extends StatelessWidget {
  final Appointment appt;
  final bool showPhone;
  const _GlassHistoryCard({required this.appt, required this.showPhone});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appt.status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.01)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _StatusIcon(status: appt.status, color: statusColor),
                const SizedBox(width: 16),
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
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed: return const Color(0xFF10B981);
      case AppointmentStatus.cancelled: return const Color(0xFFF43F5E);
      default: return const Color(0xFF6366F1);
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final AppointmentStatus status;
  final Color color;
  const _StatusIcon({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (status) {
      case AppointmentStatus.completed: icon = Icons.check_rounded; break;
      case AppointmentStatus.cancelled: icon = Icons.close_rounded; break;
      default: icon = Icons.history_rounded;
    }
    return Container(
      height: 46, width: 46,
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _BlurCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: Container(color: Colors.transparent)),
    );
  }
}