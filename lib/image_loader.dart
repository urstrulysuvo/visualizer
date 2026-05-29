import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

Future<ui.Image> loadNetworkImage(String url) async {
  final ByteData data = await NetworkAssetBundle(Uri.parse(url)).load(url);
  final Uint8List bytes = data.buffer.asUint8List();
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(bytes, (ui.Image img) {
    return completer.complete(img);
  });
  return completer.future;
}
