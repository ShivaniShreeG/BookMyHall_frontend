import 'package:flutter/material.dart';
import 'home_page/manage_hall.dart';
import 'home_page/dashboard_page.dart';

class HomePageWithSelectedHall extends StatefulWidget {
  final dynamic selectedHall;
  const HomePageWithSelectedHall({super.key, this.selectedHall});

  @override
  State<HomePageWithSelectedHall> createState() => _HomePageWithSelectedHallState();
}

class _HomePageWithSelectedHallState extends State<HomePageWithSelectedHall> {
  int _selectedIndex = 0;
  dynamic _selectedHall;

  @override
  void initState() {
    super.initState();
    _selectedHall = widget.selectedHall;
  }

  List<Widget> get _pages => [
    DashboardPage(selectedHall: _selectedHall),
    ManagePage(selectedHall: _selectedHall),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EAD6), // light cream background
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFF5B6547), // Olive green navbar
        selectedItemColor: const Color(0xFFD8C9A9), // Muted tan selected
        unselectedItemColor:
        const Color(0xFFD8C9A9).withOpacity(0.7), // lighter tan unselected
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Manage',
          ),
        ],
      ),
    );
  }
}
