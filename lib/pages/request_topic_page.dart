import 'package:flutter/material.dart';

import '../appointment_repository.dart';
import '../widgets/clinic_feedback.dart';
import '../widgets/clinic_loader.dart';
import 'choose_mentor_page.dart';

class RequestTopicPage extends StatefulWidget {
  const RequestTopicPage(this.repository, {super.key});
  final AppointmentRepository repository;
  @override
  State<RequestTopicPage> createState() => _RequestTopicPageState();
}

class _RequestTopicPageState extends State<RequestTopicPage> {
  late Future<List<String>> topics = widget.repository.loadTopics();
  String? topic;
  String custom = '', course = '', professor = '';
  DateTime? scheduled;
  bool star = false;

  Future<void> chooseTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: scheduled ?? now,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduled ?? now),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!value.isAfter(DateTime.now())) {
      showClinicToast(context, 'Choose a future time.');
      return;
    }
    setState(() => scheduled = value);
  }

  Future<void> next(String selected) async {
    if (selected == 'Other' && custom.trim().isEmpty) {
      showClinicToast(context, 'Describe the topic you need help with.');
      return;
    }
    if (scheduled?.isBefore(DateTime.now()) == true) {
      showClinicToast(context, 'Choose a future time.');
      return;
    }
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChooseMentorPage(
          repository: widget.repository,
          topic: selected,
          displayTopic: selected == 'Other' ? custom.trim() : selected,
          scheduled: scheduled,
          send: (mentor) => widget.repository.create(
            topic: selected,
            customTopic: selected == 'Other' ? custom.trim() : null,
            targetMentorId: mentor,
            scheduledAt: scheduled,
            courseCode: course.trim(),
            professorName: professor.trim(),
            isStar: star,
          ),
        ),
      ),
    );
    if (sent == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mentorship request'), centerTitle: true),
    body: SafeArea(
      child: FutureBuilder<List<String>>(
        future: topics,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ClinicLoader());
          }
          final names = snapshot.data ?? [];
          if (names.isEmpty) {
            return Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => topics = widget.repository.loadTopics()),
                child: const Text('Topics unavailable · Retry'),
              ),
            );
          }
          final selected = topic ?? names.first;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const LinearProgressIndicator(value: 0.5),
              const SizedBox(height: 24),
              Text(
                'Select a topic',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text('Describe your topic, then set a time.'),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Topic'),
                items: [
                  for (final name in names)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => topic = v),
              ),
              if (selected == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                    initialValue: custom,
                    decoration: const InputDecoration(
                      labelText: 'Describe your topic',
                    ),
                    onChanged: (v) => custom = v,
                  ),
                ),
              const SizedBox(height: 20),
              const Text('When'),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('ASAP')),
                  ButtonSegment(value: true, label: Text('Schedule')),
                ],
                selected: {scheduled != null},
                onSelectionChanged: (v) {
                  if (v.first) {
                    chooseTime();
                  } else {
                    setState(() => scheduled = null);
                  }
                },
              ),
              if (scheduled != null)
                TextButton(
                  onPressed: chooseTime,
                  child: Text(
                    '${MaterialLocalizations.of(context)
                            .formatMediumDate(scheduled!)} · ${TimeOfDay.fromDateTime(scheduled!).format(context)}',
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Course code (optional)',
                ),
                onChanged: (v) => course = v,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Professor (optional)',
                ),
                onChanged: (v) => professor = v,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('STAR session'),
                value: star,
                onChanged: (v) => setState(() => star = v ?? false),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => next(selected),
                child: const Text('Choose mentor'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
