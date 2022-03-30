// Copyright (c) 2020, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:convert';

///Extension type for the icon extension
const int extensionTypeIcon = 1;

///Extension type for the tag extension
const int extensionTypeTag = 2;

///Minimal extension number for user-defined extensions
const int extensionUserStart = 256;

///Encapsulates the tooling server
abstract class ToolingServer {
  ///The port the tooling server is running on
  int get port;

  ///The protocol version this tooling server 'speaks'
  int get protocolVersion;
}

///Base for announcement extensions.
///Announcement extensions add additional functionalities to the
///discovery process without changing the api
///
///User extensions should start with types above
///[extensionUserStart], anything below is reserved
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
  TagExtension(String tag) : super(extensionTypeTag, 'tag', tag);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagExtension &&
          runtimeType == other.runtimeType &&
          _dataEqual(data(), other.data());

  @override
  int get hashCode => 0;
}

///Icon extension
class IconExtension extends StringExtension {
  IconExtension(String icon) : super(extensionTypeIcon, 'icon', icon);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IconExtension &&
          runtimeType == other.runtimeType &&
          _dataEqual(data(), other.data());

  @override
  int get hashCode => 0;
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

  ///The port on which to announce.
  ///This is a constant per tooling type, eg niddler uses 6394
  final int announcementPort;

  ///Constructor
  BaseServerAnnouncementManager(
      this.packageName, this.announcementPort, this.server);

  ///Adds the given extension to the server.
  ///Will not take effect until the server is (re)started
  void addExtension(AnnouncementExtension extension);

  ///Removes the given extension from the server.
  ///Will not take effect until the server is (re)started
  ///
  ///The == operator is used to find the extension to remove
  void removeExtension(AnnouncementExtension extension);

  ///Starts the announcement server
  Future<void> start();

  ///Stops the announcement server
  Future<void> stop();
}

bool _dataEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; ++i) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

///Minimal extension number for user-defined extensions
@Deprecated('Deprecated, use extensionUserStart instead')
// ignore: constant_identifier_names
const int EXTENSION_USER_START = extensionUserStart;

///Extension type for the tag extension
@Deprecated('Deprecated, use extensionTypeTag instead')
// ignore: constant_identifier_names
const int EXTENSION_TYPE_TAG = extensionTypeTag;

///Extension type for the icon extension
@Deprecated('Deprecated, use extensionTypeIcon instead')
// ignore: constant_identifier_names
const int EXTENSION_TYPE_ICON = extensionTypeIcon;
