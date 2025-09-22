import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _message;

  int? hallId;
  int? userId;

  bool _oldPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    hallId = prefs.getInt('hallId');
    userId = prefs.getInt('userId');
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _message = "New password and confirm password do not match";
      });
      return;
    }

    if (hallId == null || userId == null) {
      setState(() {
        _message = "User not found. Please login again.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final url = Uri.parse('$baseUrl/auth/change-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "hallId": hallId,
          "userId": userId,
          "oldPassword": _oldPasswordController.text,
          "newPassword": _newPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);
      setState(() {
        _message = data['message'] ?? 'Operation completed';
      });

      if (response.statusCode == 200) {
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EAD6), // Warm beige background
      appBar: AppBar(
        title: const Text(
          'Change Password',
          style: TextStyle(
            color: Color(0xFFD8C9A9), // Muted Tan text
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF5B6547), // Olive Green header
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)), // Muted Tan icons
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: const Color(0xFFE6DCC3), // Slightly darker beige card
              shadowColor: const Color(0xFF5B6547).withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_message != null)
                        Text(
                          _message!,
                          style: TextStyle(
                            color: _message!.contains('successfully')
                                ? Colors.green
                                : const Color(0xFF3C3B37), // Earthy brown for errors
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Old Password
                      TextFormField(
                        controller: _oldPasswordController,
                        obscureText: !_oldPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Old Password',
                          prefixIcon: const Icon(Icons.lock, color: Color(0xFF5B6547)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _oldPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF5B6547),
                            ),
                            onPressed: () {
                              setState(() {
                                _oldPasswordVisible = !_oldPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) =>
                        value == null || value.isEmpty ? 'Enter old password' : null,
                      ),
                      const SizedBox(height: 12),

                      // New Password
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: !_newPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF5B6547)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _newPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF5B6547),
                            ),
                            onPressed: () {
                              setState(() {
                                _newPasswordVisible = !_newPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) =>
                        value == null || value.isEmpty ? 'Enter new password' : null,
                      ),
                      const SizedBox(height: 12),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_confirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF5B6547)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _confirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF5B6547),
                            ),
                            onPressed: () {
                              setState(() {
                                _confirmPasswordVisible = !_confirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) =>
                        value == null || value.isEmpty ? 'Confirm new password' : null,
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B6547), // Olive Green
                            foregroundColor: const Color(0xFFD8C9A9), // Muted Tan text
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _changePassword,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Color(0xFFD8C9A9))
                              : const Text('Change Password', style: TextStyle(fontSize: 16)),
                        ),
                      ),
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
