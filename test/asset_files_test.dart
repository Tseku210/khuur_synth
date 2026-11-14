import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuur_synth/src/asset_files.dart';

final class _Bundle extends CachingAssetBundle {
  var loads = 0;
  var fail = false;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    if (fail) throw StateError('no asset $key');
    return ByteData.sublistView(Uint8List.fromList([1, 2, 3, key.length]));
  }
}

void main() {
  late Directory temp;
  late _Bundle bundle;
  late AssetFiles files;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('khuur_synth_test');
    bundle = _Bundle();
    files = AssetFiles(bundle: bundle, directory: () async => temp);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('an asset is copied once and named by its key', () async {
    final first = await files.pathOf('assets/sf/piano.sf2');
    final second = await files.pathOf('assets/sf/piano.sf2');
    expect(second, first);
    expect(bundle.loads, 1);
    expect(first, '${temp.path}/khuur_synth/assets%2Fsf%2Fpiano.sf2');
    expect(File(first).readAsBytesSync(), [1, 2, 3, 19]);
    expect(File('$first.part').existsSync(), isFalse);
  });

  test('a copy that fails is tried again', () async {
    bundle.fail = true;
    await expectLater(files.pathOf('a.sf2'), throwsStateError);
    bundle.fail = false;
    expect(File(await files.pathOf('a.sf2')).existsSync(), isTrue);
    expect(bundle.loads, 2);
  });
}
