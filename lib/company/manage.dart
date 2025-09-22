import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../public/config.dart';
import 'home.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> with RouteAware {
  List<dynamic> _halls = [];
  int totalUsers = 0;
  int totalBookings = 0;

  bool _showForm = false;
  bool _isLoading = false;

  final _hallIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  String? _pickedImageBase64;

  @override
  void initState() {
    super.initState();
    fetchHalls();
    fetchCounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Refresh when returning from another page
    fetchHalls();
    fetchCounts();
  }

  Future<void> fetchHalls() async {
    try {
      final url = Uri.parse('$baseUrl/halls');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _halls = jsonDecode(response.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to fetch halls: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  Future<void> fetchCounts() async {
    try {
      final url = Uri.parse('$baseUrl/dashboard/counts');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalUsers = data['totalUsers'] ?? 0;
          totalBookings = data['totalBookings'] ?? 0;
        });
      }
    } catch (e) {
      // silently fail
    }
  }

  Future<void> addHall() async {
    setState(() => _isLoading = true);

    int? hallId;
    if (_hallIdController.text.isNotEmpty) {
      hallId = int.tryParse(_hallIdController.text);
      if (hallId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Hall ID must be a number')),
        );
        setState(() => _isLoading = false);
        return;
      }
    }

    final hall = {
      if (hallId != null) 'hall_id': hallId,
      'name': _nameController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'address': _addressController.text,
      'logo': _pickedImageBase64,
    };

    try {
      final url = Uri.parse('$baseUrl/halls');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(hall),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _hallIdController.clear();
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _addressController.clear();
        _pickedImageBase64 = null;
        setState(() => _showForm = false);

        fetchHalls();
        fetchCounts();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Hall registered successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to add hall: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedImageBase64 = base64Encode(bytes);
      });
    }
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(color: Color(0xFF5B6547)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF5B6547)),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF5B6547), width: 2),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildRegisterHallForm() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: const Color(0xFFE6DCC3),
      shadowColor: const Color(0xFF5B6547).withOpacity(0.3),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            _buildTextField(_hallIdController, 'Hall ID (optional)'),
            const SizedBox(height: 16),
            _buildTextField(_nameController, 'Name'),
            const SizedBox(height: 16),
            _buildTextField(_phoneController, 'Phone', keyboard: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField(_emailController, 'Email', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildTextField(_addressController, 'Address', maxLines: 2),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload, color: Color(0xFF5B6547)),
              label: const Text("Upload Logo", style: TextStyle(color: Color(0xFF5B6547))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD8C9A9),
              ),
            ),
            if (_pickedImageBase64 != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFD8C9A9),
                  backgroundImage: MemoryImage(base64Decode(_pickedImageBase64!)),
                ),
              ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF5B6547))
                : ElevatedButton(
              onPressed: addHall,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B6547),
                foregroundColor: const Color(0xFFD8C9A9),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Submit",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBox(String title, int count) {
    return Expanded(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFFE6DCC3),
        shadowColor: const Color(0xFF5B6547).withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B6547),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5B6547),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHallCard(dynamic hall) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HomePageWithSelectedHall(selectedHall: hall),
          ),
        );
        // Refresh halls after returning
        fetchHalls();
        fetchCounts();
      },
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: const Color(0xFFE6DCC3),
        shadowColor: const Color(0xFF5B6547).withOpacity(0.3),
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFD8C9A9),
                backgroundImage: hall['logo'] != null
                    ? MemoryImage(base64Decode(hall['logo']))
                    : null,
                child: hall['logo'] == null
                    ? const Icon(Icons.home_work, size: 40, color: Color(0xFF5B6547))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hall['name'] ?? 'No Name',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5B6547),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hall['address'] ?? 'No Address',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B6547),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EAD6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showForm = !_showForm;
                  if (_showForm) {
                    _hallIdController.clear();
                    _nameController.clear();
                    _phoneController.clear();
                    _emailController.clear();
                    _addressController.clear();
                    _pickedImageBase64 = null;
                  }
                });
              },
              icon: Icon(
                _showForm ? Icons.close : Icons.add_business,
                size: 24,
                color: const Color(0xFFD8C9A9),
              ),
              label: Text(
                _showForm ? "Close Form" : "Register Hall",
                style: const TextStyle(fontSize: 18, color: Color(0xFFD8C9A9)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B6547),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_showForm) _buildRegisterHallForm(),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildCountBox('Total Halls', _halls.length),
                const SizedBox(width: 12),
                _buildCountBox('Total Users', totalUsers),
                const SizedBox(width: 12),
                _buildCountBox('Bookings', totalBookings),
              ],
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Registered Halls",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B6547),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._halls.map((hall) => _buildHallCard(hall)).toList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
