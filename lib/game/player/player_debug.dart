part of 'player.dart';

mixin _PlayerDebug on _PlayerMovement {
  final _offset = MutableOffset(0, 0);

  @override
  void renderTree(Canvas canvas) {
    super.renderTree(canvas);
    render_debug_vectors(canvas);
  }

  void render_debug_vectors(Canvas canvas) {
    if (!dev || !debug) return;

    canvas.translate(position.x, position.y);
    _render_vectors(canvas);
    canvas.translate(-position.x, -position.y);
  }

  void _render_vectors(Canvas canvas) {
    if (thrust_power > 0) {
      final thrust_length = 40.0;
      final thrust_end = Vector2(
        cos(movement_angle) * thrust_length,
        sin(movement_angle) * thrust_length,
      );

      final paint = Paint()
        ..color = const Color(0xFF00FF00)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      _offset.setFrom(thrust_end);
      canvas.drawLine(Offset.zero, _offset, paint);
    }

    final velocity_length = velocity.length;
    if (velocity_length > 0.1) {
      final velocity_end = Vector2(
        cos(movement_angle) * velocity_length,
        sin(movement_angle) * velocity_length,
      );

      final paint = Paint()
        ..color = const Color(0xFFFF0000)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      _offset.setFrom(velocity_end);
      canvas.drawLine(Offset.zero, _offset, paint);
    }
  }
}
