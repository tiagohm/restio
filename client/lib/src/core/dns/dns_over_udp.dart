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

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:raw/raw.dart';
import 'package:restio/restio.dart';
import 'package:restio/src/core/dns/dns.dart';
import 'package:restio/src/core/dns/dns_packet.dart';

class DnsOverUdp extends PacketBasedDns {
  final String remoteAddress;
  final int remotePort;
  final String localAddress;
  final int localPort;
  final Duration timeout;

  static final _portRandom = Random.secure();

  const DnsOverUdp({
    @required this.remoteAddress,
    this.remotePort = 53,
    this.localAddress,
    this.localPort,
    this.timeout,
  })  : assert(remoteAddress != null),
        assert(remotePort != null);

  const DnsOverUdp.ip(String ip) : this(remoteAddress: ip);

  const DnsOverUdp.google() : this(remoteAddress: '8.8.8.8');

  const DnsOverUdp.cloudflare() : this(remoteAddress: '1.1.1.1');

  const DnsOverUdp.openDns() : this(remoteAddress: '208.67.222.222');

  const DnsOverUdp.norton() : this(remoteAddress: '199.85.126.10');

  const DnsOverUdp.comodo() : this(remoteAddress: '8.26.56.26');

  @override
  Future<DnsPacket> lookupPacket(
    String name, {
    InternetAddressType type = InternetAddressType.any,
    Cancellable cancellable,
  }) async {
    if (cancellable != null && cancellable.isCancelled) {
      throw cancellable.exception;
    }

    final completer = Completer<DnsPacket>();

    final dnsPacket = DnsPacket();
    dnsPacket.questions = [DnsQuestion(host: name)];

    final socket = await _getSocket();

    // Send query.
    socket.send(
      dnsPacket.toImmutableBytes(),
      InternetAddress(remoteAddress),
      remotePort,
    );

    final timer = Timer(timeout ?? Dns.defaultTimeout, () {
      completer.completeError(TimedOutException("DNS query '$name' timeout"));
    });

    StreamSubscription subscription;

    cancellable?.add((message) async {
      timer.cancel();
      await subscription?.cancel();
      completer.complete(null);
    });

    subscription = socket.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          // Read UDP packet.
          final datagram = socket.receive();

          // No datagram available.
          if (datagram == null) {
            return;
          }

          timer.cancel();
          completer.complete(_receiveUdpPacket(datagram));
        }
      },
      onError: completer.completeError,
      cancelOnError: true,
    );

    // Return future.
    return completer.future;
  }

  Future<RawDatagramSocket> _getSocket() {
    final address = localAddress == null
        ? InternetAddress.anyIPv4
        : InternetAddress(localAddress);
    return _bindSocket(address, localPort);
  }

  DnsPacket _receiveUdpPacket(Datagram datagram) {
    // Read DNS packet.
    final dnsPacket = DnsPacket();
    dnsPacket.decodeSelf(RawReader.withBytes(datagram.data));
    return dnsPacket;
  }

  static Future<RawDatagramSocket> _bindSocket(
    InternetAddress address,
    int port,
  ) async {
    return await RawDatagramSocket.bind(
      address,
      port ?? _randomPort(),
    );
  }

  static int _randomPort() {
    const min = 10000;
    return min + _portRandom.nextInt((1 << 16) - min);
  }
}
