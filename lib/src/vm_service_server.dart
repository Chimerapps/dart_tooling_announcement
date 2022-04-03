import 'dart:convert';
import 'dart:developer';

import 'package:dart_service_announcement/src/server_base.dart';

BaseServerAnnouncementManager internalCreateVMServiceServer(
  String packageName,
  int announcementPort,
  ToolingServer server,
) =>
    _VMServiceServerAnnouncementManager(packageName, announcementPort, server);

class _VMServiceExtensionHelper {
  static final _instances = <int, _VMServiceExtensionHelper>{};

  factory _VMServiceExtensionHelper(int port) =>
      _instances.putIfAbsent(port, () => _VMServiceExtensionHelper(port));

  Future<ServiceExtensionResponse> Function(
      String method, Map<String, String> params)? handler;

  _VMServiceExtensionHelper._(int port) {
    registerExtension(
        'ext.dart_service_announcement_${_encodeSimpleString(port)}.query',
        _handle);
  }

  Future<ServiceExtensionResponse> _handle(
      String method, Map<String, String> params) {
    final localHandler = handler;
    if (localHandler == null) {
      return Future.value(ServiceExtensionResponse.error(
        -1,
        'Announcement server stopped',
      ));
    }
    return localHandler(method, params);
  }
}

class _VMServiceServerAnnouncementManager
    extends BaseServerAnnouncementManager {
  final _extensions = <AnnouncementExtension>[];
  var _started = false;

  late final _VMServiceExtensionHelper _extensionHelper;

  _VMServiceServerAnnouncementManager(
    String packageName,
    int announcementPort,
    ToolingServer server,
  ) : super(packageName, announcementPort, server) {
    _extensionHelper = _VMServiceExtensionHelper(announcementPort);
    _extensionHelper.handler = (method, params) async {
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
    };
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

String _encodeSimpleString(int digits) {
  return utf8.decode(_digitsOf(digits).map((e) => e + 0x41).toList());
}

Iterable<int> _digitsOf(int number) sync* {
  var remainder = number;
  do {
    yield remainder.remainder(10);
    remainder ~/= 10;
  } while (remainder != 0);
}
