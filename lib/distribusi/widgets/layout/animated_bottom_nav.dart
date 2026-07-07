import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class AnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AnimatedNavItem> items;

  const AnimatedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BGNColors.surface,
        border: Border(
          top: BorderSide(color: BGNColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final isActive = i == currentIndex;
          return Expanded(
            child: _NavItemWidget(
              item: items[i],
              isActive: isActive,
              onTap: () => onTap(i),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItemWidget extends StatelessWidget {
  final AnimatedNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Icon(
                key: ValueKey(isActive),
                isActive ? item.activeIcon : item.icon,
                size: 22,
                color: isActive
                    ? BGNColors.primary
                    : BGNColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w500 : FontWeight.normal,
                color: isActive
                    ? BGNColors.primary
                    : BGNColors.textSecondary,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedNavItem {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final List<String> roles;

  const AnimatedNavItem({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.roles,
  });
}
