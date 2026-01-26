import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/queueController.dart';
import '../models/appoinmentModel.dart';

class HistoryView extends StatelessWidget {
  final bool isAdmin;
  const HistoryView({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);
    final historyStream = isAdmin ? queue.adminFullHistory : queue.customerHistory;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Base
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Vivid accent blurs for Glassmorphism effect
          Positioned(
            top: -50,
            right: -50,
            child: _BlurCircle(color: Colors.indigo.withOpacity(0.3), size: 250),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _BlurCircle(color: Colors.redAccent.withOpacity(0.2), size: 300),
          ),

          CustomScrollView(
            slivers: [
              _buildAppBar(context, isAdmin),
              StreamBuilder<List<Appointment>>(
                stream: historyStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                  }
                  final appointments = snapshot.data ?? [];
                  if (appointments.isEmpty) return _buildEmptyState();

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _GlassHistoryCard(appt: appointments[index]),
                        childCount: appointments.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isAdmin) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(isAdmin ? "Clinic Records" : "My History",
            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 24)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text("No past records yet", style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _GlassHistoryCard extends StatelessWidget {
  final Appointment appt;
  const _GlassHistoryCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appt.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
            ),
            child: Row(
              children: [
                _StatusIndicator(status: appt.status, color: statusColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appt.customerName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text("${appt.serviceType} • ${DateFormat('MMM dd').format(appt.appointmentDate)}",
                          style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("#${appt.tokenNumber}",
                        style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 20)),
                    Text(appt.status.name.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
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
      case AppointmentStatus.completed: return Colors.purple;
      case AppointmentStatus.missed: return Colors.orangeAccent;
      case AppointmentStatus.cancelled: return Colors.redAccent;
      default: return Colors.lightBlueAccent;
    }
  }
}

class _BlurCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _BlurCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final AppointmentStatus status;
  final Color color;
  const _StatusIndicator({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (status) {
      case AppointmentStatus.completed: icon = Icons.check_circle_outline; break;
      case AppointmentStatus.missed: icon = Icons.timer_off_outlined; break;
      case AppointmentStatus.cancelled: icon = Icons.block_flipped; break;
      default: icon = Icons.hourglass_empty_rounded;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 24),
    );
  }
}