import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Turns an asset key into a file FluidSynth can open.
///
/// Each asset is copied once per process to `khuur_synth/` in the temporary
/// directory, through a `.part` file and a rename, so a crash never leaves half
/// a file and an app update never loads an old copy.
final class AssetFiles {
  /// Reads from the given bundle, or the root bundle, and copies into the
  /// given directory, or the temporary directory.
  AssetFiles({this._bundle, this._directory = getTemporaryDirectory});

  /// The copies every synth of the process shares.
  static final shared = AssetFiles();

  final AssetBundle? _bundle;
  final Future<Directory> Function() _directory;
  final _paths = <String, Future<String>>{};

  /// The path of the copy of the asset [key], made on the first call.
  ///
  /// A copy that fails is tried again on the next call.
  Future<String> pathOf(String key) async {
    final copy = _paths[key] ??= _copy(key);
    try {
      return await copy;
    } catch (_) {
      if (identical(_paths[key], copy)) _paths.remove(key)?.ignore();
      rethrow;
    }
  }

  Future<String> _copy(String key) async {
    final data = await (_bundle ?? rootBundle).load(key);
    final folder = Directory('${(await _directory()).path}/khuur_synth');
    await folder.create(recursive: true);
    final file = File('${folder.path}/${Uri.encodeComponent(key)}');
    final part = File('${file.path}.part');
    await part.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    await part.rename(file.path);
    return file.path;
  }
}
