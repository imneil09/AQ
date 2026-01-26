import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appoinmentModel.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool isAdmin;
  final VoidCallback? onStatusNext;
  final VoidCallback? onSkip;
  final VoidCallback? onCancel;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.isAdmin = false,
    this.onStatusNext,
    this.onSkip,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    // Format: "10:30 AM"
    final timeStr = appointment.estimatedTime != null
        ? DateFormat('hh:mm a').format(appointment.estimatedTime!)
        : "Calculating...";

    final dateStr = DateFormat('MMM d').format(appointment.appointmentDate);

    // Dynamic styling based on Status
    Color cardColor;
    Color avatarColor;
    IconData statusIcon;

    switch (appointment.status) {
      case AppointmentStatus.inProgress:
        cardColor = Colors.green.shade50;
        avatarColor = Colors.green;
        statusIcon = Icons.medical_services;
        break;
      case AppointmentStatus.missed: // Previously 'skipped'
        cardColor = Colors.orange.shade50;
        avatarColor = Colors.orange;
        statusIcon = Icons.history;
        break;
      case AppointmentStatus.completed:
        cardColor = Colors.grey.shade100;
        avatarColor = Colors.grey;
        statusIcon = Icons.check;
        break;
      default: // Waiting
        cardColor = Colors.white;
        avatarColor = Colors.blue;
        statusIcon = Icons.person;
    }

    return Card(
      elevation: appointment.status == AppointmentStatus.inProgress ? 4 : 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Token / Status Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                "#${appointment.tokenNumber}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: avatarColor,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        "$timeStr • $dateStr",
                        style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Text(
                    appointment.serviceType,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),

            // Admin Actions
            if (isAdmin) _buildAdminControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (appointment.status == AppointmentStatus.waiting)
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, color: Colors.orange),
            tooltip: "Mark Missed",
            onPressed: onSkip,
          ),

        if (appointment.status != AppointmentStatus.missed && appointment.status != AppointmentStatus.completed)
          IconButton(
            icon: Icon(
              appointment.status == AppointmentStatus.inProgress
                  ? Icons.check_circle_rounded
                  : Icons.play_arrow_rounded,
              color: appointment.status == AppointmentStatus.inProgress
                  ? Colors.green
                  : Colors.blue,
            ),
            onPressed: onStatusNext,
          ),

        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'cancel',
              child: Row(children: [Icon(Icons.delete_outline, color: Colors.red), SizedBox(width: 8), Text('Cancel')]),
            ),
          ],
          onSelected: (val) {
            if (val == 'cancel') onCancel?.call();
          },
        ),
      ],
    );
  }
}