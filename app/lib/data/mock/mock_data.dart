import '../models/models.dart';

class MockData {
  const MockData._();

  static const user = UserProfile(
    username: 'Salty',
    handle: '@saltywave',
    avatarUrl: 'https://i.pravatar.cc/300?img=12',
    dailyMinutesGoal: 120,
    dailyMinutesListened: 74,
  );

  static const quoteOfDay =
      '"Sound is the color of the night; press play and let the grid hum."';

  static const quickLinks = <({String label, String icon, int colorIndex})>[
    (label: 'GitHub', icon: 'github', colorIndex: 0),
    (label: 'Discord', icon: 'discord', colorIndex: 1),
    (label: 'YouTube', icon: 'youtube', colorIndex: 5),
    (label: 'Last.fm', icon: 'lastfm', colorIndex: 4),
  ];

  static const artists = <Artist>[
    Artist(
      id: 'a1',
      name: 'Neon Koi',
      imageUrl: 'https://picsum.photos/seed/artist1/400/400',
      monthlyListeners: 1240030,
      bio: 'Synth-soaked dreams from midnight rooftops.',
      genres: ['synthwave', 'chillwave'],
    ),
    Artist(
      id: 'a2',
      name: 'Pixel Shrine',
      imageUrl: 'https://picsum.photos/seed/artist2/400/400',
      monthlyListeners: 842110,
      bio: '8-bit hymns for fluorescent temples.',
      genres: ['chiptune', 'ambient'],
    ),
    Artist(
      id: 'a3',
      name: 'Lavender Static',
      imageUrl: 'https://picsum.photos/seed/artist3/400/400',
      monthlyListeners: 2100450,
      bio: 'Noise, velvet, and violet skies.',
      genres: ['dreampop', 'shoegaze'],
    ),
    Artist(
      id: 'a4',
      name: 'CRT Ghost',
      imageUrl: 'https://picsum.photos/seed/artist4/400/400',
      monthlyListeners: 560320,
      bio: 'Haunting the scanlines between stations.',
      genres: ['lofi', 'electronica'],
    ),
    Artist(
      id: 'a5',
      name: 'Midnight Compiler',
      imageUrl: 'https://picsum.photos/seed/artist5/400/400',
      monthlyListeners: 390880,
      bio: 'Beats that build clean at 3AM.',
      genres: ['idm', 'techno'],
    ),
    Artist(
      id: 'a6',
      name: 'Sakura Modem',
      imageUrl: 'https://picsum.photos/seed/artist6/400/400',
      monthlyListeners: 975400,
      bio: 'Dial-up love songs in bloom.',
      genres: ['city pop', 'future funk'],
    ),
    Artist(
      id: 'a7',
      name: 'Velvet Kernel',
      imageUrl: 'https://picsum.photos/seed/artist7/400/400',
      monthlyListeners: 445210,
      bio: 'Soft cores, hard grooves.',
      genres: ['jazztronica', 'downtempo'],
    ),
    Artist(
      id: 'a8',
      name: 'Tokyo Rainbus',
      imageUrl: 'https://picsum.photos/seed/artist8/400/400',
      monthlyListeners: 1330780,
      bio: 'Window-seat melodies for neon commutes.',
      genres: ['lofi hip hop', 'jazz'],
    ),
  ];

