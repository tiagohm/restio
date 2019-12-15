import 'dart:io';

enum TlsVersion { tls13, tls12, tls11, tls10, ssl30 }

class Handshake {
  final TlsVersion tlsVersion;
  final List<X509Certificate> certificates;

  const Handshake({
    this.tlsVersion,
    this.certificates,
  });
}
