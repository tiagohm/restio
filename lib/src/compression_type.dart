enum CompressionType { notCompressed, gzip, deflate, brotli }

CompressionType obtainCompressionType(String contentEncoding) {
  if (contentEncoding != null && contentEncoding.isNotEmpty) {
    switch (contentEncoding) {
      case 'gzip':
        return CompressionType.gzip;
      case 'deflate':
        return CompressionType.deflate;
      case 'brotli':
      case 'br':
        return CompressionType.brotli;
    }
  }

  return CompressionType.notCompressed;
}
