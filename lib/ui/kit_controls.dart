part of 'kit.dart';

class Button extends StatefulWidget {
  const Button({
    super.key,
    required this.title,
    required this.onPress,
    this.onLongPress,
    this.disabled = false,
    this.loading = false,
    this.kind = 'primary',
    this.icon,
    this.size = 'md',
    this.accessibilityLabel,
  });
  final String title, kind, size;
  final VoidCallback onPress;
  final VoidCallback? onLongPress;
  final bool disabled, loading;
  final IconData? icon;
  final String? accessibilityLabel;

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final Button(
      :title,
      :kind,
      :size,
      :onPress,
      :onLongPress,
      :disabled,
      :loading,
      :icon,
      :accessibilityLabel,
    ) = widget;
    final off = disabled || loading;
    final (fg, background, stroke) = switch (kind) {
      'soft' || 'secondary' => (brand, brandSoft, Colors.transparent),
      'danger' => (danger, card, dangerBorder),
      'link' => (link, Colors.transparent, Colors.transparent),
      _ => (card, primary, Colors.transparent),
    };
    final small = size == 'sm';
    final radius = small ? 12.0 : 14.0;
    final button = Pressable(
      label: loading
          ? '${accessibilityLabel ?? title}, đang xử lý'
          : accessibilityLabel ?? title,
      disabled: off,
      onPress: onPress,
      onLongPress: onLongPress,
      pressedOpacity: 1,
      onHighlightChanged: (value) => setState(() => pressed = value),
      child: Opacity(
        opacity: off ? 0.45 : 1,
        child: Container(
          constraints: BoxConstraints(minHeight: small ? 48 : 52),
          padding: EdgeInsets.symmetric(
            horizontal: kind == 'link'
                ? 4
                : small
                ? 16
                : 20,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: pressed && kind == 'primary' ? primaryPressed : background,
            border: kind == 'link' ? null : Border.all(color: stroke),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            heightFactor: 1,
            widthFactor: small ? 1 : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: loading ? 0 : 1,
                  child: m.Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      if (icon != null) Icon(icon, size: 20, color: fg),
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: fg,
                            fontWeight: kind == 'primary'
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: small ? 15 : 16,
                            letterSpacing: kind == 'primary' ? 0.1 : 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: fg, strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      liveRegion: true,
      child: small
          ? Align(
              alignment: Alignment.centerLeft,
              heightFactor: 1,
              widthFactor: 1,
              child: button,
            )
          : button,
    );
  }
}

/// Equal-size actions, stacked when their labels need more room.
class ButtonGroup extends StatelessWidget {
  const ButtonGroup({super.key, required this.children, this.spacing = 12});
  final List<Button> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cellWidth =
          (constraints.maxWidth - spacing * (children.length - 1)) /
          children.length;
      final stack = children.any((button) {
        final painter = TextPainter(
          text: TextSpan(
            text: button.title,
            style: TextStyle(
              fontSize: button.size == 'sm' ? 15 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final needed = painter.width + 40 + (button.icon == null ? 0 : 28);
        painter.dispose();
        return cellWidth < needed || cellWidth < 48;
      });
      return stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing,
              children: children,
            )
          : m.Row(
              spacing: spacing,
              children: [
                for (final button in children) Expanded(child: button),
              ],
            );
    },
  );
}

class IconButton extends StatelessWidget {
  const IconButton({
    super.key,
    required this.icon,
    required this.onPress,
    required this.label,
    this.tone = 'plain',
    this.badge,
  });
  final IconData icon;
  final VoidCallback onPress;
  final String label, tone;
  final int? badge;
  @override
  Widget build(BuildContext context) {
    final (background, fg) = switch (tone) {
      'brand' => (primary, card),
      'glass' => (const Color.fromRGBO(255, 255, 255, 0.16), card),
      _ => (card, text),
    };
    final hasBadge = badge != null && badge != 0;
    return Pressable(
      label: hasBadge ? '$label, $badge mới' : label,
      onPress: onPress,
      pressedOpacity: 0.7,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 21, color: fg),
                ),
                if (hasBadge)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: _Badge('$badge', cap: true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.value, {this.cap = false, this.isGold = false});
  final String value;
  final bool cap, isGold;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isGold ? gold : brand,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: card, width: 1.5),
    ),
    child: Text(
      cap && (int.tryParse(value) ?? 0) > 99 ? '99+' : value,
      style: TextStyle(
        color: isGold ? brandDeep : card,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    this.error,
    this.controller,
    this.value,
    this.onChangeText,
    this.placeholder,
    this.onFocus,
    this.onBlur,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmit,
    this.autoFocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.autoCapitalize = TextCapitalization.sentences,
    this.autofillHints,
    this.inputFormatters,
    this.autocorrect = true,
  });
  final String label;
  final String? error, value, placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChangeText, onSubmit;
  final VoidCallback? onFocus, onBlur;
  final FocusNode? focusNode;
  final bool obscureText, autoFocus, enabled, readOnly, autocorrect;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength, maxLines;
  final TextCapitalization autoCapitalize;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  @override
  Widget build(BuildContext context) {
    final stroke = error?.isNotEmpty == true ? danger : primary;
    OutlineInputBorder outline(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Semantics(
          label: label,
          hint: error,
          child: Focus(
            onFocusChange: (focused) =>
                focused ? onFocus?.call() : onBlur?.call(),
            child: _TextInput(
              value: value,
              controller: controller,
              onChangeText: onChangeText,
              builder: (controller) => TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                onSubmitted: onSubmit,
                autofocus: autoFocus,
                maxLength: maxLength,
                maxLines: maxLines,
                enabled: enabled,
                readOnly: readOnly,
                autocorrect: autocorrect,
                textCapitalization: autoCapitalize,
                autofillHints: autofillHints,
                inputFormatters: inputFormatters,
                onChanged: onChangeText,
                style: const TextStyle(fontSize: 16, color: text),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: placeholder,
                  hintStyle: const TextStyle(color: subtle),
                  filled: true,
                  fillColor: card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  constraints: const BoxConstraints(minHeight: 50),
                  enabledBorder: outline(
                    error?.isNotEmpty == true ? danger : border,
                  ),
                  disabledBorder: outline(border),
                  focusedBorder: outline(stroke),
                ),
              ),
            ),
          ),
        ),
        if (error?.isNotEmpty == true)
          ExcludeSemantics(
            child: Text(
              error!,
              style: const TextStyle(color: danger, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

// Own only Flutter's input controller; the caller remains the source of truth.
class _TextInput extends StatefulWidget {
  const _TextInput({
    this.value,
    this.controller,
    this.onChangeText,
    required this.builder,
  });
  final String? value;
  final TextEditingController? controller;
  final ValueChanged<String>? onChangeText;
  final Widget Function(TextEditingController) builder;
  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  TextEditingController? _owned;
  TextEditingController get controller =>
      widget.controller ??
      (_owned ??= TextEditingController(text: widget.value));
  @override
  void didUpdateWidget(covariant _TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null &&
        widget.value != null &&
        widget.value != controller.text) {
      controller.value = TextEditingValue(
        text: widget.value!,
        selection: TextSelection.collapsed(offset: widget.value!.length),
      );
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(controller);
}

class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    required this.value,
    required this.onChangeText,
    this.placeholder = 'Tìm kiếm…',
    this.onSubmit,
    this.onFilter,
    this.filterCount = 0,
    this.autoFocus = false,
    this.autoCapitalize = TextCapitalization.none,
    this.onFocus,
    this.onBlur,
    this.maxLength,
  });
  final String value, placeholder;
  final ValueChanged<String> onChangeText;
  final VoidCallback? onSubmit, onFilter, onFocus, onBlur;
  final int filterCount;
  final bool autoFocus;
  final TextCapitalization autoCapitalize;
  final int? maxLength;
  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => m.Row(
    spacing: 10,
    children: [
      Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: focused ? primary : line),
          ),
          child: m.Row(
            spacing: 10,
            children: [
              const Icon(Ionicons.search, size: 20, color: subtle),
              Expanded(
                child: Focus(
                  onFocusChange: (v) {
                    setState(() => focused = v);
                    v ? widget.onFocus?.call() : widget.onBlur?.call();
                  },
                  child: _TextInput(
                    value: widget.value,
                    builder: (controller) => TextField(
                      controller: controller,
                      onChanged: widget.onChangeText,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => widget.onSubmit?.call(),
                      autofocus: widget.autoFocus,
                      textCapitalization: widget.autoCapitalize,
                      maxLength: widget.maxLength,
                      style: const TextStyle(fontSize: 16, color: text),
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: const TextStyle(color: subtle),
                        border: InputBorder.none,
                        isDense: true,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.value.isNotEmpty)
                Semantics(
                  button: true,
                  label: 'Xoá từ khoá',
                  onTap: () => widget.onChangeText(''),
                  child: Pressable(
                    onPress: () => widget.onChangeText(''),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Ionicons.closeCircle,
                        size: 20,
                        color: subtle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (widget.onFilter != null)
        Semantics(
          button: true,
          label: widget.filterCount != 0
              ? 'Bộ lọc, đang bật ${widget.filterCount}'
              : 'Bộ lọc',
          onTap: widget.onFilter,
          child: Pressable(
            onPress: widget.onFilter,
            child: ExcludeSemantics(
              child: SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.filterCount != 0 ? primary : card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.filterCount != 0
                              ? Colors.transparent
                              : line,
                        ),
                      ),
                      child: Icon(
                        Ionicons.optionsOutline,
                        size: 22,
                        color: widget.filterCount != 0 ? card : text,
                      ),
                    ),
                    if (widget.filterCount != 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: _Badge('${widget.filterCount}', isGold: true),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class Chip extends StatelessWidget {
  const Chip({
    super.key,
    required this.label,
    this.active = false,
    this.onPress,
    this.color,
    this.icon,
    this.trailing,
    this.informational = false,
  });
  final String label;
  final bool active;
  final bool informational;
  final VoidCallback? onPress;
  final Color? color;
  final IconData? icon, trailing;
  @override
  Widget build(BuildContext context) {
    final fg = active ? solidForeground(color ?? primary) : text;
    return MergeSemantics(
      child: Semantics(
        button: informational ? null : true,
        selected: informational ? null : active,
        enabled: informational ? null : onPress != null,
        child: Pressable(
          onPress: informational ? null : onPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Opacity(
              opacity: !informational && onPress == null ? 0.45 : 1,
              child: Material(
                color: active ? color ?? primary : card,
                shape: StadiumBorder(
                  side: BorderSide(color: active ? color ?? primary : border),
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: m.Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      if (color != null && !active)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                      if (icon ?? trailing case final leading?)
                        Icon(leading, size: 20, color: fg),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontSize: 14,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Chips extends StatelessWidget {
  const Chips({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class ChipRail extends StatelessWidget {
  const ChipRail({super.key, required this.children, this.bleed = 20});
  final List<Widget> children;
  final double bleed;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      height: 56 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 1.5,
      child: OverflowBox(
        minWidth: constraints.maxWidth + bleed * 2,
        maxWidth: constraints.maxWidth + bleed * 2,
        alignment: Alignment.center,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: bleed, vertical: 4),
          child: m.Row(spacing: 8, children: children),
        ),
      ),
    ),
  );
}

class Segmented<T extends String> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.onChange,
    required this.options,
  });
  final T? value;
  final ValueChanged<T> onChange;
  final List<({T key, String label, int? count})> options;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: quiet,
      borderRadius: BorderRadius.circular(14),
    ),
    child: m.Row(
      children: options.map((o) {
        final active = o.key == value;
        return Expanded(
          child: Semantics(
            selected: active,
            button: true,
            child: Pressable(
              onPress: () => onChange(o.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: active ? card : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        '${o.label}${o.count == null ? '' : ' · ${o.count}'}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active ? brand : muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.soft = false,
  });
  final String label;
  final Color color;
  final bool soft;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    heightFactor: 1,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: soft ? color.withValues(alpha: 0.102) : color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: soft ? color : solidForeground(color),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class FilterGroup extends StatelessWidget {
  const FilterGroup({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 10,
    children: [
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: muted,
          letterSpacing: 0.3,
        ),
      ),
      Chips(children: children),
    ],
  );
}
