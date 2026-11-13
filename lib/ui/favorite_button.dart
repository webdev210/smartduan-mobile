import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/errors.dart';
import '../api/me.dart';
import '../auth/session.dart';
import 'theme.dart' as c;

final savedProjectsProvider =
    AsyncNotifierProvider<SavedProjects, List<String>>(
      SavedProjects.new,
      retry: (_, _) => null,
    );

class SavedProjects extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final session = ref.watch(sessionProvider);
    if (session.status != SessionStatus.signedIn) return const [];
    return ref.watch(meApiProvider).fetchSavedProjects();
  }

  Future<void> toggle(String code) async {
    final previous = state;
    final codes = state.asData?.value ?? <String>[];
    final on = codes.contains(code);
    state = AsyncData(
      List.unmodifiable(
        on
            ? codes.where((c) => c != code)
            : [...codes.where((c) => c != code), code],
      ),
    );
    final session = ref.read(sessionProvider);
    try {
      final api = ref.read(meApiProvider);
      final result = await (on
          ? api.unsaveProject(code)
          : api.saveProjects([code]));
      if (ref.mounted && identical(session, ref.read(sessionProvider))) {
        state = AsyncData(result);
      }
    } catch (_) {
      if (ref.mounted && identical(session, ref.read(sessionProvider))) {
        state = previous;
      }
      rethrow;
    }
  }
}

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    super.key,
    required this.code,
    required this.name,
    this.overlay = false,
    this.size = 22,
  });
  final String code, name;
  final bool overlay;
  final double size;
  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool busy = false;
  Future<void> press() async {
    if (busy) return;
    if (ref.read(sessionProvider).status != SessionStatus.signedIn) {
      context.push('/dang-nhap');
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(savedProjectsProvider.notifier).toggle(widget.code);
    } catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Không lưu được'),
            content: Text(errorMessage(error)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn =
        ref.watch(sessionProvider).status == SessionStatus.signedIn;
    final on =
        signedIn &&
        (ref.watch(savedProjectsProvider).asData?.value.contains(widget.code) ??
            false);
    return Semantics(
      button: true,
      selected: on,
      enabled: !busy,
      onTap: busy ? null : press,
      label: '${on ? 'Bỏ yêu thích' : 'Yêu thích'} ${widget.name}',
      excludeSemantics: true,
      child: IconButton(
        tooltip: '${on ? 'Bỏ yêu thích' : 'Yêu thích'} ${widget.name}',
        style: widget.overlay
            ? IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .94),
                shadowColor: c.text,
                elevation: 1,
              )
            : null,
        icon: Icon(
          on ? Ionicons.heart : Ionicons.heartOutline,
          size: widget.size,
          color: on
              ? c.brand
              : widget.overlay
              ? c.text
              : c.muted,
        ),
        onPressed: busy ? null : press,
      ),
    );
  }
}
