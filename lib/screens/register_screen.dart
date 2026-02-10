import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AppColors {
  static const Color backgroundBlack = Color(0xFF0F1218);
  static const Color surfaceDark = Color(0xFF1C212B);
  static const Color accentTeal = Color(0xFF00E5FF);
  static const Color textMuted = Color(0xFF94A3B8);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Auth Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Profile Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  String? _gender;

  bool _loading = false;
  final List<String> _genders = ['Male', 'Female', 'Other'];

  // Helper for Styled Inputs
  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.accentTeal, size: 20),
        filled: true,
        fillColor: AppColors.backgroundBlack,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accentTeal),
        ),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate() || _gender == null) return;

    setState(() => _loading = true);

    try {
      // 1. Create User in Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2. Save EVERYTHING at once (Auth data + Profile data)
      // This ensures the PatientHomeScreen sees the 'profile' node immediately
      await FirebaseDatabase.instance.ref('users/$uid').set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': 'patient',
        'profile': {
          'name': _nameController.text.trim(),
          'age': int.parse(_ageController.text.trim()),
          'gender': _gender,
          'phone': _phoneController.text.trim(),
        },
        'createdAt': ServerValue.timestamp,
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/patientHome');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Create Account",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Fill details to start booking tokens",
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),

              _buildInput(
                controller: _nameController,
                label: "Full Name",
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),

              _buildInput(
                controller: _emailController,
                label: "Email Address",
                icon: Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInput(
                      controller: _ageController,
                      label: "Age",
                      icon: Icons.cake_outlined,
                      type: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      dropdownColor: AppColors.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Gender",
                        labelStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.backgroundBlack,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white10),
                        ),
                      ),
                      items: _genders
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (v) => _gender = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildInput(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone_android_outlined,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              _buildInput(
                controller: _passwordController,
                label: "Password",
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(
                          color: AppColors.backgroundBlack,
                        )
                      : const Text(
                          "Register & Join",
                          style: TextStyle(
                            color: AppColors.backgroundBlack,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
