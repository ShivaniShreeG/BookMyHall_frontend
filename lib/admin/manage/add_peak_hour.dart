import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../public/config.dart';

class PeakHoursPage extends StatefulWidget {
  const PeakHoursPage({super.key});

  @override
  State<PeakHoursPage> createState() => _PeakHoursPageState();
}

class _PeakHoursPageState extends State<PeakHoursPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showForm = false;
  List<Map<String, dynamic>> _peakHours = [];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _customReasonController = TextEditingController();

  String? _selectedReason;
  bool _showCustomReasonField = false;

  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFD8C9A9);

  double _defaultPeakHourAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchDefaultPeakHourAmount();
    _fetchPeakHours();
  }

  Future<void> _fetchDefaultPeakHourAmount() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/default-values/$hallId");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final peakHourDefault = (data as List)
            .firstWhere((d) => d['reason'] == "Peak Hours", orElse: () => null);
        if (peakHourDefault != null) {
          setState(() => _defaultPeakHourAmount = double.parse(peakHourDefault['amount'].toString()));
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching default peak hour amount: $e");
    }
  }

  Future<void> _fetchPeakHours() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/peak-hour/$hallId");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _peakHours = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching peak hours: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleForm({bool clearFields = false}) {
    setState(() {
      _showForm = !_showForm;
      if (clearFields) {
        _dateController.clear();
        _customReasonController.clear();
        _selectedReason = null;
        _showCustomReasonField = false;
      }
    });
  }

  Future<void> _createPeakHour() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    final userId = prefs.getInt("userId");
    if (hallId == null || userId == null) return;

    setState(() => _isSubmitting = true);

    String reason = _selectedReason == "Other"
        ? _customReasonController.text.trim()
        : _selectedReason ?? "";

    if (reason.isNotEmpty) {
      reason = reason[0].toUpperCase() + reason.substring(1);
    }

    final body = {
      "hall_id": hallId,
      "user_id": userId,
      "date": _dateController.text.trim(),
      "reason": reason,
      "rent": _defaultPeakHourAmount,
    };

    try {
      final url = Uri.parse("$baseUrl/peak-hour/$hallId");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newPeak = jsonDecode(response.body);
        setState(() {
          _peakHours.add(newPeak);
          _toggleForm(clearFields: true);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Peak hour created successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error creating peak hour: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error creating peak hour")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deletePeakHour(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/peak-hour/$hallId/$id");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          _peakHours.removeWhere((peak) => peak['id'] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Peak hour deleted successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to delete peak hour: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error deleting peak hour: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error deleting peak hour")),
      );
    }
  }

  void _showDeleteDialog(Map<String, dynamic> peak) {
    String formattedDate = "";
    if (peak['date'] != null) {
      DateTime parsedDate = DateTime.parse(peak['date']);
      formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Delete Peak Hour", style: TextStyle(color: primaryColor)),
        content: Text(
          "${peak['reason']}\nDate: $formattedDate\nRent: ${peak['rent']}",
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
              _deletePeakHour(peak['id']);
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
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
    );
  }

  Widget _buildForm() {
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
              GestureDetector(
                onTap: () async {
                  DateTime firstDate = DateTime.now().add(const Duration(days: 1));
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: firstDate,
                    firstDate: firstDate,
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: primaryColor,
                            onPrimary: backgroundColor,
                            onSurface: primaryColor,
                            surface: backgroundColor,
                          ),
                          dialogBackgroundColor: backgroundColor,
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(foregroundColor: primaryColor),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null) {
                    _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dateController,
                    decoration: _buildInputDecoration("Date"),
                    validator: (value) => value == null || value.isEmpty ? "Select a date" : null,
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: _buildInputDecoration("Reason"),
                dropdownColor: backgroundColor,
                style: TextStyle(color: primaryColor),
                iconEnabledColor: primaryColor,
                items: [
                  DropdownMenuItem(
                    value: "Muhurtam",
                    child: Text("Muhurtam", style: TextStyle(color: primaryColor)),
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
                  });
                },
                validator: (value) => value == null ? "Select a reason" : null,
              ),
              if (_showCustomReasonField)
                TextFormField(
                  controller: _customReasonController,
                  decoration: _buildInputDecoration("Custom Reason"),
                  style: TextStyle(color: primaryColor),
                  validator: (value) => value == null || value.isEmpty ? "Enter custom reason" : null,
                ),
              const SizedBox(height: 12),
              Text(
                "Rent: ₹$_defaultPeakHourAmount",
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
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
                      onPressed: _isSubmitting ? null : _createPeakHour,
                      child: _isSubmitting
                          ? CircularProgressIndicator(color: backgroundColor)
                          : const Text("Add Peak Hour"),
                    ),
                  ),
                  const SizedBox(width: 40),
                  TextButton(
                    onPressed: () => _toggleForm(clearFields: true),
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

  Widget _buildPeakCard(Map<String, dynamic> peak) {
    String formattedDate = "";
    if (peak['date'] != null) {
      DateTime parsedDate = DateTime.parse(peak['date']);
      formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: backgroundColor,
      child: ListTile(
        title: Text(
          peak['reason'] ?? "No reason",
          style: TextStyle(color: primaryColor),
        ),
        subtitle: Text(
          "Date: $formattedDate",
          style: TextStyle(color: primaryColor),
        ),
        leading: Icon(Icons.event, color: primaryColor),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _showDeleteDialog(peak),
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
        title: const Text(
          "Peak Hours",
          style: TextStyle(color: Color(0xFFD8C9A9)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
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
                onPressed: () => _toggleForm(clearFields: true),
                child: const Text("Add Peak Hour"),
              ),
            if (_showForm) _buildForm(),
            const SizedBox(height: 16),
            if (_peakHours.isEmpty)
              Text(
                "No peak hours found.",
                style: TextStyle(color: primaryColor, fontSize: 16),
              ),
            ..._peakHours.map(_buildPeakCard).toList(),
          ],
        ),
      ),
    );
  }
}
