import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../admin/manage.dart';
import '../admin/admin_dashboard.dart';
import '../company/manage.dart';
import 'app_drawer.dart';
import 'app_navbar.dart';
import 'login_page.dart';
import '../public/config.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  String? role;
  int _selectedIndex = 0;
  bool isLoading = true;
  late List<Widget> _pages;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  // Check login status and setup pages
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('role');
    final savedHallId = prefs.getInt('hallId');
    final savedUserId = prefs.getInt('userId');

    if (savedRole == null ||
        savedHallId == null ||
        savedUserId == null ||
        (savedRole != 'admin' && savedRole != 'administrator')) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    // If admin → fetch and save designation
    if (savedRole == 'admin') {
      await _fetchAndSaveDesignation(savedHallId, savedUserId);
    }

    setState(() {
      role = savedRole;
      isLoading = false;

      if (role == 'admin') {
        _pages = const [
          AdminDashboard(),
          AdminManagePage(),
          Center(child: Text("Booking Details Coming Soon")),
        ];
      } else {
        _pages = const [
          ManagePage(), // Administrator has only one page
        ];
      }
    });

    // Start session validation timer
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _validateSession();
    });
  }

  // Fetch and save designation for admin
  Future<void> _fetchAndSaveDesignation(int hallId, int userId) async {
    try {
      final url = Uri.parse('$baseUrl/admins/$hallId/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String designation = '';
        if (data['admins'] != null && data['admins'].isNotEmpty) {
          designation = data['admins'][0]['designation'] ?? '';
        }

        debugPrint("💡 Fetched designation: $designation");

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('designation', designation);
      }
    } catch (e) {
      debugPrint("❌ Failed to fetch designation: $e");
    }
  }

  // Validate session by checking hall and user active status
  Future<void> _validateSession() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');
    final userId = prefs.getInt('userId');

    if (hallId == null || userId == null) return;

    try {
      final url = Uri.parse('$baseUrl/users/$hallId/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final userActive = data['is_active'] ?? false;
        final hallActive = data['hall']?['is_active'] ?? false;

        if (!hallActive) {
          _showInactiveDialog("This hall has been blocked by the administrator.");
        } else if (!userActive) {
          _showInactiveDialog("Your user account has been deactivated.");
        }
      } else {
        debugPrint("❌ Session validation failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Session validation error: $e");
    }
  }

  // Show blocking dialog
  Future<void> _showInactiveDialog(String reason) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Access Denied"),
        content: Text(reason),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _validateSession();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Only show navbar if role is admin and more than 1 page
    final showNavbar = role == 'admin' && _pages.length > 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B6547), // Olive Green 🌿
        title: Text(
          role == 'admin' ? 'Admin Panel' : 'Administrator Panel',
          style: const TextStyle(
            color: Color(0xFFD8C9A9), // Muted Tan 🏺
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFD8C9A9), // Tan color for drawer icon
        ),
      ),
      drawer: const AppDrawer(),
      body: _pages[_selectedIndex],
      bottomNavigationBar: showNavbar
          ? BottomNavbar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        role: role ?? "",
      )
          : null,
    );
  }
}
