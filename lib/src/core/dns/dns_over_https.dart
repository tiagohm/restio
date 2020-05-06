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
import 'package:restio/restio.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/dns/dns.dart';
import 'package:restio/src/core/dns/dns_over_udp.dart';
import 'package:restio/src/core/dns/dns_packet.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/request/query/queries.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_options.dart';
import 'package:restio/src/core/request/request_uri.dart';
import 'package:restio/src/core/response/response.dart';

class DnsOverHttps extends PacketBasedDns {
  final RequestUri uri;
  final Dns dns;
  final bool maximalPrivacy;
  final Duration timeout;
  final Queries queries;
  final Restio client;

  const DnsOverHttps(
    this.uri, {
    Restio client,
    this.timeout,
    this.maximalPrivacy = false,
    this.dns,
    this.queries,
  }) : client = client ?? const Restio();

  const DnsOverHttps.google({
    Restio client,
    Duration timeout,
    bool maximalPrivacy = false,
    Dns dns,
  }) : this(
          // RequestUri.parse('https://dns.google.com/resolve'),
          const RequestUri(
              scheme: 'https', host: 'dns.google.com', paths: ['resolve']),
          client: client,
          timeout: timeout,
          maximalPrivacy: maximalPrivacy,
          dns: dns,
        );

  const DnsOverHttps.cloudflare({
    Restio client,
    Duration timeout,
    bool maximalPrivacy = false,
    Dns dns,
  }) : this(
          // RequestUri.parse('https://cloudflare-dns.com/dns-query'),
          const RequestUri(
              scheme: 'https',
              host: 'cloudflare-dns.com',
              paths: ['dns-query']),
          client: client,
          timeout: timeout,
          maximalPrivacy: maximalPrivacy,
          dns: dns,
          queries: const Queries([Query('ct', 'application/dns-json')]),
        );

  const DnsOverHttps.mozilla({
    Restio client,
    Duration timeout,
    bool maximalPrivacy = false,
    Dns dns,
  }) : this(
          // RequestUri.parse('https://mozilla.cloudflare-dns.com/dns-query'),
          const RequestUri(
              scheme: 'https',
              host: 'mozilla.cloudflare-dns.com',
              paths: ['dns-query']),
          client: client,
          timeout: timeout,
          maximalPrivacy: maximalPrivacy,
          dns: dns,
          queries: const Queries([Query('ct', 'application/dns-json')]),
        );

  Future<Response> _execute(RequestUri uri) async {
    final options = RequestOptions(connectTimeout: timeout);
    final request = Request(uri: uri, options: options);
    final call = client.newCall(request);
    return call.execute();
  }

  @override
  Future<DnsPacket> lookupPacket(
    String name, {
    InternetAddressType type = InternetAddressType.any,
  }) async {
    //  Are we are resolving host of the DNS-over-HTTPS service?
    if (name == uri.host) {
      final dns = this.dns ?? DnsOverUdp.google();
      return dns.lookupPacket(name, type: type);
    }

    // Build URL.
    final queries = QueriesBuilder();
    queries.add('name', Uri.encodeQueryComponent(name));

    // Add: IPv4 or IPv6?
    if (type == null) {
      throw ArgumentError.notNull('type');
    } else if (type == InternetAddressType.any ||
        type == InternetAddressType.IPv4) {
      queries.add('type', 'A');
    } else {
      queries.add('type', 'AAAA');
    }

    // Hide my IP?
    if (maximalPrivacy) {
      queries.add('edns_client_subnet', '0.0.0.0/0');
    }

    // Additional queries.
    uri.queries.forEach((item) => queries.add(item.name, item.value));
    this.queries?.forEach((item) => queries.add(item.name, item.value));

    final response = await _execute(uri.copyWith(queries: queries.build()));

    if (response.code != 200) {
      throw RestioException(
        'Bad DNS response: ${response.code} (${response.message})',
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
      for (final key in json.keys) {
        final value = json[key];

        switch (key) {
          case 'Status':
            result.responseCode = value.toInt();
            break;
          case 'AA':
            result.isAuthorativeAnswer = value;
            break;
          case 'ID':
            result.id = value.toInt();
            break;
          case 'QR':
            result.isResponse = value;
            break;
          case 'RA':
            result.isRecursionAvailable = value;
            break;
          case 'RD':
            result.isRecursionDesired = value;
            break;
          case 'TC':
            result.isTruncated = value;
            break;
          case 'Question':
            final questions = <DnsQuestion>[];
            result.questions = questions;

            if (value is List) {
              for (final item in value) {
                questions.add(_decodeDnsQuestion(item));
              }
            }
            break;
          case 'Answer':
            final answers = <DnsResourceRecord>[];
            result.answers = answers;

            if (value is List) {
              for (final item in value) {
                answers.add(_decodeDnsResourceRecord(item));
              }
            }
            break;
          case 'Additional':
            final additionalRecords = <DnsResourceRecord>[];
            result.additionalRecords = additionalRecords;

            if (value is List) {
              for (final item in value) {
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

      for (final key in json.keys) {
        final value = json[key];
        switch (key) {
          case 'name':
            result.name = _trimDotSuffix(value);
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

      for (final key in json.keys) {
        final value = json[key];
        switch (key) {
          case 'name':
            result.name = _trimDotSuffix(value);
            break;
          case 'type':
            result.type = value.toInt();
            break;
          case 'TTL':
            result.ttl = value.toInt();
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
