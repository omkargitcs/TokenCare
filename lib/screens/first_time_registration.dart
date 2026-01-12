import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class FirstTimeRegistration extends StatefulWidget {
  final Function(Map<String, dynamic>) onProfileSaved;

  const FirstTimeRegistration({Key? key, required this.onProfileSaved})
    : super(key: key);

  @override
  State<FirstTimeRegistration> createState() => _FirstTimeRegistrationState();
}

class _FirstTimeRegistrationState extends State<FirstTimeRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _gender;
  bool _saving = false;

  final List<String> _genders = ['Male', 'Female', 'Other'];

  void _saveProfile() async {
    if (!_formKey.currentState!.validate() || _gender == null) return;

    setState(() => _saving = true);

    final profileData = {
      'name': _nameController.text.trim(),
      'age': int.parse(_ageController.text.trim()),
      'gender': _gender,
      'phone': _phoneController.text.trim(),
    };

    try {
      widget.onProfileSaved(profileData); // callback to PatientHomeScreen
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 12),

                // Age
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter your age';
                    if (int.tryParse(value) == null)
                      return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Gender
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: _genders
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => setState(() => _gender = val),
                  validator: (val) => val == null ? 'Select gender' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter phone number';
                    }
                    if (value.length < 10) {
                      return 'Enter valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Save button
                ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Profile',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
