import 'package:restio/src/client_certificate.dart';

abstract class ClientCertificateJar {
  Future<ClientCertificate> get(String host, int port);
}
