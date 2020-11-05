import 'package:dart_service_announcement/src/server_base.dart';

BaseServerAnnouncementManager internalCreateServer(
  String packageName,
  int announcementPort,
  ToolingServer server,
) =>
    _DummyServerAnnouncementManager(packageName, announcementPort, server);

class _DummyServerAnnouncementManager extends BaseServerAnnouncementManager {
  _DummyServerAnnouncementManager(
    String packageName,
    int announcementPort,
    ToolingServer server,
  ) : super(packageName, announcementPort, server);

  @override
  void addExtension(AnnouncementExtension extension) {}

  @override
  Future<void> start() {
    return Future.value();
  }

  @override
  Future<void> stop() {
    return Future.value();
  }
}
