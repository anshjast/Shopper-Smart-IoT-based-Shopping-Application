import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shopper/payment.dart';
import 'scanner.dart';
import 'cart.dart';
import 'secure_checkout_service.dart';

class HomeDashboard extends StatefulWidget {
  final String username;
  final String uid;

  const HomeDashboard({
    Key? key,
    required this.username,
    required this.uid,
  }) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final SecureCheckoutService _checkoutService = SecureCheckoutService();
  bool _isCheckingOut = false;

  void _initiateSecureCheckout() async {
    setState(() => _isCheckingOut = true);

    try {
      final transactionData = await _checkoutService.createTransaction(widget.uid);
      final String txnId = transactionData['txn_id'];
      final double totalAmount = (transactionData['total_amount'] as num).toDouble();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            txnId: txnId,
            totalAmount: totalAmount,
            username: widget.username,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout Failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shopper Dashboard', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartScreen(
                    username: widget.username,
                    uid: widget.uid,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome back, ${widget.username}!',
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                _FeatureButton(
                  icon: Icons.camera_alt,
                  label: 'Scan Products (AI Scanner)',
                  color: Colors.deepPurple.shade700,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScannerScreen(username: widget.username, uid: widget.uid),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                _FeatureButton(
                  icon: Icons.payment,
                  label: 'Checkout & Pay Securely',
                  color: Colors.green.shade600,
                  onPressed: _isCheckingOut ? null : _initiateSecureCheckout,
                  child: _isCheckingOut
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    'Checkout & Pay Securely',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 20),

                _FeatureButton(
                  icon: Icons.history,
                  label: 'View Past Receipts',
                  color: Colors.blueGrey,
                  onPressed: () { /* TODO */ },
                ),
                const SizedBox(height: 20),
                _FeatureButton(
                  icon: Icons.inventory_2,
                  label: 'Manage Home Inventory',
                  color: Colors.orange.shade700,
                  onPressed: () { /* TODO */ },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final Widget? child;

  const _FeatureButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
        alignment: Alignment.centerLeft,
      ),
      icon: Icon(icon, size: 28),
      label: child ?? Text(
        label,
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }
}