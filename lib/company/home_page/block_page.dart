import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../public/config.dart';

class BlockHallPage extends StatefulWidget {
  final dynamic hall;
  const BlockHallPage({super.key, required this.hall});

  @override
  State<BlockHallPage> createState() => _BlockHallPageState();
}

class _BlockHallPageState extends State<BlockHallPage> {
  final _reasonController = TextEditingController();
  bool _isBlocking = false;
  List<String> _blockReasons = [];
  bool? _isActive; // nullable until loaded
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHallDetails();
  }

  Future<void> _fetchHallDetails() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('$baseUrl/halls/${widget.hall['hall_id']}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isActive = data['is_active'] ?? true;
          _blockReasons = List<String>.from(data['block_reasons'] ?? []);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load hall details'),
            backgroundColor: Color(0xFF5B6547),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFF5B6547),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _blockUnblockHall(bool block) async {
    final reason = _reasonController.text.trim();
    if (block && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason to block the hall'),
          backgroundColor: Color(0xFF5B6547),
        ),
      );
      return;
    }

    setState(() => _isBlocking = true);

    try {
      final url = Uri.parse('$baseUrl/halls/${widget.hall['hall_id']}/block');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'block': block, 'reason': block ? reason : null}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: const Color(0xFF5B6547),
          ),
        );
        _reasonController.clear();

        setState(() {
          _isActive = !block;
          _blockReasons = block ? [reason] : [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.body}'),
            backgroundColor: const Color(0xFF5B6547),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFF5B6547),
        ),
      );
    } finally {
      setState(() => _isBlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8),
      appBar: _isLoading
          ? AppBar(
        backgroundColor: const Color(0xFF5B6547),
        title: const Text(
          'Loading...',
          style: TextStyle(color: Color(0xFFD8C9A9)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
      )
          : AppBar(
        backgroundColor: const Color(0xFF5B6547),
        elevation: 6,
        title: Text(
          "${_isActive == true ? 'Block' : 'Unblock'} - ${widget.hall['name'] ?? 'Hall'}",
          style: const TextStyle(
            color: Color(0xFFD8C9A9),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFD8C9A9)),
      )
          : Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Text(
                _isActive == true
                    ? 'Reason for blocking the hall:'
                    : 'Block Reason(s):',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF5B6547),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),

              // Card
              SizedBox(
                width: 350,
                child: Card(
                  color: const Color(0xFFD8C9A9),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _isActive == true
                        ? TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Enter reason...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Color(0xFF5B6547)),
                      ),
                      style: const TextStyle(color: Color(0xFF5B6547)),
                    )
                        : _blockReasons.isEmpty
                        ? const Text(
                      'No reason provided',
                      style: TextStyle(color: Color(0xFF5B6547)),
                      textAlign: TextAlign.center,
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _blockReasons
                          .map(
                            (r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            "• $r",
                            style: const TextStyle(color: Color(0xFF5B6547)),
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Button
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isBlocking ? null : () => _blockUnblockHall(_isActive!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B6547),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isBlocking
                      ? const CircularProgressIndicator(color: Color(0xFFD8C9A9))
                      : Text(
                    _isActive == true ? 'Block Hall' : 'Unblock Hall',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD8C9A9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
