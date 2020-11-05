A helper library for creating tooling announcement servers for tools such as niddler

[license](https://raw.githubusercontent.com/Chimerapps/dart_tooling_announcement/master/LICENSE).

## Usage

A simple usage example:

```dart
import 'package:dart_service_announcement/dart_service_announcement.dart';

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
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Chimerapps/dart_tooling_announcement/issues
