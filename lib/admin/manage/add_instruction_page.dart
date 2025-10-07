import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';

class HallInstructionsPage extends StatefulWidget {
  const HallInstructionsPage({super.key});

  @override
  State<HallInstructionsPage> createState() => _HallInstructionsPageState();
}

class _HallInstructionsPageState extends State<HallInstructionsPage> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFD8C9A9);

  bool _isLoading = false;
  bool _isLoadingInstructions = true;
  bool _showForm = false;

  List<Map<String, dynamic>> _instructions = [];
  List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _fetchInstructions();
  }

  Future<void> _fetchInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/instructions/hall/$hallId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _instructions = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching instructions: $e");
    } finally {
      setState(() => _isLoadingInstructions = false);
    }
  }

  Future<void> _submitInstructions() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Hall ID not found")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final newInstructions = _controllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .map((t) => {"hall_id": hallId, "instruction": t})
          .toList();

      if (newInstructions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Please add at least one instruction")),
        );
        setState(() => _isLoading = false);
        return;
      }

      final url = Uri.parse("$baseUrl/instructions/bulk");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(newInstructions),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _controllers.clear();
        _showForm = false;
        // Refresh instructions immediately
        await _fetchInstructions();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Instructions added successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error submitting instructions: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error submitting instructions")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteInstruction(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/instructions/$id/hall/$hallId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        // Refresh instructions immediately
        await _fetchInstructions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Instruction deleted")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to delete: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error deleting instruction: $e");
    }
  }

  Future<void> _editInstruction(int id, String oldText) async {
    final controller = TextEditingController(text: oldText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Edit Instruction", style: TextStyle(color: primaryColor)),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 300), // max height for scrolling
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "Instruction",
                labelStyle: TextStyle(color: primaryColor),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
              style: TextStyle(color: primaryColor),
              cursorColor: primaryColor,
              keyboardType: TextInputType.multiline,
              maxLines: null, // allow multiple lines
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty) return;

              Navigator.pop(context);

              final prefs = await SharedPreferences.getInstance();
              final hallId = prefs.getInt("hallId");
              if (hallId == null) return;

              try {
                final url = Uri.parse("$baseUrl/instructions/$id");
                final response = await http.patch(
                  url,
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({"instruction": newText, "hall_id": hallId}),
                );

                if (response.statusCode == 200) {
                  await _fetchInstructions(); // refresh immediately
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Instruction updated")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("❌ Failed to update: ${response.body}")),
                  );
                }
              } catch (e) {
                debugPrint("❌ Error updating instruction: $e");
              }
            },
            child: Text("Save", style: TextStyle(color: backgroundColor)),
          ),
        ],
      ),
    );
  }


  Widget _buildInstructionCard(Map<String, dynamic> d) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.rule, color: primaryColor, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                d["instruction"] ?? "-",
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: primaryColor),
                  onPressed: () => _editInstruction(d["id"], d["instruction"] ?? ""),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(Icons.delete, color: primaryColor),
                  onPressed: () => _showDeleteDialog(d["id"], d["instruction"] ?? "-"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(int id, String instruction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Delete Instruction", style: TextStyle(color: primaryColor)),
        content: Text(
          "Do you want to delete the instruction:\n\n\"$instruction\"?",
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
              _deleteInstruction(id);
            },
            child: Text("Confirm", style: TextStyle(color: backgroundColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionForm() {
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
              ..._controllers.map((controller) {
                int index = _controllers.indexOf(controller);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: "Instruction ${index + 1}",
                      labelStyle: TextStyle(color: primaryColor),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                    ),
                    cursorColor: primaryColor,
                    style: TextStyle(color: primaryColor),
                    validator: (value) => value == null || value.isEmpty ? "Enter instruction" : null,
                  ),
                );
              }).toList(),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _controllers.add(TextEditingController());
                    });
                  },
                  icon: Icon(Icons.add, color: primaryColor),
                  label: Text("Add another instruction", style: TextStyle(color: primaryColor)),
                ),
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
                      onPressed: _isLoading ? null : _submitInstructions,
                      child: _isLoading
                          ? CircularProgressIndicator(color: backgroundColor)
                          : const Text("Save Instructions"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _controllers.clear();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Hall Instructions", style: TextStyle(color: Color(0xFFD8C9A9))),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
      ),
      body: _isLoadingInstructions
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, foregroundColor: backgroundColor),
                onPressed: () {
                  setState(() {
                    _showForm = true;
                    _controllers = [TextEditingController()];
                  });
                },
                child: const Text("Add Instructions"),
              ),
            if (_showForm) _buildInstructionForm(),
            const SizedBox(height: 16),
            if (_instructions.isNotEmpty)
              ..._instructions.map(_buildInstructionCard).toList()
            else
              Center(
                child: Column(
                  children: [
                    Text("No instructions found.",
                        style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
