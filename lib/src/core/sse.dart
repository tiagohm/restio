part of 'client.dart';

class RealSse implements Sse {
  final Restio _client;
  @override
  final Request request;
  SseTransformer transformer;
  String _lastEventId;
  Duration _retryInterval;
  final int maxRetries;
  var _retries = 0;

  RealSse(
    this._client,
    this.request, {
    Duration retryInterval,
    String lastEventId,
    this.maxRetries,
  })  : _retryInterval = retryInterval,
        _lastEventId = lastEventId {
    transformer = SseTransformer(retry: (duration) {
      // O servidor tem prioridade, mas só se o usuário habilitar.
      if (_retryInterval != null) {
        _retryInterval = duration;
      }
    });
  }

  @override
  Duration get retryInterval => _retryInterval;

  @override
  String get lastEventId => _lastEventId;

  @override
  Future<SseConnection> open() async {
    // ignore: close_sinks
    StreamController<SseEvent> incomingController;
    Response response;
    var retry = false;
    var error = false;
    var listened = false;

    incomingController = StreamController<SseEvent>.broadcast(
      // Ao escutar.
      onListen: () async {
        // Não recriar uma conexão (já que é um broadcast).
        if (listened) {
          return;
        }

        listened = true;

        // Tenta conectar várias e várias vezes se for necessário.
        while (!error) {
          // Aguarda um tempo antes de reconectar.
          if (retry) {
            // Incrementa a contagem de tentativas.
            _retries++;

            // Estourou o número máximo de tentativas.
            if (maxRetries != null &&
                maxRetries != -1 &&
                _retries > maxRetries) {
              incomingController
                  .addError(const TooManyRetriesException('Too many retries'));
              return;
            }

            await Future.delayed(retryInterval);
          }

          // Monta o cabeçalho.
          final headers = request.headers.toBuilder();
          headers.set('accept', 'text/event-stream');

          if (lastEventId != null) {
            headers.set('Last-Event-ID', lastEventId);
          }

          final connectRequest = request.copyWith(
            method: 'GET',
            headers: headers.build(),
          );

          try {
            // Conecta ao servidor.
            final call = _client.newCall(connectRequest);
            response = await call.execute();

            retry = false;

            // Sucesso!
            if (response.code == 200) {
              try {
                final eventStream = response.body.data.transform(transformer);
                // Para cada evento recebido, enviar para o controller.
                await for (final event in eventStream) {
                  if (incomingController.hasListener &&
                      !incomingController.isClosed &&
                      !incomingController.isPaused) {
                    incomingController.add(event);

                    if (event.id != null) {
                      _lastEventId = event.id;
                    }
                  }
                }
              } catch (e, stackTrace) {
                // Reconectar.
                if (retryInterval != null && !retryInterval.isNegative) {
                  retry = true;
                  continue;
                } else {
                  error = true;

                  if (incomingController.hasListener &&
                      !incomingController.isClosed &&
                      !incomingController.isPaused) {
                    incomingController.addError(e, stackTrace);
                  }
                }
              } finally {
                await response?.close();
                response = null;
              }

              return;
            }
          } catch (e, stackTrace) {
            print(e);
            print(stackTrace);
          }

          error = true;
        }

        incomingController
            .addError(RestioException('Failed to connect to ${request.uri}'));
      },
      onCancel: () {
        // nada.
      },
    );

    return _SseConnection(incomingController, onClose: () async {
      await response?.close();
    });
  }
}

class _SseConnection implements SseConnection {
  final StreamController<SseEvent> controller;
  final Future<void> Function() onClose;

  _SseConnection(
    this.controller, {
    this.onClose,
  });

  @override
  Stream<SseEvent> get stream => controller.stream;

  @override
  Future<void> close() async {
    await onClose?.call();
    await controller.close();
  }

  @override
  bool get isClosed => controller.isClosed;
}
