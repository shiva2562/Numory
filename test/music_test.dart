import 'package:flutter_test/flutter_test.dart';
import 'package:numory/services/music.dart';
import 'package:numory/services/save.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('music plays only while the app is on screen and Music is on', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = Profile(store: await SaveStore.open());
    final player = FakeMusicPlayer();
    final music = Music(profile: profile, player: player);
    expect(player.playing, isFalse);

    music.visible = true;
    expect(player.playing, isTrue);

    music.visible = false;
    expect(player.playing, isFalse);

    music.visible = true;
    profile.music = false;
    expect(player.playing, isFalse);

    profile.music = true;
    expect(player.playing, isTrue);
  });
}
