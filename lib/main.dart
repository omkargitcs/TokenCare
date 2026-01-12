import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

import 'screens/clinic_home_screen.dart';
import 'screens/patient_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TokenCare',
      debugShowCheckedModeBanner: false,
      theme: appTheme(), // use your custom theme
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginRegisterScreen(),
        '/register': (context) => const RegisterScreen(),
        '/clinicHome': (context) => const ClinicDashboardScreen(),
        '/patientHome': (context) => PatientHomeScreen(),
      },
    );
  }
}
