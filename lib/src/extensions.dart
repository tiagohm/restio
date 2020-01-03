import 'package:ip/ip.dart';

extension StringExtension on String {
  bool isIp() {
    try {
      return IpAddress.parse(this) != null;
    } catch (e) {
      return false;
    }
  }
}
