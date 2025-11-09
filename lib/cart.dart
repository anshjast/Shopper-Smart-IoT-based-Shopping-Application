import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment.dart'; // We will update this navigation
import 'secure_checkout_service.dart'; // Import the service

class CartScreen extends StatefulWidget {
  final String username;
  final String uid;

  const CartScreen({
    Key? key,
    required this.username,
    required this.uid,
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SecureCheckoutService _checkoutService = SecureCheckoutService();
  bool _isCheckingOut = false;

  // --- Functions to modify cart directly in Firestore ---
  void increaseQuantity(String docId, int currentQuantity) {
    _firestore
        .collection('carts')
        .doc(widget.uid)
        .collection('items')
        .doc(docId)
        .update({'quantity': currentQuantity + 1});
  }

  void decreaseQuantity(String docId, int currentQuantity) {
    if (currentQuantity > 1) {
      _firestore
          .collection('carts')
          .doc(widget.uid)
          .collection('items')
          .doc(docId)
          .update({'quantity': currentQuantity - 1});
    } else {
      // Remove item if quantity goes to 0
      _firestore
          .collection('carts')
          .doc(widget.uid)
          .collection('items')
          .doc(docId)
          .delete();
    }
  }

  // --- Secure Checkout from Cart ---
  void _initiateSecureCheckout() async {
    setState(() => _isCheckingOut = true);
    try {
      final transactionData = await _checkoutService.createTransaction(widget.uid);
      final String txnId = transactionData['txn_id'];
      final double totalAmount = transactionData['total_amount'].toDouble();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout Failed: $e')),
      );
    } finally {
      setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the stream of cart items from the subcollection
    final Stream<QuerySnapshot> cartStream = _firestore
        .collection('carts')
        .doc(widget.uid)
        .collection('items')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.username}'s Cart", style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: cartStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Your cart is empty!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            );
          }

          // Calculate total price from the snapshot
          double totalPrice = 0;
          for (var doc in snapshot.data!.docs) {
            final item = doc.data() as Map<String, dynamic>;
            final price = (item['price'] ?? 0).toDouble();
            final quantity = (item['quantity'] ?? 1).toInt();
            totalPrice += price * quantity;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final String docId = doc.id; // Document ID for updates
                    final int quantity = (item['quantity'] ?? 1).toInt();

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['name'] ?? "Unknown Product",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Qty: $quantity",
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Price: ₹${(item['price'] ?? 0).toStringAsFixed(2)}",
                                style: const TextStyle(fontSize: 16),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () => decreaseQuantity(docId, quantity),
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStateProperty.all(Colors.grey.shade200),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => increaseQuantity(docId, quantity),
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStateProperty.all(Colors.grey.shade200),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // --- Bottom Bar ---
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.deepPurple,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total:",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      "₹${totalPrice.toStringAsFixed(2)}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: _isCheckingOut ? null : _initiateSecureCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isCheckingOut
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "Checkout",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}