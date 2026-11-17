class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.monthlyListeners,
    this.bio = '',
    this.genres = const [],
  });

  final String id;
  final String name;
  final String imageUrl;
  final int monthlyListeners;
  final String bio;
  final List<String> genres;
}
