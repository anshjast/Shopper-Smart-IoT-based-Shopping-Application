import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecureCheckoutService {
  // IMPORTANT: Ensure this is set correctly (10.0.2.2 for emulator)
  final String _backendUrl = 'http://10.0.2.2:5000';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> createTransaction(String uid) async {
    // 1. CRITICAL FIX: Query the 'items' SUBCOLLECTION, not the parent document.
    final itemsSnapshot = await _firestore.collection('carts').doc(uid).collection('items').get();

    if (itemsSnapshot.docs.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    // 2. Map the documents into a simple list of item data
    final List<Map<String, dynamic>> itemsList = itemsSnapshot.docs.map((doc) {
      // Ensure we convert data types safely for JSON transfer
      final data = doc.data();
      return {
        'productId': data['productId'],
        'name': data['name'],
        'price': (data['price'] as num).toDouble(),
        'weight_grams': (data['weight_grams'] as num).toDouble(),
        'quantity': (data['quantity'] as int).toInt(),
      };
    }).toList();

    // 3. Get the user's Firebase auth token
    final idToken = await _auth.currentUser?.getIdToken(true);
    if (idToken == null) {
      throw Exception('User not authenticated.');
    }

    // 4. Call the Python backend's '/create_transaction' endpoint
    final response = await http.post(
      Uri.parse('$_backendUrl/create_transaction'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'userId': uid,
        'items': itemsList, // Send the list of cart items
      }),
    );

    if (response.statusCode == 200) {
      // Clear the user's cart immediately after a successful transaction request
      for (var doc in itemsSnapshot.docs) {
        await doc.reference.delete();
      }
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create transaction: ${response.body}');
    }
  }

  // --- (finalizeTransaction function remains the same) ---
  Future<String> finalizeTransaction(String txnId) async {
    final idToken = await _auth.currentUser?.getIdToken(true);

    final response = await http.post(
      Uri.parse('$_backendUrl/finalize_transaction'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'txn_id': txnId,
        'payment_gateway_id': 'DUMMY_PAYMENT_ID_FROM_UPI'
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['receipt_token'];
    } else {
      throw Exception('Failed to finalize transaction: ${response.body}');
    }
  }
}