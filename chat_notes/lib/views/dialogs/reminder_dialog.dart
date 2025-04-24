import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReminderDialog extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onSetReminder;
  final Function() onRemoveReminder;

  const ReminderDialog({
    Key? key,
    required this.initialDate,
    required this.onSetReminder,
    required this.onRemoveReminder,
  }) : super(key: key);

  @override
  _ReminderDialogState createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedTime = TimeOfDay.fromDateTime(widget.initialDate);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('Set Reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: Text('Date'),
                  subtitle: Text(DateFormat.yMMMd().format(_selectedDate)),
                  onTap: () => _selectDate(context),
                ),
              ),
              IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: Text('Time'),
                  subtitle: Text(_selectedTime.format(context)),
                  onTap: () => _selectTime(context),
                ),
              ),
              IconButton(
                icon: Icon(Icons.access_time),
                onPressed: () => _selectTime(context),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onRemoveReminder();
            Navigator.pop(context);
          },
          child: Text('Remove', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final dateTime = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              _selectedTime.hour,
              _selectedTime.minute,
            );
            widget.onSetReminder(dateTime);
            Navigator.pop(context);
          },
          child: Text('Set Reminder'),
        ),
      ],
    );
  }
}