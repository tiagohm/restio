import 'package:restio/restio.dart';
import 'package:restio_retrofit/restio_retrofit.dart' as retrofit;

part 'jsonplaceholder.g.dart';

@retrofit.Api('https://jsonplaceholder.typicode.com/')
abstract class JsonplaceholderApi {
  factory JsonplaceholderApi({Restio client, String baseUri}) =
      _JsonplaceholderApi;

  @retrofit.Get('/users')
  Future<List<User>> getUsers();

  @retrofit.Get('/users/{id}')
  Future<User> getUser(@retrofit.Path() int id);

  @retrofit.Get('/users/{id}')
  Future<Result<User>> getUserWithResult(@retrofit.Path() int id);

  @retrofit.Post('/users')
  Future<dynamic> createUser(
      @retrofit.Body(contentType: 'application/json') User user);

  @retrofit.Post('/users')
  Future<Result<void>> createUserWithResult(
      @retrofit.Body(contentType: 'application/json') User user);
}

class User {
  final int id;
  final String name;

  const User(this.id, this.name);

  factory User.fromJson(dynamic data) {
    return User(data['id'], data['name']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
