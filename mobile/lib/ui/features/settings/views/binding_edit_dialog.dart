import 'package:flutter/material.dart';

/// Per-control key/button binder dialog, shared by Settings and the driving
/// grid's unbound affordance (REQ-013). [onSave] receives the trimmed value;
/// empty means unbound (phone sends nothing).
class BindingEditDialog extends StatefulWidget {
  const BindingEditDialog({
    super.key,
    required this.title,
    required this.current,
    required this.isGamepad,
    required this.onSave,
  });

  final String title;
  final String current;
  final bool isGamepad;
  final ValueChanged<String> onSave;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String current,
    required bool isGamepad,
    required ValueChanged<String> onSave,
  }) =>
      showDialog(
        context: context,
        builder: (_) => BindingEditDialog(
          title: title,
          current: current,
          isGamepad: isGamepad,
          onSave: onSave,
        ),
      );

  @override
  State<BindingEditDialog> createState() => _BindingEditDialogState();
}

class _BindingEditDialogState extends State<BindingEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.title}'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
            labelText: widget.isGamepad ? 'Button' : 'Key',
            border: const OutlineInputBorder()),
        autofocus: true,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            Navigator.pop(context);
            widget.onSave(value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
