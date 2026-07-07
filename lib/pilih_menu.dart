import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';

class PilihMenuPage extends StatelessWidget {
  const PilihMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('SPPG',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Portal',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih Menu',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('Silakan pilih modul yang ingin diakses',
                style: TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 14),
              ),
              const SizedBox(height: 40),
              _MenuButton(
                icon: Icons.shopping_cart_rounded,
                label: 'Procurement',
                description: 'Kelola pengadaan bahan baku',
                color: const Color(0xFF1A8FCC),
                onTap: () => context.push('/procurement'),
              ),
              if (context.watch<AuthProvider>().currentRole == 'kepala_sppg' ||
                  context.watch<AuthProvider>().currentRole == 'ag') ...[
                const SizedBox(height: 20),
                _MenuButton(
                  icon: Icons.assignment_rounded,
                  label: 'Planning',
                  description: 'Perencanaan menu & gizi',
                  color: const Color(0xFFFF9800),
                  onTap: () => context.push('/planning'),
                ),
              ],
              const SizedBox(height: 20),
              _MenuButton(
                icon: Icons.local_shipping_rounded,
                label: 'Distribution',
                description: 'Kelola distribusi ke wilayah',
                color: const Color(0xFF4CAF50),
                onTap: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 30, 30, 30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(description,
                        style: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
