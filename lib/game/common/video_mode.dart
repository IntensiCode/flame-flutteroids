import 'package:flutteroids/game/common/configuration.dart';
import 'package:flutteroids/util/log.dart';

enum VideoMode {
  performance,
  balanced,
  quality,
}

VideoMode guess_video_mode() {
  if (frame_skip.value == 4) return VideoMode.performance;
  if (frame_skip.value == 2) return VideoMode.balanced;
  return VideoMode.quality;
}

void apply_video_mode(VideoMode mode) {
  video_mode.value = mode;
  switch (mode) {
    case VideoMode.performance:
      bg_anim.value = false;
      exhaust_anim.value = false;
      frame_skip << 4;

    case VideoMode.balanced:
      bg_anim.value = true;
      exhaust_anim.value = false;
      frame_skip << 2;

    case VideoMode.quality:
      bg_anim.value = true;
      exhaust_anim.value = true;
      frame_skip << 0;
  }
  log_info('$mode: $bg_anim $exhaust_anim $frame_skip');
}
