import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';

class PeakHoursPage extends StatefulWidget {
  const PeakHoursPage({super.key});

  @override
  State<PeakHoursPage> createState() => _PeakHoursPageState();
}

class _PeakHoursPageState extends State<PeakHoursPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _dateController = TextEditingController();
  final _reasonController = TextEditingController();
  final _rentController = TextEditingController();

  bool _isLoading = false;
  bool _showForm = false;
  List<Map<String, dynamic>> _peakHours = [];

  @override
  void initState() {
    super.initState();
    _fetchPeakHours();
  }

  Future<void> _fetchPeakHours() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/peak-hours/hall/$hallId"); // backend API
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _peakHours = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching peak hours: $e");
    }
  }

  Future<void> _createPeakHour() async {
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
      final url = Uri.parse("$baseUrl/peak-hours");
      final body = jsonEncode({
        "hall_id": hallId,
        "user_id": userId,
        "date": _dateController.text.trim(),
        "reason": _reasonController.text.trim(),
        "rent": double.parse(_rentController.text.trim()),
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newPeak = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Peak hour created successfully")),
        );

        _formKey.currentState!.reset();
        _dateController.clear();
        _reasonController.clear();
        _rentController.clear();

        setState(() {
          _showForm = false;
          _peakHours.insert(0, newPeak);
        });
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePeakHour(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/peak-hours/hall/$hallId/$id");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          _peakHours.removeWhere((ph) => ph["id"] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Peak hour deleted successfully")),
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

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Peak Hour"),
        content: Text("Do you want to delete this peak hour?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePeakHour(id);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakHourForm() {
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
                controller: _dateController,
                decoration: const InputDecoration(labelText: "Date"),
                keyboardType: TextInputType.datetime,
                validator: (value) => value == null || value.isEmpty ? "Enter date" : null,
              ),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: "Reason (optional)"),
              ),
              TextFormField(
                controller: _rentController,
                decoration: const InputDecoration(labelText: "Rent"),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || value.isEmpty ? "Enter rent" : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createPeakHour,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Add Peak Hour"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => setState(() => _showForm = false),
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

  Widget _buildPeakHourCard(Map<String, dynamic> ph) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.access_time),
        title: Text("Date: ${ph["date"] ?? "-"}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reason: ${ph["reason"]?.isNotEmpty == true ? ph["reason"] : "-"}"),
            Text("Rent: \$${ph["rent"] ?? "-"}"),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _showDeleteDialog(ph["id"]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Peak Hours")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_showForm)
              ElevatedButton(
                onPressed: () => setState(() => _showForm = true),
                child: const Text("Add Peak Hour"),
              ),
            if (_showForm) _buildPeakHourForm(),
            const SizedBox(height: 16),
            if (_peakHours.isEmpty) const Text("No peak hours found."),
            ..._peakHours.map(_buildPeakHourCard).toList(),
          ],
        ),
      ),
    );
  }
}
