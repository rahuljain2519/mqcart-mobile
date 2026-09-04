// Option-aware stock arithmetic shared by ProductRepository (reduce on order)
// and ProductRemoteDS (restock on cancel). Web mirrors this in
// src/lib/data.ts applyStockDelta().

Map<String, List<Map<String, dynamic>>> groupByProduct(
  List<Map<String, dynamic>> items,
) {
  final m = <String, List<Map<String, dynamic>>>{};
  for (final it in items) {
    (m[it['productId'] as String] ??= []).add(it);
  }
  return m;
}

/// Firestore patch for one product doc after applying [lines] with [sign]
/// (+1 restock / -1 reduce). When the doc has `options`, the matching option's
/// quantity is adjusted and the root quantity is recomputed as the sum.
Map<String, dynamic> applyStockDelta(
  Map<String, dynamic> data,
  List<Map<String, dynamic>> lines,
  int sign, {
  required bool validate,
}) {
  final rawOptions = data['options'];
  if (rawOptions is List && rawOptions.isNotEmpty) {
    final options =
        rawOptions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    for (final l in lines) {
      final name = l['optionName'] as String?;
      final qty = l['quantity'] as int;
      final idx = options.indexWhere((o) => o['name'] == name);
      if (idx < 0) {
        if (validate) throw Exception('Option "$name" is unavailable');
        continue;
      }
      final cur = (options[idx]['quantity'] ?? 0) as int;
      final next = cur + sign * qty;
      if (validate && next < 0) throw Exception('Insufficient stock');
      options[idx]['quantity'] = next < 0 ? 0 : next;
    }
    final total =
        options.fold<int>(0, (s, o) => s + ((o['quantity'] ?? 0) as int));
    return {'options': options, 'quantity': total};
  }

  // Simple product.
  final total = lines.fold<int>(0, (s, l) => s + (l['quantity'] as int));
  final cur = (data['quantity'] ?? 0) as int;
  final next = cur + sign * total;
  if (validate && next < 0) throw Exception('Insufficient stock');
  return {'quantity': next < 0 ? 0 : next};
}
