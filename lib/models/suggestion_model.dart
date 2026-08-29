import 'package:flutter/material.dart';

/// One piece of advice produced by the [SuggestionEngine].
///
/// [priority] is lower = more important; the Dashboard (Phase 6) shows the
/// lowest-priority suggestion at the top as "today's top suggestion".
class SuggestionModel {
  final IconData icon;
  final String title;
  final String message;
  final int priority;

  const SuggestionModel({
    required this.icon,
    required this.title,
    required this.message,
    this.priority = 3,
  });
}
