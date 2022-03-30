import 'package:dart_service_announcement/src/server_base.dart';
import 'package:dart_service_announcement/src/server_empty.dart'
    if (dart.library.html) 'package:dart_service_announcement/src/web_server.dart'
    if (dart.library.io) 'package:dart_service_announcement/src/io_server.dart';
import 'package:dart_service_announcement/src/vm_service_server.dart';

///Create the announcement server(s) for the tooling server
// ignore: non_constant_identifier_names
BaseServerAnnouncementManager ServerAnnouncementManager(
  String packageName,
  int announcementPort,
  ToolingServer server,
) =>
    _CombiningServerAnnouncementManager([
      internalCreateServer(packageName, announcementPort, server),
      internalCreateVMServiceServer(packageName, announcementPort, server),
    ]);

///A proxy ServerAnnouncementManager that combines multiple ServerAnnouncementManagers
class _CombiningServerAnnouncementManager
    implements BaseServerAnnouncementManager {
  final List<BaseServerAnnouncementManager> _managers;

  _CombiningServerAnnouncementManager(this._managers);

  @override
  void addExtension(AnnouncementExtension extension) {
    for (final manager in _managers) {
      manager.addExtension(extension);
    }
  }

  @override
  int get announcementPort => _managers[0].announcementPort;

  @override
  String get packageName => _managers[0].packageName;

  @override
  void removeExtension(AnnouncementExtension extension) {
    for (final manager in _managers) {
      manager.removeExtension(extension);
    }
  }

  @override
  ToolingServer get server => _managers[0].server;

  @override
  Future<void> start() async {
    for (final manager in _managers) {
      await manager.start();
    }
  }

  @override
  Future<void> stop() async {
    for (final manager in _managers) {
      await manager.stop();
    }
  }
}
