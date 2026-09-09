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

/// Icon asset per category, used by the buyer home category scroller.
/// 'All' is UI-only and has no product-category counterpart.
const Map<String, String> kCategoryIconAsset = {
  'All': 'assets/images/categories/all.png',
  'Grocery': 'assets/images/categories/grocery.png',
  'Bakery': 'assets/images/categories/bakery.png',
  'Snacks': 'assets/images/categories/snacks.png',
  'Personal Care': 'assets/images/categories/personal_care.png',
  'Home & Utility': 'assets/images/categories/home_utility.png',
  'Stationery': 'assets/images/categories/stationery.png',
  'Fashion': 'assets/images/categories/fashion.png',
  'Food': 'assets/images/categories/food.png',
  'Art & Decor': 'assets/images/categories/art_decor.png',
};

/// Second-level taxonomy, product-only (shops keep a flat category).
/// Additive — existing products simply have no subcategory and keep
/// working unchanged. Mirrors web's SUBCATEGORIES in src/lib/categories.ts.
const Map<String, List<String>> kSubcategories = {
  'Grocery': [
    'Fruits & Vegetables',
    'Atta, Rice & Dal',
    'Masalas & Cooking Oils',
    'Dairy & Eggs',
    'Breakfast & Cereals',
    'Tea, Coffee & Beverages',
    'Packaged Food',
    'Other',
  ],
  'Bakery': ['Bread & Buns', 'Cakes & Pastries', 'Cookies & Rusks', 'Other'],
  'Snacks': [
    'Chips & Namkeen',
    'Chocolates & Candies',
    'Ice Cream & Frozen Desserts',
    'Noodles & Instant Food',
    'Other',
  ],
  'Personal Care': [
    'Bath & Body',
    'Hair Care',
    'Oral Care',
    'Skin Care',
    'Feminine Hygiene',
    'Baby Care',
    'Other',
  ],
  'Home & Utility': [
    'Cleaning Supplies',
    'Kitchen & Dining',
    'Electricals & Batteries',
    'Pooja Needs',
    'Other',
  ],
  'Stationery': [
    'Notebooks & Paper',
    'Pens & Writing',
    'Art Supplies',
    'Office Supplies',
    'Other',
  ],
  'Fashion': [
    "Men's Wear",
    "Women's Wear",
    "Kids' Wear",
    'Footwear',
    'Accessories',
    'Other',
  ],
  'Food': ['Ready to Eat', 'Sweets', 'Beverages', 'Tiffin & Meals', 'Other'],
  'Art & Decor': [
    'Wall Decor',
    'Showpieces',
    'Plants & Pots',
    'Festive Decor',
    'Other',
  ],
  'Other': ['Other'],
};

List<String> subcategoriesFor(String category) {
  return kSubcategories[normalizeCategory(category)] ?? ['Other'];
}
