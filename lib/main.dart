import 'package:bgn/login.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/providers/jadwal_provider.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';
import 'package:bgn/distribusi/providers/pengiriman_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => JadwalProvider()),
        ChangeNotifierProvider(create: (_) => DistribusiProvider()),
        ChangeNotifierProvider(create: (_) => PengirimanProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BGN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePageMyWidget(),
    );
  }
}
