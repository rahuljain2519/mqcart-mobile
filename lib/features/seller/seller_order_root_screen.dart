import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

import "seller_orders_screen.dart";
import "../buyer/buyer_orders_screen.dart";

class SellerOrdersRootScreen extends StatelessWidget {
  const SellerOrdersRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'My Orders',
            style: TextStyle(color: Colors.black),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFFFF6A00),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Incoming'),
              Tab(text: 'My Purchases'),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: const TabBarView(
          children: [
            SellerOrdersScreen(), // EXISTING
            BuyerOrdersScreen(),  // REUSED AS-IS ✅
          ],
        ),
      ),
    );
  }
}
