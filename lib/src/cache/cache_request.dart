import 'dart:async';

import 'package:restio/src/cache/cache.dart';
import 'package:restio/src/cache/editor.dart';

class CacheRequest {
  CacheRequest(this.editor, this.metaData);

  final Editor editor;
  final List<int> metaData;

  EventSink<List<int>> body() {
    final metaDataSink = editor.newSink(Cache.entryMetaData);
    metaDataSink.add(metaData);
    metaDataSink.close();

    final bodySink = editor.newSink(Cache.entryBody);
    final streamController = StreamController<List<int>>();

    streamController.stream.listen(
      bodySink.add,
      onError: (error, stackTrace) async {
        bodySink.addError(error, stackTrace);
        await editor.abort();
        await bodySink.close();
      },
      onDone: () async {
        await editor.commit();
        await bodySink.close();
      },
      cancelOnError: true,
    );

    return streamController;
  }
}
