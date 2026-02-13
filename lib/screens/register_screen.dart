import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  // --- Secret Key Configuration ---
  final TextEditingController _secretKeyController = TextEditingController();
  static const String _actualClinicKey = "Mithi1412";

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();

  String? _gender;
  String _selectedRole = 'patient';
  bool _loading = false;
  String? _generatedOtp;

  // --- STEP 1: SEND EMAIL VIA EMAILJS ---
  Future<void> _sendOtpEmail(String email, String otp) async {
    const serviceId = 'service_cw9tmeh';
    const templateId = 'template_jh829hd';
    const publicKey = 's34m6ATJ5HFhtFE2Q';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'origin': 'http://localhost',
      },
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'to_email': email,
          'otp_code': otp,
          'user_name': _nameController.text.trim(),
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send OTP email');
    }
  }

  // --- STEP 2: HANDLE REGISTRATION (With Secret Key Check) ---
  Future<void> _handleRegisterInitiate() async {
    // Basic Form Validation
    if (!_formKey.currentState!.validate() || _gender == null) {
      if (_gender == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Please select gender")));
      }
      return;
    }

    // DOCTOR-ONLY: Secret Key Validation
    if (_selectedRole == 'doctor') {
      if (_secretKeyController.text.trim() != _actualClinicKey) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid Clinic Invite Code! Access Denied."),
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);

    try {
      _generatedOtp = (Random().nextInt(900000) + 100000).toString();
      await _sendOtpEmail(_emailController.text.trim(), _generatedOtp!);

      if (!mounted) return;
      _showOtpVerifyDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send OTP. Check EmailJS or Internet."),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- STEP 3: OTP VERIFICATION DIALOG ---
  void _showOtpVerifyDialog() {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Verify Email",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Code sent to ${_emailController.text}",
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.accentTeal,
                fontSize: 28,
                letterSpacing: 10,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: AppColors.backgroundBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
            ),
            onPressed: () {
              if (otpController.text.trim() == _generatedOtp) {
                Navigator.pop(context);
                _finalizeAccount();
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
              }
            },
            child: const Text(
              "Verify & Join",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 4: FIREBASE SAVING ---
  Future<void> _finalizeAccount() async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = cred.user!.uid;
      final db = FirebaseDatabase.instance.ref();

      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'profile': {
          'name': _nameController.text.trim(),
          'age': int.parse(_ageController.text.trim()),
          'gender': _gender,
          'phone': _phoneController.text.trim(),
        },
        'createdAt': ServerValue.timestamp,
      };

      await db.child('users/$uid').set(userData);

      if (_selectedRole == 'doctor') {
        await db.child('doctors/$uid').set({
          'isVerified': true,
          'clinicName': _nameController.text.trim(),
        });
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        _selectedRole == 'doctor' ? '/clinicHome' : '/patientHome',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                "Fill in your details to get started",
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              _buildRoleToggle(),
              const SizedBox(height: 24),

              // --- CONDITIONAL SECRET KEY FIELD ---
              if (_selectedRole == 'doctor') ...[
                _buildInput(
                  controller: _secretKeyController,
                  label: "Clinic Invite Code",
                  icon: Icons.vpn_key_outlined,
                  obscure: true,
                ),
                const SizedBox(height: 16),
              ],

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
              _buildAgeGenderRow(),
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
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildRoleToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _roleTab("Patient", "patient"),
          _roleTab("Doctor", "doctor"),
        ],
      ),
    );
  }

  Widget _roleTab(String label, String role) {
    bool isActive = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedRole = role;
          if (role == 'patient') _secretKeyController.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

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
        fillColor: AppColors.surfaceDark,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentTeal),
        ),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildAgeGenderRow() {
    return Row(
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
              fillColor: AppColors.surfaceDark,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white10),
              ),
            ),
            items: [
              'Male',
              'Female',
              'Other',
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => _gender = v,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _loading ? null : _handleRegisterInitiate,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentTeal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? const CircularProgressIndicator(color: Colors.black)
            : const Text(
                "Get Verification Code",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
