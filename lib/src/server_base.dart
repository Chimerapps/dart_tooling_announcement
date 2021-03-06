// Copyright (c) 2020, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:convert';

///Extension type for the icon extension
const int EXTENSION_TYPE_ICON = 1;

///Extension type for the tag extension
const int EXTENSION_TYPE_TAG = 2;

///Minimal extension number for user-defined extensions
const int EXTENSION_USER_START = 256;

///Encapsulates the tooling server
abstract class ToolingServer {
  ///The port the tooling server is running on
  int get port;

  ///The protocol version this tooling server 'speaks'
  int get protocolVersion;
}

///Base for announcement extensions. Announcement extensions add additional functionalities to the discovery process without chaning the api
///User extensions should start with types above `EXTENSION_USER_START`, anything below is reserved
abstract class AnnouncementExtension {
  ///The type id of the extension
  final int type;

  ///The name of the extension, more for debugging purposes
  final String name;

  ///Constructor
  AnnouncementExtension(this.type, this.name);

  ///The length, in bytes of the announcement data part
  int length();

  ///The binary data part of the extension
  List<int> data();
}

///Base class for extensions wrapping string data as UTF-8
class StringExtension extends AnnouncementExtension {
  final List<int> _data;

  StringExtension(int type, String name, String data)
      : _data = utf8.encode(data),
        super(type, name);

  @override
  List<int> data() => _data;

  @override
  int length() => _data.length;
}

///Tag extension
class TagExtension extends StringExtension {
  TagExtension(String tag) : super(EXTENSION_TYPE_TAG, 'tag', tag);
}

///Icon extension
class IconExtension extends StringExtension {
  IconExtension(String tag) : super(EXTENSION_TYPE_ICON, 'icon', tag);
}

///Base class for any unknown user extensions
class UserExtension extends AnnouncementExtension {
  final List<int> _data;

  UserExtension(int type, this._data) : super(type, 'Extension $type');

  @override
  List<int> data() => _data;

  @override
  int length() => _data.length;
}

///Announcement manager
abstract class BaseServerAnnouncementManager {
  ///The package name of the application under test/development
  final String packageName;

  ///The server that is being announcement
  final ToolingServer server;

  ///The port on which to announce. This is a constant per tooling type, eg niddler uses 6394
  final int announcementPort;

  ///Constructor
  BaseServerAnnouncementManager(
      this.packageName, this.announcementPort, this.server);

  ///Adds the given extension to the server. Will not take effect until the server is (re)started
  void addExtension(AnnouncementExtension extension);

  ///Starts the announcement server
  Future<void> start();

  ///Stops the announcement server
  Future<void> stop();
}
