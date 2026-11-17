class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.trackIds,
    this.owner = 'you',
  });

  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final List<String> trackIds;
  final String owner;
}
