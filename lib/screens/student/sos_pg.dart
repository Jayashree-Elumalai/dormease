import 'package:flutter/material.dart';

class SosPage extends StatelessWidget {
  const SosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: const Text(
          'SOS',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 60),
            shape: const CircleBorder(),
            elevation: 8,
          ),
          onPressed: () {
            // TODO: Add your SOS alert logic here (e.g., push notification, Firestore update)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("🚨 SOS Alert Sent!")),
            );
          },
          child: const Text(
            "SOS",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
