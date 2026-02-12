import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class SendFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const SendFeedbackScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends State<SendFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  final int _maxFeedbackLength = 500;
  final bool _useEmailClient =
      false; // Set to true to use email client fallback

  @override
  void dispose() {
    _titleController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    if (_useEmailClient) {
      await _sendViaEmailClient();
    } else {
      await _sendViaApi();
    }

    setState(() => _isSubmitting = false);
  }

  Future<void> _sendViaApi() async {
    try {
      await widget.apiService.sendFeedback({
        'title': _titleController.text,
        'feedback': _feedbackController.text,
        'user_id': widget.user['id']?.toString() ?? 'N/A',
        'company_id': widget.user['company_id']?.toString() ?? 'N/A',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Feedback submitted successfully'),
          backgroundColor: Colors.teal[700],
          duration: const Duration(seconds: 2),
        ),
      );
      _titleController.clear();
      _feedbackController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit feedback: $e'),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _submitFeedback,
          ),
        ),
      );
    }
  }

  Future<void> _sendViaEmailClient() async {
    final email = 'mu.wesonga@gmail.com';
    final subject = 'Feedback: ${_titleController.text}';
    final body = '''
User ID: ${widget.user['id']?.toString() ?? 'N/A'}
Company ID: ${widget.user['company_id']?.toString() ?? 'N/A'}
Title: ${_titleController.text}

Feedback:
${_feedbackController.text}
''';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Opened email client'),
            backgroundColor: Colors.teal[700],
            duration: const Duration(seconds: 2),
          ),
        );
        _titleController.clear();
        _feedbackController.clear();
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open email client: $e'),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _submitFeedback,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Send Feedback',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          developer.log('Notifications tapped', name: 'SendFeedbackScreen');
        },
        onProfileTap: () {
          developer.log('Profile tapped', name: 'SendFeedbackScreen');
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share Your Thoughts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Help us improve by sharing your suggestions or issues.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.teal[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Feedback Title',
                              labelStyle: TextStyle(color: Colors.teal[900]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.teal[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.teal[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.teal[700]!),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'e.g., Payroll Feature Suggestion',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a feedback title';
                              }
                              return null;
                            },
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _feedbackController,
                            decoration: InputDecoration(
                              labelText: 'Your Feedback',
                              labelStyle: TextStyle(color: Colors.teal[900]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.teal[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.teal[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.teal[700]!),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              hintText:
                                  'e.g., Please add a feature to export payslips as PDF',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              counterText:
                                  '${_feedbackController.text.length}/$_maxFeedbackLength',
                            ),
                            maxLines: 4,
                            maxLength: _maxFeedbackLength,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your feedback';
                              }
                              return null;
                            },
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitFeedback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      'Submit',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
