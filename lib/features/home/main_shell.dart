import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/auth_intent.dart';
import 'home_router.dart';
import '../buyer/buyer_shops_screen.dart';
import '../orders/orders_router.dart';
import '../profile/profile_router.dart';
import '../../core/widgets/cart_badge.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/society_repository.dart';
import '../../models/user_model.dart';
import '../../models/society_model.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // AppBar only on Home tab
  PreferredSizeWidget? _buildAppBar() {
    if (_currentIndex != 0) return null;

    final userRepo = UserRepository();
    final societyRepo = SocietyRepository();

    return PreferredSize(
      preferredSize: const Size.fromHeight(104),
      child: StreamBuilder<UserModel?>(
        stream: userRepo.streamCurrentUser(),
        builder: (context, userSnap) {
          final user = userSnap.data;

          if (user == null || user.societyId.isEmpty) {
            return _headerUI('Select delivery address');
          }

          return FutureBuilder<SocietyModel?>(
            future: societyRepo.getSocietyById(user.societyId),
            builder: (context, societySnap) {
              final societyName =
                  societySnap.data?.name ?? 'Your Society';
              return _headerUI(
                'Flat ${user.flatNumber}, $societyName',
              );
            },
          );
        },
      ),
    );
  }

  Widget _headerUI(String addressText) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1CC), // 🌤 brighter peach (less dull)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔹 Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// Brand + Delivery
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'MQ Cart',
                          style: TextStyle(
                            fontSize: 21,              // ⬆ Bigger
                            fontWeight: FontWeight.w800, // ⬆ Strong bold
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(text: '  '),
                        TextSpan(
                          text: '⚡ Fast Delivery',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600, // ⬆ Bold
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// Cart + Logout
                  Row(
                    children: [
                      const CartBadge(),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        color: Colors.black87,
                        onPressed: _confirmAndLogout,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              /// 🔹 Address Row
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.black87,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      addressText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500, // ⬆ Medium bold
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.black87,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const HomeRouter();
      case 1:
        return const BuyerShopsScreen();
      case 2:
        return const OrdersRouter();
      case 3:
        return const ProfileRouter();
      default:
        return const HomeRouter();
    }
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      selectedItemColor: const Color(0xFFFF6A00), // 🧡 Brand orange
      unselectedItemColor: Colors.grey,
      onTap: _onTabTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.store),
          label: 'Shops',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  /* --------------------------------------------------
     TAB TAP HANDLER (AUTH INTENT)
     -------------------------------------------------- */
  void _onTabTapped(int index) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null && index != 0) {
      AuthIntent.pendingTabIndex = index;
      return;
    }

    setState(() => _currentIndex = index);
  }

  /* --------------------------------------------------
     LOGOUT WITH CONFIRMATION (FINAL)
     -------------------------------------------------- */
  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      AuthIntent.pendingTabIndex = null;
      await FirebaseAuth.instance.signOut();
    }
  }
}