  static const tracks = <Track>[
    Track(
      id: 't1',
      title: 'Neon Garden',
      artist: 'Neon Koi',
      artistId: 'a1',
      album: 'Afterglow District',
      albumArtUrl: 'https://picsum.photos/seed/track1/400/400',
      duration: Duration(minutes: 3, seconds: 42),
      lyrics: [
        'Boot sequence humming low,',
        'lanterns flicker in the code,',
        'we trace the grid where colors flow,',
        'neon garden, take me home.',
        'Pixels bloom in violet rain,',
        'soft electric, sweet refrain.',
      ],
    ),
    Track(
      id: 't2',
      title: 'Scanline Heart',
      artist: 'CRT Ghost',
      artistId: 'a4',
      album: 'Phosphor Sleep',
      albumArtUrl: 'https://picsum.photos/seed/track2/400/400',
      duration: Duration(minutes: 4, seconds: 5),
      lyrics: [
        'A quiet signal through the haze,',
        'your name in monochrome delays,',
        'scanline heart, it gently plays,',
        'across these cathode-ray days.',
      ],
    ),
    Track(
      id: 't3',
      title: 'Lavender Loop',
      artist: 'Lavender Static',
      artistId: 'a3',
      album: 'Soft Noise',
      albumArtUrl: 'https://picsum.photos/seed/track3/400/400',
      duration: Duration(minutes: 3, seconds: 18),
    ),
    Track(
      id: 't4',
      title: 'Kernel Panic at Dusk',
      artist: 'Midnight Compiler',
      artistId: 'a5',
      album: 'Segfault Ballet',
      albumArtUrl: 'https://picsum.photos/seed/track4/400/400',
      duration: Duration(minutes: 5, seconds: 11),
    ),
    Track(
      id: 't5',
      title: 'Cherry Blossom Dial Tone',
      artist: 'Sakura Modem',
      artistId: 'a6',
      album: '56k Spring',
      albumArtUrl: 'https://picsum.photos/seed/track5/400/400',
      duration: Duration(minutes: 3, seconds: 55),
      lyrics: [
        'Hold the line, the petals fall,',
        'a modem sings its silver call,',
        'spring connects us through it all.',
      ],
    ),
    Track(
      id: 't6',
      title: 'Rain on Route 246',
      artist: 'Tokyo Rainbus',
      artistId: 'a8',
      album: 'Window Seat',
      albumArtUrl: 'https://picsum.photos/seed/track6/400/400',
      duration: Duration(minutes: 2, seconds: 58),
    ),
    Track(
      id: 't7',
      title: 'Pixel Prayer',
      artist: 'Pixel Shrine',
      artistId: 'a2',
      album: 'Bit Temple',
      albumArtUrl: 'https://picsum.photos/seed/track7/400/400',
      duration: Duration(minutes: 4, seconds: 21),
    ),
    Track(
      id: 't8',
      title: 'Velvet Thread',
      artist: 'Velvet Kernel',
      artistId: 'a7',
      album: 'Soft Core',
      albumArtUrl: 'https://picsum.photos/seed/track8/400/400',
      duration: Duration(minutes: 3, seconds: 33),
    ),
    Track(
      id: 't9',
      title: 'Midnight Arcade',
      artist: 'Neon Koi',
      artistId: 'a1',
      album: 'Afterglow District',
      albumArtUrl: 'https://picsum.photos/seed/track9/400/400',
      duration: Duration(minutes: 3, seconds: 47),
    ),
    Track(
      id: 't10',
      title: 'Blue Screen Lullaby',
      artist: 'CRT Ghost',
      artistId: 'a4',
      album: 'Phosphor Sleep',
      albumArtUrl: 'https://picsum.photos/seed/track10/400/400',
      duration: Duration(minutes: 4, seconds: 44),
    ),
    Track(
      id: 't11',
      title: 'Static Petals',
      artist: 'Lavender Static',
      artistId: 'a3',
      album: 'Soft Noise',
      albumArtUrl: 'https://picsum.photos/seed/track11/400/400',
      duration: Duration(minutes: 3, seconds: 9),
    ),
    Track(
      id: 't12',
      title: 'Compile & Chill',
      artist: 'Midnight Compiler',
      artistId: 'a5',
      album: 'Segfault Ballet',
      albumArtUrl: 'https://picsum.photos/seed/track12/400/400',
      duration: Duration(minutes: 4, seconds: 2),
    ),
    Track(
      id: 't13',
      title: 'Future Funk Express',
      artist: 'Sakura Modem',
      artistId: 'a6',
      album: '56k Spring',
      albumArtUrl: 'https://picsum.photos/seed/track13/400/400',
      duration: Duration(minutes: 3, seconds: 26),
    ),
    Track(
      id: 't14',
      title: 'Last Train Glow',
      artist: 'Tokyo Rainbus',
      artistId: 'a8',
      album: 'Window Seat',
      albumArtUrl: 'https://picsum.photos/seed/track14/400/400',
      duration: Duration(minutes: 3, seconds: 51),
    ),
    Track(
      id: 't15',
      title: '8-Bit Incense',
      artist: 'Pixel Shrine',
      artistId: 'a2',
      album: 'Bit Temple',
      albumArtUrl: 'https://picsum.photos/seed/track15/400/400',
      duration: Duration(minutes: 2, seconds: 47),
    ),
    Track(
      id: 't16',
      title: 'Low Latency Love',
      artist: 'Velvet Kernel',
      artistId: 'a7',
      album: 'Soft Core',
      albumArtUrl: 'https://picsum.photos/seed/track16/400/400',
      duration: Duration(minutes: 4, seconds: 15),
    ),
    Track(
      id: 't17',
      title: 'Glass City FM',
      artist: 'Neon Koi',
      artistId: 'a1',
      album: 'Afterglow District',
      albumArtUrl: 'https://picsum.photos/seed/track17/400/400',
      duration: Duration(minutes: 3, seconds: 29),
    ),
    Track(
      id: 't18',
      title: 'Violet Buffer',
      artist: 'Lavender Static',
      artistId: 'a3',
      album: 'Soft Noise',
      albumArtUrl: 'https://picsum.photos/seed/track18/400/400',
      duration: Duration(minutes: 4, seconds: 38),
    ),
    Track(
      id: 't19',
      title: 'Platform Nine & Three Quarters Past',
      artist: 'Tokyo Rainbus',
      artistId: 'a8',
      album: 'Window Seat',
      albumArtUrl: 'https://picsum.photos/seed/track19/400/400',
      duration: Duration(minutes: 3, seconds: 14),
    ),
    Track(
      id: 't20',
      title: 'Handshake.wav',
      artist: 'Sakura Modem',
      artistId: 'a6',
      album: '56k Spring',
      albumArtUrl: 'https://picsum.photos/seed/track20/400/400',
      duration: Duration(minutes: 2, seconds: 39),
    ),
    Track(
      id: 't21',
      title: 'Floating Point',
      artist: 'Midnight Compiler',
      artistId: 'a5',
      album: 'Segfault Ballet',
      albumArtUrl: 'https://picsum.photos/seed/track21/400/400',
      duration: Duration(minutes: 5, seconds: 3),
    ),
    Track(
      id: 't22',
      title: 'Shrine Reboot',
      artist: 'Pixel Shrine',
      artistId: 'a2',
      album: 'Bit Temple',
      albumArtUrl: 'https://picsum.photos/seed/track22/400/400',
      duration: Duration(minutes: 3, seconds: 36),
    ),
  ];

