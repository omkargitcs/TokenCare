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
  // Update this with your actual Clinic UID
  static const String clinicAdminUid = "PUT_CLINIC_UID_HERE";

  @override
  void initState() {
    super.initState();
    // We call the check directly, the delay is handled inside the function
    _startAppSequence();
  }

  Future<void> _startAppSequence() async {
    // 1. Wait for 2 seconds so the user actually sees the logo
    await Future.delayed(const Duration(seconds: 2));

    try {
      // 2. Check if onboarding is complete
      final prefs = await SharedPreferences.getInstance();
      final bool onboardingComplete =
          prefs.getBool('onboarding_complete') ?? false;

      if (!mounted) return;

      if (!onboardingComplete) {
        // Go to Introduction/Onboarding
        Navigator.pushReplacementNamed(context, '/onboarding');
        return;
      }

      // 3. Check Authentication
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        // 4. Decide Dashboard
        if (user.uid == clinicAdminUid) {
          Navigator.pushReplacementNamed(context, '/clinicHome');
        } else {
          Navigator.pushReplacementNamed(context, '/patientHome');
        }
      }
    } catch (e) {
      // If something fails (like Firebase init), send them to login as fallback
      debugPrint("Splash Error: $e");
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1218), // Midnight Black
      body: Container(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your Animated Logo
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
            // Use a Circular indicator so it doesn't look like a "stuck" bar
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
