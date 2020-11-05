import 'package:dart_service_announcement/src/server_base.dart';

import 'package:dart_service_announcement/src/server_empty.dart'
    if (dart.library.html) 'package:dart_service_announcement/src/web_server.dart'
    if (dart.library.io) 'package:dart_service_announcement/src/io_server.dart';

///Create the announcement server for the tooling server
ServerAnnouncementManager createToolingServer(
  String packageName,
  int announcementPort,
  ToolingServer server,
) =>
    internalCreateServer(packageName, announcementPort, server);
