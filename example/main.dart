// Copyright (c) 2020, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'package:dart_service_announcement/dart_service_announcement.dart';

class DemoServer extends ToolingServer {
  @override
  int get port => 10290;

  @override
  int get protocolVersion => 4;
}

Future<void> main() async {
  final manager = createToolingServer('com.example.test', 6394, DemoServer());

  await manager.start();

  //Run tooling server etc

  const waitDuration = Duration(seconds: 1000000);

  await Future.delayed(waitDuration);

  await manager.stop();
}
