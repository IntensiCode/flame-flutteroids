enum ExtraId {
  /// Primary weapon: Plasma gun with spread shot
  plasma_gun(8, probability: 0.2),

  /// Primary weapon: Pulsed energy blasts
  ion_pulse(10, probability: 0.2),

  /// Primary weapon: Automatic laser
  auto_laser(24, probability: 0.2),

  /// Secondary weapon: Expanding plasma ring
  plasma_ring(13, probability: 0.1),

  /// Secondary weapon: Nukes large area on impact
  nuke_missile(15, probability: 0.1),

  /// Secondary weapon: Smart Bomb
  smart_bomb(22, probability: 0.05),

  /// Restore some integrity
  integrity(16, probability: 0.8),

  /// Restore some shield energy
  shield(17, probability: 0.5),

  /// Cool down secondary weapon
  cooldown(18, probability: 0.5),
  ;

  final int sheet_index;
  final double probability;

  const ExtraId(this.sheet_index, {this.probability = 0});
}
