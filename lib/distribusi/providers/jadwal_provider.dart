// lib/providers/jadwal_provider.dart

import 'package:flutter/material.dart';

class JadwalModel {
  final int id;
  final String tujuan;
  final String alamat;
  final String waktu;
  final int porsi;
  final String kategori;
  final String driver;
  final String armada;
  String status;
  final Map<String, double> koordinat;

  JadwalModel({
    required this.id,
    required this.tujuan,
    required this.alamat,
    required this.waktu,
    required this.porsi,
    required this.kategori,
    required this.driver,
    required this.armada,
    required this.status,
    required this.koordinat,
  });
}

class JadwalProvider extends ChangeNotifier {
  final List<JadwalModel> _jadwalList = [
    JadwalModel(
      id: 1,
      tujuan: 'SDN 01 Bandung',
      alamat: 'Jl. Merdeka No. 1, Bandung',
      waktu: '07:00',
      porsi: 120,
      kategori: 'Peserta Didik',
      driver: 'Driver 01',
      armada: 'BGN-01',
      status: 'selesai',
      koordinat: {'lat': -6.9175, 'lng': 107.6191},
    ),
    JadwalModel(
      id: 2,
      tujuan: 'Posyandu 01',
      alamat: 'Jl. Melati No. 5, Bandung',
      waktu: '08:30',
      porsi: 45,
      kategori: 'Balita & Ibu Hamil',
      driver: 'Driver 01',
      armada: 'BGN-01',
      status: 'dalam_perjalanan',
      koordinat: {'lat': -6.9218, 'lng': 107.6072},
    ),
    JadwalModel(
      id: 3,
      tujuan: 'SMP 01 Cimahi',
      alamat: 'Jl. Cimahi Raya No. 12',
      waktu: '10:00',
      porsi: 200,
      kategori: 'Peserta Didik',
      driver: 'Driver 02',
      armada: 'BGN-02',
      status: 'belum_berangkat',
      koordinat: {'lat': -6.8842, 'lng': 107.5424},
    ),
    JadwalModel(
      id: 4,
      tujuan: 'Posyandu 02',
      alamat: 'Jl. Anggrek No. 3, Bandung',
      waktu: '11:30',
      porsi: 30,
      kategori: 'Balita',
      driver: 'Driver 02',
      armada: 'BGN-02',
      status: 'belum_berangkat',
      koordinat: {'lat': -6.9301, 'lng': 107.6284},
    ),
  ];

  List<JadwalModel> get jadwalList => _jadwalList;

  int get totalSelesai =>
      _jadwalList.where((j) => j.status == 'selesai').length;

  int get totalDalamPerjalanan =>
      _jadwalList.where((j) => j.status == 'dalam_perjalanan').length;

  int get totalBelumBerangkat =>
      _jadwalList.where((j) => j.status == 'belum_berangkat').length;

  int get totalPorsi =>
      _jadwalList.fold(0, (sum, j) => sum + j.porsi);

  List<JadwalModel> filterByStatus(String status) {
    if (status == 'semua') return _jadwalList;
    return _jadwalList.where((j) => j.status == status).toList();
  }

  void updateStatus(int id, String status) {
    final item = _jadwalList.firstWhere((j) => j.id == id);
    item.status = status;
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    notifyListeners();
  }
}