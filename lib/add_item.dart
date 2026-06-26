import 'package:flutter/material.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  final _imageUrlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        title: const Text(
          "Tambah Bahan",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                style: const TextStyle(color: Colors.white),
                controller: _nameController,
                decoration: _inputDecoration("Nama Bahan", Icons.shopping_bag),
                validator: (v) => (v == null || v.isEmpty) ? 'Nama bahan wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      style: const TextStyle(color: Colors.white),
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration("Stok Saat Ini", Icons.inventory),
                      validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      style: const TextStyle(color: Colors.white),
                      controller: _targetController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration("Target Stok", Icons.flag),
                      validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: const TextStyle(color: Colors.white),
                controller: _unitController,
                decoration: _inputDecoration("Satuan (kg, pcs, liter)", Icons.scale),
                validator: (v) => (v == null || v.isEmpty) ? 'Satuan wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: const TextStyle(color: Colors.white),
                controller: _imageUrlController,
                decoration: _inputDecoration("URL Gambar (opsional)", Icons.image),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(context, {
                            'name': _nameController.text.trim(),
                            'stock': int.tryParse(_stockController.text) ?? 0,
                            'target': int.tryParse(_targetController.text) ?? 0,
                            'unit': _unitController.text.trim(),
                            'imageUrl': _imageUrlController.text.trim().isEmpty
                                ? null
                                : _imageUrlController.text.trim(),
                          });
                        }
                      },
                      child: const Center(
                        child: Text(
                          "Simpan",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color.fromARGB(255, 133, 133, 133),
        fontSize: 14,
      ),
      filled: true,
      fillColor: const Color.fromARGB(255, 40, 40, 40),
      prefixIcon: Icon(icon, color: Color.fromARGB(255, 133, 133, 133)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color.fromARGB(255, 19, 89, 146)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color.fromARGB(255, 19, 89, 146)),
      ),
      errorStyle: const TextStyle(color: Color(0xFFE55555)),
    );
  }
}
