import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // TIP: If you have multiple clinic staff, checking the email suffix is easier
  // than a single UID.
  static const String clinicEmailSuffix = "@clinic.com";

  @override
  void initState() {
    super.initState();
    _startAppSequence();
  }

  Future<void> _startAppSequence() async {
    // 1. Branding delay
    await Future.delayed(const Duration(seconds: 2));

    try {
      // 2. Check persistent Onboarding state
      final prefs = await SharedPreferences.getInstance();
      final bool onboardingComplete =
          prefs.getBool('onboarding_complete') ?? false;

      if (!mounted) return;

      if (!onboardingComplete) {
        Navigator.pushReplacementNamed(context, '/onboarding');
        return;
      }

      // 3. Persistent Auth Check
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // No active session
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        // 4. Role-Based Routing
        // We check if the email contains your clinic identifier
        if (user.email != null && user.email!.endsWith(clinicEmailSuffix)) {
          Navigator.pushReplacementNamed(context, '/clinicHome');
        } else {
          // It's a patient
          Navigator.pushReplacementNamed(context, '/patientHome');
        }
      }
    } catch (e) {
      debugPrint("Splash Error: $e");
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1218), // Midnight Black
      body: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.medical_services_rounded,
              size: 80,
              color: Color(0xFF00E5FF),
            ),
            const SizedBox(height: 24),
            const Text(
              'TokenCare',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 60),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF00E5FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
