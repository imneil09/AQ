import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import 'customerJoinView.dart'; // Ensure filename matches this EXACTLY

class CustomerHomeView extends StatelessWidget {
  const CustomerHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<QueueController>(context);
    final myAppt = controller.myAppointment;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("QueuePro", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Logout button just in case you need it
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {},
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (myAppt == null)
              _buildJoinOptions(context)
            else
              _buildRadarTicket(context, myAppt, controller),

            const SizedBox(height: 30),

            const Align(alignment: Alignment.centerLeft, child: Text("Live Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),

            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: controller.waitingQueue.isEmpty
                    ? const Center(child: Text("Queue is empty"))
                    : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: controller.waitingQueue.length,
                  separatorBuilder: (_,__) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final appt = controller.waitingQueue[index];
                    final isMe = appt.id == controller.currentCustomerId;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isMe ? const Color(0xFF2E3192) : Colors.grey[200],
                        child: Text("${index + 1}", style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                      ),
                      title: Text(isMe ? "YOU" : appt.customerName, style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text("Est. Service: ${10 + (index * 15)} mins"),
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRadarTicket(BuildContext context, Appointment appt, QueueController controller) {
    if (appt.status == AppointmentStatus.skipped) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red)),
        child: Row(children: [
          const Icon(Icons.warning, color: Colors.red, size: 30),
          const SizedBox(width: 15),
          const Expanded(child: Text("You were skipped! Please speak to the receptionist to be recalled.", style: TextStyle(color: Colors.red)))
        ]),
      );
    }

    int myIndex = controller.waitingQueue.indexWhere((a) => a.id == appt.id);
    bool isNext = myIndex == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E3192), Color(0xFF00D4FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF2E3192).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Text(isNext ? "YOU ARE NEXT!" : "YOU ARE #${myIndex + 1}",
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(controller.getEstimatedWaitTime(appt),
              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          const Text("Estimated Wait Time", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          if (myIndex < 3 && myIndex >= 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_walk, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text("Stay close to the store", style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildJoinOptions(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _btn(context, "Join Queue", Icons.flash_on, false)),
        const SizedBox(width: 16),
        Expanded(child: _btn(context, "Book Later", Icons.calendar_today, true)),
      ],
    );
  }

  Widget _btn(BuildContext context, String title, IconData icon, bool booking) {
    return GestureDetector(
      // FIX: Ensure 'CustomerJoinView' matches the class name exactly
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerJoinView(isBooking: booking))),
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: const Color(0xFF2E3192)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }
}