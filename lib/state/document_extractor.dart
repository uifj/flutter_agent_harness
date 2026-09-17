// Extracts plain text from document files for the composer's send.
//
// Two tiers: text-shaped files (.txt, .md, .json, …) are read as UTF-8 with no
// dependency; PDFs go through `pdfrx` (pure Dart, cross-platform). The result
// is a single string the composer prepends to the user's draft, so the model
// sees the document content inline — no new genkit part type, no controller
// change, no runtime change.

import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

/// File extensions whose content is already plain text — read as UTF-8.
const textExtensions = <String>{
  '.txt',
  '.md',
  '.markdown',
  '.json',
  '.yaml',
  '.yml',
  '.toml',
  '.xml',
  '.csv',
  '.ini',
  '.cfg',
  '.conf',
  '.html',
  '.htm',
  '.css',
  '.scss',
  '.less',
  '.js',
  '.ts',
  '.jsx',
  '.tsx',
  '.mjs',
  '.cjs',
  '.dart',
  '.java',
  '.kt',
  '.swift',
  '.go',
  '.rs',
  '.rb',
  '.py',
  '.php',
  '.c',
  '.cpp',
  '.h',
  '.hpp',
  '.cc',
  '.cs',
  '.sh',
  '.bash',
  '.zsh',
  '.bat',
  '.ps1',
  '.cmd',
  '.sql',
  '.r',
  '.lua',
  '.vim',
  '.el',
  '.clj',
  '.scala',
  '.hs',
  '.erl',
  '.makefile',
  '.cmake',
  '.dockerfile',
  '.gradle',
  '.groovy',
  '.kts',
};

/// Returns the file's extension (lowercased, with dot), or '' when none.
String _ext(String path) {
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot).toLowerCase();
}

/// Whether [path] names a file this extractor can read (text or PDF).
bool isExtractable(String path) {
  final e = _ext(path);
  return e == '.pdf' || textExtensions.contains(e);
}

/// Reads the text content of [path].
///
/// Text-shaped files are read as UTF-8 directly. PDFs are opened via `pdfrx`
/// and their pages' text is concatenated with blank-line separators. Returns
/// null on any I/O or parse failure — the caller treats null as "nothing to
/// extract" and skips the document rather than failing the send.
Future<String?> extractText(String path) async {
  final e = _ext(path);
  if (textExtensions.contains(e)) {
    try {
      return await File(path).readAsString();
    } catch (_) {
      return null;
    }
  }
  if (e == '.pdf') return _extractPdf(path);
  return null;
}

Future<String?> _extractPdf(String path) async {
  PdfDocument? doc;
  try {
    doc = await PdfDocument.openFile(path);
    final buf = StringBuffer();
    for (final page in doc.pages) {
      final text = await page.loadText();
      if (buf.isNotEmpty) buf.writeln();
      buf.write(text.fullText);
    }
    return buf.isEmpty ? null : buf.toString();
  } catch (_) {
    return null;
  } finally {
    await doc?.dispose();
  }
}
