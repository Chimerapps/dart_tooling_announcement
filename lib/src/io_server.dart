// Copyright (c) 2020, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_service_announcement/src/server_base.dart';
import 'package:logging/logging.dart';
import 'package:synchronized/synchronized.dart';

const int _COMMAND_REQUEST_QUERY = 0x01;
const int _COMMAND_REQUEST_ANNOUNCE = 0x02;
const int _ANNOUNCEMENT_VERSION = 3;

BaseServerAnnouncementManager internalCreateServer(
  String packageName,
  int announcementPort,
  ToolingServer server,
) =>
    _IOServerAnnouncementManager(packageName, announcementPort, server);

/// TCP based server that handles client/server announcements.
/// These announcements allow clients to discover all processes which currently have the tooling server enabled.
class _IOServerAnnouncementManager extends BaseServerAnnouncementManager {
  final _log = Logger('ServerAnnouncementManager');

  final _extensions = <AnnouncementExtension>[];

  final _lock = Lock();
  bool _running = false;
  ServerSocket? _serverSocket;
  Socket? _secondarySocket;

  _IOServerAnnouncementManager(
    String packageName,
    int announcementPort,
    ToolingServer server,
  ) : super(packageName, announcementPort, server);

  @override
  void addExtension(AnnouncementExtension extension) {
    _extensions.add(extension);
  }

  /// Start the announcement server
  @override
  Future<void> start() async {
    return _lock.synchronized(() async {
      if (_running) return;
      _running = true;

      _startLoop();
    });
  }

