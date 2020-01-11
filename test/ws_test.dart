import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio/ws.dart';
import 'package:test/test.dart';

final client = Restio();

void main() {
  Process process;

  setUpAll(() async {
    process = await Process.start('node', ['./test/node/ws/index.js']);
    return Future.delayed(const Duration(seconds: 2));
  });

  tearDownAll(() {
    process?.kill();
  });

  test('Open connection', () async {
    final conn = await openConnection();

    expect(conn.readyState, 1);

    await conn.close();
    await conn.done;
  });

  test('Close connection from client side', () async {
    final conn = await openConnection();

    await expectLater(conn.stream, emitsInOrder(<dynamic>[]));

    await conn.close(3000, 'Closed by client');

    await expectLater(conn.stream, emitsDone);

    expect(conn.closeCode, 3000);
    expect(conn.closeReason, 'Closed by client');

    await conn.done;
  });

  test('Close connection from server side', () async {
    final conn = await openConnection();

    conn.addString('close');

    await expectLater(conn.stream, emitsDone);

    expect(conn.closeCode, 4000);
    expect(conn.closeReason, 'Closed by server');

    await conn.done;
  });

  test('String ASCII', () async {
    final conn = await openConnection();
    conn.addString('String data');

    await expectLater(conn.stream, emits('String data'));

    await conn.close();
    await conn.done;
  });

  test('String Unicode/Emoji', () async {
    final conn = await openConnection();
    conn.addString('Unicode 🎾');

    await expectLater(conn.stream, emits('Unicode 🎾'));

    await conn.close();
    await conn.done;
  });

  test('Bytes', () async {
    final conn = await openConnection();
    conn.addBytes(<int>[0, 1, 195, 191]);

    await expectLater(conn.stream, emits(<int>[0, 1, 195, 191]));

    await conn.close();
    await conn.done;
  });

  test('UTF8', () async {
    final conn = await openConnection();
    conn.addUtf8Text(<int>[00, 1, 195, 191]);

    expect(await conn.stream.first, '\u{0}\u{1}\u{FF}');

    await conn.close();
    await conn.done;
  });
}

Future<WebSocketConnection> openConnection() async {
  final request = Request(uri: Uri.parse('ws://localhost:3001'));
  final ws = client.newWebSocket(request);
  final conn = await ws.open();
  return conn;
}
