// Copyright 2019 Gohilla.com team.
// Modifications Copyright 2019 Tiago Melo.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:ip/foundation.dart';
import 'package:meta/meta.dart';
import 'package:raw/raw.dart';

void _writeDnsName(
  RawWriter writer,
  List<String> parts,
  int startIndex,
  Map<String, int> offsets,
) {
  // Store pointer in the map.
  if (offsets != null) {
    final key = parts.join('.');
    final existingPointer = offsets[key];

    if (existingPointer != null) {
      writer.writeUint16(0xC000 | existingPointer);
      return;
    }

    offsets[key] = writer.length - startIndex;
  }

  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];

    // Find pointer.
    if (i >= 1 && offsets != null) {
      final offset = offsets[parts.skip(i).join('.')];

      if (offset != null) {
        // Write pointer.
        writer.writeUint16(0xc000 | offset);
        return;
      }
    }

    // Write length and string bytes;
    writer.writeUint8(part.length);
    writer.writeUtf8Simple(part);
  }

  // Zero-length part means end of name parts;
  writer.writeUint8(0);
}

List<String> _readDnsName(
  RawReader reader,
  int startIndex,
) {
  final name = <String>[];

  while (reader.availableLengthInBytes > 0) {
    // Read length.
    final length = reader.readUint8();

    if (length == 0) {
      // End of name.
      break;
    } else if (length < 64) {
      // A label.
      final value = reader.readUtf8(length);
      name.add(value);
    } else {
      // This is a pointer.
      // Validate we received start index,
      // so we can actually handle pointers.
      if (startIndex == null) {
        throw ArgumentError.notNull('startIndex');
      }

      // Calculate and validate index in the data.
      final byte1 = reader.readUint8();
      final pointedIndex = startIndex + (((0x3F & length) << 8) | byte1);

      if (pointedIndex > reader.bufferAsByteData.lengthInBytes ||
          reader.bufferAsByteData.getUint8(pointedIndex) >= 64) {
        final index = reader.index - 2;
        throw StateError(
          'invalid pointer from index 0x${index.toRadixString(16)} (decimal: $index) to index 0x${pointedIndex.toRadixString(16)} ($pointedIndex)',
        );
      }

      final oldIndex = reader.index;
      reader.index = pointedIndex;

      // Read name.
      final result = _readDnsName(reader, startIndex);

      reader.index = oldIndex;

      // Concatenate.
      name.addAll(result);

      // End.
      break;
    }
  }

  return name;
}

class DnsResourceRecord extends SelfCodec {
  static const int responseCodeNoError = 0;
  static const int responseCodeFormatError = 1;
  static const int responseCodeServerFailure = 2;
  static const int responseCodeNonExistentDomain = 3;
  static const int responseCodeNotImplemented = 4;
  static const int responseCodeQueryRefused = 5;
  static const int responseCodeNotInZone = 10;

  static String stringFromResponseCode(int code) {
    switch (code) {
      case responseCodeNoError:
        return 'No error';
      case responseCodeFormatError:
        return 'Format error';
      case responseCodeServerFailure:
        return 'Server failure';
      case responseCodeNonExistentDomain:
        return 'Non-existent domain';
      case responseCodeNotImplemented:
        return 'Not implemented';
      case responseCodeQueryRefused:
        return 'Query refused';
      case responseCodeNotInZone:
        return 'Not in the zone';
      default:
        return 'Unknown';
    }
  }

  /// A host address ('A' record).
  static const int typeIp4 = 1;

  /// Authoritative name server ('NS' record).
  static const int typeNameServer = 2;

  /// The canonical name for an alias ('CNAME' record).
  static const int typeCanonicalName = 5;

  /// Domain name pointer ('PTR' record).
  static const int typeDomainNamePointer = 12;

  /// Mail server ('MX' record) record.
  static const int typeMailServer = 15;

  /// Text record ('TXT' record).
  static const int typeText = 15;

  /// IPv6 host address record.
  static const int typeIp6 = 28;

  /// Server discovery ('SRV' record).
  static const int typeServerDiscovery = 33;

  static String stringFromType(int value) {
    return DnsQuestion.stringFromType(value);
  }

  static const int classInternetAddress = 1;

  static String stringFromClass(int value) {
    return DnsQuestion.stringFromClass(value);
  }

  /// List of name parts.
  ///
  /// It can be an immutable value.
  List<String> nameParts = const <String>[];

  set name(String value) {
    nameParts = value.split('.');
  }

  String get name => nameParts.join('.');

  /// 16-bit type
  int type = typeIp4;

