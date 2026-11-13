import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/projects.dart';
import 'package:smartduan/api/units.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/realtime/socket.dart';

class BoardSession extends Session {
  BoardSession([this.roles = const ['sales']]);
  final List<String> roles;
  @override
  SessionState build() =>
      SessionState(SessionStatus.signedIn, me: {'roles': roles});
  void endSession() => state = const SessionState(SessionStatus.guest);
}

class BoardSocket extends InventorySocket {
  BoardSocket() : super(fetchTicket: () async => 'unused');
  ProjectHandlers? handlers;
  int leaves = 0, joins = 0;
  @override
  Future<void> joinProject(String id, ProjectHandlers handlers) async {
    this.handlers = handlers;
    joins++;
  }

  @override
  void disconnect() {
    leaves++;
    handlers = null;
  }
}

class BoardProjects extends ProjectsApi {
  BoardProjects(super.client);
  List<Block> blocks = [];
  int reads = 0;
  Future<List<Block>>? pendingBlocks;
  @override
  Future<List<Block>> fetchBlocks(String projectId) async {
    reads++;
    if (pendingBlocks != null) return pendingBlocks!;
    return blocks;
  }
}

class BoardUnits extends UnitsApi {
  BoardUnits(super.client);
  List<Unit> units = [
    Unit.fromJson({
      'id': 'u1',
      'code': 'A-12.05',
      'block_id': 'b',
      'status': 'available',
      'version': 1,
      'area_net': '50.5',
      'price_min': '400000000',
    }),
  ];
  int reads = 0, stackReads = 0, downloads = 0;
  Object? stackError, historyError;
  Paged<HistoryRow> history = Paged(data: [], total: 0, page: 1, perPage: 100);
  @override
  Future<List<Unit>> fetchAllUnits(
    String id, [
    Map<String, dynamic> params = const {},
  ]) async {
    reads++;
    return units;
  }

  @override
  Future<Enums> fetchEnums() async => const Enums();
  @override
  Future<StackPlan> fetchStackPlan(String blockId) async {
    stackReads++;
    if (stackError != null) throw stackError!;
    return StackPlan(
      block: BlockRef(id: blockId),
      layout: 'floors',
      axes: ['01'],
      floors: [
        StackFloor(
          floor: 12,
          cells: [
            StackCell(
              id: 'u1',
              code: 'A-12.05',
              axis: '01',
              status: 'available',
              version: 1,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<String> downloadUnitsXlsx(String id, String code) async {
    downloads++;
    throw const ApiError(
      403,
      'forbidden',
      'Bạn không có quyền thực hiện thao tác này',
    );
  }

  @override
  Future<Paged<HistoryRow>> fetchProjectHistory(
    String id, [
    int page = 1,
  ]) async {
    if (historyError != null) throw historyError!;
    return history;
  }
}
