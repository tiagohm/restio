import 'package:restio/restio.dart';
import 'package:test/test.dart';

import 'jsonplaceholder.dart';

void main() {
  Restio client;
  JsonplaceholderApi api;

  setUpAll(() {
    Restio.bodyConverter = const _BodyConverter();
    client = Restio();
    api = JsonplaceholderApi(client: client);
  });

  test('User', () async {
    final user = await api.getUser(1);
    expect(user.id, 1);
    expect(user.name, 'Leanne Graham');
  });

  test('List of User', () async {
    final user = await api.getUsers();
    expect(user, hasLength(10));
    expect(user[0].id, 1);
    expect(user[0].name, 'Leanne Graham');
    expect(user[9].id, 10);
    expect(user[9].name, 'Clementina DuBuque');
  });

  test('Create User', () async {
    final user = await api.createUser(const User(11, 'Tiago'));
    expect(user['id'], 11);
  });

  tearDownAll(() async {
    await client.close();
  });
}

class _BodyConverter extends BodyConverter {
  const _BodyConverter();

  @override
  Future<T> decode<T>(String source, MediaType contentType) async {
    final data = await super.decode(source, contentType);
    final type = '$T';

    if (T == User) {
      return User.fromJson(data) as T;
    } else if (type.startsWith('List<')) {
      if (type.endsWith('<User>')) {
        return [for (final item in data) User.fromJson(item)] as T;
      }
    }

    return data;
  }
}
