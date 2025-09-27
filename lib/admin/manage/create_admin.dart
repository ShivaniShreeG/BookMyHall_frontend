import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';

class CreateAdminPage extends StatefulWidget {
  const CreateAdminPage({super.key});

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  String _designation = "Manager";
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingAdmins = true;
  bool _showForm = false;
  List<Map<String, dynamic>> _admins = [];

  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFD8C9A9);

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/admins/$hallId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _admins = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching admins: $e");
    } finally {
      setState(() {
        _isLoadingAdmins = false;
      });
    }
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Hall ID not found in session")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/users/$hallId/admin");
      final body = jsonEncode({
        "user_id": int.parse(_userIdController.text.trim()),
        "password": _passwordController.text.trim(),
        "designation": _designation,
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "is_active": true
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newAdmin = jsonDecode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Admin created successfully")),
        );

        _formKey.currentState!.reset();
        _userIdController.clear();
        _passwordController.clear();
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        setState(() {
          _designation = "Manager";
          _showForm = false;
          _admins.insert(0, newAdmin);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error creating admin: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error creating admin")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAdmin(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/admins/$hallId/admin/$userId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          _admins.removeWhere((admin) => admin["user_id"] == userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Admin $userId deleted successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to delete admin: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error deleting admin: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error deleting admin")),
      );
    }
  }

  void _showDeleteDialog(int userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Delete Admin", style: TextStyle(color: primaryColor)),
        content: Text("Do you want to delete admin with User ID $userId?",
            style: TextStyle(color: primaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _deleteAdmin(userId);
            },
            child: Text("Confirm", style: TextStyle(color: backgroundColor)),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: primaryColor),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: primaryColor),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: primaryColor),
      ),
    );
  }

  Widget _buildAdminForm() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: backgroundColor,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _userIdController,
                decoration: _buildInputDecoration("User ID"),
                keyboardType: TextInputType.number,
                cursorColor: primaryColor,
                style: TextStyle(color: primaryColor),
                validator: (value) => value == null || value.isEmpty ? "Enter user ID" : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: _buildInputDecoration("Password"),
                obscureText: true,
                cursorColor: primaryColor,
                style: TextStyle(color: primaryColor),
                validator: (value) => value == null || value.isEmpty ? "Enter password" : null,
              ),
              DropdownButtonFormField<String>(
                value: _designation,
                decoration: _buildInputDecoration("Designation"),
                dropdownColor: backgroundColor,
                style: TextStyle(color: primaryColor),
                items: const [
                  DropdownMenuItem(value: "Manager", child: Text("Manager")),
                  DropdownMenuItem(value: "Owner", child: Text("Owner")),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _designation = value;
                    });
                  }
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration("Name (optional)"),
                cursorColor: primaryColor,
                style: TextStyle(color: primaryColor),
              ),
              TextFormField(
                controller: _phoneController,
                decoration: _buildInputDecoration("Phone (optional)"),
                keyboardType: TextInputType.phone,
                cursorColor: primaryColor,
                style: TextStyle(color: primaryColor),
              ),
              TextFormField(
                controller: _emailController,
                decoration: _buildInputDecoration("Email (optional)"),
                keyboardType: TextInputType.emailAddress,
                cursorColor: primaryColor,
                style: TextStyle(color: primaryColor),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: backgroundColor,
                      ),
                      onPressed: _isLoading ? null : _createAdmin,
                      child: _isLoading
                          ? CircularProgressIndicator(color: backgroundColor)
                          : const Text("Create Admin"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() => _showForm = false);
                    },
                    child: Text("Close", style: TextStyle(color: primaryColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.person, color: primaryColor, size: 40),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "User ID: ${admin["user_id"] ?? "N/A"}",
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Name: ${admin["name"]?.isNotEmpty == true ? admin["name"] : "-"}",
                    style: TextStyle(color: primaryColor),
                    softWrap: true,
                  ),
                  Text(
                    "Phone: ${admin["phone"]?.isNotEmpty == true ? admin["phone"] : "-"}",
                    style: TextStyle(color: primaryColor),
                    softWrap: true,
                  ),
                  Text(
                    "Email: ${admin["email"]?.isNotEmpty == true ? admin["email"] : "-"}",
                    style: TextStyle(color: primaryColor),
                    softWrap: true,
                  ),
                  Text(
                    "Designation: ${admin["designation"] ?? "-"}",
                    style: TextStyle(color: primaryColor),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteDialog(admin["user_id"]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Admins", style: TextStyle(color: Color(0xFFD8C9A9))),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
      ),
      body: _isLoadingAdmins
          ? Center(child: CircularProgressIndicator(color: Color(0xFF5B6547)))
          : _admins.isEmpty && !_showForm
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "No admins found.",
              style: TextStyle(
                color: primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: backgroundColor,
              ),
              onPressed: () {
                setState(() => _showForm = true);
              },
              child: const Text("Create Admin"),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                ),
                onPressed: () {
                  setState(() => _showForm = true);
                },
                child: const Text("Create Admin"),
              ),
            if (_showForm) _buildAdminForm(),
            const SizedBox(height: 16),
            ..._admins.map(_buildAdminCard).toList(),
          ],
        ),
      ),
    );
  }
}
