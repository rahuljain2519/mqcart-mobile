import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../repositories/order_repository.dart';

/// Exports every order (COD and online) as a CSV — transaction type, seller
/// name, shop name, bank account/IFSC, society, order ID, product details,
/// and date — then hands it to the OS share sheet (save to Files, email,
/// WhatsApp, etc.) since there's no direct "download" concept on mobile.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final OrderRepository _repo = OrderRepository();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _busy = false;
  String? _error;
  int? _lastCount;

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Any';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final rows = await _repo.buildTransactionsReport(
        startDate: _startDate,
        endDate: _endDate,
      );

      final csvData = [
        [
          'Order ID',
          'Date',
          'Transaction Type',
          'Payment Status',
          'Order Status',
          'Society Name',
          'Seller Name',
          'Shop Name',
          'Bank Account Number',
          'IFSC Code',
          'Product Details',
          'Total Amount',
        ],
        ...rows.map((r) => [
              r.orderId,
              r.date,
              r.transactionType,
              r.paymentStatus,
              r.orderStatus,
              r.societyName,
              r.sellerName,
              r.shopName,
              r.bankAccountNumber,
              r.ifscCode,
              r.productDetails,
              r.totalAmount,
            ]),
      ];
      final csvString = const ListToCsvConverter().convert(csvData);

      final dir = await getTemporaryDirectory();
      final today = DateTime.now().toIso8601String().slice0To10();
      final file = File('${dir.path}/mqcart-transactions-$today.csv');
      await file.writeAsString(csvString);

      if (!mounted) return;
      setState(() => _lastCount = rows.length);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'MQ Cart transaction report',
      );
    } catch (e) {
      setState(() => _error = 'Could not build the report: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exports every order (COD and online) with transaction type, '
              'seller name, shop name, bank account & IFSC, society, order '
              'ID, product details, and date. Leave dates unset to export '
              'every order ever placed.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text('From: ${_formatDate(_startDate)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text('To: ${_formatDate(_endDate)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_lastCount != null && _error == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Exported $_lastCount transactions.',
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            ElevatedButton(
              onPressed: _busy ? null : _export,
              child: Text(_busy ? 'Building…' : 'Export & Share CSV'),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String slice0To10() => length >= 10 ? substring(0, 10) : this;
}
