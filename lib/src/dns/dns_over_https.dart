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
import 'package:restio/restio.dart';
import 'package:restio/src/dns/dns.dart';
import 'package:restio/src/dns/dns_over_udp.dart';
import 'package:restio/src/dns/dns_packet.dart';

class DnsOverHttps extends PacketBasedDns {
  final String url;
  final String host;
  final Dns dns;
  final bool maximalPrivacy;
  final Duration timeout;
  final Queries queries;
  final Restio client;

  DnsOverHttps(
    this.client,
    this.url, {
    this.timeout,
    this.maximalPrivacy = false,
    this.dns,
    this.queries,
  }) : host = Uri.parse(url).host;

  DnsOverHttps.google(
    Restio client, {
    Duration timeout,
    bool maximalPrivacy = false,
    Dns dns,
  }) : this(
          client,
          'https://dns.google.com/resolve',
          timeout: timeout,
          maximalPrivacy: maximalPrivacy,
          dns: dns,
        );

  DnsOverHttps.cloudflare(
    Restio client, {
    Duration timeout,
    bool maximalPrivacy = false,
    Dns dns,
  }) : this(
          client,
          'https://cloudflare-dns.com/dns-query',
          timeout: timeout,
          maximalPrivacy: maximalPrivacy,
          dns: dns,
          queries: Queries.of({
            'ct': 'application/dns-json',
          }),
        );

  DnsOverHttps.mozilla(
    Restio client, {
    Duration timeout,
    bool maximalPrivacy = false,
    Dns dns,
  }) : this(
          client,
          'https://mozilla.cloudflare-dns.com/dns-query',
          timeout: timeout,
          maximalPrivacy: maximalPrivacy,
          dns: dns,
          queries: Queries.of({
            'ct': 'application/dns-json',
          }),
        );

  Future<Response> execute(String url) async {
    final request = Request.get(url);
    final call = client.newCall(request);
    return await call.execute();
  }

  @override
  Future<DnsPacket> lookupPacket(
    String host, {
    InternetAddressType type = InternetAddressType.any,
  }) async {
    //  Are we are resolving host of the DNS-over-HTTPS service?
    if (host == this.host) {
      final dns = this.dns ?? DnsOverUdp.google();
      return dns.lookupPacket(host, type: type);
    }

    // Build URL.
    final s = this.url.contains('?') ? '&' : '?';
    var url = '${this.url}${s}name=${Uri.encodeQueryComponent(host)}';

    // Add: IPv4 or IPv6?
    if (type == null) {
      throw ArgumentError.notNull('type');
    } else if (type == InternetAddressType.any ||
        type == InternetAddressType.IPv4) {
      url += '&type=A';
    } else {
      url += '&type=AAAA';
    }

    // Hide my IP?
    if (maximalPrivacy) {
      url += '&edns_client_subnet=0.0.0.0/0';
    }

    // Additional queries.
    queries?.forEach((key, name) => url += '&$key=$name');

    final response = await execute(url);

    if (response.code != 200) {
      throw StateError(
        'HTTP response was ${response.code} (${response.message}). URL was: $url',
      );
    }

    // Decode JSON.
    final data = await response.body.json();
    // Decode DNS packet from JSON.
    return _decodeDnsPacket(data);
  }

  DnsPacket _decodeDnsPacket(Object json) {
    if (json is Map) {
      final result = DnsPacket.withResponse();
      for (var key in json.keys) {
        final value = json[key];

        switch (key) {
          case 'Status':
            result.responseCode = (value as num).toInt();
            break;
          case 'AA':
            result.isAuthorativeAnswer = value as bool;
            break;
          case 'ID':
            result.id = (value as num).toInt();
            break;
          case 'QR':
            result.isResponse = value as bool;
            break;
          case 'RA':
            result.isRecursionAvailable = value as bool;
            break;
          case 'RD':
            result.isRecursionDesired = value as bool;
            break;
          case 'TC':
            result.isTruncated = value as bool;
            break;
          case 'Question':
            final questions = <DnsQuestion>[];
            result.questions = questions;
            if (value is List) {
              for (var item in value) {
                questions.add(_decodeDnsQuestion(item));
              }
            }
            break;
          case 'Answer':
            final answers = <DnsResourceRecord>[];
            result.answers = answers;
            if (value is List) {
              for (var item in value) {
                answers.add(_decodeDnsResourceRecord(item));
              }
            }
            break;
          case 'Additional':
            final additionalRecords = <DnsResourceRecord>[];
            result.additionalRecords = additionalRecords;
            if (value is List) {
              for (var item in value) {
                additionalRecords.add(_decodeDnsResourceRecord(item));
              }
            }
            break;
        }
      }

      return result;
    } else {
      throw ArgumentError.value(json);
    }
  }

  DnsQuestion _decodeDnsQuestion(Object json) {
    if (json is Map) {
      final result = DnsQuestion();

      for (var key in json.keys) {
        final value = json[key];
        switch (key) {
          case 'name':
            result.name = _trimDotSuffix(value as String);
            break;
        }
      }
      return result;
    } else {
      throw ArgumentError.value(json);
    }
  }

  DnsResourceRecord _decodeDnsResourceRecord(Object json) {
    if (json is Map) {
      final result = DnsResourceRecord();

      for (var key in json.keys) {
        final value = json[key];
        switch (key) {
          case 'name':
            result.name = _trimDotSuffix(value as String);
            break;
          case 'type':
            result.type = (value as num).toInt();
            break;
          case 'TTL':
            result.ttl = (value as num).toInt();
            break;
          case 'data':
            result.data = IpAddress.parse(value).toImmutableBytes();
            break;
        }
      }
      return result;
    } else {
      throw ArgumentError.value(json);
    }
  }

  static String _trimDotSuffix(String s) {
    if (s.endsWith('.')) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }
}
