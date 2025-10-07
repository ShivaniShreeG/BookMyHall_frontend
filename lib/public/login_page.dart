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

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

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

  // ✅ Custom styled SnackBar
  void _showMessage(String message) {
    const Color oliveGreen = Color(0xFF5B6547);
    const Color mutedTan = Color(0xFFD8C9A9);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: mutedTan,
            fontSize: 16,
          ),
        ),
        backgroundColor: oliveGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

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

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final user = data['user'];
        final message = data['message'] ?? "Login successful";

        _showMessage(message);
        await _saveUserData(user['role'], user['hallId'], user['userId']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
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
    const Color oliveGreen = Color(0xFF5B6547);
    const Color mutedTan = Color(0xFFD8C9A9);
    const Color beige = Color(0xFFF3EAD6);

    // 📱 Responsive sizing based on screen width
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    final double textScale = screenWidth / 375; // base iPhone 11 width
    final double boxScale = screenHeight / 812; // base height reference

    return Scaffold(
      backgroundColor: beige,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 24 * textScale,
            vertical: 40 * boxScale,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Image.asset(
                'assets/logo.png',
                height: 100 * boxScale,
                width: 200 * textScale,
              ),
              SizedBox(height: 20 * boxScale),

              // Card
              Container(
                padding: EdgeInsets.all(24 * boxScale),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20 * boxScale),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10 * boxScale,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Icon(Icons.lock_outline,
                          color: oliveGreen, size: 40 * boxScale),
                      SizedBox(height: 12 * boxScale),
                      Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 26 * textScale,
                          fontWeight: FontWeight.bold,
                          color: oliveGreen,
                        ),
                      ),
                      SizedBox(height: 24 * boxScale),

                      // Hall ID
                      TextFormField(
                        controller: _hallIdController,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.home,
                              color: oliveGreen, size: 22 * boxScale),
                          labelText: "Hall ID",
                          labelStyle:
                          TextStyle(color: oliveGreen, fontSize: 14 * textScale),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(12 * boxScale),
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
                      SizedBox(height: 16 * boxScale),

                      // User ID
                      TextFormField(
                        controller: _userIdController,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.person,
                              color: oliveGreen, size: 22 * boxScale),
                          labelText: "User ID",
                          labelStyle:
                          TextStyle(color: oliveGreen, fontSize: 14 * textScale),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(12 * boxScale),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "User ID is required";
                          }
                          if (int.tryParse(value.trim()) == null) {
                            return "Enter a valid User ID";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16 * boxScale),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock,
                              color: oliveGreen, size: 22 * boxScale),
                          labelText: "Password",
                          labelStyle:
                          TextStyle(color: oliveGreen, fontSize: 14 * textScale),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(12 * boxScale),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: oliveGreen,
                              size: 22 * boxScale,
                            ),
                            onPressed: () {
                              setState(() =>
                              _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? "Password is required"
                            : null,
                      ),
                      SizedBox(height: 12 * boxScale),

                      // Remember Me
                      Row(
                        children: [
                          Transform.scale(
                            scale: 1 * textScale,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: oliveGreen,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                          ),
                          Text(
                            "Remember Me",
                            style: TextStyle(fontSize: 14 * textScale),
                          ),
                        ],
                      ),
                      SizedBox(height: 16 * boxScale),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 50 * boxScale,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: oliveGreen,
                            foregroundColor: mutedTan,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(12 * boxScale),
                            ),
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                              color: Colors.white)
                              : Text(
                            "Login",
                            style: TextStyle(
                                fontSize: 18 * textScale,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      SizedBox(height: 12 * boxScale),

                      // Forgot Password
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ForgotPasswordPage()),
                          );
                        },
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                              color: oliveGreen, fontSize: 14 * textScale),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24 * boxScale),
              Text(
                "© Ramchin Technologies Private Limited",
                style: TextStyle(color: Colors.grey, fontSize: 12 * textScale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
