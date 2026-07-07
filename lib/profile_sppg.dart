import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'checkout_page.dart';
import 'draft_store.dart';
import 'login.dart';
import 'to_ship_page.dart';
import 'to_receive_page.dart';
import 'to_rate_page.dart';
import 'distribusi/providers/auth_provider.dart';

class ProfileSppgPage extends StatefulWidget {
  const ProfileSppgPage({super.key});

  @override
  State<ProfileSppgPage> createState() => _ProfileSppgPageState();
}

class _ProfileSppgPageState extends State<ProfileSppgPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Profil SPPG',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: Listenable.merge([DraftStore.paymentNotifier, DraftStore.shippingNotifier, DraftStore.receiveNotifier, DraftStore.rateNotifier]),
              builder: (_, __) => _buildOrderStatus(context),
            ),
            const SizedBox(height: 20),
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildStatsCard(),
            const SizedBox(height: 16),
            _buildMenuList(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2640), Color(0xFF135B92)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const CircleAvatar(
              backgroundColor: Color.fromARGB(255, 40, 40, 40),
              child: Icon(Icons.person, color: Colors.white, size: 44),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.watch<AuthProvider>().activeUser.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A8FCC).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DraftStore.loggedInRole,
              style: const TextStyle(
                color: Color(0xFF498CC8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Color.fromARGB(255, 133, 133, 133), size: 16),
              const SizedBox(width: 4),
              Text(
                context.watch<AuthProvider>().activeUser.unit,
                style: const TextStyle(
                  color: Color.fromARGB(255, 176, 176, 176),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatus(BuildContext context) {
    final draftCount = DraftStore.pendingPayments.length;
    final toShipCount = DraftStore.paidOrders.length;
    final toRateCount = DraftStore.ratedOrders.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statusButton(context, Icons.receipt_long, 'To Pay', draftCount, Colors.orange, () {
            _showDraftList(context);
          }),
          _statusDivider(),
          _statusButton(context, Icons.inventory_2, 'To Ship', toShipCount, const Color(0xFF498CC8), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ToShipPage(),
              ),
            );
          }),
          _statusDivider(),
          _statusButton(context, Icons.local_shipping, 'To Receive', DraftStore.readyOrders.length, Colors.green, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ToReceivePage(),
              ),
            );
          }),
          _statusDivider(),
          _statusButton(context, Icons.star_outline, 'To Rate', toRateCount, const Color(0xFFD4A843), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ToRatePage(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statusButton(BuildContext context, IconData icon, String label, int count, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 28),
              if (count > 0)
                Positioned(
                  right: -10,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color.fromARGB(255, 176, 176, 176),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDivider() {
    return Container(
      width: 1,
      height: 36,
      color: const Color.fromARGB(255, 60, 60, 60),
    );
  }

  void _showDraftList(BuildContext context) {
    final drafts = DraftStore.pendingPayments;

    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada item yang menunggu pembayaran'),
          backgroundColor: Color.fromARGB(255, 60, 60, 60),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 7, 32, 52),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 100, 100, 100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Menunggu Pembayaran',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${drafts.length} item',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 133, 133, 133),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color.fromARGB(255, 60, 60, 60)),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final draft = drafts[i];
                  return _draftItemCard(context, draft);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _draftItemCard(BuildContext context, Map<String, dynamic> draft) {
    final item = draft['item'] as String;
    final name = draft['name'] as String;
    final price = draft['price'] as String;
    final imageUrl = draft['imageUrl'] as String;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutPage(items: [draft]),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 47, 47, 47),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color.fromARGB(255, 40, 40, 40),
                    child: const Icon(Icons.image, color: Colors.grey, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 73, 143, 200),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: const TextStyle(
                      color: Color(0xFFD4A843),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1A8FCC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Bayar',
                style: TextStyle(
                  color: Color(0xFF1A8FCC),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: Color(0xFF1A8FCC), width: 5),
        ),
      ),
      child: Column(
        children: [
          _infoRow(MaterialCommunityIcons.badge_account, 'NIP', '199003102022011001'),
          const Divider(color: Color.fromARGB(255, 60, 60, 60), height: 20),
          _infoRow(Icons.business, 'Instansi', context.watch<AuthProvider>().activeUser.unit),
          const Divider(color: Color.fromARGB(255, 60, 60, 60), height: 20),
          _infoRow(Icons.email_outlined, 'Email', DraftStore.loggedInUser),
          const Divider(color: Color.fromARGB(255, 60, 60, 60), height: 20),
          _infoRow(Icons.phone_outlined, 'Telepon', context.watch<AuthProvider>().phone),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF498CC8), size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color.fromARGB(255, 133, 133, 133),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.inventory_2, '32', 'Item Dikelola'),
          _containerDivider(),
          _statItem(Icons.store, '12', 'Mitra Supplier'),
          _containerDivider(),
          _statItem(Icons.check_circle, '96%', 'Ketersediaan'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF498CC8), size: 26),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color.fromARGB(255, 133, 133, 133),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _containerDivider() {
    return Container(
      width: 1,
      height: 48,
      color: const Color.fromARGB(255, 60, 60, 60),
    );
  }

  Widget _buildMenuList(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _menuTile(Icons.settings_outlined, 'Pengaturan Akun', () {}),
          _menuBorder(),
          _menuTile(Icons.history, 'Riwayat Pesanan', () {}),
          _menuBorder(),
          _menuTile(MaterialCommunityIcons.shield_check, 'Kebijakan Privasi', () {}),
          _menuBorder(),
          _menuTile(Icons.help_outline, 'Pusat Bantuan', () {}),
          _menuBorder(),
          _menuTile(Icons.logout, 'Keluar', () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Konfirmasi'),
                content: const Text('Apakah Anda yakin ingin logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Tidak'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Ya'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            if (!context.mounted) return;
            await context.read<AuthProvider>().logout();
            if (!context.mounted) return;
            context.go('/login-legacy');
          }),
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF498CC8), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color.fromARGB(255, 100, 100, 100), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _menuBorder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: const Color.fromARGB(255, 60, 60, 60),
    );
  }
}