  /// 16-it class
  int classy = classInternetAddress;

  /// 32-bit TTL
  int ttl = 0;

  /// Data
  List<int> data = const <int>[];

  DnsResourceRecord();

  DnsResourceRecord.withAnswer({
    @required String name,
    @required this.type,
    @required this.data,
  }) {
    this.name = name;
    ttl = 600;
  }

  @override
  void encodeSelf(
    RawWriter writer, {
    int startIndex,
    Map<String, int> pointers,
  }) {
    // Write name.
    _writeDnsName(writer, nameParts, startIndex, pointers);
    // 2-byte type.
    writer.writeUint16(type);
    // 2-byte class.
    writer.writeUint16(classy);
    // 4-byte time-to-live.
    writer.writeUint32(ttl);
    // 2-byte length of answer data.
    writer.writeUint16(data.length);
    // Answer data.
    writer.writeBytes(data);
  }

  @override
  void decodeSelf(
    RawReader reader, {
    int startIndex,
  }) {
    startIndex ??= 0;
    // Read name.
    nameParts = _readDnsName(reader, startIndex);
    // 2-byte type.
    type = reader.readUint16();
    // 2-byte class.
    classy = reader.readUint16();
    // 4-byte time-to-live.
    ttl = reader.readUint32();
    // 2-byte length.
    final dataLength = reader.readUint16();
    // N-byte data.
    data = reader.readUint8ListViewOrCopy(dataLength);
  }

  @override
  int encodeSelfCapacity() {
    var n = 64;

    for (final part in nameParts) {
      n += 1 + part.length;
    }

    return n;
  }
}

class DnsPacket extends Packet {
  static const int opQuery = 0;
  static const int opInverseQuery = 1;
  static const int opStatus = 2;
  static const int opNotify = 3;
  static const int opUpdate = 4;

  int _v0 = 0;

  List<DnsQuestion> questions = const <DnsQuestion>[];
  List<DnsResourceRecord> answers = const <DnsResourceRecord>[];
  List<DnsResourceRecord> authorities = const <DnsResourceRecord>[];
  List<DnsResourceRecord> additionalRecords = const <DnsResourceRecord>[];

  DnsPacket() {
    op = opQuery;
    isRecursionDesired = true;
  }

  DnsPacket.withResponse({DnsPacket request}) {
    op = opQuery;
    isResponse = true;
    if (request != null) {
      questions = <DnsQuestion>[];
    }
  }

  int get id => extractUint32Bits(_v0, 16, 0xFFFF);

  set id(int value) {
    _v0 = transformUint32Bits(_v0, 16, 0xFFFF, value);
  }

  bool get isAuthorativeAnswer => extractUint32Bool(_v0, 10);

  set isAuthorativeAnswer(bool value) {
    _v0 = transformUint32Bool(_v0, 10, value);
  }

  bool get isRecursionAvailable => extractUint32Bool(_v0, 7);

  set isRecursionAvailable(bool value) {
    _v0 = transformUint32Bool(_v0, 7, value);
  }

  bool get isRecursionDesired => extractUint32Bool(_v0, 8);

  set isRecursionDesired(bool value) {
    _v0 = transformUint32Bool(_v0, 8, value);
  }

  bool get isResponse => extractUint32Bool(_v0, 15);

  set isResponse(bool value) {
    _v0 = transformUint32Bool(_v0, 15, value);
  }

  bool get isTruncated => extractUint32Bool(_v0, 9);

  set isTruncated(bool value) {
    _v0 = transformUint32Bool(_v0, 9, value);
  }

  int get op => extractUint32Bits(_v0, 11, 0xF);

  set op(int value) {
    _v0 = transformUint32Bits(_v0, 11, 0xF, value);
  }

  @override
  Protocol get protocol => const Protocol('DNS');

  int get reservedBits => 0x3 & (_v0 >> 4);

  int get responseCode => extractUint32Bits(_v0, 0, 0xF);

  set responseCode(int value) {
    _v0 = transformUint32Bits(_v0, 0, 0xF, value);
  }

