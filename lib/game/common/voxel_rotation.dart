import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/voxel_entity.dart';

mixin VoxelRotation on PositionComponent, GameContext {
  late final VoxelEntity voxel;

  final _wobble_matrix = Matrix3.identity();
  final _rot_x = Matrix3.identity();
  final _rot_y = Matrix3.identity();
  final _rot_z = Matrix3.identity();

  double max_wobble = pi / 64;
  double wobble_anim = 0;
  double rot_x = pi / 2;
  double rot_y = 0;
  double rot_z = 0;

  @override
  void update(double dt) {
    super.update(dt);
    update_rotation(dt);
  }

  void update_rotation(double dt) {
    final wobble_x = sin(wobble_anim * 1.78926) * max_wobble;
    final wobble_y = sin(wobble_anim * 1.99292) * max_wobble;
    final wobble_z = sin(wobble_anim * 2.12894) * max_wobble;
    wobble_anim += dt;

    _rot_x.setRotationX(wobble_x + rot_x);
    _rot_y.setRotationY(wobble_y + rot_y);
    _rot_z.setRotationZ(wobble_z + rot_z);

    _wobble_matrix.setFrom(_rot_z);
    _wobble_matrix.multiply(_rot_y);
    _wobble_matrix.multiply(_rot_x);

    voxel.orientation_matrix.setFrom(_wobble_matrix);
  }
}
