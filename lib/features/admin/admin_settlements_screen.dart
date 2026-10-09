import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/settlement_model.dart';
import '../../repositories/order_repository.dart';

/// Option A: fully manual settlement. Online orders collect 100% into
/// MQ Cart's Razorpay account with no automatic payout (Route is built and
/// deployed, but deliberately not being activated per seller for now).
/// Admin sees what each seller is owed, pays them directly by bank
/// transfer/UPI outside the app, and records it here.
class AdminSettlementsScreen extends StatefulWidget {
  const AdminSettlementsScreen({super.key});

  @override
  State<AdminSettlementsScreen> createState() =>
      _AdminSettlementsScreenState();
}

class _AdminSettlementsScreenState extends State<AdminSettlementsScreen> {
  final OrderRepository _repo = OrderRepository();
  List<UnsettledSellerTotal>? _totals;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final totals = await _repo.getUnsettledAmountsBySeller();
    if (!mounted) return;
    setState(() => _totals = totals);
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    final grandTotal =
        totals?.fold<double>(0, (sum, t) => sum + t.totalAmount) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Seller Settlements')),
      body: totals == null
          ? const Center(child: CircularProgressIndicator())
          : totals.isEmpty
              ? const Center(
                  child: Text('Nothing owed to any seller right now.'),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Total owed across all sellers: ₹${grandTotal.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ...totals.map(
                        (t) => _SellerSettlementTile(
                          total: t,
                          onSettled: _load,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SellerSettlementTile extends StatefulWidget {
  final UnsettledSellerTotal total;
  final VoidCallback onSettled;

  const _SellerSettlementTile({required this.total, required this.onSettled});

  @override
  State<_SellerSettlementTile> createState() => _SellerSettlementTileState();
}

class _SellerSettlementTileState extends State<_SellerSettlementTile> {
  final OrderRepository _repo = OrderRepository();
  final _noteCtrl = TextEditingController();
  bool _expanded = false;
  bool _busy = false;
  List<SettlementModel>? _history;

  Future<void> _loadHistory() async {
    final history = await _repo.getSettlementsForSeller(widget.total.sellerId);
    if (!mounted) return;
    setState(() => _history = history);
  }

  Future<void> _settle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await _repo.markOrdersSettled(
        sellerId: widget.total.sellerId,
        shopName: widget.total.shopName,
        orderIds: widget.total.orderIds,
        totalAmount: widget.total.totalAmount,
        settledBy: uid,
        note: _noteCtrl.text.trim(),
      );
      widget.onSettled();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not record settlement: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              widget.total.shopName.isEmpty
                  ? '(unnamed shop)'
                  : widget.total.shopName,
            ),
            subtitle: Text('${widget.total.orderIds.length} orders'),
            trailing: Text(
              '₹${widget.total.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded && _history == null) _loadHistory();
            },
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pay ₹${widget.total.totalAmount.toStringAsFixed(0)} to this '
                    'seller by bank transfer/UPI outside MQ Cart, then record '
                    'it here.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Optional note — e.g. UPI ref number',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _busy ? null : _settle,
                    child: Text(_busy ? 'Recording…' : 'Mark as paid'),
                  ),
                  const Divider(height: 24),
                  Text(
                    'Past settlements',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_history == null)
                    const Text('Loading…')
                  else if (_history!.isEmpty)
                    const Text('None yet.')
                  else
                    ..._history!.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '₹${s.totalAmount.toStringAsFixed(0)} · '
                          '${s.orderIds.length} orders'
                          '${s.note != null && s.note!.isNotEmpty ? ' · ${s.note}' : ''}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
