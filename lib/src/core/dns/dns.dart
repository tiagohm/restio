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

import 'dart:io';

import 'package:ip/ip.dart';
import 'package:restio/src/core/dns/dns_packet.dart';

abstract class Dns {
  static const Duration defaultTimeout = Duration(seconds: 5);
  static const Dns system = _SystemDns();

  const Dns();

  Future<List<IpAddress>> lookup(
    String name, {
    InternetAddressType type = InternetAddressType.any,
  });

  Future<DnsPacket> lookupPacket(
    String name, {
    InternetAddressType type = InternetAddressType.any,
  }) async {
    final list = await lookup(name);

    final result = DnsPacket.withResponse();
    result.answers = [
      for (final ipAddress in list)
        DnsResourceRecord.withAnswer(
          name: name,
          type: ipAddress is Ip4Address
              ? DnsResourceRecord.typeIp4
              : DnsResourceRecord.typeIp6,
          data: ipAddress.toImmutableBytes(),
        ),
    ];

    return result;
  }

  Future<DnsPacket> handlePacket(
    DnsPacket packet, {
    Duration timeout,
  }) async {
    if (packet.questions.isEmpty) {
      return null;
    }

    if (packet.questions.length == 1) {
      final question = packet.questions.single;

      switch (question.type) {
        case DnsQuestion.typeIp4:
          return lookupPacket(
            packet.questions.single.name,
            type: InternetAddressType.IPv4,
          );
        case DnsQuestion.typeIp6:
          return lookupPacket(
            packet.questions.single.name,
            type: InternetAddressType.IPv4,
          );
        default:
          return null;
      }
    }

    final result = DnsPacket.withResponse();
    result.id = packet.id;
    result.answers = <DnsResourceRecord>[];

    final futures = <Future>[];
    for (final question in packet.questions) {
      var type = InternetAddressType.any;

      switch (question.type) {
        case DnsQuestion.typeIp4:
          type = InternetAddressType.IPv4;
          break;
        case DnsQuestion.typeIp6:
          type = InternetAddressType.IPv6;
          break;
      }

      futures.add(lookupPacket(question.name, type: type).then((packet) {
        result.answers.addAll(packet.answers);
      }));
    }

    await Future.wait(futures).timeout(timeout ?? defaultTimeout);

    return result;
  }
}

class _SystemDns extends Dns {
  const _SystemDns();

  @override
  Future<List<IpAddress>> lookup(
    String host, {
    InternetAddressType type = InternetAddressType.any,
  }) async {
    final addresses = await InternetAddress.lookup(host, type: type);

    return [
      for (final item in addresses) IpAddress.fromBytes(item.rawAddress),
    ];
  }
}

abstract class PacketBasedDns extends Dns {
  @override
  Future<DnsPacket> lookupPacket(
    String name, {
    InternetAddressType type = InternetAddressType.any,
  });

  @override
  Future<List<IpAddress>> lookup(
    String name, {
    InternetAddressType type = InternetAddressType.any,
  }) async {
    final packet = await lookupPacket(name, type: type);
    final result = <IpAddress>[];

    for (final answer in packet.answers) {
      try {
        if (name.endsWith(answer.name)) {
          final ipAddress = IpAddress.fromBytes(answer.data);
          result.add(ipAddress);
        }
      } catch (e) {
        print(e);
      }
    }

    return result;
  }
}
