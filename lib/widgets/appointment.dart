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
    final bool isDone = appointment.status == AppointmentStatus.completed;
    final bool isActive = appointment.status == AppointmentStatus.inProgress;
    final Color accentColor = isActive ? const Color(0xFF10B981) : const Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isActive ? 0.15 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: accentColor.withOpacity(isActive ? 0.3 : 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Visual Indicator Strip
              Container(width: 6, color: accentColor),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text("TOKEN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[400])),
                    Text("#${appointment.tokenNumber}",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: accentColor)),
                  ],
                ),
              ),

              const VerticalDivider(width: 1, indent: 20, endIndent: 20),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(appointment.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? "NOW" : DateFormat('hh:mm a').format(appointment.estimatedTime ?? DateTime.now()),
                            style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(" • ${appointment.serviceType}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isAdmin && !isDone)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      if (appointment.status == AppointmentStatus.waiting)
                        IconButton(
                          icon: const Icon(Icons.forward_rounded, color: Colors.orangeAccent),
                          onPressed: onSkip,
                        ),
                      IconButton(
                        icon: Icon(isActive ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
                            color: accentColor, size: 32),
                        onPressed: onStatusNext,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}