import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appoinmentModel.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final int? index; // Display "Token Number" or Queue Position
  final bool isAdmin;
  final VoidCallback? onStatusNext;
  final VoidCallback? onSkip;
  final VoidCallback? onCancel;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.index,
    this.isAdmin = false,
    this.onStatusNext,
    this.onSkip,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(appointment.bookingTime);

    // Dynamic styling based on Status
    Color cardColor;
    Color avatarColor;
    IconData statusIcon;

    switch (appointment.status) {
      case AppointmentStatus.inProgress:
        cardColor = Colors.green.shade50;
        avatarColor = Colors.green;
        statusIcon = Icons.cut;
        break;
      case AppointmentStatus.skipped:
        cardColor = Colors.orange.shade50;
        avatarColor = Colors.orange;
        statusIcon = Icons.history;
        break;
      case AppointmentStatus.completed:
        cardColor = Colors.grey.shade200;
        avatarColor = Colors.grey;
        statusIcon = Icons.check;
        break;
      default: // Waiting
        cardColor = Colors.white;
        avatarColor = Colors.blue;
        statusIcon = Icons.person;
    }

    return Card(
      elevation: appointment.status == AppointmentStatus.inProgress ? 4 : 1,
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarColor,
          foregroundColor: Colors.white,
          child: index != null
              ? Text("#${index! + 1}", style: const TextStyle(fontWeight: FontWeight.bold))
              : Icon(statusIcon),
        ),
        title: Text(
          appointment.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${appointment.serviceType} • $timeStr'),
            if (appointment.skipCount > 0)
              Text(
                "Skipped ${appointment.skipCount} times",
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: isAdmin ? _buildAdminControls() : _buildCustomerStatus(),
      ),
    );
  }

  // --- Admin Actions (Skip, Next, Cancel) ---
  Widget _buildAdminControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. SKIP BUTTON (Only if waiting)
        if (appointment.status == AppointmentStatus.waiting)
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.orange),
            tooltip: "Skip (Park User)",
            onPressed: onSkip,
          ),

        // 2. NEXT / COMPLETE BUTTON
        if (appointment.status != AppointmentStatus.skipped)
          IconButton(
            icon: Icon(
              appointment.status == AppointmentStatus.inProgress
                  ? Icons.check_circle
                  : Icons.play_arrow,
              color: appointment.status == AppointmentStatus.inProgress
                  ? Colors.green
                  : Colors.blue,
            ),
            tooltip: appointment.status == AppointmentStatus.inProgress
                ? "Finish Service"
                : "Call Customer",
            onPressed: onStatusNext,
          ),

        // 3. MORE MENU (Cancel)
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'cancel',
              child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Cancel Appointment')]),
            ),
          ],
          onSelected: (val) {
            if (val == 'cancel') onCancel?.call();
          },
        ),
      ],
    );
  }

  // --- Customer View (Read Only) ---
  Widget? _buildCustomerStatus() {
    if (appointment.status == AppointmentStatus.inProgress) {
      return const Chip(
        label: Text("Serving", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      );
    }
    return null; // Standard list view
  }
}