  void _startLoop() {
    final _secondaries = <_Secondary>[];

    Future.doWhile(() async {
      final streamer = StreamController();
      var awaitStreamer = true;
      try {
        _log.finest('Attempting to start in main mode');
        final serverSocket =
            await ServerSocket.bind(InternetAddress.anyIPv4, announcementPort)
              ..listen((socket) {
                _onSocket(socket, _secondaries);
              }, onError: (e) async {
                _log.finer('On error, closing ($e)');
                streamer.add(1);
                // ignore: cascade_invocations
                await streamer.close();
              }, onDone: () async {
                _log.finest('Server socket done');
                streamer.add(2);
                // ignore: cascade_invocations
                await streamer.close();
              });
        await _lock.synchronized(() {
          if (_running) {
            _serverSocket = serverSocket;
          } else {
            serverSocket.close();
            _secondarySocket = null;
          }
        });
      } catch (e) {
        _log.finest('Got error in primary mode, trying as secondary');
        try {
          if (await _lock.synchronized(() => _running)) {
            awaitStreamer = false;
            await _runSecondary();
            _log.finest('Run secondary has returned');
          }
        } catch (e) {
          _log.finest('Got error in secondary mode');
          awaitStreamer = false;
        } finally {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (awaitStreamer) {
        _log.finest('Awaiting run loop results');
        final data = await streamer.stream.first;
        _log.finest('Run loop finished a loop with $data');
      }

      return _lock.synchronized(() => _running);
    });
  }

  /// Stop the announcement server
  @override
  Future<void> stop() async {
    return _lock.synchronized(() async {
      _running = false;
      final server = _serverSocket;
      if (server != null) {
        await server.close();
      }
      final secondary = _secondarySocket;
      if (secondary != null) {
        await secondary.close();
      }
      _serverSocket = null;
      _secondarySocket = null;
    });
  }

  Future<void> _onSocket(Socket socket, List<_Secondary> secondaries) async {
    _log.finest('Got announcement secondary connection');
    Stream<List<int>> dataStream;
    if (!socket.isBroadcast) {
      dataStream = socket.asBroadcastStream();
    } else {
      dataStream = socket;
    }
    final data = await dataStream.first;
    if (data.isEmpty) {
      return socket.close();
    }
    final command = data[0];
    if (command == _COMMAND_REQUEST_QUERY) {
      final responseData = await _handleQuery(dataStream, secondaries);
      socket.add(responseData);
      await socket.flush();
      await socket.close();
    } else if (command == _COMMAND_REQUEST_ANNOUNCE) {
      await _handleAnnounce(dataStream, socket, data, secondaries);
    }
  }

  Future<List<int>> _handleQuery(
    Stream<List<int>> socket,
    List<_Secondary> secondaries,
  ) async {
    _log.finest('Got query request');
    final responses = <Map<String, dynamic>>[];

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
    responses.add(responseData);

    secondaries.forEach((secondary) {
      final secondaryDescriptor = <String, dynamic>{};
      secondaryDescriptor['packageName'] = secondary.packageName;
      secondaryDescriptor['port'] = secondary.port;
      secondaryDescriptor['pid'] = secondary.pid;
      secondaryDescriptor['protocol'] = secondary.protocolVersion;
      secondaryDescriptor['extensions'] = secondary.extensions.map((ext) {
        return {
          'name': ext.name,
          'data': base64.encoder.convert(ext.data()),
        };
      }).toList();
      responses.add(secondaryDescriptor);
    });
    return utf8.encode(json.encode(responses));
  }

  Future<void> _handleAnnounce(
    Stream<List<int>> socket,
    Socket done,
    List<int> initialData,
    List<_Secondary> secondaries,
  ) async {
    _log.finest('Got secondary announce');

    final byteView = _SocketByteView(initialData, socket);

    final version = await byteView.getInt32();
    final packageNameLength = await byteView.getInt32();
    final packageName = utf8.decode(await byteView.getBytes(packageNameLength));
    final port = await byteView.getInt32();
    final pid = await byteView.getInt32();
    final protocolVersion = await byteView.getInt32();

    final extensions = <AnnouncementExtension>[];
    if (version == 2) {
      final iconLength = await byteView.getInt32();
      if (iconLength > 0) {
        final icon = utf8.decode(await byteView.getBytes(iconLength));
        extensions.add(IconExtension(icon));
      }
    } else if (version >= _ANNOUNCEMENT_VERSION) {
      final extensionCount = await byteView.getInt16();
      for (var i = 0; i < extensionCount; ++i) {
        final type = await byteView.getInt16();
        final size = await byteView.getInt16();
        final extensionBytes = await byteView.getBytes(size);

        switch (type) {
          case EXTENSION_TYPE_TAG:
            extensions.add(TagExtension(utf8.decode(extensionBytes)));
            break;
          case EXTENSION_TYPE_ICON:
            extensions.add(IconExtension(utf8.decode(extensionBytes)));
            break;
          default:
            extensions.add(UserExtension(type, extensionBytes));
            break;
        }
      }
    }

    final secondary = _Secondary(
      packageName,
      port,
      pid,
      protocolVersion,
      extensions,
    );
    _log.finest('Got new secondary: $packageName on $port');
    secondaries.add(secondary);
    // ignore: unawaited_futures
    socket.drain().then((_) {
      print('Secondary at $port closed');
      return secondaries.remove(secondary);
    });
    return;
  }

  Future<void> _runSecondary() async {
    _log.finest('Connecting secondary socket');
    final secondarySocket =
        await Socket.connect(InternetAddress.loopbackIPv4, announcementPort);
    final doContinue = await _lock.synchronized(() async {
      if (_running) {
        _secondarySocket = secondarySocket;
        return true;
      } else {
        await secondarySocket.close();
        return false;
      }
    });
    if (!doContinue) return;

    final packageNameBytes = utf8.encode(packageName);
    //Command + version + packageName length + packageName + port + pid + protocolVersion + extension count
    var length = 1 + 4 + 4 + packageNameBytes.length + 4 + 4 + 4 + 2;

    _extensions.forEach((ex) => length += 4 + ex.length());

    final data = Int8List(length);
    final bytes = data.buffer;
    final byteView = ByteData.view(bytes);
    data[0] = _COMMAND_REQUEST_ANNOUNCE;
    var offset = 1;
    byteView.setInt32(offset, _ANNOUNCEMENT_VERSION);
    offset += 4;
    byteView.setInt32(offset, packageNameBytes.length);
    offset += 4;
    data.setAll(offset, packageNameBytes);
    offset += packageNameBytes.length;
    byteView.setInt32(offset, server.port);
    offset += 4;
    byteView.setInt32(offset, -1); //PID
    offset += 4;
    byteView.setInt32(offset, server.protocolVersion);
    offset += 4;
    byteView.setInt16(offset, _extensions.length);
    offset += 2;

    _extensions.forEach((extension) {
      byteView.setInt16(offset, extension.type);
      offset += 2;
      byteView.setInt16(offset, extension.length());
      offset += 2;
      data.setAll(offset, extension.data());
      offset += extension.length();
    });

    _log.finest('Sending secondary data');
    secondarySocket.add(data);
    _log.finest('Flushing secondary data');
    await secondarySocket.flush();
    _log.finest('Waiting for secondary socket to close');
    // ignore: unawaited_futures
    secondarySocket.drain().then((value) async {
      _log.finest('Primary seems to have gone away! Closing secondary');
      await secondarySocket.close();
      _log.finest('Secondary closed for primary');

      await _lock.synchronized(() async {
        _secondarySocket = null;
      });
    });
    await secondarySocket.done.then((value) async {
      _log.finest('Closing secondary');
      await secondarySocket.close();
      _log.finest('Secondary closed');

      await _lock.synchronized(() async {
        _secondarySocket = null;
      });
    });
    _log.finest('Run secondary existing');
  }
}

class _Secondary {
  final String packageName;
  final int port;
  final int pid;
  final int protocolVersion;
  final List<AnnouncementExtension> extensions;

  _Secondary(
    this.packageName,
    this.port,
    this.pid,
    this.protocolVersion,
    this.extensions,
  );
}

class _SocketByteView {
  final Stream<List<int>> _socket;
  List<int> _currentBlob;
  int _offsetInCurrentBlob = 1;

  _SocketByteView(this._currentBlob, this._socket);

  Future<int> getInt32() async {
    final list = Int8List(4);
    list[0] = await getByte();
    list[1] = await getByte();
    list[2] = await getByte();
    list[3] = await getByte();
    return ByteData.view(list.buffer).getInt32(0);
  }

  Future<int> getInt16() async {
    final list = Int8List(2);
    list[0] = await getByte();
    list[1] = await getByte();
    return ByteData.view(list.buffer).getInt16(0);
  }

  Future<Int8List> getBytes(int length) async {
    final list = Int8List(length);
    for (var i = 0; i < length; ++i) {
      list[i] = await getByte();
    }
    return list;
  }

  Future<int> getByte() async {
    if (_currentBlob != null && _offsetInCurrentBlob < _currentBlob.length) {
      return _currentBlob[_offsetInCurrentBlob++];
    }

    _currentBlob = await _socket.first;
    _offsetInCurrentBlob = 0;

    return getByte();
  }
}
