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
    // Format Time: if active "NOW", else "10:30 AM"
    String timeStr;
    if (appointment.status == AppointmentStatus.inProgress) {
      timeStr = "NOW";
    } else if (appointment.estimatedTime != null) {
      timeStr = DateFormat('hh:mm a').format(appointment.estimatedTime!);
    } else {
      timeStr = "Calculating...";
    }

    // Dynamic Colors based on status
    Color color;
    Color bgColor;

    switch (appointment.status) {
      case AppointmentStatus.inProgress:
        color = Colors.green;
        bgColor = Colors.green.shade50;
        break;
      case AppointmentStatus.missed:
        color = Colors.orange;
        bgColor = Colors.orange.shade50;
        break;
      case AppointmentStatus.completed:
        color = Colors.grey;
        bgColor = Colors.grey.shade100;
        break;
      default:
        color = Colors.blue;
        bgColor = Colors.white;
    }

    return Card(
      elevation: appointment.status == AppointmentStatus.inProgress ? 4 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Token Box
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text("#${appointment.tokenNumber}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            ),
            const SizedBox(width: 16),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appointment.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("$timeStr • ${appointment.serviceType}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                ],
              ),
            ),

            // Admin Controls
            if (isAdmin)
              Row(
                children: [
                  // Only show "Miss" button if waiting
                  if (appointment.status == AppointmentStatus.waiting)
                    IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.orange), onPressed: onSkip),

                  // Show "Next/Complete" unless already done/missed
                  if (appointment.status != AppointmentStatus.missed && appointment.status != AppointmentStatus.completed)
                    IconButton(
                        icon: Icon(
                            appointment.status == AppointmentStatus.inProgress ? Icons.check_circle : Icons.play_arrow,
                            color: color
                        ),
                        onPressed: onStatusNext
                    ),

                  // More menu for cancel
                  PopupMenuButton(
                    itemBuilder: (context) => [const PopupMenuItem(value: 'c', child: Text('Cancel Appointment'))],
                    onSelected: (v) => onCancel?.call(),
                  )
                ],
              ),
          ],
        ),
      ),
    );
  }
}