import 'dart:convert';
import 'dart:developer';

import 'package:dart_service_announcement/src/server_base.dart';

BaseServerAnnouncementManager internalCreateVMServiceServer(
  String packageName,
  int announcementPort,
  ToolingServer server,
) =>
    _VMServiceServerAnnouncementManager(packageName, announcementPort, server);

class _VMServiceServerAnnouncementManager
    extends BaseServerAnnouncementManager {
  final _extensions = <AnnouncementExtension>[];
  var _started = false;

  _VMServiceServerAnnouncementManager(
    String packageName,
    int announcementPort,
    ToolingServer server,
  ) : super(packageName, announcementPort, server) {
    registerExtension('ext.${server.name}.query', (method, params) async {
      if (!_started) {
        return ServiceExtensionResponse.error(
          -1,
          'Announcement server stopped',
        );
      }

      final responseData = <String, dynamic>{};
      responseData['packageName'] = packageName;
      responseData['port'] = server.port;
      responseData['pid'] = -1;
      responseData['protocol'] = server.protocolVersion;
      responseData['extensions'] = _extensions.map((ext) {
        return {
          'name': ext.name,
          'data': base64.encoder.convert(ext.data()),
        };
      }).toList();
      return ServiceExtensionResponse.result(json.encode(responseData));
    });
  }

  @override
  void addExtension(AnnouncementExtension extension) {
    _extensions.add(extension);
  }

  @override
  void removeExtension(AnnouncementExtension extension) {
    _extensions.removeWhere((element) => element == extension);
  }

  @override
  Future<void> start() {
    _started = true;
    return Future.value();
  }

  @override
  Future<void> stop() {
    _started = false;
    return Future.value();
  }
}
