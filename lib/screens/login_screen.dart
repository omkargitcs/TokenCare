import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'clinic_home_screen.dart'; // import your clinic screen

// Static clinic credentials
const clinicEmail = 'clinic@example.com';
const clinicPassword = 'clinic123';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Clinic login
      if (_isLogin && email == clinicEmail && password == clinicPassword) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClinicDashboardScreen()),
        );
        return;
      }

      if (_isLogin) {
        // Patient login
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/patientHome');
      } else {
        // Patient registration
        if (email == clinicEmail) {
          setState(() {
            _error = "Clinic cannot register here.";
            _loading = false;
          });
          return;
        }

        if (_passwordController.text != _confirmController.text) {
          setState(() {
            _error = "Passwords do not match";
            _loading = false;
          });
          return;
        }

        if (_passwordController.text.length < 6) {
          setState(() {
            _error = "Password must be at least 6 characters";
            _loading = false;
          });
          return;
        }

        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/patientHome');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),

            if (!_isLogin) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],

            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text(
                _loading
                    ? 'Please wait...'
                    : _isLogin
                    ? 'Login'
                    : 'Register',
              ),
            ),

            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  _error = null;
                });
              },
              child: Text(
                _isLogin
                    ? "Don't have an account? Register"
                    : "Already have an account? Login",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
