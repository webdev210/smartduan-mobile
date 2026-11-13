part of 'kit.dart';

class FaqItem extends StatefulWidget {
  const FaqItem({super.key, required this.question, required this.answer});
  final String question, answer;
  @override
  State<FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<FaqItem> {
  bool open = false;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    title: Text(widget.question),
    onExpansionChanged: (value) => setState(() => open = value),
    trailing: Icon(
      open ? Ionicons.chevronUp : Ionicons.chevronDown,
      size: 18,
      color: c.subtle,
    ),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    children: [Body(widget.answer)],
  );
}

class Card extends StatelessWidget {
  const Card({
    super.key,
    this.child,
    this.children,
    this.onPress,
    this.accessibilityLabel,
    this.padding = const EdgeInsets.all(16),
    this.style,
  }) : assert((child == null) != (children == null));
  final Widget? child;
  final List<Widget>? children;
  final VoidCallback? onPress;
  final String? accessibilityLabel;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? style;
  @override
  Widget build(BuildContext context) => Pressable(
    onPress: onPress,
    pressedScale: 0.985,
    label: accessibilityLabel,
    child: Container(
      decoration:
          BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: line,
              width: 1 / MediaQuery.devicePixelRatioOf(context),
            ),
          ).copyWith(
            color: style?.color,
            borderRadius: style?.borderRadius,
            border: style?.border,
            boxShadow: style?.boxShadow,
            gradient: style?.gradient,
          ),
      child: Padding(
        padding: padding,
        child:
            child ??
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: children!,
            ),
      ),
    ),
  );
}

class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.title,
    this.child,
    this.children,
    this.eyebrow,
    this.action,
  }) : assert((child == null) != (children == null));
  final String title;
  final String? eyebrow;
  final Widget? child;
  final List<Widget>? children;
  final ({String label, VoidCallback onPress})? action;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [if (eyebrow != null) Eyebrow(eyebrow!), H2(title)],
          );
          if (action == null) return heading;
          double measure(String value, double size, FontWeight weight) {
            final painter = TextPainter(
              text: TextSpan(
                text: value,
                style: TextStyle(fontSize: size, fontWeight: weight),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          final button = Button(
            title: action!.label,
            kind: 'link',
            size: 'sm',
            icon: Ionicons.chevronForward,
            onPress: action!.onPress,
          );
          final needed =
              measure(title, 19, FontWeight.w700) +
              measure(action!.label, 15, FontWeight.w600) +
              48;
          return needed > constraints.maxWidth
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, button],
                )
              : m.Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 12,
                  children: [
                    Expanded(child: heading),
                    button,
                  ],
                );
        },
      ),
      if (child != null) child! else ...children!,
    ],
  );
}

class Hero extends StatelessWidget {
  const Hero({super.key, this.child, this.children, this.style})
    : assert((child == null) != (children == null));
  final Widget? child;
  final List<Widget>? children;
  final BoxDecoration? style;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: brandDeep,
          border: Border.all(color: gold),
        ).copyWith(color: style?.color, gradient: style?.gradient),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child:
                  child ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: children!,
                  ),
            ),
          ],
        ),
      ),
    ),
  );
}

class Stat extends StatelessWidget {
  const Stat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onPress,
    this.accent = text,
  });
  final String label;
  final Object value;
  final IconData icon;
  final VoidCallback? onPress;
  final Color accent;
  @override
  Widget build(BuildContext context) => Card(
    onPress: onPress,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        m.Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 24, color: accent),
            if (onPress != null)
              const Icon(Ionicons.arrowForward, size: 16, color: subtle),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            DefaultTextStyle(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: -0.8,
              ),
              child: value is Widget ? value as Widget : Text('$value'),
            ),
            Muted(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ],
    ),
  );
}

class ListItem extends StatelessWidget {
  const ListItem({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.onPress,
    this.right,
    this.tone,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });
  final IconData? icon;
  final String title;
  final String? subtitle, tone;
  final VoidCallback? onPress;
  final Widget? right;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      'brand' => brand,
      'danger' => danger,
      _ => text,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: padding,
          child: m.Row(
            spacing: 12,
            children: [
              if (icon != null)
                Icon(icon, size: 24, color: tone == 'danger' ? danger : brand),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        height: 22 / 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Muted(subtitle!, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              if (right != null)
                right!
              else if (onPress != null)
                const Icon(Ionicons.chevronForward, size: 18, color: subtle),
            ],
          ),
        ),
      ),
    );
  }
}

