
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/calendar_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarService _calendarService = CalendarService();

  DateTime _selectedDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();

  static const Color _teal = Color(0xFF008F83);
  static const Color _green = Color(0xFF10B981);

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekDays = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _getMonthName(int month) {
    return _months[month - 1];
  }

  void _changeMonth(int amount) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + amount,
      );

      _selectedDate = DateTime(
        _displayedMonth.year,
        _displayedMonth.month,
        1,
      );
    });
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _displayedMonth = DateTime.now();
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  bool _hasEventOnDate(
    DateTime date,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
  ) {
    return events.any((document) {
      final timestamp = document.data()['eventDate'] as Timestamp?;

      if (timestamp == null) return false;

      return _isSameDay(timestamp.toDate(), date);
    });
  }

  // ADD / EDIT EVENT DIALOG
  Future<void> _showEventDialog({
    String? eventId,
    String title = '',
    String description = '',
    DateTime? eventDate,
  }) async {
    final titleController = TextEditingController(text: title);
    final descriptionController =
        TextEditingController(text: description);

    DateTime selectedDate = eventDate ?? _selectedDate;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                eventId == null ? 'Add Event' : 'Edit Event',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_formatDate(selectedDate)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter event title.'),
                        ),
                      );
                      return;
                    }

                    try {
                      if (eventId == null) {
                        await _calendarService.addEvent(
                          title: titleController.text.trim(),
                          description:
                              descriptionController.text.trim(),
                          eventDate: selectedDate,
                        );
                      } else {
                        await _calendarService.updateEvent(
                          eventId: eventId,
                          title: titleController.text.trim(),
                          description:
                              descriptionController.text.trim(),
                          eventDate: selectedDate,
                        );
                      }

                      if (!dialogContext.mounted) return;

                      Navigator.pop(dialogContext);

                      if (mounted) {
                        setState(() {
                          _selectedDate = selectedDate;
                          _displayedMonth = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                          );
                        });
                      }
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  // DELETE EVENT
  Future<void> _deleteEvent(String eventId) async {
    try {
      await _calendarService.deleteEvent(eventId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event deleted successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  // CALENDAR HEADER
  Widget _buildCalendarHeader() {
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_teal, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 75,
            width: 75,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_selectedDate.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getMonthName(_selectedDate.month)
                      .substring(0, 3)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSameDay(_selectedDate, now)
                      ? 'Today'
                      : _weekDays[_selectedDate.weekday % 7],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_getMonthName(_selectedDate.month)} '
                  '${_selectedDate.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Go to Today',
            onPressed: _goToToday,
            icon: const Icon(
              Icons.today_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
        ],
      ),
    );
  }

  // MONTH NAVIGATION
  Widget _buildMonthNavigation() {
    return Row(
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous Month',
        ),
        Expanded(
          child: Text(
            '${_getMonthName(_displayedMonth.month)} '
            '${_displayedMonth.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next Month',
        ),
      ],
    );
  }

  // MONTHLY CALENDAR GRID
  Widget _buildCalendarGrid(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
  ) {
    final firstDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );

    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;

    // Sunday = 0, Monday = 1, ..., Saturday = 6
    final startingWeekday = firstDayOfMonth.weekday % 7;

    final totalCells = startingWeekday + daysInMonth;

    return Column(
      children: [
        // WEEKDAY NAMES
        Row(
          children: _weekDays.map((day) {
            return Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: day == 'Sun'
                          ? Colors.redAccent
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // DATE CELLS
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            if (index < startingWeekday) {
              return const SizedBox();
            }

            final day = index - startingWeekday + 1;

            final date = DateTime(
              _displayedMonth.year,
              _displayedMonth.month,
              day,
            );

            final isToday = _isSameDay(date, DateTime.now());
            final isSelected = _isSameDay(date, _selectedDate);
            final hasEvent = _hasEventOnDate(date, events);

            return InkWell(
              onTap: () => _selectDate(date),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _teal
                      : isToday
                          ? _green.withValues(alpha: 0.14)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday && !isSelected
                      ? Border.all(color: _green, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (hasEvent)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : _green,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 5),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // EVENT LIST
  Widget _buildEventList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
  ) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 35),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 55,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'No events yet.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Tap Add Event to create your first event.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: events.map((document) {
        final data = document.data();

        final eventTitle = data['title'] as String? ?? '';
        final description = data['description'] as String? ?? '';

        final timestamp = data['eventDate'] as Timestamp?;
        final date = timestamp?.toDate() ?? DateTime.now();

        final isSelected = _isSameDay(date, _selectedDate);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: _teal.withValues(alpha: 0.12),
              child: const Icon(
                Icons.event_rounded,
                color: _teal,
              ),
            ),
            title: Text(
              eventTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDate(date)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(description),
                  ],
                ],
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEventDialog(
                    eventId: document.id,
                    title: eventTitle,
                    description: description,
                    eventDate: date,
                  );
                } else if (value == 'delete') {
                  _deleteEvent(document.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
            tileColor: isSelected
                ? _green.withValues(alpha: 0.06)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _calendarService.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Something went wrong: ${snapshot.error}',
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final events = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // SELECTED DATE, MONTH AND YEAR
              _buildCalendarHeader(),

              const SizedBox(height: 22),

              // MONTHLY CALENDAR
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildMonthNavigation(),
                      const Divider(height: 15),
                      _buildCalendarGrid(events),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // EVENT SECTION
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'All Events',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${events.length} Events',
                    style: const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _buildEventList(events),
            ],
          );
        },
      ),
    );
  }
}
