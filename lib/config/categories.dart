// Single source of truth for categories in the app. The web app mirrors this
// in src/lib/categories.ts — keep them identical.
//
// One canonical list for both a shop's category and a product's category
// (there were three drifting lists before). Buyer filtering does an EXACT match
// after normalising through [kCategoryAliases], so products saved with legacy
// names ("Groceries", "Household", "Clothing", "Stationary") still bucket
// correctly with no data migration.

const List<String> kProductCategories = [
  'Grocery',
  'Bakery',
  'Snacks',
  'Personal Care',
  'Home & Utility',
  'Stationery',
  'Fashion',
  'Food',
  'Art & Decor',
  'Other',
];

/// Shop application uses the same set.
const List<String> kShopCategories = kProductCategories;

/// Legacy / misspelled values seen in existing docs -> canonical.
const Map<String, String> kCategoryAliases = {
  'groceries': 'Grocery',
  'grocery': 'Grocery',
  'household': 'Home & Utility',
  'home and utility': 'Home & Utility',
  'home & utility': 'Home & Utility',
  'stationary': 'Stationery',
  'stationery': 'Stationery',
  'clothing': 'Fashion',
  'fashion': 'Fashion',
  'art and decor': 'Art & Decor',
  'art & decor': 'Art & Decor',
};

String normalizeCategory(String raw) {
  final key = raw.toLowerCase().trim();
  return kCategoryAliases[key] ?? raw.trim();
}
