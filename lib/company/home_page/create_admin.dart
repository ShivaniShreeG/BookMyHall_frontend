import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

class CreateAdminPage extends StatefulWidget {
  final dynamic hall;
  const CreateAdminPage({super.key, required this.hall});

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool submitting = false;
  String? message;

  Future<void> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      submitting = true;
      message = null;
    });

    try {
      final userId = int.tryParse(_userIdController.text.trim());
      if (userId == null) {
        setState(() => message = "❌ User ID must be a number");
        return;
      }

      final response = await http.post(
        Uri.parse("$baseUrl/users/${widget.hall['hall_id']}/admin"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "password": _passwordController.text.trim(),
          "designation": "Owner",
          "name": _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          "phone": _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          "email": _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          message = "✅ Admin created successfully for ${widget.hall['name']}";
          _userIdController.clear();
          _passwordController.clear();
          _nameController.clear();
          _phoneController.clear();
          _emailController.clear();
        });
      } else {
        setState(() => message = "❌ Failed: ${response.body}");
      }
    } catch (e) {
      setState(() => message = "❌ Error: $e");
    } finally {
      setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8), // Beige 🏡
      appBar: AppBar(
        title: Text(
          "Create Admin - ${widget.hall['name'] ?? 'Hall'}",
          style: const TextStyle(
            color: Color(0xFFD8C9A9), // Muted Tan 🏺
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF5B6547), // Olive Green 🌿
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)), // Muted Tan 🏺
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ✅ Hall details instead of logo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8C9A9), // Muted Tan 🏺
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "Hall ID: ${widget.hall['hall_id']}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5B6547), // Olive Green 🌿
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Hall Name: ${widget.hall['name'] ?? ''}",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5B6547),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _userIdController,
                decoration: const InputDecoration(
                  labelText: "New Admin User ID",
                  labelStyle: TextStyle(color: Color(0xFF5B6547)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5B6547)),
                  ),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF5B6547)),
                validator: (v) => v == null || v.isEmpty ? "Enter user ID" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  labelStyle: TextStyle(color: Color(0xFF5B6547)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5B6547)),
                  ),
                ),
                obscureText: true,
                style: const TextStyle(color: Color(0xFF5B6547)),
                validator: (v) => v == null || v.length < 4 ? "Min 4 characters" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Name (optional)",
                  labelStyle: TextStyle(color: Color(0xFF5B6547)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5B6547)),
                  ),
                ),
                style: const TextStyle(color: Color(0xFF5B6547)),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone (optional)",
                  labelStyle: TextStyle(color: Color(0xFF5B6547)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5B6547)),
                  ),
                ),
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Color(0xFF5B6547)),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email (optional)",
                  labelStyle: TextStyle(color: Color(0xFF5B6547)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5B6547)),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Color(0xFF5B6547)),
              ),
              const SizedBox(height: 24),

              submitting
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF5B6547)))
                  : ElevatedButton(
                onPressed: _addAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B6547), // Olive Green 🌿
                  foregroundColor: const Color(0xFFD8C9A9), // Muted Tan 🏺
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Add Admin",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 20),
                Text(
                  message!,
                  style: const TextStyle(
                    color: Color(0xFF5B6547), // Always Olive Green 🌿
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
