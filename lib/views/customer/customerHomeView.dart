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
      appBar: AppBar(
        title: const Text("My Visits"),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.history_rounded, color: Color(0xFF6366F1), size: 20),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryView(isAdmin: false))),
          ),
          IconButton(icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)), onPressed: _logout),
        ],
      ),
      body: myAppt == null ? _buildEmptyState() : _buildTicketState(myAppt, queue),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20)]),
            child: const Icon(Icons.calendar_month_rounded, size: 60, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          const Text("No Active Visits", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          const Text("Join the queue or book for later", style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 40),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                _actionBtn("Join Live Queue", "I am near the clinic", Icons.flash_on_rounded, Colors.white, const Color(0xFF2563EB),
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerJoinView(isBooking: false)))),
                const SizedBox(height: 16),
                _actionBtn("Book Appointment", "Schedule for a future date", Icons.event_rounded, const Color(0xFFEFF6FF), const Color(0xFF1E3A8A),
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerJoinView(isBooking: true)))),
                const SizedBox(height: 16),
                _actionBtn("Visit Records", "Track all your past visits", Icons.auto_stories_rounded, const Color(0xFFF1F5F9), const Color(0xFF6366F1),
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryView(isAdmin: false)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String title, String subtitle, IconData icon, Color bgColor, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: textColor.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7))),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: textColor.withOpacity(0.5))
        ]),
      ),
    );
  }

  Widget _buildTicketState(Appointment appt, QueueController queue) {
    bool inProgress = appt.status == AppointmentStatus.inProgress;
    bool isMissed = appt.status == AppointmentStatus.missed;

    Color statusColor = isMissed ? const Color(0xFFEF4444) : (inProgress ? const Color(0xFF10B981) : const Color(0xFF2563EB));
    String statusText = isMissed ? "MISSED" : (inProgress ? "YOUR TURN" : "IN QUEUE");

    String timeDisplay = inProgress ? "NOW" : (appt.estimatedTime != null ? DateFormat('hh:mm a').format(appt.estimatedTime!) : "Checking...");

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20))]),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: statusColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
              child: Row(children: [
                Icon(isMissed ? Icons.warning_rounded : Icons.confirmation_number_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const Spacer(),
                Text(DateFormat('MMM d').format(appt.appointmentDate), style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold))
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                const Text("TOKEN NUMBER", style: TextStyle(color: Color(0xFF64748B), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                Text("#${appt.tokenNumber}", style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: statusColor, height: 1.0)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    const Text("ESTIMATED TIME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(timeDisplay, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor)),
                  ]),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 20),
                _infoRow("PATIENT", appt.customerName),
                const SizedBox(height: 12),
                _infoRow("SERVICE", appt.serviceType),
                const SizedBox(height: 12),
                _infoRow("CLINIC", queue.selectedClinic?.name ?? "Main Clinic"),
                if (isMissed) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFEE2E2))),
                    child: const Row(children: [
                      Icon(Icons.info_rounded, color: Color(0xFFEF4444)),
                      SizedBox(width: 12),
                      Expanded(child: Text("You missed your turn. Please see the receptionist.", style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600)))
                    ]),
                  )
                ]
              ]),
            )
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 13)),
      Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
    ]);
  }
}