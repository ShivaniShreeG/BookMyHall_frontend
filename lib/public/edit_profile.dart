import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  bool isLoading = true;
  bool submitting = false;
  Map<String, dynamic>? profileData;
  String? errorMessage;
  String? message;

  int? hallId;
  int? userId;
  String? role;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    final prefs = await SharedPreferences.getInstance();
    hallId = prefs.getInt('hallId');
    userId = prefs.getInt('userId');
    role = prefs.getString('role');

    if (hallId != null && userId != null && role != null) {
      await _fetchProfile();
    } else {
      setState(() {
        isLoading = false;
        errorMessage = 'User data not found.';
      });
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final url = Uri.parse('$baseUrl/profile/$role/$hallId/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          profileData = data;
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load profile: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching profile: $e';
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      submitting = true;
      message = null;
    });

    try {
      final url = Uri.parse('$baseUrl/profile/$role/$hallId/$userId');

      final body = {
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
      };

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        setState(() {
          message = "✅ Profile updated successfully";
        });
      } else {
        setState(() {
          message = "❌ Failed to update: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        message = "❌ Error: $e";
      });
    } finally {
      setState(() {
        submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3EAD6), // Warm beige
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF5B6547)), // Olive loader
        ),
      );
    }

    if (profileData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3EAD6),
        body: Center(
          child: Text(
            errorMessage ?? 'No profile data found',
            style: const TextStyle(color: Color(0xFF5B6547)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3EAD6), // Warm beige
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFFD8C9A9), // Muted Tan
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF5B6547), // Olive Green
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)), // Muted Tan icons
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: const Color(0xFFE6DCC3), // Slightly darker beige
              shadowColor: const Color(0xFF5B6547).withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // User ID (read-only)
                      TextFormField(
                        initialValue: userId.toString(),
                        decoration: const InputDecoration(
                          labelText: "User ID",
                          labelStyle: TextStyle(color: Color(0xFF5B6547)),
                        ),
                        readOnly: true,
                      ),
                      const SizedBox(height: 16),
                      // Designation (read-only) if admin
                      if (role == 'admin') ...[
                        TextFormField(
                          initialValue: profileData!['designation'] ?? '',
                          decoration: const InputDecoration(
                            labelText: "Designation",
                            labelStyle: TextStyle(color: Color(0xFF5B6547)),
                          ),
                          readOnly: true,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: "Name",
                          labelStyle: TextStyle(color: Color(0xFF5B6547)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: "Phone",
                          labelStyle: TextStyle(color: Color(0xFF5B6547)),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          labelStyle: TextStyle(color: Color(0xFF5B6547)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      if (submitting)
                        const Center(child: CircularProgressIndicator(color: Color(0xFF5B6547))),
                      if (!submitting)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B6547),
                            foregroundColor: const Color(0xFFD8C9A9),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _updateProfile,
                          child: const Text("Save Changes", style: TextStyle(fontSize: 16)),
                        ),
                      if (message != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          message!,
                          style: TextStyle(
                              color: message!.contains("✅")
                                  ? Colors.green
                                  : const Color(0xFF3C3B37)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
