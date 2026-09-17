import 'package:flutter/material.dart';

/// Shown when a buyer tries to add a product from a different seller than
/// what's already in their cart. Returns true if they chose to clear the
/// cart and continue, false/null if cancelled.
Future<bool> showClearCartDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Switch seller?'),
      content: const Text(
        'Your cart has items from a different seller. Clear your cart '
        'and add this item instead?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear & Add'),
        ),
      ],
    ),
  );

  return result == true;
}