  @override
  void encodeSelf(RawWriter writer) {
    final startIndex = writer.length;
    // 4-byte span at index 0.
    writer.writeUint32(_v0);
    // 2-byte span at index 4.
    writer.writeUint16(questions.length);
    // 2-byte span at index 6.
    writer.writeUint16(answers.length);
    // 2-byte span at index 8.
    writer.writeUint16(authorities.length);
    // 2-byte span at index 10.
    writer.writeUint16(additionalRecords.length);
    // Name -> pointer.
    final pointers = <String, int>{};

    for (final item in questions) {
      item.encodeSelf(writer, startIndex: startIndex, pointers: pointers);
    }

    for (final item in answers) {
      item.encodeSelf(writer, startIndex: startIndex, pointers: pointers);
    }

    for (final item in authorities) {
      item.encodeSelf(writer, startIndex: startIndex, pointers: pointers);
    }

    for (final item in additionalRecords) {
      item.encodeSelf(writer, startIndex: startIndex, pointers: pointers);
    }
  }

  @override
  void decodeSelf(RawReader reader) {
    // Clear existing values.
    questions = <DnsQuestion>[];
    answers = <DnsResourceRecord>[];
    authorities = <DnsResourceRecord>[];
    additionalRecords = <DnsResourceRecord>[];
    // Fixed header.
    final startIndex = reader.index;
    // 4-byte span at index 0.
    _v0 = reader.readUint32();
    // 2-byte span at index 4.
    var questionsLength = reader.readUint16();
    // 2-byte span at index 6.
    var answersLength = reader.readUint16();
    // 2-byte span at index 8.
    var nameServerResourcesLength = reader.readUint16();
    // 2-byte span at index 10.
    var additionalResourcesLength = reader.readUint16();

    for (; questionsLength > 0; questionsLength--) {
      final item = DnsQuestion();
      item.decodeSelf(reader, startIndex: startIndex);
      questions.add(item);
    }

    for (; answersLength > 0; answersLength--) {
      final item = DnsResourceRecord();
      item.decodeSelf(reader, startIndex: startIndex);
      answers.add(item);
    }

    for (; nameServerResourcesLength > 0; nameServerResourcesLength--) {
      final item = DnsResourceRecord();
      item.decodeSelf(reader, startIndex: startIndex);
      authorities.add(item);
    }

    for (; additionalResourcesLength > 0; additionalResourcesLength--) {
      final item = DnsResourceRecord();
      item.decodeSelf(reader, startIndex: startIndex);
      additionalRecords.add(item);
    }
  }

  @override
  int encodeSelfCapacity() {
    var n = 64;

    for (final item in questions) {
      n += item.encodeSelfCapacity();
    }
    for (final item in answers) {
      n += item.encodeSelfCapacity();
    }
    for (final item in authorities) {
      n += item.encodeSelfCapacity();
    }
    for (final item in additionalRecords) {
      n += item.encodeSelfCapacity();
    }

    return n;
  }
}

class DnsQuestion extends SelfCodec {
  static const int typeIp4 = 1;
  static const int typeNameServer = 2;
  static const int typeCanonicalName = 5;
  static const int typeMailServer = 15;
  static const int typeTxt = 16;
  static const int typeIp6 = 28;

  static String stringFromType(int type) {
    switch (type) {
      case typeIp4:
        return 'IPv4';
      case typeNameServer:
        return 'name server';
      case typeCanonicalName:
        return 'Canonical name';
      case typeIp6:
        return 'IPv6';
      case typeMailServer:
        return 'MX';
      case typeTxt:
        return 'TXT';
      default:
        return 'type $type';
    }
  }

  static const int classInternetAddress = 1;

  static String stringFromClass(int type) {
    switch (type) {
      case classInternetAddress:
        return 'Internet address';
      default:
        return 'class $type';
    }
  }

  /// List of name parts.
  List<String> nameParts = <String>[];

  set name(String value) {
    nameParts = value.split('.');
  }

  String get name => nameParts.join('.');

  /// 16-bit type.
  int type = typeIp4;

  /// 16-bit class.
  int classy = classInternetAddress;

  DnsQuestion({String host}) {
    if (host != null) {
      nameParts = host.split('.');
    }
  }

  @override
  void encodeSelf(
    RawWriter writer, {
    int startIndex,
    Map<String, int> pointers,
  }) {
    // Write name.
    _writeDnsName(writer, nameParts, startIndex, pointers);
    // 2-byte type.
    writer.writeUint16(type);
    // 2-byte class.
    writer.writeUint16(classy);
  }

  @override
  void decodeSelf(
    RawReader reader, {
    int startIndex,
  }) {
    // Name.
    nameParts = _readDnsName(reader, startIndex);
    // 2-byte question type.
    type = reader.readUint16();
    // 2-byte question class.
    classy = reader.readUint16();
  }

  @override
  int encodeSelfCapacity() {
    var n = 16;

    for (final part in nameParts) {
      n += 1 + part.length;
    }

    return n;
  }
}
