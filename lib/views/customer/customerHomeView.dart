import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../historyView.dart';
import 'customerJoinView.dart';
import '../authView.dart';

class CustomerHomeView extends StatefulWidget {
  const CustomerHomeView({super.key});
  @override
  State<CustomerHomeView> createState() => _CustomerHomeViewState();
}

class _CustomerHomeViewState extends State<CustomerHomeView> {
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthView()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);
    final myAppt = queue.myAppointment;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("My Visits", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.history_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryView(isAdmin: false))),
          ),
          IconButton(icon: const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E)), onPressed: _logout),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background Base
          Container(color: const Color(0xFF0F172A)),

          // Blurred Accents
          Positioned(top: -50, right: -50, child: _BlurCircle(color: const Color(0xFF6366F1).withOpacity(0.2), size: 300)),
          Positioned(bottom: 100, left: -80, child: _BlurCircle(color: const Color(0xFF10B981).withOpacity(0.1), size: 250)),

          SafeArea(
            child: myAppt == null ? _buildEmptyState() : _buildTicketState(myAppt, queue),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.calendar_month_rounded, size: 60, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 32),
            const Text("No Active Visits", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
            const SizedBox(height: 8),
            Text("Ready for your next checkup?", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)),
            const SizedBox(height: 48),

            _actionBtn("Join Live Queue", "I am near the clinic", Icons.flash_on_rounded, const Color(0xFF6366F1)),
            const SizedBox(height: 16),
            _actionBtn("Book Appointment", "Schedule for later", Icons.event_rounded, const Color(0xFF10B981)),
            const SizedBox(height: 16),
            _actionBtn("Visit Records", "Track past visits", Icons.auto_stories_rounded, const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String title, String subtitle, IconData icon, Color accentColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onTap: () {
              bool isBooking = title.contains("Book");
              bool isHistory = title.contains("Records");
              if (isHistory) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryView(isAdmin: false)));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerJoinView(isBooking: isBooking)));
              }
            },
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: accentColor),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17)),
            subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketState(Appointment appt, QueueController queue) {
    bool inProgress = appt.status == AppointmentStatus.inProgress;
    bool isMissed = appt.status == AppointmentStatus.missed;

    Color statusColor = isMissed ? const Color(0xFFF43F5E) : (inProgress ? const Color(0xFF10B981) : const Color(0xFF6366F1));
    String statusText = isMissed ? "MISSED" : (inProgress ? "YOUR TURN" : "IN QUEUE");
    String timeDisplay = inProgress ? "NOW" : (appt.estimatedTime != null ? DateFormat('hh:mm a').format(appt.estimatedTime!) : "CALCULATING...");

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Ticket Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.2))),
                  ),
                  child: Row(
                    children: [
                      Icon(isMissed ? Icons.warning_rounded : Icons.confirmation_number_rounded, color: statusColor),
                      const SizedBox(width: 12),
                      Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
                      const Spacer(),
                      Text(DateFormat('MMM dd').format(appt.appointmentDate), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Ticket Body
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Text("TOKEN NUMBER", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text("#${appt.tokenNumber}", style: TextStyle(fontSize: 84, fontWeight: FontWeight.w900, color: statusColor, height: 1.0, shadows: [Shadow(color: statusColor.withOpacity(0.5), blurRadius: 20)])),
                      const SizedBox(height: 48),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
                        child: Column(
                          children: [
                            const Text("ESTIMATED WAIT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(timeDisplay, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: statusColor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      _infoRow("PATIENT", appt.customerName),
                      const Divider(height: 32, color: Colors.white10),
                      _infoRow("SERVICE", appt.serviceType),
                      const Divider(height: 32, color: Colors.white10),
                      _infoRow("CLINIC", queue.selectedClinic?.name ?? "Main Clinic"),
                      if (isMissed) ...[
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFFF43F5E).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.2))),
                          child: const Row(
                            children: [
                              Icon(Icons.info_rounded, color: Color(0xFFF43F5E)),
                              SizedBox(width: 12),
                              Expanded(child: Text("You missed your turn. Please see the receptionist.", style: TextStyle(color: Color(0xFFF43F5E), fontSize: 13, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
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
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
    );
  }
}