import 'package:ip/ip.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/proxy/proxy.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

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

  @override
  String toString() {
    return '$runtimeType { request: $request }';
  }
}

class CallStart extends RequestEvent {
  const CallStart(Request request) : super(request);
}

class CallEnd extends RequestEvent {
  const CallEnd(Request request) : super(request);
}

class CallFailed extends RequestEvent {
  final dynamic error;

  const CallFailed(Request request, this.error) : super(request);

  bool get isCancelled => error is CancelledException;

  @override
  String toString() {
    return '$CallFailed { request: $request, error: $error }';
  }
}

class DnsStart extends RequestEvent {
  const DnsStart(Request request) : super(request);
}

class DnsEnd extends RequestEvent {
  final List<IpAddress> addresses;

  const DnsEnd(Request request, this.addresses) : super(request);

  @override
  String toString() {
    return 'DnsEnd { request: $request, addresses: $addresses }';
  }
}

class ConnectStart extends RequestEvent {
  final dynamic host;
  final Proxy proxy;

  const ConnectStart(Request request, this.host, this.proxy) : super(request);

  @override
  String toString() {
    return 'ConnectStart { request: $request, host: $host, proxy: $proxy }';
  }
}

class ConnectEnd extends RequestEvent {
  const ConnectEnd(Request request) : super(request);
}

class CacheHit extends RequestEvent {
  final Response response;

  const CacheHit(Request request, this.response) : super(request);

  @override
  String toString() {
    return 'CacheHit { request: $request, response: $response }';
  }
}

class CacheMiss extends RequestEvent {
  const CacheMiss(Request request) : super(request);
}

class CacheConditionalHit extends RequestEvent {
  final Response cachedResponse;

  const CacheConditionalHit(Request request, this.cachedResponse)
      : super(request);

  @override
  String toString() {
    return 'CacheConditionalHit { request: $request,'
        ' cachedResponse: $cachedResponse }';
  }
}
