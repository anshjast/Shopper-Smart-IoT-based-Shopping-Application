import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cart.dart';

class ScannerScreen extends StatefulWidget {
  final String username;

  const ScannerScreen({Key? key, required this.username}) : super(key: key);

  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  List<Map<String, dynamic>> cartItems = [];

  // Helper method to safely convert price to double
  double _convertToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // Format price with INR symbol
  String _formatPrice(dynamic price) {
    double amount = _convertToDouble(price);
    return '₹${amount.toStringAsFixed(2)}';
  }

  Future<void> scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan();
      if (result.rawContent.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(result.rawContent)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final index = cartItems.indexWhere((item) => item['id'] == doc.id);

          if (index >= 0) {
            setState(() {
              // Ensure quantity is handled as an integer
              cartItems[index]['quantity'] = (cartItems[index]['quantity'] as int) + 1;
            });
          } else {
            setState(() {
              cartItems.add({
                'id': doc.id,
                'name': data['name'] ?? 'Unknown Product',
                // Convert price to double regardless of its original type
                'price': _convertToDouble(data['price']),
                'quantity': 1,
              });
            });
          }

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${data['name'] ?? 'Product'} to cart'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print("Scan error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning: ${e.toString().split(":").first}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void goToCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          cartItems: cartItems,
          username: widget.username,
        ),
      ),
    ).then((value) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan Products", style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepPurple,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: goToCart,
              ),
              if (cartItems.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${cartItems.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Product scanning section
          Center(
            child: ElevatedButton.icon(
              onPressed: scanBarcode,
              icon: const Icon(Icons.qr_code),
              label: const Text("Scan Product"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                textStyle: GoogleFonts.poppins(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Display cart status
          if (cartItems.isNotEmpty)
            Text(
              "${cartItems.length} items in cart",
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          if (cartItems.isNotEmpty) ...[
            const SizedBox(height: 30),
            const Text(
              "Recently Added:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cartItems.last['name'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    _formatPrice(cartItems.last['price']),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
