import 'dart:io';

import 'package:restio/restio.dart';
import 'package:test/test.dart';

final client = Restio();

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

    int counter;
    int lastId;
    var n = 0;

    await for (final event in conn.stream) {
      final id = int.parse(event.id);

      if (lastId != null && lastId != id - 1) {
        continue;
      }

      lastId = id;

      if (counter == null) {
        counter = int.parse(event.data);
      } else {
        expect(int.parse(event.data), counter);
      }

      counter++;

      if (++n >= 3) {
        break;
      }
    }

    expect(n, 3);

    counter = null;
    n = 0;

    await for (final event in conn.stream) {
      final id = int.parse(event.id);

      if (lastId != null && lastId != id - 1) {
        continue;
      }

      lastId = id;

      if (counter == null) {
        counter = int.parse(event.data);
      } else {
        expect(int.parse(event.data), counter);
      }

      counter++;

      if (++n >= 3) {
        break;
      }
    }

    expect(n, 3);

    await conn.close();

    expect(conn.isClosed, true);
  });
}
