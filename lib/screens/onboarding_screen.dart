import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const Color backgroundBlack = Color(0xFF0F1218);
  static const Color surfaceDark = Color(0xFF1C212B);
  static const Color accentTeal = Color(0xFF00E5FF);
  static const Color textMuted = Color(0xFF94A3B8);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _pages = [
    {
      "title": "Skip the Waiting Room",
      "desc":
          "Join the clinic queue from the comfort of your home. No more sitting in crowded rooms.",
      "icon": "assets/queue.png",
    },
    {
      "title": "Live Token Tracking",
      "desc":
          "Track your position in real-time. We'll alert you exactly when it's your turn to see the doctor.",
      "icon": "assets/live.png",
    },
    {
      "title": "Time Saving",
      "desc":
          "Save Your Time by taking tokens digitally. Secure, fast, and paperless.",
      "icon": "assets/secure.png",
    },
  ];

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      index == 0
                          ? Icons.access_time_rounded
                          : index == 1
                          ? Icons.stacked_line_chart_rounded
                          : Icons.security_rounded,
                      size: 120,
                      color: AppColors.accentTeal,
                    ),
                    const SizedBox(height: 40),
                    Text(
                      _pages[index]['title']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _pages[index]['desc']!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),

          // Bottom Navigation
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text(
                    "SKIP",
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 5),
                      height: 8,
                      width: _currentIndex == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? AppColors.accentTeal
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_currentIndex == _pages.length - 1) {
                      _completeOnboarding();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.ease,
                      );
                    }
                  },
                  icon: Icon(
                    _currentIndex == _pages.length - 1
                        ? Icons.check_circle
                        : Icons.arrow_forward_ios,
                    color: AppColors.accentTeal,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
