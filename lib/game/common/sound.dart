import 'package:flutteroids/util/auto_dispose.dart';

enum Sound {
  bonus,
  clash,
  emit,
  explosion,
  explosion_hollow,
  flash,
  game_over,
  homing,
  incoming,
  plasma,
  pulse,
  shot,
  shot1,
  shot2,
  swirl,
  teleport,
  teleport_long,
  trigger,
  ;
}

late Future Function(Sound sound, {double volume_factor}) play_sound;

late Future<Disposable> Function(String filename, {double volume_factor, bool cache, bool loop}) play_one_shot;
