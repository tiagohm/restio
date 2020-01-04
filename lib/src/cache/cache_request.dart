import 'dart:async';

import 'package:restio/src/cache/cache.dart';
import 'package:restio/src/cache/editor.dart';

class CacheRequest {
  CacheRequest(this.editor, this.metaData);

  final Editor editor;
  final List<int> metaData;

  EventSink<List<int>> body() {
    final bodySink = editor.newSink(Cache.entryBody);
    final metaDataSink = editor.newSink(Cache.entryMetaData);
    final streamController = StreamController<List<int>>();

    streamController.stream.listen(
      bodySink.add,
      onError: (error, stackTrace) {
        bodySink.addError(error, stackTrace);
        editor.abort();
        bodySink.close();
        metaDataSink.close();
      },
      onDone: () {
        metaDataSink.add(metaData);
        editor.commit();
        bodySink.close();
        metaDataSink.close();
      },
      cancelOnError: true,
    );

    return streamController;
  }
}
