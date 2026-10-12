import 'package:flutter/material.dart';

import '../core/utils/format.dart';
import 'common_widgets.dart';

class DateField extends StatefulWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate, lastDate;
  final bool isRequired;
  const DateField({super.key, required this.label, required this.onChanged, required this.firstDate, required this.lastDate, this.value, this.isRequired = true});
  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  late final TextEditingController _c = TextEditingController(text: widget.value == null ? '' : fmtDate(widget.value!));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomTextField(
        controller: _c,
        label: widget.label,
        icon: Icons.calendar_today_outlined,
        readOnly: true,
        validator: widget.isRequired ? (v) => requiredField(v, widget.label) : null,
        onTap: () async {
          var init = widget.value ?? DateTime.now();
          if (init.isBefore(widget.firstDate)) init = widget.firstDate;
          if (init.isAfter(widget.lastDate)) init = widget.lastDate;
          final d = await showDatePicker(context: context, initialDate: init, firstDate: widget.firstDate, lastDate: widget.lastDate);
          if (d != null) {
            _c.text = fmtDate(d);
            widget.onChanged(d);
          }
        },
      );
}
