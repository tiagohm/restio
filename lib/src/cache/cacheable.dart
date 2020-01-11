import 'package:restio/src/response.dart';

abstract class Cacheable {
  Response get networkResponse;
  
  Response get cacheResponse;
}
