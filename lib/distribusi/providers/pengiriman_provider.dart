// lib/providers/pengiriman_provider.dart

import 'package:flutter/material.dart';

class ValidasiData {
  final int jumlah;
  final String kondisi;
  final String catatan;
  final String petugas;
  final String timestamp;

  ValidasiData({
    required this.jumlah,
    required this.kondisi,
    required this.catatan,
    required this.petugas,
    required this.timestamp,
  });
}

class PengirimanModel {
  final int id;
  final String tanggal;
  final String waktu;
  final String alamat;
  final int porsiRencana;
  final String kategori;
  final String pengantar;
  final String penerima;
  String status;
  ValidasiData? validasiKeluar;
  ValidasiData? validasiMasuk;
  int? selisih;

  PengirimanModel({
    required this.id,
    required this.tanggal,
    required this.waktu,
    required this.alamat,
    required this.porsiRencana,
    required this.kategori,
    required this.pengantar,
    required this.penerima,
    required this.status,
    this.validasiKeluar,
    this.validasiMasuk,
    this.selisih,
  });
}

class PengirimanProvider extends ChangeNotifier {
  final List<PengirimanModel> _pengirimanList = [
    PengirimanModel(
      id: 1,
      tanggal: '2026-06-07',
      waktu: '07:00',
      alamat: 'SDN 01, Jl. Merdeka No. 1',
      porsiRencana: 120,
      kategori: 'Peserta Didik',
      pengantar: 'Aslab 01',
      penerima: 'Penerima 01',
      status: 'selesai',
      validasiKeluar: ValidasiData(
        jumlah: 120, kondisi: 'baik',
        catatan: '', petugas: 'Aslab 01',
        timestamp: '06:45',
      ),
      validasiMasuk: ValidasiData(
        jumlah: 120, kondisi: 'baik',
        catatan: '', petugas: 'Aslab 01',
        timestamp: '07:28',
      ),
      selisih: 0,
    ),
    PengirimanModel(
      id: 2,
      tanggal: '2026-06-07',
      waktu: '08:30',
      alamat: 'Posyandu 01, Jl. Melati No. 5',
      porsiRencana: 45,
      kategori: 'Balita & Ibu Hamil',
      pengantar: 'Aslab 01',
      penerima: 'Penerima 02',
      status: 'dalam_perjalanan',
      validasiKeluar: ValidasiData(
        jumlah: 45, kondisi: 'baik',
        catatan: '', petugas: 'Aslab 01',
        timestamp: '08:10',
      ),
    ),
    PengirimanModel(
      id: 3,
      tanggal: '2026-06-07',
      waktu: '10:00',
      alamat: 'SMP 01, Jl. Cimahi Raya No. 12',
      porsiRencana: 200,
      kategori: 'Peserta Didik',
      pengantar: 'Aslab 02',
      penerima: 'Penerima 03',
      status: 'belum_berangkat',
    ),
  ];

  List<PengirimanModel> get pengirimanList => _pengirimanList;

  int get totalSelesai =>
      _pengirimanList.where((p) => p.status == 'selesai').length;

  int get totalDalamPerjalanan =>
      _pengirimanList.where((p) => p.status == 'dalam_perjalanan').length;

  int get totalBelumBerangkat =>
      _pengirimanList.where((p) => p.status == 'belum_berangkat').length;

  PengirimanModel? getPengirimanById(int id) {
    try {
      return _pengirimanList.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  void tambahPengiriman(PengirimanModel data) {
    _pengirimanList.add(data);
    notifyListeners();
  }

  void inputValidasiKeluar(int id, ValidasiData data) {
    final item = getPengirimanById(id);
    if (item == null) return;
    item.validasiKeluar = data;
    item.status = 'dalam_perjalanan';
    notifyListeners();
  }

  void inputValidasiMasuk(int id, ValidasiData data) {
    final item = getPengirimanById(id);
    if (item == null) return;
    item.validasiMasuk = data;
    item.selisih = data.jumlah - (item.validasiKeluar?.jumlah ?? 0);
    item.status = 'selesai';
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    notifyListeners();
  }
}