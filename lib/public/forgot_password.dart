import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _hallIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  String? _message;

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/auth/forgot-password');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hallId': int.tryParse(_hallIdController.text.trim()) ?? 0,
          'userId': int.tryParse(_userIdController.text.trim()) ?? 0,
          'email': _emailController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      setState(() {
        _message = data['message'] ?? 'Request submitted';
      });
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
      backgroundColor: const Color(0xFFF3EAD6), // Warm beige
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: const Color(0xFF5B6547), // Olive Green 🌿
        foregroundColor: const Color(0xFFD8C9A9), // Muted Tan 🏺
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: const Color(0xFFECE5D8), // Beige 🏡 card
              shadowColor: const Color(0xFF5B6547).withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Reset Your Password",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5B6547),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _hallIdController,
                        decoration: const InputDecoration(
                          labelText: "Hall ID",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                        value == null || value.isEmpty ? 'Enter Hall ID' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _userIdController,
                        decoration: const InputDecoration(
                          labelText: "User ID",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                        value == null || value.isEmpty ? 'Enter User ID' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter Email';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$')
                              .hasMatch(value)) return 'Enter valid Email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      if (_message != null)
                        Text(
                          _message!,
                          style: TextStyle(
                            color: _message!.toLowerCase().contains('success')
                                ? Colors.green
                                : Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B6547),
                            foregroundColor: const Color(0xFFD8C9A9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submitRequest,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Submit Request"),
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
