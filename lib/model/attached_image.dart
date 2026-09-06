// One image attached to a user message.
//
// A plain value the model layer can hold and the UI can render, with the
// genkit-facing shape (the data-URI a `Media.url` carries) derived rather than
// stored — `lib/genkit/` owns every genkit type, so the model hands it bytes
// and a media type, and the runtime builds the wire part.
//
// Bytes rather than a path: a picked file can be replaced or deleted between
// the pick and the send, and a paste never had a path at all.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The image extensions Flutter's own decoders handle — the same set
/// `matchFileViewer` in the sidebar registry treats as images.
const imageExtensions = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.bmp': 'image/bmp',
};

/// The media type for [path], or null when the name does not name an image.
String? mediaTypeOf(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return null;
  return imageExtensions[path.substring(dot).toLowerCase()];
}

class AttachedImage {
  const AttachedImage({
    required this.name,
    required this.bytes,
    required this.mediaType,
  });

  /// The file's basename, or a minted label for a paste. Display only — the
  /// model never sees it.
  final String name;

  /// The decoded image bytes, exactly as they will be sent.
  final Uint8List bytes;

  /// An IANA media type ('image/png', …).
  final String mediaType;

  /// The data-URI form genkit's `Media.url` carries inline images as.
  String get dataUrl => 'data:$mediaType;base64,${base64Encode(bytes)}';

  /// Reads [file] as an image, or null when its extension is not one —
  /// the picker filters, this is the second line.
  static AttachedImage? fromFile(String file) {
    final mediaType = mediaTypeOf(file);
    if (mediaType == null) return null;
    return AttachedImage(
      name: _basename(file),
      // Synchronous on purpose: picked images are local and small, and the
      // composer's menu handler is already async — a second await would buy
      // nothing but a frame of spinner over a millisecond of disk.
      bytes: File(file).readAsBytesSync(),
      mediaType: mediaType,
    );
  }

  static String _basename(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }
}
