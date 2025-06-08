import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/voxel_entity.dart';
import 'package:flutteroids/game/common/voxel_rotation.dart';

class TitleManta extends PositionComponent with VoxelRotation {
  var _time = 0.0;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    size.setAll(128);
    anchor = Anchor.center;

    voxel = VoxelEntity(
      voxel_image: await images.load('voxel/manta19.png'),
      height_frames: 19,
      exhaust_color: Color(0xFFff0037),
      parent_size: size,
    );
    voxel.model_scale.setValues(0.8, 0.2, 0.8);
    voxel.exhaust_length = 2;

    await add(voxel..priority = 10);

    voxel.set_exhaust_gradient(0, const Color(0xFF80ffff));
    voxel.set_exhaust_gradient(1, const Color(0xF000ffff));
    voxel.set_exhaust_gradient(2, const Color(0xE00080ff));
    voxel.set_exhaust_gradient(3, const Color(0xD00000ff));
    voxel.set_exhaust_gradient(4, const Color(0xC0000080));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    rot_x = rot_y = rot_z = 0;
    rot_x = pi / 5;
    rot_y = pi + sin(_time * 0.5) * pi / 8;
    rot_z = pi / 8 + cos(_time * 0.25) * pi / 5;
  }
}
