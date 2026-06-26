// lib/providers/distribusi_provider.dart

import 'package:flutter/material.dart';

class CheckpointModel {
  final String lokasi;
  final String waktu;
  final String status;

  CheckpointModel({
    required this.lokasi,
    required this.waktu,
    required this.status,
  });
}

class DriverModel {
  final int id;
  final String nama;
  final String armada;
  final String status;
  final String tujuanSekarang;
  final String eta;
  final Map<String, double> koordinat;
  final List<CheckpointModel> checkpoint;

  DriverModel({
    required this.id,
    required this.nama,
    required this.armada,
    required this.status,
    required this.tujuanSekarang,
    required this.eta,
    required this.koordinat,
    required this.checkpoint,
  });
}

class AktivitasModel {
  final int id;
  final String pesan;
  final String waktu;
  final String tipe;

  AktivitasModel({
    required this.id,
    required this.pesan,
    required this.waktu,
    required this.tipe,
  });
}

class KomplainModel {
  final int id;
  final String lokasi;
  final String pesan;
  final String waktu;
  String status;

  KomplainModel({
    required this.id,
    required this.lokasi,
    required this.pesan,
    required this.waktu,
    required this.status,
  });
}

class DistribusiProvider extends ChangeNotifier {
  // Stats harian
  final Map<String, dynamic> statHarian = {
    'totalPengiriman': 125,
    'tepatWaktu': 118,
    'tepatSasaran': 98.5,
    'komplain': 12,
  };

  // Driver list
  final List<DriverModel> driverList = [
    DriverModel(
      id: 1,
      nama: 'Driver 01',
      armada: 'BGN-01',
      status: 'dalam_perjalanan',
      tujuanSekarang: 'Posyandu 01',
      eta: '08:55',
      koordinat: {'lat': -6.9195, 'lng': 107.6130},
      checkpoint: [
        CheckpointModel(lokasi: 'Dapur SPPG',    waktu: '06:50', status: 'lewat'),
        CheckpointModel(lokasi: 'SDN 01 Bandung', waktu: '07:25', status: 'lewat'),
        CheckpointModel(lokasi: 'Posyandu 01',    waktu: '08:55', status: 'menuju'),
        CheckpointModel(lokasi: 'SMP 01 Cimahi',  waktu: '10:00', status: 'belum'),
      ],
    ),
    DriverModel(
      id: 2,
      nama: 'Driver 02',
      armada: 'BGN-02',
      status: 'standby',
      tujuanSekarang: 'Dapur SPPG',
      eta: '-',
      koordinat: {'lat': -6.9150, 'lng': 107.6400},
      checkpoint: [
        CheckpointModel(lokasi: 'Dapur SPPG',   waktu: '09:30', status: 'belum'),
        CheckpointModel(lokasi: 'SMP 01 Cimahi', waktu: '10:00', status: 'belum'),
        CheckpointModel(lokasi: 'Posyandu 02',   waktu: '11:30', status: 'belum'),
      ],
    ),
  ];

  // Aktivitas terbaru
  final List<AktivitasModel> aktivitasTerbaru = [
    AktivitasModel(id: 1, pesan: 'SDN 01 Bandung — terkirim',            waktu: '08:45', tipe: 'sukses'),
    AktivitasModel(id: 2, pesan: 'Posyandu 01 — dalam perjalanan',       waktu: '08:32', tipe: 'proses'),
    AktivitasModel(id: 3, pesan: 'SMP 01 Cimahi — loading selesai',      waktu: '08:10', tipe: 'info'),
    AktivitasModel(id: 4, pesan: 'BGN-02 standby di dapur',              waktu: '07:55', tipe: 'info'),
    AktivitasModel(id: 5, pesan: 'Komplain diterima — Posyandu 02',      waktu: '07:30', tipe: 'warning'),
  ];

  // Komplain
  final List<KomplainModel> komplainList = [
    KomplainModel(id: 1, lokasi: 'Posyandu 02',  pesan: 'Porsi kurang 3 dari rencana',    waktu: '07:30', status: 'belum_ditangani'),
    KomplainModel(id: 2, lokasi: 'SDN 02',       pesan: 'Makanan tiba terlambat 20 menit', waktu: '08:00', status: 'ditangani'),
  ];

  void tanganiKomplain(int id) {
    final item = komplainList.firstWhere((k) => k.id == id);
    item.status = 'ditangani';
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    notifyListeners();
  }
}