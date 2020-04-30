class ClientCertificate {
  final List<int> certificate;
  final List<int> privateKey;
  final String password;

  const ClientCertificate(
    this.certificate,
    this.privateKey, {
    this.password,
  });
}
