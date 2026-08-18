import 'package:flutter/material.dart';

/// Dropdown dengan label form — menggantikan DropdownButtonFormField (value deprecated).
class FormDropdown<T> extends StatelessWidget {
  final String labelText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isDense;

  const FormDropdown({
    super.key,
    required this.labelText,
    required this.value,
    required this.items,
    this.onChanged,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        isDense: isDense,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: isDense,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
