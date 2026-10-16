import 'package:flutter/material.dart';

Future<bool> showFullVersionPrompt(
  BuildContext context, {
  required String feature,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Looking for the full version?'),
          content: Text(
            '$feature is available in the full Omoji version. Was that an '
            'accidental tap, or would you like to view the full version? '
            'Donations are optional gifts and do not unlock features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Accidental tap'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('View full version'),
            ),
          ],
        ),
      ) ??
      false;
}
