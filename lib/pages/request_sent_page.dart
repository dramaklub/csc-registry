import 'package:flutter/material.dart';

import '../widgets/clinic_feedback.dart';

class RequestSentPage extends StatefulWidget {
  const RequestSentPage({
    super.key,
    required this.topic,
    required this.target,
    required this.scheduled,
    required this.cancel,
  });
  final String topic, target;
  final DateTime? scheduled;
  final Future<String> Function() cancel;
  @override
  State<RequestSentPage> createState() => _RequestSentPageState();
}

class _RequestSentPageState extends State<RequestSentPage> {
  bool busy = false;
  Future<void> cancel() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.cancel();
      if (mounted) {
        showClinicToast(context, 'Request cancelled.');
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showClinicToast(
          context,
          'Unable to cancel the request. Check its status on Home.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Request sent'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: const Color(0xFFEEE7F5),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Icon(Icons.schedule, color: Color(0xFF5B3F91)),
                    const SizedBox(height: 12),
                    Text(
                      'Waiting for a mentor',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
            ListTile(title: const Text('Topic'), subtitle: Text(widget.topic)),
            ListTile(
              title: const Text('When'),
              subtitle: Text(
                widget.scheduled == null
                    ? 'ASAP'
                    : '${MaterialLocalizations.of(context)
                              .formatMediumDate(widget.scheduled!)} · ${TimeOfDay.fromDateTime(widget.scheduled!)
                              .format(context)}',
              ),
            ),
            ListTile(
              title: const Text('Target'),
              subtitle: Text(widget.target),
            ),
            FilledButton(
              onPressed: busy ? null : () => Navigator.pop(context, true),
              child: const Text('Back to home'),
            ),
            TextButton(
              onPressed: busy ? null : cancel,
              child: Text(busy ? 'Cancelling…' : 'Cancel request'),
            ),
          ],
        ),
      ),
    ),
  );
}
