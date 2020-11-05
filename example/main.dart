// Copyright (c) 2020, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'package:dart_service_announcement/announcement.dart';

class DemoServer extends ToolingServer {
  DemoServer(int port, int protocolVersion) : super(port, protocolVersion);
}

Future<void> main() async {
  final manager =
      ServerAnnouncementManager('com.example.test', 6394, DemoServer(10290, 2));

  await manager.start();

  //Run tooling server etc

  const waitDuration = Duration(seconds: 1000000);

  await Future.delayed(waitDuration);

  await manager.stop();
}
