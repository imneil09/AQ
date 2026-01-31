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
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Deep Slate Base
          Container(color: const Color(0xFF0F172A)),

          // High-End Mesh Accent Blurs
          Positioned(
            top: -100,
            right: -100,
            child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.2), size: 400),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: _BlurCircle(color: const Color(0xFFF43F5E).withOpacity(0.15), size: 350),
          ),
          Positioned(
            top: 300,
            left: 50,
            child: _BlurCircle(color: const Color(0xFF10B981).withOpacity(0.1), size: 200),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, isAdmin),

              // NEW: History Search Bar
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    onChanged: (val) => queue.updateHistorySearch(val),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    cursorColor: const Color(0xFF6366F1),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Search records...",
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
                      icon: Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                    ),
                  ),
                ),
              ),

              StreamBuilder<List<Appointment>>(
                stream: historyStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
                    );
                  }
                  final appointments = snapshot.data ?? [];
                  if (appointments.isEmpty) return _buildEmptyState();

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
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
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
        title: Text(
          isAdmin ? "Clinic Records" : "My History",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 28,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.white24),
            ),
            const SizedBox(height: 20),
            const Text(
              "No past records yet",
              style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
              gradient: LinearGradient(
                colors: [
                  statusColor.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                _StatusIndicator(status: appt.status, color: statusColor),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.customerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${appt.serviceType} • ${DateFormat('MMM dd, yyyy').format(appt.appointmentDate)}",
                          style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
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
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        fontSize: 24,
                        shadows: [Shadow(color: statusColor.withOpacity(0.3), blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appt.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 1.5,
                      ),
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
      case AppointmentStatus.completed: return const Color(0xFF10B981); // Emerald
      case AppointmentStatus.skipped: return const Color(0xFFF59E0B);   // UPDATED: Amber for Skipped
      case AppointmentStatus.cancelled: return const Color(0xFFF43F5E); // Rose
      default: return const Color(0xFF6366F1);                          // Indigo
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
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
      case AppointmentStatus.completed: icon = Icons.check_circle_rounded; break;
      case AppointmentStatus.skipped: icon = Icons.timer_off_rounded; break; // UPDATED
      case AppointmentStatus.cancelled: icon = Icons.cancel_rounded; break;
      default: icon = Icons.hourglass_full_rounded;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}