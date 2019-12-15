import 'package:restio/src/web_socket/client.dart';
import 'package:restio/src/web_socket/connection.dart';
import 'package:restio/src/web_socket/request.dart';
import 'package:test/test.dart';

void main() {
  test('Open connection', () async {
    final conn = await openConnection();

    expect(conn.readyState, 1);

    await conn.close();
    await conn.done;
  });

  test('Close connection from client side', () async {
    final conn = await openConnection();

    expect(conn.readyState, 1);

    await expectLater(conn.stream, emitsInOrder(<dynamic>[]));

    await conn.close(3001, 'Reason 3001');

    await expectLater(conn.stream, emitsDone);

    expect(conn.closeCode, 3001);
    expect(conn.closeReason, 'Reason 3001');

    await conn.done;
  });

  test('Close connection from server side', () async {
    // TODO:
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
    conn.addString('String 🎾');

    await expectLater(conn.stream, emits('String 🎾'));

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
  final client = WebSocketClient();
  final request = WebSocketRequest.url('wss://echo.websocket.org');
  final conn = await client.connect(request);
  return conn;
}
