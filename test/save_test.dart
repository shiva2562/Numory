import 'package:flutter_test/flutter_test.dart';
import 'package:numory/core/round.dart';
import 'package:numory/services/save.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('bests per mode survive a reload; slower times keep the best', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Profile(store: await SaveStore.open());
    expect(p.roundWon(Mode.hard, const Duration(milliseconds: 8123)), isTrue);
    expect(p.roundWon(Mode.hard, const Duration(milliseconds: 9000)), isFalse);
    expect(p.roundWon(Mode.easy, const Duration(milliseconds: 1500)), isTrue);
    p.roundLost();
    p.mode = Mode.hard;
    await p.save();

    final again = Profile(store: await SaveStore.open());
    expect(again.best(Mode.hard), const Duration(milliseconds: 8120));
    expect(again.best(Mode.easy), const Duration(milliseconds: 1500));
    expect(again.best(Mode.medium), isNull);
    expect(again.rounds, 4);
    expect(again.mode, Mode.hard);
  });

  test('an unreadable save starts fresh and is kept aside', () async {
    SharedPreferences.setMockInitialValues({SaveStore.key: '{not json'});
    final prefs = await SharedPreferences.getInstance();
    final p = Profile(store: SaveStore(prefs));
    expect(p.rounds, 0);
    expect(prefs.getString(SaveStore.corruptKey), '{not json');
  });
}
