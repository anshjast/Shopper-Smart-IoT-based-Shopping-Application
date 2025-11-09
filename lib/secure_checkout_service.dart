import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecureCheckoutService {
  // !!! IMPORTANT !!!
  // Replace this with the IP address of the machine running your Python server.
  // 1. If running on a real Android device, this must be your computer's network IP (e.g., 192.168.1.100).
  // 2. If running on an Android Emulator, use '10.0.2.2'.
  // 3. DO NOT use 'localhost' or '127.0.0.1' - your phone/emulator cannot reach it.
  final String _backendUrl = 'http://10.0.2.2:5000'; // Default for emulator

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> createTransaction(String uid) async {
    // 1. Get the user's cart from Firestore
    final cartRef = _firestore.collection('carts').doc(uid);
    final cartSnapshot = await cartRef.get();

    if (!cartSnapshot.exists || (cartSnapshot.data()?['items'] as List).isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final cartData = cartSnapshot.data()!;
    final items = cartData['items'] as List;

    // 2. Get the user's Firebase auth token to prove their identity to the backend
    final idToken = await _auth.currentUser?.getIdToken(true);
    if (idToken == null) {
      throw Exception('User not authenticated.');
    }

    // 3. Call the Python backend's '/create_transaction' endpoint
    final response = await http.post(
      Uri.parse('$_backendUrl/create_transaction'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken', // Send auth token
      },
      body: jsonEncode({
        'userId': uid,
        'items': items,
        // The backend will securely recalculate totals and weight
      }),
    );

    if (response.statusCode == 200) {
      // The backend successfully created the pending transaction
      return jsonDecode(response.body);
    } else {
      // Handle backend errors
      throw Exception('Failed to create transaction: ${response.body}');
    }
  }

  // This function will be called by payment.dart AFTER UPI success
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
        // We also need to send proof of payment, e.g., a paymentId from UPI
        'payment_gateway_id': 'DUMMY_PAYMENT_ID_FROM_UPI'
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Return the secure JWT receipt token!
      return data['receipt_token'];
    } else {
      throw Exception('Failed to finalize transaction: ${response.body}');
    }
  }
}