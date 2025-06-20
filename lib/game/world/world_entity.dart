import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/world/world_bounds.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/log.dart';

Vector2 spawn_pos_for(PositionComponent origin) {
  if (origin is Player) {
    return v2z_;
  } else if (origin is WorldEntity) {
    return origin.world_pos;
  } else {
    return origin.position;
  }
}

mixin WorldEntity on PositionComponent, Recyclable {
  //

  /// Updated by [WorldCamera]. Has to be added to [world_pos] when updating [position].
  static final camera_offset = Vector2.zero();

  final velocity = Vector2.zero();
  final world_pos = Vector2.zero();

  bool is_outside_world() => world_pos.length2 > cull_distance_squared;

  @override
  void update(double dt) {
    super.update(dt);

    world_pos.add(velocity * dt);

    if (is_outside_world()) {
      log_verbose('Recycling entity outside world: $this');
      recycle();
    } else {
      position.setFrom(world_pos);
      position.add(camera_offset);
    }
  }
}
