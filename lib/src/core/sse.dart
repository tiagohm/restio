part of 'client.dart';

class RealSse implements Sse {
  final Restio _client;
  @override
  final Request request;
  final SseTransformer _transformer;

  RealSse(
    this._client,
    this.request, [
    Retry retry,
  ]) : _transformer = SseTransformer(retry: retry);

  @override
  Future<SseConnection> open() async {
    // ignore: close_sinks
    StreamController<SseEvent> incomingController;

    incomingController = StreamController<SseEvent>.broadcast(
      onListen: () async {
        final realRequest = request.copyWith(
          method: 'GET',
          headers: (request.headers.toBuilder()
                ..set('accept', 'text/event-stream'))
              .build(),
        );

        final call = _client.newCall(realRequest);

        try {
          final response = await call.execute();

          if (response.code == 200) {
            response.body.data.transform(_transformer).listen((event) {
              if (incomingController.hasListener &&
                  !incomingController.isClosed &&
                  !incomingController.isPaused) {
                incomingController.add(event);
              }
            }, onError: (e, stackTrace) {
              if (incomingController.hasListener &&
                  !incomingController.isClosed &&
                  !incomingController.isPaused) {
                incomingController.addError(e, stackTrace);
              }
            });

            return;
          }
        } catch (e, stackTrace) {
          print(e);
          print(stackTrace);
        }

        incomingController
            .addError(RestioException('Failed to connect to ${request.uri}'));
      },
    );

    return _SseConnection(incomingController);
  }
}

class _SseConnection implements SseConnection {
  final StreamController<SseEvent> controller;

  _SseConnection(this.controller);

  @override
  Stream<SseEvent> get stream => controller.stream;

  @override
  Future<void> close() async {
    await controller.close();
  }

  @override
  bool get isClosed => controller.isClosed;
}