  static const playlists = <Playlist>[
    Playlist(
      id: 'p1',
      title: 'Night Rice',
      description: 'Cozy synths for late terminal sessions.',
      coverUrl: 'https://picsum.photos/seed/pl1/400/400',
      trackIds: ['t1', 't2', 't4', 't7', 't9', 't12'],
    ),
    Playlist(
      id: 'p2',
      title: 'Lavender Drive',
      description: 'Soft-focus beats on a violet highway.',
      coverUrl: 'https://picsum.photos/seed/pl2/400/400',
      trackIds: ['t3', 't5', 't11', 't13', 't18', 't20'],
    ),
    Playlist(
      id: 'p3',
      title: 'Compile at 3AM',
      description: 'High-focus electronica for deep work.',
      coverUrl: 'https://picsum.photos/seed/pl3/400/400',
      trackIds: ['t4', 't12', 't21', 't8', 't16'],
    ),
    Playlist(
      id: 'p4',
      title: 'Window Seat FM',
      description: 'Rainy commutes and glowing skylines.',
      coverUrl: 'https://picsum.photos/seed/pl4/400/400',
      trackIds: ['t6', 't14', 't19', 't10', 't2'],
    ),
    Playlist(
      id: 'p5',
      title: 'Pixel Bloom',
      description: 'Chiptune petals and arcade sunsets.',
      coverUrl: 'https://picsum.photos/seed/pl5/400/400',
      trackIds: ['t7', 't15', 't22', 't1', 't17'],
    ),
    Playlist(
      id: 'p6',
      title: 'Made For You: Soft Glow',
      description: 'A mellow blend tuned to your late-night taste.',
      coverUrl: 'https://picsum.photos/seed/pl6/400/400',
      trackIds: ['t8', 't16', 't3', 't11', 't6', 't14'],
    ),
  ];

  static Track trackById(String id) =>
      tracks.firstWhere((t) => t.id == id, orElse: () => tracks.first);

  static Artist artistById(String id) =>
      artists.firstWhere((a) => a.id == id, orElse: () => artists.first);

  static List<Track> tracksForPlaylist(Playlist p) =>
      p.trackIds.map(trackById).toList(growable: false);

  static List<Track> tracksForArtist(String artistId) =>
      tracks.where((t) => t.artistId == artistId).toList(growable: false);

  static List<Track> recentlyPlayed() => [
        trackById('t2'),
        trackById('t1'),
        trackById('t6'),
        trackById('t9'),
        trackById('t14'),
        trackById('t4'),
      ];

  static List<Playlist> madeForYou() => [playlists[5], playlists[1], playlists[3]];
}
