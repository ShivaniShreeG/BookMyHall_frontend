import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';
import 'config.dart';
import 'edit_profile.dart';
import 'profile.dart';
import 'change_password.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String hallName = 'Hall';
  String? hallLogoBase64;

  @override
  void initState() {
    super.initState();
    _loadHallInfo();
  }

  Future<void> _loadHallInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('hallName');
    String? logo = prefs.getString('hallLogo');
    int? hallId = prefs.getInt('hallId');

    // Show cached data if available
    if (name != null) {
      if (!mounted) return;
      setState(() {
        hallName = name;
        hallLogoBase64 = logo;
      });
    }

    // Always refresh from API if hallId exists
    if (hallId != null) {
      await _fetchHallInfo(hallId);
    }
  }


  Future<void> _fetchHallInfo(int hallId) async {
    try {
      final url = Uri.parse('$baseUrl/halls/$hallId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('hallName', data['name']);
        if (data['logo'] != null) await prefs.setString('hallLogo', data['logo']);

        if (!mounted) return;
        setState(() {
          hallName = data['name'];
          hallLogoBase64 = data['logo'];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch hall info: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFECE5D8), // beige background below header
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Color(0xFF5B6547), // olive green header
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: const Color(0xFFD8C9A9), // muted tan
                          backgroundImage: hallLogoBase64 != null
                              ? MemoryImage(base64Decode(hallLogoBase64!))
                              : null,
                          child: hallLogoBase64 == null
                              ? const Icon(Icons.home,
                              size: 35, color: Color(0xFF5B6547)) // olive green
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Flexible(
                          child: Text(
                            hallName,
                            style: const TextStyle(
                              color: Color(0xFFD8C9A9), // dark earthy text
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFF5B6547)),
                    title: const Text('Profile',
                        style: TextStyle(color: Color(0xFF5B6547))),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ProfilePage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock, color: Color(0xFF5B6547)),
                    title: const Text('Change Password',
                        style: TextStyle(color: Color(0xFF5B6547))),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ChangePasswordPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit, color: Color(0xFF5B6547)),
                    title: const Text('Edit profile',
                        style: TextStyle(color: Color(0xFF5B6547))),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const EditProfilePage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFF5B6547)),
                    title: const Text('Logout',
                        style: TextStyle(color: Color(0xFF5B6547))),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            color: const Color(0xFFECE5D8), // beige footer background
            child: const Text(
              '© Ramchin Technologies Private Limited',
              style: TextStyle(color: Color(0xFF5B6547), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
