import 'dart:ui';
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
    final bool isMissed = appointment.status == AppointmentStatus.missed;

    // Dynamic Color Palette
    final Color accentColor = isMissed
        ? const Color(0xFFF43F5E) // Rose for missed
        : (isActive ? const Color(0xFF10B981) : const Color(0xFF6366F1)); // Emerald for active, Indigo for waiting

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: accentColor.withOpacity(isActive ? 0.4 : 0.1),
                width: 1.5,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: accentColor.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: -5,
                  )
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Left Accent Branding Strip
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      boxShadow: [
                        BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 10)
                      ],
                    ),
                  ),

                  // Token Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "TOKEN",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "#${appointment.tokenNumber}",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            shadows: [
                              Shadow(color: accentColor.withOpacity(0.3), blurRadius: 12)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Elegant Vertical Divider
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    color: Colors.white.withOpacity(0.1),
                  ),

                  // Info Content Section
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            appointment.customerName.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: accentColor.withOpacity(0.7)),
                              const SizedBox(width: 6),
                              Text(
                                isActive ? "NOW" : DateFormat('hh:mm a').format(appointment.estimatedTime ?? DateTime.now()),
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                " • ${appointment.serviceType}",
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Admin Quick Actions
                  if (isAdmin && !isDone)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        children: [
                          if (appointment.status == AppointmentStatus.waiting)
                            _buildActionButton(
                              icon: Icons.fast_forward_rounded,
                              color: Colors.amberAccent,
                              onTap: onSkip,
                            ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            icon: isActive ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                            color: accentColor,
                            isLarge: true,
                            onTap: onStatusNext,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isLarge ? 12 : 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: isLarge ? 28 : 20),
      ),
    );
  }
}