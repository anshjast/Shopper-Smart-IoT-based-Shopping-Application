import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ReceiptScreen extends StatelessWidget {
  final String receiptToken; // The secure JWT from the Python backend

  const ReceiptScreen({Key? key, required this.receiptToken}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Secure Receipt", style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Payment Successful!",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Scan this QR code at the exit gate for verification.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              const SizedBox(height: 30),
              // This widget generates the QR code from the JWT string
              QrImageView(
                data: receiptToken,
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // Navigate back to the dashboard
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text("Back to Dashboard"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}