import 'dart:io';

import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/society_model.dart';
import '../../models/user_model.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/society_repository.dart';
import '../../repositories/user_repository.dart';

/// Every order (COD and online) — transaction type, seller name, shop
/// name, bank account/IFSC, society, order ID, product details, date —
/// filterable by seller/society/payment type/date range, shown as a list
/// on this screen, with the exact filtered set exportable as a CSV via the
/// OS share sheet (no "download" concept on mobile).
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  final UserRepository _userRepo = UserRepository();
  final SocietyRepository _societyRepo = SocietyRepository();

  List<UserModel> _sellers = [];
  List<SocietyModel> _societies = [];

  String? _sellerId;
  String? _societyId;
  String? _paymentMethod;
  DateTime? _startDate;
  DateTime? _endDate;

  List<TransactionReportRow>? _rows;
  bool _busy = false;
  String? _error;
  String? _statusBusyOrderId;

  @override
  void initState() {
    super.initState();
    _userRepo.getAllUsers().then((users) {
      if (!mounted) return;
      setState(() => _sellers = users.where((u) => u.role == 'seller').toList());
    });
    _societyRepo.getActiveSocieties().then((societies) {
      if (!mounted) return;
      setState(() => _societies = societies);
    });
  }

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

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await _orderRepo.buildTransactionsReport(
        startDate: _startDate,
        endDate: _endDate,
        sellerId: _sellerId,
        societyId: _societyId,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _error = 'Could not build the report: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSettled(TransactionReportRow row) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _statusBusyOrderId = row.orderId);
    try {
      await _orderRepo.updateOrderSettlementStatus(
        orderId: row.orderId,
        sellerId: row.sellerId,
        shopName: row.shopName,
        settlementAmount: row.settlementAmount,
        settled: !row.settled,
        settledBy: uid,
      );
      if (!mounted) return;
      setState(() {
        _rows = _rows
            ?.map((r) => r.orderId == row.orderId
                ? TransactionReportRow(
                    orderId: r.orderId,
                    date: r.date,
                    transactionType: r.transactionType,
                    paymentStatus: r.paymentStatus,
                    orderStatus: r.orderStatus,
                    societyName: r.societyName,
                    sellerId: r.sellerId,
                    sellerName: r.sellerName,
                    shopName: r.shopName,
                    bankAccountNumber: r.bankAccountNumber,
                    ifscCode: r.ifscCode,
                    productDetails: r.productDetails,
                    totalAmount: r.totalAmount,
                    settlementAmount: r.settlementAmount,
                    settled: !r.settled,
                  )
                : r)
            .toList();
      });
    } catch (e) {
      setState(() => _error = 'Could not update settlement status: $e');
    } finally {
      if (mounted) setState(() => _statusBusyOrderId = null);
    }
  }

  Future<void> _exportFiltered() async {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return;

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
        'Settlement Amount',
        'Settlement Status',
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
            r.settlementAmount.toStringAsFixed(2),
            r.transactionType == 'razorpay'
                ? (r.settled ? 'Paid' : 'Pending')
                : 'COD - n/a',
          ]),
    ];
    final csvString = const ListToCsvConverter().convert(csvData);

    final dir = await getTemporaryDirectory();
    final today = DateTime.now().toIso8601String().slice0To10();
    final file = File('${dir.path}/mqcart-transactions-$today.csv');
    await file.writeAsString(csvString);

    await Share.shareXFiles([XFile(file.path)], text: 'MQ Cart transaction report');
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final total = rows?.fold<double>(0, (sum, r) => sum + r.totalAmount) ?? 0;
    final settlementTotal =
        rows?.fold<double>(0, (sum, r) => sum + r.settlementAmount) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Report')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _sellerId,
                  decoration: const InputDecoration(labelText: 'Seller'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._sellers.map(
                      (s) => DropdownMenuItem(
                        value: s.uid,
                        child: Text(s.name.isNotEmpty ? s.name : s.phone),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _sellerId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _societyId,
                  decoration: const InputDecoration(labelText: 'Society'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._societies.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _societyId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment type'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'cod', child: Text('COD')),
                    DropdownMenuItem(value: 'razorpay', child: Text('Online (Razorpay)')),
                  ],
                  onChanged: (v) => setState(() => _paymentMethod = v),
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 14),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : _load,
                        child: Text(_busy ? 'Loading…' : 'Apply filters'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (rows == null || rows.isEmpty) ? null : _exportFiltered,
                        child: const Text('Export CSV'),
                      ),
                    ),
                  ],
                ),
                if (rows != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${rows.length} transactions · ₹${total.toStringAsFixed(0)} gross · '
                      '₹${settlementTotal.toStringAsFixed(0)} settlement amount',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Set your filters and tap "Apply filters" to load transactions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : rows.isEmpty
                    ? const Center(child: Text('No transactions match these filters.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        r.shopName.isEmpty ? '(unnamed shop)' : r.shopName,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '₹${r.totalAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${r.sellerName} · ${r.societyName}',
                                    style: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  Text(
                                    '${r.transactionType.toUpperCase()} · ${r.paymentStatus} · ${r.orderStatus}',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                  ),
                                  if (r.bankAccountNumber.isNotEmpty)
                                    Text(
                                      'A/C ${r.bankAccountNumber} · IFSC ${r.ifscCode}',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    r.productDetails,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Settlement: ₹${r.settlementAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (r.transactionType == 'razorpay')
                                        _SettlementStatusChip(
                                          settled: r.settled,
                                          busy: _statusBusyOrderId == r.orderId,
                                          onTap: () => _toggleSettled(r),
                                        )
                                      else
                                        const Text(
                                          'COD — n/a',
                                          style: TextStyle(color: Colors.grey, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    r.date.isNotEmpty
                                        ? DateTime.tryParse(r.date)?.toLocal().toString().slice0To10() ?? r.date
                                        : '—',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String slice0To10() => length >= 10 ? substring(0, 10) : this;
}

class _SettlementStatusChip extends StatelessWidget {
  final bool settled;
  final bool busy;
  final VoidCallback onTap;

  const _SettlementStatusChip({
    required this.settled,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: settled ? Colors.green.shade100 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          busy ? '…' : (settled ? 'Paid' : 'Pending'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: settled ? Colors.green.shade800 : Colors.black54,
          ),
        ),
      ),
    );
  }
}
