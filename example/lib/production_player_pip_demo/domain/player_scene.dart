enum PlayerSceneType {
  live,
  video,
}

class PlayerScene {
  const PlayerScene({
    required this.type,
    required this.id,
    required this.title,
    required this.url,
    this.aspectRatio = 16 / 9,
  });

  final PlayerSceneType type;
  final String id;
  final String title;
  final String url;
  final double aspectRatio;

  bool isSameScene(PlayerScene other) {
    return type == other.type && id == other.id;
  }
}
