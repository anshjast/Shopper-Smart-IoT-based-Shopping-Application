import 'package:flutter/material.dart';
import 'payment.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final String username;

  const CartScreen({
    Key? key,
    required this.cartItems,
    required this.username,
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double calculateTotal(List<Map<String, dynamic>> items) {
    double total = 0;
    for (var item in items) {
      double price = 0.0;
      if (item['price'] != null) {
        if (item['price'] is int) {
          price = (item['price'] as int).toDouble();
        } else if (item['price'] is double) {
          price = item['price'] as double;
        } else {
          price = double.tryParse(item['price'].toString()) ?? 0.0;
        }
      }
      int quantity = 1;
      if (item['quantity'] != null) {
        if (item['quantity'] is int) {
          quantity = item['quantity'] as int;
        } else {
          quantity = int.tryParse(item['quantity'].toString()) ?? 1;
        }
      }

      total += price * quantity;
    }
    return total;
  }
  String formatPrice(dynamic price) {
    if (price == null) return '₹0.00';

    double doublePrice;
    if (price is int) {
      doublePrice = price.toDouble();
    } else if (price is double) {
      doublePrice = price;
    } else {
      doublePrice = double.tryParse(price.toString()) ?? 0.0;
    }

    return '₹${doublePrice.toStringAsFixed(2)}';
  }

  void increaseQuantity(int index) {
    setState(() {
      if (widget.cartItems[index]['quantity'] is int) {
        widget.cartItems[index]['quantity'] += 1;
      } else {
        widget.cartItems[index]['quantity'] =
            (int.tryParse(widget.cartItems[index]['quantity'].toString()) ?? 0) + 1;
      }
    });
  }

  void decreaseQuantity(int index) {
    setState(() {
      if (widget.cartItems[index]['quantity'] is int) {
        if (widget.cartItems[index]['quantity'] > 1) {
          widget.cartItems[index]['quantity'] -= 1;
        }
      } else {
        int currentQty = int.tryParse(widget.cartItems[index]['quantity'].toString()) ?? 0;
        if (currentQty > 1) {
          widget.cartItems[index]['quantity'] = currentQty - 1;
        }
      }
    });
  }
  void proceedToCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          cartItems: widget.cartItems,
          totalAmount: calculateTotal(widget.cartItems),
          username: widget.username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalPrice = calculateTotal(widget.cartItems);

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.username}'s Cart", style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.deepPurple,
      ),
      body: widget.cartItems.isEmpty
          ? const Center(
        child: Text(
          "Your cart is empty!",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      )
          : ListView.builder(
        itemCount: widget.cartItems.length,
        itemBuilder: (context, index) {
          var item = widget.cartItems[index];
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
                    Row(
                      children: [
                        Text(
                          "Qty: ",
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          "${item['quantity'] ?? 1}",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Price: ${formatPrice(item['price'])}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () => decreaseQuantity(index),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(
                                Colors.grey.shade200),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () => increaseQuantity(index),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(
                                Colors.grey.shade200),
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  formatPrice(totalPrice),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // New checkout button
          if (widget.cartItems.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: proceedToCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
  }
}
