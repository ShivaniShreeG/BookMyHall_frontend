import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  Map<String, dynamic>? profileData;
  String? errorMessage;

  int? hallId;
  int? userId;
  String? role;

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
      await _fetchProfile(hallId!, userId!, role!);
    } else {
      setState(() {
        isLoading = false;
        errorMessage = 'User data not found.';
      });
    }
  }

  Future<void> _fetchProfile(int hallId, int userId, String role) async {
    try {
      final url = Uri.parse('$baseUrl/profile/$role/$hallId/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          profileData = data;
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

  Widget _buildInfoRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5B6547)), // Olive Green 🌿
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3C3B37), // Earthy dark brown 🪵
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3EAD6), // Warm Beige 🏡
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4F5B34)), // Darker Olive 🌿
        ),
      );
    }

    if (profileData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3EAD6), // Warm Beige 🏡
        body: Center(
          child: Text(
            errorMessage ?? 'No profile data found',
            style: const TextStyle(color: Color(0xFF5B6547)), // Olive 🌿
          ),
        ),
      );
    }

    final hall = profileData!['hall'] ?? {};
    final hallLogoBase64 = hall['logo'];
    final hallName = hall['name'] ?? 'Hall';

    return Scaffold(
      backgroundColor: const Color(0xFFF3EAD6), // Warm Beige 🏡
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFFD8C9A9), // Muted Tan 🏺
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF5B6547), // Olive Green 🌿
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)), // Muted Tan 🏺
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: const Color(0xFFE6DCC3), // Slightly darker beige 🏡
              shadowColor: const Color(0xFF5B6547).withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFD8C9A9), // Muted Tan 🏺
                      backgroundImage: hallLogoBase64 != null
                          ? MemoryImage(base64Decode(hallLogoBase64))
                          : null,
                      child: hallLogoBase64 == null
                          ? const Icon(
                        Icons.home,
                        size: 50,
                        color: Color(0xFF5B6547), // Olive Green 🌿
                      )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hallName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5B6547), // Olive Green 🌿
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Divider(
                      color: const Color(0xFF5B6547).withOpacity(0.6), // Slightly darker
                      thickness: 1,
                      height: 20,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Personal Information',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5B6547), // Olive Green 🌿
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.account_circle, profileData!['name'] ?? ''),
                    if (profileData!['role'] == 'admin')
                      _buildInfoRow(Icons.badge, profileData!['designation'] ?? ''),
                    _buildInfoRow(Icons.phone, profileData!['phone'] ?? ''),
                    _buildInfoRow(Icons.email, profileData!['email'] ?? ''),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
