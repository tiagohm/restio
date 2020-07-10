import 'package:restio/restio.dart';
import 'package:test/test.dart';

void main() {
  group('System Dns', () {
    test('Lookup packet', () async {
      const dns = Dns.system;
      final packet = await dns.lookupPacket('google.com');
      expect(packet, isNotNull);
      expect(packet.isResponse, isTrue);
      expect(packet.answers, hasLength(greaterThan(0)));
      expect(packet.answers[0].name, 'google.com');
      expect(packet.answers[0].data, hasLength(greaterThan(1)));
    });

    test('Lookup', () async {
      const dns = Dns.system;
      final response = await dns.lookup('tiagohm.dev');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });
  });

  group('Dns over Udp', () {
    test('Lookup packet', () async {
      const dns = DnsOverUdp(remoteAddress: '8.8.8.8');
      final packet = await dns.lookupPacket('google.com');
      expect(packet, isNotNull);
      expect(packet.isResponse, isTrue);
      expect(packet.answers, hasLength(greaterThan(0)));
      expect(packet.answers[0].name, 'google.com');
      expect(packet.answers[0].data, hasLength(greaterThan(1)));
    });

    test('Google Lookup', () async {
      const dns = DnsOverUdp.google();
      final response = await dns.lookup('tiagohm.dev');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('Cloudflare Lookup', () async {
      const dns = DnsOverUdp.cloudflare();
      final response = await dns.lookup('tiagohm.dev');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('OpenDNS Lookup', () async {
      const dns = DnsOverUdp.openDns();
      final response = await dns.lookup('tiagohm.dev');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('Norton Lookup', () async {
      const dns = DnsOverUdp.norton();
      final response = await dns.lookup('tiagohm.dev');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('Comodo Lookup', () async {
      const dns = DnsOverUdp.comodo();
      final response = await dns.lookup('tiagohm.dev');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });
  });

  group('Dns over Https', () {
    test('Lookup packet', () async {
      final dns = DnsOverHttps.google();
      final packet = await dns.lookupPacket('google.com');
      expect(packet, isNotNull);
      expect(packet.isResponse, isTrue);
      expect(packet.answers, hasLength(greaterThan(0)));
      expect(packet.answers[0].name, 'google.com');
      expect(packet.answers[0].data, hasLength(greaterThan(1)));
    });

    test('Google Lookup', () async {
      final dns = DnsOverHttps.google();
      final response = await dns.lookup('tiagohm.dev');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('Cloudflare Lookup', () async {
      final dns = DnsOverHttps.cloudflare();
      final response = await dns.lookup('tiagohm.dev');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });

    test('Mozilla Lookup', () async {
      final dns = DnsOverHttps.mozilla();
      final response = await dns.lookup('tiagohm.dev');
      expect(response, hasLength(greaterThan(0)));
      expect(response[0].toString(), '104.248.51.46');
    });
  });
}
