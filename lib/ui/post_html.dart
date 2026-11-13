import 'dart:math' show max;

import 'in_app.dart';

typedef Span = Map<String, Object?>;
typedef PostBlock = Map<String, Object?>;

const _named = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'laquo': '«',
  'raquo': '»',
  'ldquo': '“',
  'rdquo': '”',
  'lsquo': '‘',
  'rsquo': '’',
};
String decodeEntities(String s) => s.replaceAllMapped(
  RegExp(r'&(#x[0-9a-f]+|#\d+|[a-z]+);', caseSensitive: false),
  (m) {
    final entity = m[1]!;
    if (entity.startsWith('#')) {
      final hex = entity[1].toLowerCase() == 'x';
      final n = int.tryParse(
        entity.substring(hex ? 2 : 1),
        radix: hex ? 16 : 10,
      );
      return n != null && n > 0 && n < 0x110000
          ? String.fromCharCode(n)
          : m[0]!;
    }
    return _named[entity.toLowerCase()] ?? m[0]!;
  },
);

String? _attr(String attrs, String name) {
  final m = RegExp(
    '\\b$name\\s*=\\s*("([^"]*)"|\'([^\']*)\'|([^\\s>]+))',
    caseSensitive: false,
  ).firstMatch(attrs);
  return m == null ? null : decodeEntities(m[2] ?? m[3] ?? m[4] ?? '').trim();
}

const _br = '\ue000';
List<Span> _tidy(List<Span> spans) {
  final out = <Span>[];
  for (final sp in spans) {
    final text = (sp['text'] as String)
        .replaceAll(RegExp('[^\\S$_br]+'), ' ')
        .replaceAll(RegExp(' ?$_br ?'), '\n');
    if (text.isEmpty) continue;
    final last = out.lastOrNull;
    if (last != null &&
        last['bold'] == sp['bold'] &&
        last['italic'] == sp['italic'] &&
        last['href'] == sp['href']) {
      last['text'] = '${last['text']}$text';
    } else {
      out.add({...sp, 'text': text});
    }
  }
  if (out.isNotEmpty) {
    out.first['text'] = (out.first['text'] as String).replaceFirst(
      RegExp(r'^\s+'),
      '',
    );
    out.last['text'] = (out.last['text'] as String).replaceFirst(
      RegExp(r'\s+$'),
      '',
    );
  }
  return out.where((s) => s['text'] != '').toList();
}

/// Backend-filtered HTML becomes data blocks, never executable markup.
/// HTTP(S) links and images are checked again at this rendering boundary.
List<PostBlock> parsePostHtml(String? html) {
  final blocks = <PostBlock>[];
  var bold = 0, italic = 0;
  String? href;
  var spans = <Span>[];
  var kind = 'p';
  List<List<Span>>? listItems;
  var ordered = false, inLi = false, inQuote = false, inCaption = false;
  var caption = '';
  PostBlock? figureImg;
  Span span(String text) => {
    'text': text,
    if (bold > 0) 'bold': true,
    if (italic > 0) 'italic': true,
    'href': ?href,
  };
  void flush() {
    final t = _tidy(spans);
    if (t.isNotEmpty) {
      if (inLi && listItems != null) {
        listItems.add(t);
      } else {
        blocks.add({'type': kind, 'spans': t});
      }
    }
    spans = [];
  }

  final re = RegExp(
    r'<(/?)([a-z0-9]+)([^>]*?)/?>|([^<]+)',
    caseSensitive: false,
  );
  for (final m in re.allMatches(html ?? '')) {
    if (m[4] != null) {
      final text = decodeEntities(m[4]!);
      if (inCaption) {
        caption += text;
      } else {
        spans.add(span(text));
      }
      continue;
    }
    final closing = m[1] == '/';
    final tag = m[2]!.toLowerCase();
    final attrs = m[3] ?? '';
    switch (tag) {
      case 'p' || 'h2' || 'h3':
        flush();
        kind = !closing && tag != 'p'
            ? tag
            : inQuote
            ? 'quote'
            : 'p';
      case 'blockquote':
        flush();
        inQuote = !closing;
        kind = inQuote ? 'quote' : 'p';
      case 'ul' || 'ol':
        flush();
        if (!closing) {
          ordered = tag == 'ol';
          listItems = [];
        } else if (listItems != null) {
          if (listItems.isNotEmpty) {
            blocks.add({
              'type': 'list',
              'ordered': ordered,
              'items': listItems,
            });
          }
          listItems = null;
        }
      case 'li':
        flush();
        inLi = !closing;
      case 'strong' || 'b':
        bold = max(0, bold + (closing ? -1 : 1));
      case 'em' || 'i':
        italic = max(0, italic + (closing ? -1 : 1));
      case 'a':
        final h = closing ? null : _attr(attrs, 'href');
        href = isHttp(h) ? h : null;
      case 'br':
        spans.add(span(_br));
      case 'hr':
        flush();
        blocks.add({'type': 'hr'});
      case 'img':
        flush();
        final src = _attr(attrs, 'src');
        if (isHttp(src)) {
          final alt = _attr(attrs, 'alt');
          final img = <String, Object?>{
            'type': 'img',
            'src': src,
            'alt': alt == '' ? null : alt,
            'caption': null,
          };
          blocks.add(img);
          figureImg = img;
        }
      case 'figure':
        flush();
        if (closing) figureImg = null;
      case 'figcaption':
        if (!closing) {
          inCaption = true;
          caption = '';
        } else {
          inCaption = false;
          final c = caption.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (figureImg != null && c.isNotEmpty) figureImg['caption'] = c;
        }
      default:
        break;
    }
  }
  flush();
  return blocks;
}

String plainText(String? html) =>
    decodeEntities((html ?? '').replaceAll(RegExp(r'<[^>]+>'), ' '))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
