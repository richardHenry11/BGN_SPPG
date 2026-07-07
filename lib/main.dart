import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/configs/routes.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/providers/jadwal_provider.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';
import 'package:bgn/distribusi/providers/pengiriman_provider.dart';
import 'package:bgn/distribusi/providers/tracking_provider.dart';
import 'package:bgn/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    if (details.exception is AssertionError &&
        details.exceptionAsString().contains('!pageBased || isWaitingForExitingDecision')) {
      debugPrint('[BGN] Suppressed GoRouter navigator assertion during logout');
      return;
    }
    FlutterError.presentError(details);
  };

  await initializeDateFormatting('id_ID');

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final authProvider = AuthProvider();
  await authProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => JadwalProvider()),
        ChangeNotifierProvider(create: (_) => DistribusiProvider()),
        ChangeNotifierProvider(create: (_) => PengirimanProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
      ],
      child: const BGNApp(),
    ),
  );
}

class BGNApp extends StatelessWidget {
  const BGNApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return MaterialApp(
        title: 'BGN',
        debugShowCheckedModeBanner: false,
        theme: BGNTheme.theme,
        home: const MyHomePageMyWidget(),
      );
    }

    return MaterialApp.router(
      title: 'BGN',
      debugShowCheckedModeBanner: false,
      theme: BGNTheme.theme,
      routerConfig: AppRouter.router,
    );
  }
}