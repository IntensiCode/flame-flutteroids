enum ExtraId {
  /// Primary weapon: Plasma gun with spread shot
  plasma_gun(8, probability: 0.1),

  /// Primary weapon: Pulsed energy blasts
  ion_pulse(10, probability: 0.1),

  /// Secondary weapon: Expanding plasma ring
  plasma_ring(13, probability: 0.1),

  /// Secondary weapon: Nukes large area on impact
  nuke_missile(15, probability: 0.1),

  /// Restore some integrity
  integrity(16, probability: 1.6),

  /// Restore some shield energy
  shield(17, probability: 0.8),

  /// Cool down secondary weapon
  cooldown(18, probability: 0.8),

  /// Secondary weapon: Smart Bomb
  smart_bomb(22, probability: 0.05),
  ;

  final int sheet_index;
  final double probability;

  const ExtraId(this.sheet_index, {this.probability = 0});

  static final defaults = {
    plasma_gun,
    ion_pulse,
    plasma_ring,
    nuke_missile,
    integrity,
    shield,
    cooldown,
  };

  static final maintenance = {
    integrity,
    shield,
    cooldown,
  };

  static final primaries = {
    plasma_gun,
    ion_pulse,
  };

  static final secondaries = {
    plasma_ring,
    nuke_missile,
    smart_bomb,
  };
}
