import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'payment.dart';

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

  // Helper to safely calculate total price from a list of cart items
  double _calculateTotal(List<DocumentSnapshot> items) {
    double total = 0;
    for (var doc in items) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('price') && data.containsKey('quantity')) {
        final price = (data['price'] as num? ?? 0.0).toDouble();
        final quantity = (data['quantity'] as int? ?? 1);
        total += price * quantity;
      }
    }
    return total;
  }

  String _formatPrice(double price) {
    return '₹${price.toStringAsFixed(2)}';
  }

  // New function to handle quantity update (used by +/- buttons)
  void _updateQuantity(String productId, int change) async {
    final itemRef = _firestore.collection('carts').doc(widget.uid).collection('items').doc(productId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);
      if (!snapshot.exists) return;

      int currentQty = (snapshot.data()?['quantity'] as int? ?? 0);
      int newQty = currentQty + change;

      if (newQty > 0) {
        transaction.update(itemRef, {'quantity': newQty});
      } else {
        transaction.delete(itemRef); // Remove item if quantity drops to zero
      }
    });
  }


  // The function called by the Checkout button
  void _proceedToCheckout(double totalAmount, List<DocumentSnapshot> items) {
    if (items.isEmpty || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Checkout Failed: Your cart is empty.")),
      );
      return;
    }

    // Navigate to Payment Screen (the PaymentScreen will call createTransaction)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          // We don't have the final txnId yet, but we need total amount
          totalAmount: totalAmount,
          username: widget.username,
          txnId: "TBD_FROM_DASHBOARD", // Placeholder; unused here, but required by PaymentScreen
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stream builder to listen for real-time updates in the cart subcollection
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('carts').doc(widget.uid).collection('items').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text('Error: ${snapshot.error}')));
        }

        final cartDocs = snapshot.data?.docs ?? [];
        final double totalPrice = _calculateTotal(cartDocs);
        final bool isCartEmpty = cartDocs.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text("${widget.username}'s Cart", style: GoogleFonts.poppins(fontSize: 18)),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          body: isCartEmpty
              ? const Center(
            child: Text(
              "Your cart is empty!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: cartDocs.length,
            itemBuilder: (context, index) {
              var item = cartDocs[index].data() as Map<String, dynamic>;
              final productId = item['productId'];
              final qty = item['quantity'] as int? ?? 1;
              final price = (item['price'] as num? ?? 0.0).toDouble();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] ?? "Unknown Product",
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text("Qty: $qty", style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Price: ${_formatPrice(price)}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => _updateQuantity(productId, -1),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _updateQuantity(productId, 1),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                ],
              );
            },
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total:", style: TextStyle(color: Colors.white, fontSize: 18)),
                    Text(_formatPrice(totalPrice), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (!isCartEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton(
                    // Calls the secure checkout logic from the dashboard
                    onPressed: () => _proceedToCheckout(totalPrice, cartDocs),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      "Checkout",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}