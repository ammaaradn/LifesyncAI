import 'package:flutter/material.dart';

import '../theme.dart';

/// Shows a short red SnackBar for a background action that failed.
void showErrorSnackBar(BuildContext context, [String? message]) {
  if (!context.mounted) return;
  showErrorSnackBarVia(ScaffoldMessenger.of(context), message);
}

/// Same as [showErrorSnackBar], but takes an already-captured
/// [ScaffoldMessengerState] - use this inside a callback that runs after an
/// `await`/`.catchError`, since holding on to a raw [BuildContext] across
/// that gap isn't safe (the widget may have been disposed by the time the
/// error arrives). Capture the messenger synchronously, before the async
/// call, then pass it in here.
void showErrorSnackBarVia(ScaffoldMessengerState messenger, [String? message]) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text(message ?? 'Something went wrong. Please try again.'),
      ),
    );
}
