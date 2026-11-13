import 'package:ionicons/ionicons.dart';

import 'network_image.dart';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import 'in_app.dart';
import 'post_html.dart';
import 'theme.dart' as c;

class PostBody extends StatelessWidget {
  const PostBody({super.key, required this.html});
  final String? html;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 14,
    children: [for (final block in parsePostHtml(html)) _block(block)],
  );
  Widget _block(PostBlock b) {
    final type = b['type'];
    return switch (type) {
      'hr' => const Divider(),
      'img' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: AppNetworkImage(
                b['src'] as String,
                fit: BoxFit.cover,
                semanticLabel:
                    (b['alt'] ?? b['caption'] ?? 'Ảnh minh hoạ') as String,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: c.quiet,
                  child: Icon(Ionicons.imageOutline),
                ),
              ),
            ),
          ),
          if (b['caption'] case final String caption)
            Text(caption, style: const TextStyle(fontSize: 13, color: c.muted)),
        ],
      ),
      'list' => Column(
        spacing: 8,
        children: [
          for (final (i, item) in (b['items'] as List<List<Span>>).indexed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    b['ordered'] == true ? '${i + 1}.' : '•',
                    style: const TextStyle(color: c.brand),
                  ),
                ),
                Expanded(child: _Spans(spans: item)),
              ],
            ),
        ],
      ),
      'quote' => Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: c.brand, width: 3)),
        ),
        padding: const EdgeInsets.only(left: 14),
        child: _Spans(spans: b['spans'] as List<Span>, color: c.muted),
      ),
      _ => Semantics(
        header: type == 'h2' || type == 'h3',
        child: _Spans(
          spans: b['spans'] as List<Span>,
          size: switch (type) {
            'h2' => 21,
            'h3' => 18,
            _ => 16,
          },
          heading: type == 'h2' || type == 'h3',
        ),
      ),
    };
  }
}

class _Spans extends StatefulWidget {
  const _Spans({
    required this.spans,
    this.size = 16,
    this.heading = false,
    this.color = c.text,
  });
  final List<Span> spans;
  final double size;
  final bool heading;
  final Color color;
  @override
  State<_Spans> createState() => _SpansState();
}

class _SpansState extends State<_Spans> {
  final recognizers = <TapGestureRecognizer>[];
  void _clear() {
    for (final r in recognizers) {
      r.dispose();
    }
    recognizers.clear();
  }

  TapGestureRecognizer? _link(Object? href) {
    if (href is! String) return null;
    final recognizer = TapGestureRecognizer()
      ..onTap = () => openInApp(context, href);
    recognizers.add(recognizer);
    return recognizer;
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    return Text.rich(
      TextSpan(
        children: [
          for (final span in widget.spans)
            TextSpan(
              text: span['text'] as String,
              recognizer: _link(span['href']),
              style: TextStyle(
                fontWeight: span['bold'] == true ? FontWeight.w700 : null,
                fontStyle: span['italic'] == true ? FontStyle.italic : null,
                color: span['href'] != null ? c.link : null,
                decoration: span['href'] != null
                    ? TextDecoration.underline
                    : null,
              ),
            ),
        ],
      ),
      style: TextStyle(
        fontSize: widget.size,
        height: 1.6,
        color: widget.color,
        fontWeight: widget.heading ? FontWeight.w700 : null,
      ),
    );
  }
}
