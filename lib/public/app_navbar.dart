import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String role;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    // Hide navbar for administrator role
    if (role == "administrator") {
      return const SizedBox.shrink();
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: const Color(0xFF5B6547), // Olive Green 🌿
      selectedItemColor: const Color(0xFFD8C9A9), // Muted Tan 🏺
      unselectedItemColor: const Color(0xFFD8C9A9).withOpacity(0.7), // lighter tan for unselected
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.manage_accounts),
          label: "Manage",
        ),
      ],
    );
  }
}
