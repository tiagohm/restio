import 'package:ip/ip.dart';

bool isIp(String source) {
  try {
    return IpAddress.parse(source) != null;
  } catch (e) {
    return false;
  }
}
