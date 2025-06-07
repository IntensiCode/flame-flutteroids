import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/player/player.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/on_message.dart';

extension GameContextExtensions on GameContext {
  WorldCamera get camera => cache.putIfAbsent('camera', () => WorldCamera());
}

class WorldCamera extends Component with AutoDispose, GameContext {
  // New zone-based camera follow constants
  static const zone1_dist_end = 50.0; // Player is close
  static const zone1_speed = 0.3; // Gentle follow speed

  static const zone2_dist_end = 100.0; // Player is ~100 units from zone1_dist_end
  static const zone2_speed = 2.0; // Moderate follow speed

  static const zone3_dist_end = 200.0; // Player is further out
  static const zone3_speed = 5.0; // Fast catch-up speed

  final target_pos = v2z();
  final camera_pos = v2z();
  final camera_offset = v2z();
  final movement = Vector2.zero();

  @override
  void onMount() {
    super.onMount();
    on_message<LeavingWarp>((_) {
      movement.setZero();
      target_pos.setZero();
      camera_pos.setZero();
      camera_offset.setZero();
    });
  }

  @override
  void update(double dt) {
    super.update(dt);

    movement.setFrom(player.velocity);
    movement.scale(dt);

    world.translate_all_by(movement);

    target_pos.add(movement);

    final distance = target_pos.distanceTo(camera_pos);
    double speed;

    if (distance <= zone1_dist_end) {
      speed = zone1_speed;
    } else if (distance <= zone2_dist_end) {
      final t = (distance - zone1_dist_end) / (zone2_dist_end - zone1_dist_end);
      speed = lerpDouble(zone1_speed, zone2_speed, t.clamp(0.0, 1.0)) ?? zone1_speed;
    } else if (distance <= zone3_dist_end) {
      final t = (distance - zone2_dist_end) / (zone3_dist_end - zone2_dist_end);
      speed = lerpDouble(zone2_speed, zone3_speed, t.clamp(0.0, 1.0)) ?? zone2_speed;
    } else {
      speed = zone3_speed;
    }

    camera_pos.x = lerpDouble(camera_pos.x, target_pos.x, speed * dt) ?? camera_pos.x;
    camera_pos.y = lerpDouble(camera_pos.y, target_pos.y, speed * dt) ?? camera_pos.y;

    camera_offset.setFrom(target_pos);
    camera_offset.sub(camera_pos);

    player.position.setFrom(camera_offset);

    space.position.x += movement.x / 5000;
    space.position.y -= movement.y / 5000;

    target_pos.lerp(player.position, 0.1 * dt);

    WorldEntity.camera_offset.setFrom(camera_offset);
  }
}
