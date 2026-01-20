import 'package:flutter/material.dart';

class CategoryScroller extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CategoryScroller({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  static const Color mqOrange = Color(0xFFFF6A00);
  static const Color mqLightOrange = Color(0xFFFFF3E8);

  /// 🔑 IMPORTANT:
  /// - 'All' is UI-only
  /// - Other names MUST match product.category
  static const List<Map<String, String>> categories = [
    {'name': 'All', 'image': 'assets/images/categories/all.png'},
    {'name': 'Grocery', 'image': 'assets/images/categories/grocery.png'},
    {'name': 'Bakery', 'image': 'assets/images/categories/bakery.png'},
    {'name': 'Snacks', 'image': 'assets/images/categories/snacks.png'},
    {'name': 'Personal Care', 'image': 'assets/images/categories/personal_care.png'},
    {'name': 'Home & Utility', 'image': 'assets/images/categories/home_utility.png'},
    {'name': 'Stationery', 'image': 'assets/images/categories/stationery.png'},
    {'name': 'Fashion', 'image': 'assets/images/categories/fashion.png'},
    {'name': 'Food', 'image': 'assets/images/categories/food.png'},
    {'name': 'Art & Decor', 'image': 'assets/images/categories/art_decor.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];
          final name = category['name']!;
          final image = category['image']!;

          /// 🔑 FORCE EXACT MATCH FOR ALL
          final bool isSelected =
              name.toLowerCase().trim() ==
              selectedCategory.toLowerCase().trim();

          return GestureDetector(
            onTap: () {
              /// 🔑 CRITICAL:
              /// Always send EXACT 'All'
              if (name == 'All') {
                onCategorySelected('All');
              } else {
                onCategorySelected(name);
              }
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? mqLightOrange : Colors.white,
                    border: Border.all(
                      color: isSelected ? mqOrange : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      image,
                      fit: BoxFit.cover,
                      cacheWidth: 64,
                      cacheHeight: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color:
                        isSelected ? mqOrange : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