class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.icon,
    required this.label,
    required this.onPress,
    this.tone = 'brand',
  });
  final IconData icon;
  final String label, tone;
  final VoidCallback onPress;
  @override
  Widget build(BuildContext context) => Card(
    onPress: onPress,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Icon(icon, size: 24, color: tone == 'gold' ? goldDeep : brand),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.textScalerOf(context).scale(13) * 34 / 13,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 17 / 13,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          (constraints.maxWidth - 20) / 3 < 104 ||
              MediaQuery.textScalerOf(context).scale(14) / 14 > 1.3
          ? 2
          : 3;
      return Column(
        spacing: 10,
        children: [
          for (var i = 0; i < children.length; i += columns)
            IntrinsicHeight(
              child: m.Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  for (var j = 0; j < columns; j++)
                    Expanded(
                      child: i + j < children.length
                          ? children[i + j]
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

String initials(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
      .toUpperCase();
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.size = 48,
    this.tone = 'brand',
  });
  final String? name;
  final double size;
  final String tone;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: tone == 'gold' ? gold : brand,
      shape: BoxShape.circle,
    ),
    child: Text(
      initials(name),
      style: TextStyle(
        color: tone == 'gold' ? brandDeep : card,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.38,
      ),
    ),
  );
}

class Sheet extends StatefulWidget {
  const Sheet({
    super.key,
    required this.visible,
    required this.onClose,
    required this.title,
    this.child,
    this.children,
    this.footer,
    this.scrollBody = true,
  }) : assert((child == null) != (children == null));
  final bool visible;
  final VoidCallback onClose;
  final String title;
  final Widget? child;
  final List<Widget>? children;
  final Widget? footer;

  /// False when the child supplies its own lazy scroll view.
  final bool scrollBody;
  @override
  State<Sheet> createState() => _SheetState();
}

class _SheetState extends State<Sheet> {
  ModalBottomSheetRoute<void>? _route;
  bool _waitingForTopRoute = false;
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant Sheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.visible && _route == null) {
        final navigator = Navigator.of(context, rootNavigator: true);
        final route = ModalBottomSheetRoute<void>(
          builder: (_) => _SheetContent(sheet: widget),
          isScrollControlled: true,
          isDismissible: true,
          enableDrag: false,
          useSafeArea: true,
          sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          backgroundColor: card,
          modalBarrierColor: const Color.fromRGBO(19, 19, 19, 0.5),
          barrierLabel: 'Đóng',
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).top,
            maxWidth: 640,
          ),
        );
        _route = route;
        navigator.push(route).then((_) {
          if (mounted) FocusScope.of(context).unfocus();
          if (_route == route) {
            _route = null;
            if (mounted && widget.visible) widget.onClose();
          }
        });
      } else if (!widget.visible && _route != null) {
        final route = _route!;
        FocusScope.of(context).unfocus();
        if (route.isCurrent) {
          _route = null;
          route.navigator?.pop();
        } else if (!_waitingForTopRoute) {
          // Do not pop a dialog or page above this sheet. Dismiss the sheet
          // once that route has finished leaving; removal is only for dispose.
          _waitingForTopRoute = true;
          void resume(AnimationStatus status) {
            if (status != AnimationStatus.dismissed) return;
            route.secondaryAnimation?.removeStatusListener(resume);
            _waitingForTopRoute = false;
            if (mounted) _sync();
          }

          route.secondaryAnimation?.addStatusListener(resume);
        }
      } else {
        _route?.changedExternalState();
      }
    });
  }

  @override
  void dispose() {
    final route = _route;
    _route = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => route.navigator?.removeRoute(route),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({required this.sheet});
  final Sheet sheet;
  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  keyboard ? 4 : 12,
                  20,
                  keyboard ? 4 : 14,
                ),
                child: m.Row(
                  spacing: 12,
                  children: [
                    Expanded(child: H2(sheet.title)),
                    IconButton(
                      icon: Ionicons.close,
                      label: 'Đóng',
                      onPress: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: sheet.scrollBody
                    ? SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child:
                              sheet.child ??
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                spacing: 20,
                                children: sheet.children!,
                              ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: sheet.child,
                      ),
              ),
              if (sheet.footer != null)
                ConstrainedBox(
                  // Leave room for the header and focused field even when
                  // large-text actions stack above the keyboard.
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .4,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: keyboard ? 4 : 12,
                      ),
                      child: sheet.footer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.delay = 0, this.style});
  final Widget child;
  final int delay;
  final BoxDecoration? style;
  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _timer = Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: AnimatedBuilder(
      animation: _curve,
      child: widget.style == null
          ? widget.child
          : DecoratedBox(decoration: widget.style!, child: widget.child),
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 16 * (1 - _curve.value)),
        child: child,
      ),
    ),
  );
}

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.height, this.style});
  final double height;
  final BoxDecoration? style;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: quiet,
      borderRadius: BorderRadius.circular(16),
    ).copyWith(color: style?.color, borderRadius: style?.borderRadius),
  );
}
