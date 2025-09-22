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
  final _designationController =
  TextEditingController(text: "Manager"); // default
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _showForm = false;
  List<Map<String, dynamic>> _admins = [];

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
      final url = Uri.parse("$baseUrl/admins/$hallId"); // API to fetch all admins
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _admins = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching admins: $e");
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
        "designation": "Manager",
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
          _showForm = false;
          _admins.insert(0, newAdmin); // add new admin to list
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
        title: const Text("Delete Admin"),
        content: Text("Do you want to delete admin with User ID $userId?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _deleteAdmin(userId);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminForm() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _userIdController,
                decoration: const InputDecoration(labelText: "User ID"),
                keyboardType: TextInputType.number,
                validator: (value) =>
                value == null || value.isEmpty ? "Enter user ID" : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (value) =>
                value == null || value.isEmpty ? "Enter password" : null,
              ),
              TextFormField(
                controller: _designationController,
                readOnly: true,
                decoration: const InputDecoration(labelText: "Designation"),
              ),
              TextFormField(
                controller: _nameController,
                decoration:
                const InputDecoration(labelText: "Name (optional)"),
              ),
              TextFormField(
                controller: _phoneController,
                decoration:
                const InputDecoration(labelText: "Phone (optional)"),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _emailController,
                decoration:
                const InputDecoration(labelText: "Email (optional)"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createAdmin,
                      child: _isLoading
                          ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                          : const Text("Create Admin"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() => _showForm = false);
                    },
                    child: const Text("Close"),
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
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text("User ID: ${admin["user_id"] ?? "N/A"}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Name: ${admin["name"]?.isNotEmpty == true ? admin["name"] : "-"}"),
            Text("Phone: ${admin["phone"]?.isNotEmpty == true ? admin["phone"] : "-"}"),
            Text("Email: ${admin["email"]?.isNotEmpty == true ? admin["email"] : "-"}"),
            Text("Designation: ${admin["designation"] ?? "-"}"),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            _showDeleteDialog(admin["user_id"]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admins"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_showForm)
              ElevatedButton(
                onPressed: () {
                  setState(() => _showForm = true);
                },
                child: const Text("Create Admin"),
              ),
            if (_showForm) _buildAdminForm(),
            const SizedBox(height: 16),
            if (_admins.isEmpty)
              const Text("No admins found."),
            ..._admins.map(_buildAdminCard).toList(),
          ],
        ),
      ),
    );
  }
}
