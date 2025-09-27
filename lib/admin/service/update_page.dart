import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

class UpdateBookingPage extends StatefulWidget {
  final int hallId;
  final int bookingId;
  final int userId;
  final Map<String, dynamic> bookingDetails;

  const UpdateBookingPage({
    super.key,
    required this.hallId,
    required this.bookingId,
    required this.userId,
    required this.bookingDetails,
  });

  @override
  State<UpdateBookingPage> createState() => _UpdateBookingPageState();
}

class _UpdateBookingPageState extends State<UpdateBookingPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _eventTypeController;
  bool _loading = false;

  final Color oliveGreen = const Color(0xFF5B6547);
  final Color lightTan = const Color(0xFFF3E2CB);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bookingDetails['name']);
    _eventTypeController = TextEditingController(text: widget.bookingDetails['event_type'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _eventTypeController.dispose();
    super.dispose();
  }

  Future<void> _updateBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final url = Uri.parse('$baseUrl/bookings/update');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hall_id': widget.hallId,
          'booking_id': widget.bookingId,
          'user_id': widget.userId,
          'name': _nameController.text,
          'event_type': _eventTypeController.text,
        }),
      );

      if (response.statusCode == 200) {
        // Return true to indicate success
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update booking')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightTan,
      appBar: AppBar(
        title: const Text('Update Booking'),
        backgroundColor: oliveGreen,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF5B6547)))
            : Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _eventTypeController,
                decoration: const InputDecoration(labelText: 'Event Type'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _updateBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: oliveGreen,
                  foregroundColor: const Color(0xFFD8C9A9),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Update Booking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
