import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:communiq/core/services/offline_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const url = 'http://localhost:3000/user/profile';

  test('a written response reads back for the same user', () async {
    await OfflineCacheService.write('uid-a', url, {'name': 'Sukhbir', 'xp': 40});

    expect(await OfflineCacheService.read('uid-a', url),
        {'name': 'Sukhbir', 'xp': 40});
  });

  test('list bodies survive the round trip', () async {
    await OfflineCacheService.write('uid-a', url, [
      {'id': 1},
      {'id': 2},
    ]);

    expect(await OfflineCacheService.read('uid-a', url), [
      {'id': 1},
      {'id': 2},
    ]);
  });

  test('another account never sees the previous one\'s cached response',
      () async {
    await OfflineCacheService.write('uid-a', url, {'name': 'Sukhbir'});

    expect(await OfflineCacheService.read('uid-b', url), isNull);
  });

  test('an uncached url reads as null rather than throwing', () async {
    expect(await OfflineCacheService.read('uid-a', url), isNull);
  });

  test('non-JSON bodies are skipped instead of poisoning the cache', () async {
    await OfflineCacheService.write('uid-a', url, 'plain text');

    expect(await OfflineCacheService.read('uid-a', url), isNull);
  });

  test('clear drops every cached response', () async {
    await OfflineCacheService.write('uid-a', url, {'name': 'Sukhbir'});
    await OfflineCacheService.write('uid-b', '$url/2', {'name': 'Other'});

    await OfflineCacheService.clear();

    expect(await OfflineCacheService.read('uid-a', url), isNull);
    expect(await OfflineCacheService.read('uid-b', '$url/2'), isNull);
  });
}
