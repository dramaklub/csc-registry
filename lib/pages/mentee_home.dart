import '../widgets/clinic_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../appointment_feed.dart';
import '../widgets/clinic_loader.dart';

const _paper = Color(0xFFFAF9F6);
const _ink = Color(0xFF242326);
const _purple = Color(0xFF5B3F91);
const _lavender = Color(0xFFEEE7F5);

class MenteeHome extends StatefulWidget {
  const MenteeHome({
    super.key,
    required this.name,
    required this.watchFeed,
    required this.onSignOut,
    required this.newRequest,
  });
  final Future<bool?> Function(BuildContext) newRequest;
  final String name;
  final Stream<AppointmentFeed> Function() watchFeed;
  final Future<void> Function() onSignOut;

  @override
  State<MenteeHome> createState() => _MenteeHomeState();
}

class _MenteeHomeState extends State<MenteeHome> {
  late Stream<AppointmentFeed> feed = widget.watchFeed();
  final scroll = ScrollController();
  bool historyOnly = false;
  String get displayName => widget.name.isEmpty ? 'Mentee' : widget.name;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> profile() async {
    final signOut = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(displayName, style: Theme.of(context).textTheme.titleLarge),
              const Text('Mentee'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
    if (signOut != true || !mounted) return;
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        showClinicToast(context, 'Unable to sign out. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    bottomNavigationBar: SafeArea(
      top: false,
      child: NavigationBar(
        backgroundColor: _paper,
        indicatorColor: _lavender,
        selectedIndex: historyOnly ? 1 : 0,
        onDestinationSelected: (index) {
          if (index == 2) {
            profile();
            return;
          }
          setState(() => historyOnly = index == 1);
          if (scroll.hasClients) scroll.jumpTo(0);
        },
        destinations: [
          for (final label in ['Home', 'History', 'Profile'])
            NavigationDestination(
              icon: SvgPicture.asset(
                'assets/mentee_home/${label.toLowerCase()}.svg',
                width: 22,
                height: 22,
              ),
              label: label,
            ),
        ],
      ),
    ),
    floatingActionButton: historyOnly
        ? null
        : SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () async {
                final sent = await widget.newRequest(context);
                if (sent == true && mounted) {
                  setState(() => feed = widget.watchFeed());
                }
              },
              icon: Icon(Icons.add),
              label: Text('New request'),
            ),
          ),
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: StreamBuilder<AppointmentFeed>(
            stream: feed,
            builder: (context, snapshot) {
              final active =
                  snapshot.data?.items
                      .where(
                        (a) =>
                            a.section == AppointmentSection.pending ||
                            a.section == AppointmentSection.active,
                      )
                      .toList() ??
                  [];
              final history =
                  snapshot.data?.section(AppointmentSection.history) ??
                  const <AppointmentSummary>[];
              return ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 90),
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/mentee_home/brand.svg',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: _ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          historyOnly ? 'History' : 'Mentorship\nRequests',
                          style: const TextStyle(
                            fontSize: 38,
                            height: 1.08,
                            letterSpacing: -1.1,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (!historyOnly &&
                          snapshot.hasData &&
                          !snapshot.hasError)
                        Text(
                          active.length.toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontSize: 58,
                            height: 1,
                            color: Color(0xFFBCAAD5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.hasError) ...[
                    const Text('Couldn’t load your appointments.'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => feed = widget.watchFeed()),
                        child: const Text('Retry'),
                      ),
                    ),
                  ] else if (!snapshot.hasData)
                    const Center(child: ClinicLoader())
                  else ...[
                    if (!historyOnly) ...[
                      if (active.isEmpty) const Text('No active requests.'),
                      for (final item in active) _RequestCard(item: item),
                      const SizedBox(height: 18),
                      const Text(
                        'Recent history',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (history.isEmpty) const Text('No past sessions yet.'),
                    for (final item in historyOnly ? history : history.take(3))
                      _HistoryRow(item: item),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

String _status(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => 'Pending',
  AppointmentStatus.accepted => 'Accepted',
  AppointmentStatus.inProgress => 'In progress',
  AppointmentStatus.completed => 'Completed',
  AppointmentStatus.cancelled => 'Cancelled',
};

String _date(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatShortDate(date.toLocal());

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item});
  final AppointmentSummary item;
  @override
  Widget build(BuildContext context) {
    final pending = item.status == AppointmentStatus.pending;
    final when = item.scheduledAt?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pending ? const Color(0xFFF5EFCF) : _lavender,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: pending
                      ? const Color(0xFFF4D35E)
                      : const Color(0xFFE4D8F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Text(
                    _status(item.status),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Text(
                when == null
                    ? 'ASAP'
                    : '${_date(context, when)} · ${TimeOfDay.fromDateTime(when).format(context)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.topic,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.mentorName?.isNotEmpty == true
                ? 'With ${item.mentorName}'
                : pending
                ? 'Waiting for a mentor'
                : 'Mentor assigned',
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});
  final AppointmentSummary item;
  @override
  Widget build(BuildContext context) {
    final date = item.scheduledAt ?? item.createdAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _lavender,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${date.toLocal().day}',
          style: const TextStyle(
            fontSize: 20,
            color: _purple,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        item.topic,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        [
          _status(item.status),
          if (item.mentorName?.isNotEmpty == true) item.mentorName!,
          _date(context, date),
        ].join(' · '),
      ),
    );
  }
}
