// Copyright 2019 Gohilla.com team.
// Modifications Copyright 2019-2020 Tiago Melo.
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
import 'package:restio/src/core/call/cancellable.dart';
import 'package:restio/src/core/dns/dns_packet.dart';

abstract class Dns {
  const Dns();

  static const Duration defaultTimeout = Duration(seconds: 15);

  static const Dns system = _SystemDns();

  Future<List<InternetAddress>> lookup(
    String name, {
    InternetAddressType type = InternetAddressType.any,
    Cancellable cancellable,
  });

  Future<DnsPacket> lookupPacket(
    String name, {
    InternetAddressType type = InternetAddressType.any,
    Cancellable cancellable,
  });

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
  Future<List<InternetAddress>> lookup(
    String host, {
    InternetAddressType type = InternetAddressType.any,
    Cancellable cancellable,
  }) async {
    if (cancellable != null && cancellable.isCancelled) {
      throw cancellable.exception;
    }

    final addresses = await InternetAddress.lookup(host, type: type);

    return addresses;
  }

  @override
  Future<DnsPacket> lookupPacket(
    String name, {
    InternetAddressType type = InternetAddressType.any,
    Cancellable cancellable,
  }) async {
    if (cancellable != null && cancellable.isCancelled) {
      throw cancellable.exception;
    }

    final addresses = await lookup(
      name,
      type: type,
      cancellable: cancellable,
    );

    final result = DnsPacket.withResponse();
    result.answers = [
      for (final ipAddress in addresses)
        DnsResourceRecord.withAnswer(
          name: name,
          type: ipAddress is Ip4Address
              ? DnsResourceRecord.typeIp4
              : DnsResourceRecord.typeIp6,
          data: ipAddress.rawAddress,
        ),
    ];

    return result;
  }
}

abstract class PacketBasedDns extends Dns {
  const PacketBasedDns();

  @override
  Future<DnsPacket> lookupPacket(
    String name, {
    InternetAddressType type = InternetAddressType.any,
    Cancellable cancellable,
  });

  @override
  Future<List<InternetAddress>> lookup(
    String name, {
    InternetAddressType type = InternetAddressType.any,
    Cancellable cancellable,
  }) async {
    if (cancellable != null && cancellable.isCancelled) {
      throw cancellable.exception;
    }

    final result = <InternetAddress>[];

    final packet = await lookupPacket(
      name,
      type: type,
      cancellable: cancellable,
    );

    if (packet != null) {
      result.addAll(packet.answers
          .where((answer) =>
              answer.type == DnsQuestion.typeIp4 ||
              answer.type == DnsQuestion.typeIp6)
          .map((answer) => InternetAddress.fromRawAddress(answer.data)));
    }

    return result;
  }
}
