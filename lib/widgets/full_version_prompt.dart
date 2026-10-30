import 'package:flutter/material.dart';

Future<bool> showFullVersionPrompt(
  BuildContext context, {
  required String feature,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Purchase a license'),
          content: Text(
            '$feature is part of Omoji Premium. View the Omoji plans and '
            'checkout options on the Aeroclipse website.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Purchase a license'),
            ),
          ],
        ),
      ) ??
      false;
}
