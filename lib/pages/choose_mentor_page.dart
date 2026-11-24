import 'package:flutter/material.dart';

import '../appointment_repository.dart';
import '../appointment_detail.dart';
import '../widgets/clinic_feedback.dart';
import '../widgets/clinic_loader.dart';
import 'request_sent_page.dart';

class ChooseMentorPage extends StatefulWidget {
  const ChooseMentorPage({
    super.key,
    required this.repository,
    required this.topic,
    required this.displayTopic,
    required this.send,
    required this.scheduled,
  });
  final AppointmentRepository repository;
  final String topic, displayTopic;
  final DateTime? scheduled;
  final Future<String> Function(String?) send;
  @override
  State<ChooseMentorPage> createState() => _ChooseMentorPageState();
}

class _ChooseMentorPageState extends State<ChooseMentorPage> {
  late Future<List<EligibleMentor>> mentors = widget.repository
      .loadEligibleMentors(widget.topic);
  String? selected;
  bool busy = false;

  Future<void> submit(String target) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final id = await widget.send(selected);
      if (!mounted) return;
      final repository = widget.repository;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RequestSentPage(
            topic: widget.displayTopic,
            target: target,
            scheduled: widget.scheduled,
            cancel: () => repository.cancel(id),
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showClinicToast(
          context,
          'Unable to send your request. Check your connection and mentor selection.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: busy
        ? const ClinicTransition('Sending your request…')
        : Scaffold(
            appBar: AppBar(
              title: const Text('Choose a mentor'),
              centerTitle: true,
            ),
            body: SafeArea(
              child: FutureBuilder<List<EligibleMentor>>(
                future: mentors,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: ClinicLoader());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(
                          () => mentors = widget.repository.loadEligibleMentors(
                            widget.topic,
                          ),
                        ),
                        child: const Text('Unable to load mentors · Retry'),
                      ),
                    );
                  }
                  final available = snapshot.data ?? [];
                  final options = <({String? id, String label, String detail})>[
                    (
                      id: null,
                      label: 'Open to any mentor',
                      detail: 'Send to mentors who cover your topic.',
                    ),
                    for (final m in available)
                      (
                        id: m.id,
                        label: m.name,
                        detail: m.specialties.join(' · '),
                      ),
                  ];
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const LinearProgressIndicator(value: 1),
                      const SizedBox(height: 24),
                      Text(
                        'Find your mentor',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Text(
                        'Open your request to everyone, or choose someone to work with.',
                      ),
                      const SizedBox(height: 20),
                      for (final option in options)
                        Card(
                          color: option.id == selected
                              ? const Color(0xFFE3D5F3)
                              : const Color(0xFFF0EDF3),
                          child: ListTile(
                            selected: option.id == selected,
                            title: Text(option.label),
                            subtitle: Text(option.detail),
                            trailing: Icon(
                              option.id == selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                            ),
                            onTap: () => setState(() => selected = option.id),
                          ),
                        ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => submit(
                          options.firstWhere((o) => o.id == selected).label,
                        ),
                        child: const Text('Send request'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
  );
}
