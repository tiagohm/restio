import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio/src/dns/dns.dart';
import 'package:restio/src/dns/dns_over_https.dart';
import 'package:restio/src/dns/dns_over_udp.dart';
import 'package:test/test.dart';

void main() {
  final client = Restio(
    interceptors: [
      LogInterceptor(),
    ],
  );

  group('System Dns', () {
    test('Lookup packet', () async {
      final dns = Dns.system;
      final packet = await dns.lookupPacket('google.com');
      expect(packet, isNotNull);
      expect(packet.isResponse, isTrue);
      expect(packet.answers, hasLength(greaterThan(0)));
      expect(packet.answers[0].name, 'google.com');
      expect(packet.answers[0].data, hasLength(greaterThan(1)));
    });

    test('Lookup', () async {
      final dns = Dns.system;
      final response = await dns.lookup('tiagohm.xyz');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });
  });

  group('Dns over Udp', () {
    test('Lookup packet', () async {
      final dns = DnsOverUdp(
        remoteAddress: InternetAddress('8.8.8.8'),
      );
      final packet = await dns.lookupPacket('google.com');
      expect(packet, isNotNull);
      expect(packet.isResponse, isTrue);
      expect(packet.answers, hasLength(greaterThan(0)));
      expect(packet.answers[0].name, 'google.com');
      expect(packet.answers[0].data, hasLength(greaterThan(1)));
    });

    test('Google Lookup', () async {
      final dns = DnsOverUdp.google();
      final response = await dns.lookup('tiagohm.xyz');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('Cloudflare Lookup', () async {
      final dns = DnsOverUdp.cloudflare();
      final response = await dns.lookup('tiagohm.xyz');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('OpenDNS Lookup', () async {
      final dns = DnsOverUdp.openDns();
      final response = await dns.lookup('tiagohm.xyz');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('Norton Lookup', () async {
      final dns = DnsOverUdp.norton();
      final response = await dns.lookup('tiagohm.xyz');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('Comodo Lookup', () async {
      final dns = DnsOverUdp.comodo();
      final response = await dns.lookup('tiagohm.xyz');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });
  });

  group('Dns over Https', () {
    test('Lookup packet', () async {
      final dns = DnsOverHttps.google(client);
      final packet = await dns.lookupPacket('google.com');
      expect(packet, isNotNull);
      expect(packet.isResponse, isTrue);
      expect(packet.answers, hasLength(greaterThan(0)));
      expect(packet.answers[0].name, 'google.com');
      expect(packet.answers[0].data, hasLength(greaterThan(1)));
    });

    test('Lookup', () async {
      final dns = DnsOverHttps.google(client);
      final response = await dns.lookup('tiagohm.xyz');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });
  });
}
