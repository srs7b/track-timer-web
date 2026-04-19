import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'services/navigation_provider.dart';
import 'services/seed_data_service.dart';
import 'theme/style_constants.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Seed data for prototype
  await SeedDataService.seedIfNecessary();

  runApp(const TrackTimerApp());
}

class TrackTimerApp extends StatelessWidget {
  const TrackTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NavigationProvider(),
      child: const TrackTimerAppContent(),
    );
  }
}

class TrackTimerAppContent extends StatelessWidget {
  const TrackTimerAppContent({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Track Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: VelocityColors.black,
        colorScheme: const ColorScheme.dark(
          primary: VelocityColors.primary,
          secondary: VelocityColors.secondary,
          surface: VelocityColors.surface,
          onSurface: VelocityColors.textBody,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: VelocityTextStyles.heading,
          displayMedium: VelocityTextStyles.subHeading,
          bodyLarge: VelocityTextStyles.body,
          bodySmall: VelocityTextStyles.dimBody,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: VelocityColors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: VelocityColors.textBody,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
