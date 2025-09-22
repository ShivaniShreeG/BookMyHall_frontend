import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation.dart';
import 'config.dart';
import 'forgot_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _hallIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  String? _hallLogoBase64;

  @override
  void initState() {
    super.initState();
    _fetchFirstHallLogo();
    _loadRememberMe();
  }

  // Load Remember Me data
  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        _hallIdController.text = prefs.getInt('hallId')?.toString() ?? '';
        _userIdController.text = prefs.getInt('userId')?.toString() ?? '';
        _passwordController.text = prefs.getString('password') ?? '';
      }
    });
  }

  Future<void> _fetchFirstHallLogo() async {
    try {
      final uri = Uri.parse('$baseUrl/halls/0');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _hallLogoBase64 = data['logo'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching hall logo: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Save user data including Remember Me
  Future<void> _saveUserData(String role, int hallId, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);
    await prefs.setInt('hallId', hallId);
    await prefs.setInt('userId', userId);

    if (_rememberMe) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('password', _passwordController.text);
    } else {
      await prefs.setBool('rememberMe', false);
      await prefs.remove('password');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse("$baseUrl/auth/login");

      Map<String, dynamic> body = {
        "userId": int.tryParse(_userIdController.text.trim()) ?? 0,
        "password": _passwordController.text.trim(),
      };
      if (_hallIdController.text.trim().isNotEmpty) {
        body["hallId"] = int.tryParse(_hallIdController.text.trim());
      }

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      setState(() => _isLoading = false);

      if (response.statusCode != 200) {
        _showMessage("Server error: ${response.statusCode}");
        return;
      }

      if (response.body.isEmpty) {
        _showMessage("Empty response from server");
        return;
      }

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final user = data['user'];
        final hall = data['hall'];

        if (hall != null && hall['logo'] != null) {
          setState(() => _hallLogoBase64 = hall['logo']);
        }

        if (hall != null && hall['is_active'] == false) {
          _showMessage("❌ This hall is inactive. Please contact support.");
          return;
        }

        _showMessage(data['message'] ?? "Login successful");

        await _saveUserData(user['role'], user['hallId'], user['userId']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );

        _hallIdController.clear();
        _userIdController.clear();
        _passwordController.clear();
      } else {
        _showMessage(data['message'] ?? "Login failed");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error connecting to server: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EAD6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hallLogoBase64 != null)
                CircleAvatar(
                  radius: 50,
                  backgroundImage: MemoryImage(base64Decode(_hallLogoBase64!)),
                  backgroundColor: const Color(0xFFD8C9A9),
                )
              else
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFFD8C9A9),
                  child: Icon(Icons.home, size: 50, color: Color(0xFF5B6547)),
                ),
              const SizedBox(height: 16),
              const Text(
                "Login",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B6547),
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _hallIdController,
                      decoration: InputDecoration(
                        labelText: "Hall ID",
                        labelStyle: const TextStyle(color: Color(0xFF5B6547)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            int.tryParse(value) == null) {
                          return "Enter a valid Hall ID";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _userIdController,
                      decoration: InputDecoration(
                        labelText: "User ID",
                        labelStyle: const TextStyle(color: Color(0xFF5B6547)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                      value!.isEmpty ? "Enter user ID" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: const TextStyle(color: Color(0xFF5B6547)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) return "Enter password";
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Remember Me checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                        const Text("Remember Me"),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6547),
                          foregroundColor: const Color(0xFFD8C9A9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Login"),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "OR",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ForgotPasswordPage()),
                          );
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(color: Color(0xFF5B6547)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "© Ramchin Technologies Private Limited",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
