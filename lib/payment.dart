import 'package:flutter/material.dart';
import 'package:easy_upi_payment/easy_upi_payment.dart';
import 'secure_checkout_service.dart';
import 'receipt_screen.dart';

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  final String username;
  final String txnId;

  const PaymentScreen({
    Key? key,
    required this.totalAmount,
    required this.username,
    required this.txnId,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _transactionStatus;
  bool _isLoading = false;
  final SecureCheckoutService _checkoutService = SecureCheckoutService();

  String formatPrice(dynamic price) {
    if (price == null) return '₹0.00';
    return '₹${price.toStringAsFixed(2)}';
  }

  Future<void> _initiateTransaction() async {
    setState(() => _isLoading = true);

    try {
      // 1. Initiate UPI Payment
      final response = await EasyUpiPaymentPlatform.instance.startPayment(
        EasyUpiPaymentModel(
          payeeVpa: 'yourmerchant@upi', // Replace with your UPI ID
          payeeName: 'Your Store Name',
          amount: widget.totalAmount,
          description: 'Order Payment for ${widget.txnId}',
        ),
      );

      if (!mounted) return;
      setState(() {
        _transactionStatus = response?.responseCode ?? 'Unknown';
      });

      // 2. Check if UPI was successful
      if (_transactionStatus == '00' || _transactionStatus == 'SUCCESS') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UPI Payment Successful! Finalizing...')),
        );

        // 3. Finalize transaction with our backend
        final String receiptToken = await _checkoutService.finalizeTransaction(widget.txnId);

        if (!mounted) return;
        // 4. Navigate to the Secure Receipt Screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptScreen(receiptToken: receiptToken),
          ),
              (route) => route.isFirst,
        );

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction Failed: $_transactionStatus')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _transactionStatus = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Order Summary Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Order Summary",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Amount to Pay",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatPrice(widget.totalAmount),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Transaction ID: ${widget.txnId}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          // Payment Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              // FIX: Added 'children:' parameter here
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [ // <-- This 'children:' was missing
                  const Text(
                    "Select Payment Method",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _initiateTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.payments),
                    label: Text(
                      _isLoading ? "Processing..." : "Pay with UPI",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  if (_transactionStatus != null && _transactionStatus != 'SUCCESS' && _transactionStatus != '00') ...[
                    const SizedBox(height: 20),
                    Text(
                      "Last Status: $_transactionStatus",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}