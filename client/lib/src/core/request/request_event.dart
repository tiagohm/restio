import 'package:ip/ip.dart';
import 'package:restio/src/core/request/request.dart';

/*
 * https://github.com/square/okhttp/blob/master/okhttp/src/main/kotlin/okhttp3/EventListener.kt
 * Events are typically nested with this structure:
 *
 * call ([callStart], [callEnd], [callFailed])
 *   proxy selection ([proxySelectStart], [proxySelectEnd])
 *   dns ([dnsStart], [dnsEnd])
 *   connect ([connectStart], [connectEnd], [connectFailed])
 *     secure connect ([secureConnectStart], [secureConnectEnd])
 *   connection held ([connectionAcquired], [connectionReleased])
 *     request ([requestFailed])
 *       headers ([requestHeadersStart], [requestHeadersEnd])
 *       body ([requestBodyStart], [requestBodyEnd])
 *     response ([responseFailed])
 *       headers ([responseHeadersStart], [responseHeadersEnd])
 *       body ([responseBodyStart], [responseBodyEnd])
*/

abstract class RequestEvent {
  final Request request;

  const RequestEvent(this.request);
}

class DnsStart extends RequestEvent {
  const DnsStart(Request request) : super(request);
}

class DnsEnd extends RequestEvent {
  final List<IpAddress> addresses;

  const DnsEnd(Request request, this.addresses) : super(request);
}
