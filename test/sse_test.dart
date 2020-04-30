import 'dart:async';
import 'dart:io';

import 'package:restio/restio.dart';
import 'package:test/test.dart';

const client = Restio();

void main() {
  Process process;

  setUpAll(() async {
    process = await Process.start('node', ['./test/node/sse/index.js']);
    return Future.delayed(const Duration(seconds: 2));
  });

  tearDownAll(() {
    process?.kill();
  });

  test('Stream', () async {
    final request = Request.get('http://localhost:3000');
    final sse = client.newSse(request);
    final conn = await sse.open();

    var n = 0;
    int lastData;

    await for (final event in conn.stream) {
      final data = int.parse(event.data);

      if (lastData == null) {
        lastData = data;
      } else {
        expect(data, lastData + 1);
        lastData = data;
      }

      if (++n >= 10) {
        break;
      }
    }

    n = 0;
    lastData = null;

    await for (final event in conn.stream) {
      final data = int.parse(event.data);

      if (lastData == null) {
        lastData = data;
      } else {
        expect(data, lastData + 1);
        lastData = data;
      }

      if (++n >= 10) {
        break;
      }
    }

    await conn.close();

    expect(conn.isClosed, true);
  });

  test('Auto Reconnect', () async {
    final request = Request.get('http://localhost:3000/closed-by-server');
    final sse = client.newSse(
      request,
      retryInterval: const Duration(seconds: 1),
      maxRetries: 3,
    );
    final conn = await sse.open();

    final expectedData = <int>[];

    try {
      await for (final event in conn.stream) {
        final data = int.parse(event.data);
        expectedData.add(data);
      }
    } catch (e) {
      // nada.
    }

    expect(expectedData, const [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3]);

    await conn.close();

    expect(conn.isClosed, true);
  });

  test('TooManyRetriesException', () async {
    final request = Request.get('http://localhost:3000/closed-by-server');
    final sse = client.newSse(
      request,
      lastEventId: '0',
      retryInterval: const Duration(seconds: 1),
      maxRetries: 1,
    );
    final conn = await sse.open();

    await expectLater(() async {
      await for (final _ in conn.stream) {}
    }, throwsA(isA<TooManyRetriesException>()));

    await conn.close();

    expect(conn.isClosed, true);
  });

  test('Close', () async {
    final request = Request.get('http://localhost:3000/');
    final sse = client.newSse(request);
    final conn = await sse.open();

    Timer(const Duration(seconds: 10), conn.close);

    await for (final _ in conn.stream) {}

    expect(conn.isClosed, true);
  });

  test('Close Stops Retry Attempts', () async {
    final request = Request.get('http://localhost:3000/closed-by-server');
    final sse = client.newSse(
      request,
      retryInterval: const Duration(seconds: 1),
      maxRetries: -1, // infinite.
    );
    final conn = await sse.open();

    Timer(const Duration(seconds: 15), conn.close);

    await for (final _ in conn.stream) {}

    expect(conn.isClosed, true);
  });
}
