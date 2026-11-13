import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/projects.dart';
import '../api/errors.dart';
import '../api/units.dart';
import '../auth/session.dart';
import 'patches.dart';
import 'socket.dart';

final inventorySocketProvider = Provider.autoDispose
    .family<InventorySocket, String>((ref, projectId) {
      signedInClient(ref);
      final session = ref.watch(sessionProvider);
      final auth = ref.watch(authApiProvider);
      final socket = InventorySocket(
        fetchTicket: () async {
          final reply = await auth.wsToken();
          if (!ref.mounted || !identical(session, ref.read(sessionProvider))) {
            throw const ApiError(
              401,
              'session_changed',
              'Phiên đăng nhập đã thay đổi',
            );
          }
          return switch (reply['token']) {
            final String token when token.isNotEmpty => token,
            _ => throw const FormatException('Invalid socket ticket'),
          };
        },
      );
      ref.onDispose(socket.disconnect);
      return socket;
    });

class InventoryState {
  const InventoryState({
    this.live = false,
    this.patches = const {},
    this.revision = 0,
    this.error,
  });
  final bool live;
  final Map<String, UnitPatch> patches;
  final int revision;
  final Object? error;
}

final inventoryChannelProvider = NotifierProvider.autoDispose
    .family<InventoryChannel, InventoryState, String>(InventoryChannel.new);

class InventoryChannel extends Notifier<InventoryState>
    with WidgetsBindingObserver {
  InventoryChannel(this.projectId);
  final String projectId;
  InventorySocket? _socket;
  int _generation = 0;

  @override
  InventoryState build() {
    final session = ref.watch(sessionProvider);
    final generation = ++_generation;
    if (session.status != SessionStatus.signedIn) {
      _socket = null;
      return const InventoryState();
    }
    final socket = ref.watch(inventorySocketProvider(projectId));
    _socket = socket;
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _generation++;
      WidgetsBinding.instance.removeObserver(this);
      socket.disconnect();
    });
    scheduleMicrotask(() {
      if (ref.mounted && generation == _generation) _join();
    });
    return const InventoryState();
  }

  void _join() {
    final generation = _generation;
    bool current() => ref.mounted && generation == _generation;
    unawaited(
      _socket!.joinProject(
        projectId,
        ProjectHandlers(
          onSnapshot: (units) {
            if (!current()) return;
            for (final patch in units ?? <UnitPatch>[]) {
              apply(patch);
            }
            state = InventoryState(
              live: true,
              patches: state.patches,
              revision: state.revision,
            );
          },
          onUnit: (patch) {
            if (current()) apply(patch);
          },
          onReload: () {
            if (current()) reload();
          },
          onDisconnected: () {
            if (current()) {
              state = InventoryState(
                patches: state.patches,
                revision: state.revision,
              );
            }
          },
          onError: (error) {
            if (current()) {
              state = InventoryState(
                patches: state.patches,
                revision: state.revision,
                error: error,
              );
            }
          },
        ),
      ),
    );
  }

  void apply(UnitPatch patch) {
    final old = state.patches[patch.unitId];
    if (old != null && patch.version < old.version) return;
    // Retain a previously supplied fund when a later status-only frame omits it.
    final merged = old == null || patch.hasFund
        ? patch
        : UnitPatch.fromJson({...old.toJson(), ...patch.toJson()});
    state = InventoryState(
      live: state.live,
      patches: {...state.patches, patch.unitId: merged},
      revision: state.revision,
    );
    ref.invalidate(fetchUnitDetailProvider(patch.unitId));
  }

  void reload() =>
      state = InventoryState(live: state.live, revision: state.revision + 1);

  void refresh() {
    if (!state.live) _join();
    reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _socket != null) {
      _join();
      reload();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _socket?.disconnect();
      this.state = InventoryState(
        patches: this.state.patches,
        revision: this.state.revision,
      );
    }
  }
}

final inventoryUnitsSourceProvider = sessionQueryFamily<List<Unit>, String>((
  ref,
  id,
) {
  ref.watch(inventoryChannelProvider(id).select((s) => s.revision));
  return ref.watch(unitsApiProvider).fetchAllUnits(id);
});

final inventoryUnitsProvider = Provider.autoDispose
    .family<AsyncValue<List<Unit>>, String>((ref, id) {
      final patches = ref.watch(inventoryChannelProvider(id)).patches;
      return ref.watch(inventoryUnitsSourceProvider(id)).whenData((units) {
        for (final patch in patches.values) {
          units = applyUnitPatch(units, patch)!;
        }
        return units;
      });
    });

typedef InventoryBlock = ({String projectId, String blockId});
final inventoryStackSourceProvider =
    sessionQueryFamily<AsyncValue<StackPlan>, InventoryBlock>((ref, key) {
      ref.watch(
        inventoryChannelProvider(key.projectId).select((s) => s.revision),
      );
      final api = ref.watch(unitsApiProvider);
      // RN disables stack retries, especially for grid_too_large. Keep the
      // shared session reset helper while returning request failures as values.
      return AsyncValue.guard(() => api.fetchStackPlan(key.blockId));
    });
final inventoryStackProvider = Provider.autoDispose
    .family<AsyncValue<StackPlan>, InventoryBlock>((ref, key) {
      final patches = ref
          .watch(inventoryChannelProvider(key.projectId))
          .patches;
      final source = ref.watch(inventoryStackSourceProvider(key));
      if (source.isLoading) return const AsyncLoading();
      if (source case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      return (source.value ?? const AsyncLoading<StackPlan>()).whenData((plan) {
        for (final patch in patches.values) {
          plan = applyPatchToStack(plan, patch)!;
        }
        return plan;
      });
    });
