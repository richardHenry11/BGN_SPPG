import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_page.dart';
import 'checkout_page.dart';
import 'draft_store.dart';

class DetailProductPage extends StatefulWidget {
  final Map<String, dynamic> supplier;

  const DetailProductPage({super.key, required this.supplier});

  @override
  State<DetailProductPage> createState() => _DetailProductPageState();
}

class _DetailProductPageState extends State<DetailProductPage> {
  int _quantity = 1;

  String _randomTime() {
    final minutes = [5, 10, 15, 20, 25, 30, 35, 40, 45];
    return '${minutes[DateTime.now().millisecond % minutes.length]} menit';
  }

  String _supplierPhone() {
    final phone = widget.supplier['supplier_phone'] as String?;
    if (phone != null && phone.isNotEmpty) {
      return phone.replaceAll(RegExp(r'[^0-9]'), '');
    }
    final name = widget.supplier['name'] as String;
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = hash * 31 + name.codeUnitAt(i);
    }
    return '62812${(hash.abs() % 100000000).toString().padLeft(8, '0')}';
  }

  void _addToCart() {
    DraftStore.addDraft({
      'item': widget.supplier['item'],
      'name': widget.supplier['name'],
      'price': widget.supplier['price'],
      'imageUrl': widget.supplier['imageUrl'],
      'distance': widget.supplier['distance'],
      'rating': widget.supplier['rating'],
      'quantity': _quantity,
      'unit': widget.supplier['unit'] ?? '',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_quantity ${widget.supplier['item']} ditambahkan ke keranjang'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.supplier['item'] as String;
    final name = widget.supplier['name'] as String;
    final distance = widget.supplier['distance'] as String;
    final rating = widget.supplier['rating'] as double;
    final imageUrl = widget.supplier['imageUrl'] as String;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: SizedBox(
                width: double.infinity,
                height: 250,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color.fromARGB(255, 40, 40, 40),
                    child: const Icon(Icons.image, color: Colors.grey, size: 64),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 73, 143, 200),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.supplier['price'] as String,
                    style: const TextStyle(
                      color: Color(0xFFD4A843),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 47, 47, 47),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: Color(0xFF1A8FCC),
                          width: 5
                        )
                      )
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoChip(Icons.location_on_outlined, 'Jarak', distance),
                        _infoChip(Icons.access_time, 'Estimasi', _randomTime()),
                        _infoChip(Icons.star, 'Rating', rating.toString(), color: const Color(0xFFD4A843)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Standar Kualitas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _qualityStandards(item).map((q) => SizedBox(
                      width: (MediaQuery.of(context).size.width - 72) / 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 35, 45, 55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color.fromARGB(255, 73, 143, 200).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                              ),
                              child: const Icon(Icons.check_circle, color: Colors.white, size: 22),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                q,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 200, 200, 200),
                                  fontSize: 11,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Kontak Supplier',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _largeIconButton(Icons.chat_bubble_outline, 'Chat', const Color(0xFF498CC8), () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(supplier: widget.supplier),
                          ),
                        );
                      }),
                      _largeIconButton(Icons.call_outlined, 'Telepon', const Color(0xFF4CAF50), () {
                        final p = _supplierPhone();
                        launchUrl(Uri.parse('tel:$p')).catchError((_) => false);
                      }),
                      _largeIconButton(MaterialCommunityIcons.whatsapp, 'WhatsApp', const Color(0xFF25D366), () {
                        final p = _supplierPhone();
                        launchUrl(Uri.parse('https://wa.me/$p')).catchError((_) => false);
                      }),
                      _largeIconButton(Icons.telegram, 'Telegram', const Color(0xFF0088CC), () {
                        final p = _supplierPhone();
                        launchUrl(Uri.parse('tg://resolve?phone=$p')).catchError((_) => false);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 47, 47, 47),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                      border: Border.all(color: const Color.fromARGB(255, 60, 60, 60)),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                          child: Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.store, color: Color(0xFF498CC8), size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tentang Supplier',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$name adalah supplier $item terpercaya yang berlokasi sekitar $distance dari lokasi SPPG. '
                                'Telah melayani berbagai mitra dengan kualitas terbaik dan pengiriman tepat waktu.',
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 176, 176, 176),
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 47, 47, 47),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                      border: Border.all(color: const Color.fromARGB(255, 60, 60, 60)),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                          child: Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shopping_bag_outlined, color: Color(0xFF498CC8), size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tentang Produk',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _productDescription(item),
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 176, 176, 176),
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 40, 40, 40),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color.fromARGB(255, 60, 60, 60)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jumlah',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_quantity > 1) setState(() => _quantity--);
                              },
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: _quantity > 1
                                      ? const Color(0xFF1A8FCC).withValues(alpha: 0.15)
                                      : const Color.fromARGB(255, 35, 35, 35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.remove, color: _quantity > 1 ? const Color(0xFF1A8FCC) : const Color.fromARGB(255, 80, 80, 80), size: 20),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$_quantity',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => setState(() => _quantity++),
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A8FCC).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add, color: Color(0xFF1A8FCC), size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1A8FCC)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _addToCart,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_cart_outlined, color: Color(0xFF1A8FCC), size: 20),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Keranjang',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  final item = Map<String, dynamic>.from(widget.supplier);
                                  item['quantity'] = _quantity;
                                  DraftStore.addDraft(item);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutPage(items: [item]),
                                    ),
                                  );
                                },
                                child: const Center(
                                  child: Text(
                                    'Pesan Sekarang',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _productDescription(String item) {
    switch (item) {
      case 'Telur Ayam':
        return 'Telur ayam segar berkualitas tinggi, langsung dari peternakan terpercaya. '
            'Dipanen setiap hari untuk menjamin kesegaran dan kandungan gizi yang optimal. '
            'Cocok untuk kebutuhan konsumsi harian SPPG.';
      case 'Sayuran Segar':
      case 'Kangkung':
      case 'Bayam':
        return 'Sayuran segar yang ditanam secara hidroponik dan organik. '
            'Bebas dari pestisida berbahaya, kaya akan vitamin dan mineral. '
            'Dipanen pada pagi hari dan langsung didistribusikan untuk menjaga kesegaran.';
      case 'Beras':
        return 'Beras berkualitas premium dengan kadar bulir utuh di atas 95%. '
            'Diproses dari pilihan terbaik petani lokal dengan teknologi penggilingan modern. '
            'Menjamin tekstur pulen dan cita rasa yang enak.';
      case 'Ikan Nila':
        return 'Ikan nila segar hasil budidaya kolam air tawar. '
            'Dibudidayakan dengan pakan alami tanpa bahan kimia berbahaya. '
            'Tekstur daging putih bersih, padat, dan tidak berbau lumpur.';
      case 'Wortel':
        return 'Wortel segar dengan kadar air tinggi dan rasa manis alami. '
            'Ditanam di dataran tinggi dengan sistem pertanian berkelanjutan. '
            'Kaya akan vitamin A dan serat alami.';
      case 'Jeruk Pontianak':
        return 'Jeruk Pontianak asli dengan ciri khas rasa manis sedikit asam yang menyegarkan. '
            'Kulit tipis dan mudah dikupas, dengan kandungan vitamin C tinggi. '
            'Dipetik langsung saat matang pohon untuk kualitas terbaik.';
      case 'Minyak Goreng':
        return 'Minyak goreng kemasan berkualitas dengan kandungan asam lemak jenuh rendah. '
            'Diproses dengan teknologi refined, bleached, dan deodorized (RBD) untuk hasil yang jernih dan tidak mudah berasap.';
      case 'Gula Pasir':
        return 'Gula pasir kristal putih berkualitas premium. '
            'Dihasilkan dari tebu pilihan dengan proses kristalisasi modern. '
            'Butiran halus dan kering, cocok untuk kebutuhan SPPG.';
      case 'Tepung Terigu':
        return 'Tepung terigu serbaguna berkualitas tinggi dengan kandungan protein sedang. '
            'Cocok untuk berbagai kebutuhan konsumsi. Diproduksi dengan standar higienis.';
      case 'Cabai Merah':
        return 'Cabai merah segar dengan tingkat kepedasan terkontrol. '
            'Dipanen langsung dari perkebunan lokal untuk menjamin kesegaran. '
            'Warna merah cerah alami tanpa bahan pengawet.';
      case 'Bawang Merah':
        return 'Bawang merah segar dengan ukuran seragam dan kulit kering sempurna. '
            'Dari sentra produksi bawang terbaik, kaya akan antioksidan dan minyak atsiri alami.';
      case 'Bawang Putih':
        return 'Bawang putih kualitas ekspor dengan siung padat dan aroma kuat. '
            'Dikeringkan secara alami tanpa bahan kimia, cocok untuk bumbu dapur.';
      default:
        return '$item berkualitas tinggi yang dipilih langsung dari produsen terpercaya. '
            'Diproses dengan standar kebersihan dan keamanan pangan yang ketat '
            'untuk menjamin produk terbaik bagi program SPPG.';
    }
  }

  List<String> _qualityStandards(String item) {
    switch (item) {
      case 'Telur Ayam':
        return [
          'Bersih, tidak retak, dan tidak bernoda',
          'Berat minimal 55 gram per butir',
          'Kuning telur utuh dan tidak encer',
          'Masa simpan maksimal 7 hari sejak panen',
          'Bebas dari bau busuk atau aroma asing',
        ];
      case 'Sayuran Segar':
      case 'Kangkung':
      case 'Bayam':
        return [
          'Kondisi segar, tidak layu, tidak menguning',
          'Bebas dari hama dan bekas gigitan serangga',
          'Tidak mengandung pestisida berbahaya',
          'Dicuci bersih dan siap olah',
          'Kemasan terjaga kebersihannya',
        ];
      case 'Beras':
        return [
          'Kadar air maksimal 14%',
          'Butir utuh minimal 95%',
          'Bebas dari kutu dan benda asing',
          'Tidak mengandung pemutih atau pewarna',
          'Derajat sosoh minimal 95%',
        ];
      case 'Ikan Nila':
        return [
          'Kondisi segar, mata jernih, insang merah',
          'Tidak berbau lumpur atau amonia',
          'Daging kenyal dan padat saat ditekan',
          'Bebas formalin dan bahan pengawet',
          'Ditangkap/dipanen maksimal 12 jam sebelumnya',
        ];
      case 'Wortel':
        return [
          'Ukuran seragam, tidak bercabang',
          'Tekstur keras dan padat',
          'Warna oranye cerah merata',
          'Bebas dari jamur dan pembusukan',
          'Dicuci bersih tanpa kotoran',
        ];
      case 'Jeruk Pontianak':
        return [
          'Diameter minimal 5 cm',
          'Kulit mulus dan tidak keriput',
          'Rasa manis dengan tingkat kemanisan minimal 11 brix',
          'Bebas dari jamur dan pembusukan',
          'Dipanen maksimal 3 hari sebelum distribusi',
        ];
      case 'Minyak Goreng':
        return [
          'Kemasan tersegel rapi dan tidak bocor',
          'Warna jernih kekuningan',
          'Tidak berbau tengik atau aroma asing',
          'Kandungan asam lemak bebas maksimal 0,3%',
          'Masa berlaku minimal 6 bulan',
        ];
      case 'Gula Pasir':
        return [
          'Warna putih bersih dan seragam',
          'Butiran kering dan tidak menggumpal',
          'Kadar air maksimal 0,1%',
          'Kemanisan standar (polarisasi min 99,8°)',
          'Kemasan bersih dan kuat',
        ];
      case 'Tepung Terigu':
        return [
          'Warna putih bersih alami',
          'Tekstur halus, tidak menggumpal',
          'Bebas dari kutu dan kontaminasi',
          'Kadar air maksimal 13,5%',
          'Protein sesuai standar mutu',
        ];
      case 'Cabai Merah':
        return [
          'Warna merah cerah merata',
          'Tingkat kepedasan sesuai standar',
          'Tidak layu dan tidak busuk',
          'Bebas dari jamur dan bercak hitam',
          'Bertangkai segar',
        ];
      case 'Bawang Merah':
        return [
          'Umbi padat dan tidak keropos',
          'Kulit kering sempurna',
          'Ukuran seragam diameter min 2 cm',
          'Bebas dari busuk dan jamur',
          'Aroma khas bawang segar',
        ];
      case 'Bawang Putih':
        return [
          'Siung utuh dan padat',
          'Kulit kering dan tidak berjamur',
          'Tidak bertunas panjang',
          'Bebas dari noda hitam atau busuk',
          'Aroma bawang putih khas kuat',
        ];
      default:
        return [
          'Produk dalam kondisi segar dan bersih',
          'Kemasan terjaga dan tidak rusak',
          'Bebas dari kontaminasi benda asing',
          'Masa berlaku yang memadai',
          'Sesuai standar mutu pangan nasional',
        ];
    }
  }

  Widget _infoChip(IconData icon, String label, String value, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? const Color.fromARGB(255, 73, 143, 200), size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
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

  Widget _largeIconButton(IconData icon, String label, Color borderColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 40, 40, 40),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: borderColor, width: 3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color.fromARGB(255, 73, 143, 200), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color.fromARGB(255, 133, 133, 133),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
