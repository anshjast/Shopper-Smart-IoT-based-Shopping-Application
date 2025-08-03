import 'package:flutter/material.dart';
import 'package:easy_upi_payment/easy_upi_payment.dart';

class PaymentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;
  final String username;

  const PaymentScreen({
    Key? key,
    required this.cartItems,
    required this.totalAmount,
    required this.username,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _transactionStatus;
  bool _isLoading = false;

  String formatPrice(dynamic price) {
    if (price == null) return '₹0.00';
    return '₹${price.toStringAsFixed(2)}';
  }

  Future<void> _initiateTransaction() async {
    setState(() => _isLoading = true);

    try {
      final response = await EasyUpiPaymentPlatform.instance.startPayment(
        EasyUpiPaymentModel(
          payeeVpa: 'yourmerchant@upi', // Replace with your UPI ID
          payeeName: 'Your Store Name',
          amount: widget.totalAmount,
          description: 'Order Payment',
        ),
      );

      setState(() {
        _transactionStatus = response?.responseCode ?? 'Unknown';
        _isLoading = false;
      });

      if (_transactionStatus == '00' || _transactionStatus == 'SUCCESS') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction Successful')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction Failed: $_transactionStatus')),
        );
      }
    } catch (e) {
      setState(() {
        _transactionStatus = 'Error: $e';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment"),
        backgroundColor: Colors.deepPurple,
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
                ...widget.cartItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${item['name']} x ${item['quantity']}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        formatPrice((item['price'] ?? 0) * (item['quantity'] ?? 1)),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )).toList(),
                const Divider(thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Amount",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatPrice(widget.totalAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Payment Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "Pay Using UPI",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _initiateTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Pay Now",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  if (_transactionStatus != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (_transactionStatus == '00' || _transactionStatus == 'SUCCESS')
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (_transactionStatus == '00' || _transactionStatus == 'SUCCESS')
                                ? Icons.check_circle
                                : Icons.error,
                            color: (_transactionStatus == '00' || _transactionStatus == 'SUCCESS')
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Status: $_transactionStatus",
                              style: TextStyle(
                                fontSize: 16,
                                color: (_transactionStatus == '00' || _transactionStatus == 'SUCCESS')
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
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
