import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'marketplace.dart';
import 'profile_sppg.dart';
import 'inventory.dart';
import 'suppliers.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  int _dashboardKey = 0;
  String? _selectedItem;
  Map<String, dynamic>? _selectedItemInfo;

  void _onOrderItem(Map<String, dynamic> info) {
    setState(() {
      _selectedItem = info['name'] as String;
      _selectedItemInfo = info;
      _selectedIndex = 1;
    });
  }

  void _onSupplierSelected() {
    setState(() {
      _selectedItem = null;
      _selectedItemInfo = null;
      _dashboardKey++;
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeroMode(enabled: false, child: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardPage(key: ValueKey(_dashboardKey), onOrderItem: _onOrderItem),
          MarketplacePage(
            selectedItem: _selectedItem,
            selectedItemInfo: _selectedItemInfo,
            onSupplierSelected: _onSupplierSelected,
          ),
          const SuppliersPage(),
          const InventoryPage(),
          const ProfileSppgPage(),
        ],
      ),
      ),
      bottomNavigationBar: _buildModernNav(),
    );
  }

  Widget _buildModernNav() {
    final navItems = [
      ('Home', Icons.home_outlined, Icons.home),
      ('Marketplace', Icons.store_outlined, Icons.store),
      ('Supplier', Icons.person_search_outlined, Icons.person_search),
      ('Inventory', Icons.inventory_2_outlined, Icons.inventory_2),
      ('Profile', Icons.person_outline, Icons.person),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 30, 30, 30),
        border: Border(
          top: BorderSide(color: Color.fromARGB(255, 50, 50, 50), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        children: List.generate(navItems.length, (i) {
          final isActive = i == _selectedIndex;
          final label = navItems[i].$1;
          final icon = navItems[i].$2;
          final activeIcon = navItems[i].$3;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1A8FCC).withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF1A8FCC)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isActive ? activeIcon : icon,
                        size: 20,
                        color: isActive
                            ? Colors.white
                            : const Color.fromARGB(255, 133, 133, 133),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? const Color(0xFF1A8FCC)
                            : const Color.fromARGB(255, 133, 133, 133),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
