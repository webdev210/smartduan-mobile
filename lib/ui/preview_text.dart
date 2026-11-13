import 'package:flutter/widgets.dart';

import 'kit.dart' as kit;

class PreviewText extends StatefulWidget {
  const PreviewText(
    this.text, {
    super.key,
    this.style = const TextStyle(fontSize: 15, height: 1.5),
  });
  final TextStyle style;
  final String text;
  @override
  State<PreviewText> createState() => _PreviewTextState();
}

class _PreviewTextState extends State<PreviewText> {
  bool expanded = false;
  @override
  void didUpdateWidget(PreviewText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) expanded = false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = DefaultTextStyle.of(context).style.merge(widget.style);
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 6,
      )..layout(maxWidth: constraints.maxWidth);
      final long = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: expanded ? null : 6,
            overflow: expanded ? null : TextOverflow.ellipsis,
          ),
          if (long)
            kit.Button(
              title: expanded ? 'Thu gọn' : 'Xem thêm',
              kind: 'link',
              onPress: () => setState(() => expanded = !expanded),
            ),
        ],
      );
    },
  );
}
