import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecureCheckoutService {
  final String _backendUrl = '[http://10.0.2.2:5000](http://10.0.2.2:5000)';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> createTransaction(String uid, List<Map<String, dynamic>> itemsList) async {

    if (itemsList.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final idToken = await _auth.currentUser?.getIdToken(true);
    if (idToken == null) {
      throw Exception('User not authenticated.');
    }

    final response = await http.post(
      Uri.parse('$_backendUrl/create_transaction'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'userId': uid,
        'items': itemsList,
      }),
    );

    if (response.statusCode == 200) {
      final cartItemsRef = _firestore.collection('carts').doc(uid).collection('items');
      final snapshot = await cartItemsRef.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create transaction: ${response.body}');
    }
  }

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