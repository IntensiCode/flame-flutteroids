import 'package:flutteroids/core/common.dart';

class ShowDebugText with Message {
  ShowDebugText({
    this.title,
    required this.text,
    this.blink_text = false,
    this.stay_longer = false,
    this.when_done,
  });

  String? title;
  final String text;
  final bool blink_text;
  final bool stay_longer;
  final Function? when_done;
}

class ShowInfoText with Message {
  ShowInfoText({
    this.title,
    required this.text,
    this.secondary,
    this.blink_text = true,
    this.hud_align = false,
    this.stay_longer = false,
    this.when_done,
  });

  String? title;
  final String text;
  final String? secondary;
  final bool blink_text;
  final bool hud_align;
  final bool stay_longer;
  final Function? when_done;
}
