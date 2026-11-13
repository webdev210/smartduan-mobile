import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart'
    hide Card, Chip, Row, Divider, IconButton, SearchBar, Hero;
import 'package:material_ui/material_ui.dart' as m show Row;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../api/errors.dart';
import 'theme.dart';
import 'theme.dart' as c;

part 'kit_controls.dart';
part 'kit_surfaces.dart';

// RN Pressable feedback, shared so controls keep the same touch/keyboard behavior.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onPress,
    this.onLongPress,
    this.label,
    this.disabled = false,
    this.pressedOpacity = 0.9,
    this.pressedScale = 1,
    this.onHighlightChanged,
  });
  final Widget child;
  final VoidCallback? onPress;
  final VoidCallback? onLongPress;
  final String? label;
  final bool disabled;
  final double pressedOpacity, pressedScale;
  final ValueChanged<bool>? onHighlightChanged;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool pressed = false;
  bool showFocus = false;
  bool get enabled => !widget.disabled && widget.onPress != null;
  void _pressed(bool value) {
    if (mounted) setState(() => pressed = value);
    widget.onHighlightChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) => widget.onPress == null
      ? widget.child
      : Semantics(
          button: true,
          enabled: enabled,
          label: widget.label,
          onTap: enabled ? widget.onPress : null,
          onLongPress: enabled ? widget.onLongPress : null,
          child: FocusableActionDetector(
            enabled: enabled,
            onShowFocusHighlight: (value) => setState(() => showFocus = value),
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onPress?.call();
                  return null;
                },
              ),
            },
            child: RawGestureDetector(
              gestures: {
                if (enabled && widget.onLongPress != null)
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer
                      >(
                        () => LongPressGestureRecognizer(
                          duration: const Duration(milliseconds: 350),
                        ),
                        (instance) => instance.onLongPress = widget.onLongPress,
                      ),
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: enabled ? widget.onPress : null,
                onTapDown: enabled ? (_) => _pressed(true) : null,
                onTapUp: enabled ? (_) => _pressed(false) : null,
                onTapCancel: enabled ? () => _pressed(false) : null,
                child: CustomPaint(
                  foregroundPainter: showFocus ? const _FocusRing() : null,
                  child: _PressableHitArea(
                    child: Transform.scale(
                      scale:
                          enabled &&
                              pressed &&
                              !MediaQuery.disableAnimationsOf(context)
                          ? widget.pressedScale
                          : 1,
                      child: Opacity(
                        opacity: enabled && pressed ? widget.pressedOpacity : 1,
                        child: widget.label == null
                            ? widget.child
                            : ExcludeSemantics(child: widget.child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
}

class _FocusRing extends CustomPainter {
  const _FocusRing();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(2),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FocusRing oldDelegate) => false;
}

class _PressableHitArea extends SingleChildRenderObjectWidget {
  const _PressableHitArea({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPressableHitArea();
}

class _RenderPressableHitArea extends RenderShiftedBox {
  _RenderPressableHitArea() : super(null);

  Size _hitSize(Size childSize, BoxConstraints constraints) =>
      constraints.constrain(
        Size(math.max(48, childSize.width), math.max(48, childSize.height)),
      );

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _hitSize(child!.getDryLayout(constraints), constraints);

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(48, child!.getMinIntrinsicWidth(height));
  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(48, child!.getMaxIntrinsicWidth(height));
  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(48, child!.getMinIntrinsicHeight(width));
  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(48, child!.getMaxIntrinsicHeight(width));

  @override
  void performLayout() {
    // Preserve the incoming constraints; only grow the surrounding hit area.
    child!.layout(constraints, parentUsesSize: true);
    size = _hitSize(child!.size, constraints);
    final parentData = child!.parentData! as BoxParentData;
    parentData.offset = Offset(
      (size.width - child!.size.width) / 2,
      (size.height - child!.size.height) / 2,
    );
  }
}

Future<void> _refresh(FutureOr<void> Function() callback) async {
  try {
    await callback();
  } catch (_) {
    // Query state presents the error; a failed pull must still stop spinning.
  }
}

class Screen extends StatelessWidget {
  const Screen({
    super.key,
    required this.children,
    this.onRefresh,
    this.padded = true,
    this.slivers = const [],
  });
  final List<Widget> children;
  final FutureOr<void> Function()? onRefresh;
  final bool padded;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final Widget scroll = CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padded
              ? const EdgeInsets.fromLTRB(20, 12, 20, 16)
              : EdgeInsets.zero,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: padded ? 16 : 0,
              children: children,
            ),
          ),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
    return ColoredBox(
      color: bg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: onRefresh == null
              ? scroll
              : RefreshIndicator(
                  color: brand,
                  onRefresh: () => _refresh(onRefresh!),
                  child: scroll,
                ),
        ),
      ),
    );
  }
}

class ListScreen<T> extends StatelessWidget {
  const ListScreen({
    super.key,
    required this.data,
    required this.keyOf,
    required this.renderItem,
    this.top,
    this.header,
    this.empty,
    this.footer,
    this.onRefresh,
  });
  final List<T> data;
  final String Function(T) keyOf;
  final Widget? Function(T) renderItem;
  final Widget? top, header, empty, footer;
  final FutureOr<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final headerCount = header == null ? 0 : 1;
    final bodyCount = data.isEmpty ? (empty == null ? 0 : 1) : data.length;
    final scroll = ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      itemCount: headerCount + bodyCount + (footer == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, index) {
        if (header != null && index == 0) return header!;
        final itemIndex = index - headerCount;
        if (itemIndex >= bodyCount) return footer!;
        if (data.isEmpty) return empty!;
        final item = data[itemIndex];
        return KeyedSubtree(
          key: ValueKey(keyOf(item)),
          child: renderItem(item) ?? const SizedBox.shrink(),
        );
      },
    );
    return ColoredBox(
      color: bg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              if (top != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: top,
                ),
              Expanded(
                child: onRefresh == null
                    ? scroll
                    : RefreshIndicator(
                        color: brand,
                        onRefresh: () => _refresh(onRefresh!),
                        child: scroll,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class H1 extends StatelessWidget {
  const H1(this.data, {super.key});
  final String data;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      data,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.7,
      ),
    ),
  );
}

class H2 extends StatelessWidget {
  const H2(this.data, {super.key});
  final String data;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      data,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -0.3,
      ),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.data, {super.key, this.color = brand});
  final String data;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    data,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.2,
    ),
  );
}

