// A user input that has not reached the model yet.
//
// Two things can happen to it: it waits for the running turn to finish and then
// becomes a turn of its own ([InputDelivery.queue]), or it is handed to the
// running turn to be read at its next model call ([InputDelivery.guide]) — the
// difference is only *when* the model gets to read it.
//
// Deliberately not persisted. A queue is a stack of half-thoughts the user has
// not seen land; a restart that brought them back would send last week's
// corrections into a new folder. The transcript is the record instead.

import 'attached_image.dart';

/// How a [QueuedInput] is meant to reach the model.
enum InputDelivery {
  /// After the running turn settles, as a turn of its own.
  queue,

  /// Inside the running turn, at its next model call.
  guide,
}

class QueuedInput {
  QueuedInput({
    required this.id,
    required this.text,
    this.images = const [],
    this.delivery = InputDelivery.queue,
  });

  /// Minted by the controller; the queue panel's row key and removal target.
  final int id;

  final String text;
  final List<AttachedImage> images;

  /// Mutable: a queued input's delivery can be changed while it waits.
  InputDelivery delivery;

  /// One line for the panel: what the user typed, up to the first break.
  String get preview {
    final line = text.split('\n').first.trim();
    return line.isEmpty ? '[attachment]' : line;
  }
}
