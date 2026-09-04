import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../models/seller_application_model.dart';
import '../../data/datasources/seller_application_remote_ds.dart';
import '../../repositories/user_repository.dart';

class AdminSellerReviewScreen extends StatelessWidget {
  final UserModel user;

  const AdminSellerReviewScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Seller Application')),
      body: StreamBuilder<SellerApplicationModel?>(
        stream: SellerApplicationRemoteDS()
            .streamMyApplication(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final app = snapshot.data;

          if (app == null) {
            return const Center(child: Text('Application not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('User'),
                _row('Name', user.name),
                _row('Phone', user.phone),

                _section('Shop'),
                _row('Shop Name', app.shopName),
                _row('Category', app.category),
                _row('Business Type', app.businessType),

                _section('Identity'),
                _row('PAN', app.panNumber),
                _row('Aadhaar', app.aadhaarLast4),
                _row('GSTIN', app.gstin ?? 'N/A'),

                _section('Address'),
                _row('Address', app.addressLine),
                _row('City', app.city),
                _row('State', app.state),
                _row('Pincode', app.pincode),

                _section('Bank'),
                _row('Account Holder', app.bankName ?? 'N/A'),
                _row('Account No', app.bankAccountNumber ?? 'N/A'),
                _row('IFSC', app.ifscCode ?? 'N/A'),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () async {
                          await UserRepository().approveSeller(user.uid);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          await UserRepository().rejectSeller(user.uid);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
