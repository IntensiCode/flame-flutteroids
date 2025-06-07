enum GamePhase {
  inactive,
  level_info,
  enter_level,
  play_level,
  level_complete,
  level_bonus,
  game_over,
  ;

  static GamePhase from(final String name) => GamePhase.values.firstWhere((e) => e.name == name);
}
