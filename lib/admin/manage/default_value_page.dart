import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';

class DefaultValuesPage extends StatefulWidget {
  const DefaultValuesPage({super.key});

  @override
  State<DefaultValuesPage> createState() => _DefaultValuesPageState();
}

class _DefaultValuesPageState extends State<DefaultValuesPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  final _customReasonController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingDefaults = true;
  bool _showForm = false;
  int? _editingDefaultId;

  String? _selectedReason;
  bool _showCustomReasonField = false;

  List<Map<String, dynamic>> _defaultValues = [];

  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFD8C9A9);

  @override
  void initState() {
    super.initState();
    _fetchDefaultValues();
  }

  Future<void> _fetchDefaultValues() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/default-values/$hallId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _defaultValues = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching default amount: $e");
    } finally {
      setState(() => _isLoadingDefaults = false);
    }
  }

  Future<void> _submitDefaultValue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    final userId = prefs.getInt("userId");
    if (hallId == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Hall ID or User ID not found in session")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      Uri url;

      // Handle custom reason capitalization
      if (_showCustomReasonField) {
        String custom = _customReasonController.text.trim();
        if (custom.isNotEmpty) {
          _reasonController.text = custom[0].toUpperCase() + custom.substring(1);
        }
      }

      Map<String, dynamic> body = {
        "userId": userId,
        "reason": _reasonController.text.trim(),
        "amount": double.parse(_amountController.text.trim()),
      };

      if (_editingDefaultId == null) {
        url = Uri.parse("$baseUrl/default-values/$hallId");
      } else {
        url = Uri.parse("$baseUrl/default-values/$_editingDefaultId");
      }

      final response = _editingDefaultId == null
          ? await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(body))
          : await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final defaultValue = jsonDecode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editingDefaultId == null
              ? "✅ Default amount added successfully"
              : "✅ Default amount updated successfully")),
        );

        _formKey.currentState!.reset();
        _reasonController.clear();
        _customReasonController.clear();
        _amountController.clear();
        _selectedReason = null;
        _showCustomReasonField = false;

        setState(() {
          if (_editingDefaultId == null) {
            _defaultValues.insert(0, defaultValue);
          } else {
            int index = _defaultValues.indexWhere((d) => d["id"] == defaultValue["id"]);
            if (index != -1) _defaultValues[index] = defaultValue;
          }
          _editingDefaultId = null;
          _showForm = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error submitting default amount: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error submitting default amount")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDefault(int defaultId) async {
    try {
      final url = Uri.parse("$baseUrl/default-values/$defaultId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() => _defaultValues.removeWhere((d) => d["id"] == defaultId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Default Amount deleted successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to delete: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error deleting default amount: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error deleting default amount")),
      );
    }
  }

  void _showDeleteDialog(int defaultId, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Delete Default Amount", style: TextStyle(color: primaryColor)),
        content: Text(
          "Do you want to delete the default amount for \"$reason\"?",
          style: TextStyle(color: primaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _deleteDefault(defaultId);
            },
            child: Text("Confirm", style: TextStyle(color: backgroundColor)),
          ),
        ],
      ),
    );
  }

  void _editDefault(Map<String, dynamic> d) {
    setState(() {
      _editingDefaultId = d["id"];
      _reasonController.text = d["reason"] ?? "";
      _amountController.text = d["amount"]?.toString() ?? "";

      // Determine if reason matches dropdown or custom
      if (d["reason"] == "Rent" || d["reason"] == "Peak Hours" ||d["reason"] == "Cancel" || d["reason"] == "EB (per unit)") {
        _selectedReason = d["reason"];
        _showCustomReasonField = false;
        _customReasonController.clear();
      } else {
        _selectedReason = "Other";
        _showCustomReasonField = true;
        _customReasonController.text = d["reason"];
      }

      _showForm = true;
    });
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: primaryColor),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
    );
  }

  Widget _buildDefaultForm() {
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
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: _buildInputDecoration("Reason"),
                dropdownColor: backgroundColor,
                style: TextStyle(color: primaryColor),
                iconEnabledColor: primaryColor,
                items: [
                  DropdownMenuItem(
                    value: "Rent",
                    child: Text("Rent", style: TextStyle(color: primaryColor)),
                  ),
                  DropdownMenuItem(
                    value: "Peak Hours",
                    child: Text("Peak Hours", style: TextStyle(color: primaryColor)),
                  ),
                  DropdownMenuItem(
                    value: "EB (per unit)",
                    child: Text("EB (per unit)", style: TextStyle(color: primaryColor)),
                  ),
                  DropdownMenuItem(
                    value: "Cancel",
                    child: Text("Cancel", style: TextStyle(color: primaryColor)),
                  ),
                  DropdownMenuItem(
                    value: "Other",
                    child: Text("Other", style: TextStyle(color: primaryColor)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                    _showCustomReasonField = value == "Other";
                    if (!_showCustomReasonField) _reasonController.text = value!;
                  });
                },
                validator: (value) =>
                (_showCustomReasonField ? null : value == null ? "Select reason" : null),
              ),
              if (_showCustomReasonField)
                TextFormField(
                  controller: _customReasonController,
                  decoration: _buildInputDecoration("Custom Reason"),
                  cursorColor: primaryColor,
                  style: TextStyle(color: primaryColor),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter custom reason" : null,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: _buildInputDecoration("Amount"),
                keyboardType: TextInputType.number,
                cursorColor: primaryColor,
                style: TextStyle(color: primaryColor),
                validator: (value) => value == null || value.isEmpty ? "Enter amount" : null,
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
                      onPressed: _isLoading ? null : _submitDefaultValue,
                      child: _isLoading
                          ? CircularProgressIndicator(color: backgroundColor)
                          : Text(_editingDefaultId == null
                          ? "Add Default Amount"
                          : "Update Default Amount"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _editingDefaultId = null;
                        _reasonController.clear();
                        _customReasonController.clear();
                        _selectedReason = null;
                        _showCustomReasonField = false;
                        _amountController.clear();
                      });
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

  Widget _buildDefaultCard(Map<String, dynamic> d) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.note_alt, color: primaryColor, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d["reason"] ?? "-",
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                  // Show percentage if reason is Cancel, else amount
                  Text(
                    d["reason"] == "Cancel"
                        ? "Percentage: ${d["amount"] ?? "-"}%"
                        : "Amount: ${d["amount"] ?? "-"}",
                    style: TextStyle(color: primaryColor),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: primaryColor),
                  onPressed: () => _editDefault(d),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: primaryColor),
                  onPressed: () => _showDeleteDialog(d["id"], d["reason"] ?? "-"),
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
        title: const Text("Default Amount", style: TextStyle(color: Color(0xFFD8C9A9))),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
      ),
      body: _isLoadingDefaults
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _defaultValues.isEmpty && !_showForm
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("No default amount found.",
                style: TextStyle(
                    color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, foregroundColor: backgroundColor),
              onPressed: () => setState(() => _showForm = true),
              child: const Text("Add Default Amount"),
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
                    backgroundColor: primaryColor, foregroundColor: backgroundColor),
                onPressed: () => setState(() => _showForm = true),
                child: const Text("Add Default Amount"),
              ),
            if (_showForm) _buildDefaultForm(),
            const SizedBox(height: 16),
            ..._defaultValues.map(_buildDefaultCard).toList(),
          ],
        ),
      ),
    );
  }
}