class Muted extends StatelessWidget {
  const Muted(
    this.data, {
    super.key,
    this.style,
    this.numberOfLines,
    this.textAlign,
  });
  final String data;
  final TextStyle? style;
  final int? numberOfLines;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => Text(
    data,
    maxLines: numberOfLines,
    overflow: numberOfLines == null ? null : TextOverflow.ellipsis,
    textAlign: textAlign,
    style: const TextStyle(
      color: muted,
      fontSize: 14,
      height: 20 / 14,
    ).merge(style),
  );
}

class Body extends StatelessWidget {
  const Body(
    this.data, {
    super.key,
    this.style,
    this.selectable = false,
    this.textAlign,
  });
  final String data;
  final TextStyle? style;
  final bool selectable;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) {
    final effective = const TextStyle(
      color: text,
      fontSize: 15,
      height: 22 / 15,
    ).merge(style);
    return selectable
        ? SelectableText(data, style: effective, textAlign: textAlign)
        : Text(data, style: effective, textAlign: textAlign);
  }
}

class Row extends StatelessWidget {
  const Row({
    super.key,
    required this.label,
    required this.value,
    this.padding = const EdgeInsets.symmetric(vertical: 7),
  });
  final String label;
  final Object value;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: LayoutBuilder(
      builder: (context, constraints) =>
          MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Muted(label),
                value is Widget
                    ? value as Widget
                    : Body(
                        '$value',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ],
            )
          : m.Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 12,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth / 2,
                  ),
                  child: Muted(label),
                ),
                Flexible(
                  child: value is Widget
                      ? value as Widget
                      : Body(
                          '$value',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
    ),
  );
}

class Divider extends StatelessWidget {
  const Divider({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1 / MediaQuery.devicePixelRatioOf(context),
    child: const ColoredBox(color: border),
  );
}

class Notice extends StatelessWidget {
  const Notice({super.key, required this.text, this.tone = 'info'});
  final String text, tone;
  @override
  Widget build(BuildContext context) {
    final (fg, background, icon) = switch (tone) {
      'error' => (danger, dangerSoft, Ionicons.alertCircle),
      'success' => (success, successSoft, Ionicons.checkmarkCircle),
      'warn' => (warn, warnSoft, Ionicons.warning),
      _ => (info, infoSoft, Ionicons.informationCircle),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: m.Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: fg),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: c.text,
                  fontSize: 14,
                  height: 20 / 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.error, this.onRetry});
  final Object? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 10,
    children: [
      Notice(text: errorMessage(error), tone: 'error'),
      if (onRetry != null)
        Button(
          title: 'Thử lại',
          kind: 'secondary',
          icon: Ionicons.refresh,
          onPress: onRetry!,
        ),
    ],
  );
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: MediaQuery.disableAnimationsOf(context)
            ? const Text('Đang tải…')
            : SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: brand, strokeWidth: 2),
              ),
      ),
    );
  }
}

class Empty extends StatelessWidget {
  const Empty({
    super.key,
    required this.text,
    this.icon = Ionicons.fileTrayOutline,
    this.action,
  });
  final String text;
  final IconData icon;
  final ({String label, VoidCallback onPress})? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 14,
      children: [
        Icon(icon, size: 24, color: muted),
        Muted(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 22 / 15),
        ),
        if (action != null)
          Button(
            title: action!.label,
            onPress: action!.onPress,
            kind: 'soft',
            size: 'sm',
          ),
      ],
    ),
  );
}

class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
  });
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback? onRetry;

  /// Supply an existing skeleton when the destination layout is predictable.
  final Widget? loading;
  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (constraints.hasBoundedHeight)
              Expanded(child: builder(value.requireValue))
            else
              builder(value.requireValue),
            if (value.isLoading)
              MediaQuery.disableAnimationsOf(context)
                  ? const Text('Đang cập nhật…')
                  : const LinearProgressIndicator(),
            if (value.hasError) ErrorBox(error: value.error, onRetry: onRetry),
          ],
        ),
      );
    }
    if (value.isLoading) return loading ?? const Loading();
    return switch (value) {
      AsyncError(:final error) => ErrorBox(error: error, onRetry: onRetry),
      AsyncData(:final value) => builder(value),
      _ => const Loading(),
    };
  }
}
