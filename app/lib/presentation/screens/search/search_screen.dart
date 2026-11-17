import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/core.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  static const _genres = <({String name, IconData icon})>[
    (name: 'synthwave', icon: PhosphorIconsRegular.waveSine),
    (name: 'lofi', icon: PhosphorIconsRegular.coffee),
    (name: 'chiptune', icon: PhosphorIconsRegular.gameController),
    (name: 'dreampop', icon: PhosphorIconsRegular.cloud),
    (name: 'techno', icon: PhosphorIconsRegular.cpu),
    (name: 'city pop', icon: PhosphorIconsRegular.buildings),
    (name: 'jazztronica', icon: PhosphorIconsRegular.musicNote),
    (name: 'ambient', icon: PhosphorIconsRegular.moonStars),
    (name: 'shoegaze', icon: PhosphorIconsRegular.sparkle),
    (name: 'idm', icon: PhosphorIconsRegular.gitBranch),
  ];

  @override
  void initState() {
    super.initState();
    final initial = ref.read(searchQueryProvider);
    _controller = TextEditingController(text: initial);
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String v) {
    ref.read(searchQueryProvider.notifier).state = v;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final q = ref.watch(searchQueryProvider).trim();
    final resultsAsync = ref.watch(searchResultsProvider(q));
    final results = resultsAsync.asData?.value ?? LibrarySearchResults.empty;
    final allPlaylists =
        ref.watch(playlistsProvider).asData?.value ?? const <Playlist>[];
    final serverGenres =
        ref.watch(genresProvider).asData?.value ?? const <String>[];
    final genreTiles = serverGenres.isEmpty
        ? _genres
        : serverGenres
            .take(12)
            .map(
              (name) => (
                name: name,
                icon: PhosphorIconsRegular.musicNotes,
              ),
            )
            .toList();

    final trackResults = results.tracks;
    final artistResults = results.artists;
    final ql = q.toLowerCase();
    final playlistResults = q.isEmpty
        ? const <Playlist>[]
        : allPlaylists
            .where((p) =>
                p.title.toLowerCase().contains(ql) ||
                p.description.toLowerCase().contains(ql))
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('user@aesthetic ~ \$ search',
              style: AppTypography.prompt(color: colors.green)),
          const SizedBox(height: 10),
          _TerminalInput(
            controller: _controller,
            focusNode: _focus,
            onChanged: _setQuery,
            onClear: () {
              _controller.clear();
              _setQuery('');
              _focus.requestFocus();
            },
          ),
          const SizedBox(height: 18),
          if (q.isEmpty) ...[
            const _SectionLabel('BROWSE GENRES',
                prompt: 'ls ./genres --color=always'),
            const SizedBox(height: 10),
            _GenreGrid(
              genres: genreTiles,
              onTap: (g) {
                _controller.text = g;
                _controller.selection =
                    TextSelection.collapsed(offset: g.length);
                _setQuery(g);
              },
            ),
          ] else ...[
            _SectionLabel('RESULTS',
                prompt:
                    'grep -i "$q" ./library  →  ${trackResults.length + artistResults.length + playlistResults.length} hits'),
            const SizedBox(height: 10),
            if (resultsAsync.isLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('searching server index...',
                    style: AppTypography.caption(color: colors.yellow)),
              ),
            if (resultsAsync.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('search backend unavailable: ${resultsAsync.error}',
                    style: AppTypography.caption(color: colors.red)),
              ),
            if (trackResults.isEmpty &&
                artistResults.isEmpty &&
                playlistResults.isEmpty)
              PixelCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('no matches found.',
                        style: AppTypography.body(color: colors.red)),
                    const SizedBox(height: 6),
                    Text('try another keyword, artist, or genre.',
                        style: AppTypography.caption()),
                  ],
                ),
              ).animate().fadeIn(duration: 180.ms),
            if (trackResults.isNotEmpty) ...[
              _ResultsHeader('SONGS', trackResults.length, colors.cyan),
              const SizedBox(height: 8),
              ..._staggerList([
                for (var i = 0; i < trackResults.length; i++)
                  _TrackResult(
                    track: trackResults[i],
                    queue: trackResults,
                    index: i,
                  ),
              ]),
              const SizedBox(height: 14),
            ],
            if (artistResults.isNotEmpty) ...[
              _ResultsHeader('ARTISTS', artistResults.length, colors.purple),
              const SizedBox(height: 8),
              ..._staggerList([
                for (final a in artistResults) _ArtistResult(artist: a),
              ]),
              const SizedBox(height: 14),
            ],
            if (playlistResults.isNotEmpty) ...[
              _ResultsHeader(
                  'PLAYLISTS', playlistResults.length, colors.green),
              const SizedBox(height: 8),
              ..._staggerList([
                for (final p in playlistResults) _PlaylistResult(playlist: p),
              ]),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _staggerList(List<Widget> items) {
    return [
      for (var i = 0; i < items.length; i++)
        items[i]
            .animate()
            .fadeIn(delay: (30 * i).ms, duration: 180.ms)
            .slideX(
                begin: 0.04,
                end: 0,
                delay: (30 * i).ms,
                duration: 200.ms,
                curve: Curves.easeOutBack),
    ];
  }
}

class _TerminalInput extends StatefulWidget {
  const _TerminalInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_TerminalInput> createState() => _TerminalInputState();
}

class _TerminalInputState extends State<_TerminalInput>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursor;

  @override
  void initState() {
    super.initState();
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    widget.focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasText = widget.controller.text.isNotEmpty;
    return PixelCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: widget.focusNode.hasFocus ? colors.accent : colors.border,
      child: Row(
        children: [
          Text('>',
              style: AppTypography.mono(
                  size: 16, color: colors.green, weight: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  onChanged: widget.onChanged,
                  style: AppTypography.mono(
                      size: 14, color: colors.textPrimary, height: 1.3),
                  cursorColor: colors.accent,
                  cursorWidth: 2,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'search tracks, artists, genres...',
                    hintStyle: AppTypography.mono(
                        size: 14, color: colors.textSecondary, height: 1.3),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (!hasText)
            FadeTransition(
              opacity: _cursor,
              child: Container(
                width: 8,
                height: 16,
                color: colors.accent.withValues(alpha: 0.7),
              ),
            )
          else
            GestureDetector(
              onTap: widget.onClear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(PhosphorIconsBold.x,
                    size: 16, color: colors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.prompt});
  final String label;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: AppTypography.prompt(color: colors.cyan)),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.label(color: colors.textSecondary)),
      ],
    );
  }
}

class _GenreGrid extends StatelessWidget {
  const _GenreGrid({required this.genres, required this.onTap});
  final List<({String name, IconData icon})> genres;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accents = colors.accentCycle;
    return LayoutBuilder(builder: (context, c) {
      final cross = c.maxWidth >= 700 ? 5 : (c.maxWidth >= 420 ? 3 : 2);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: genres.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
        ),
        itemBuilder: (context, i) {
          final g = genres[i];
          final accent = accents[i % accents.length];
          return PixelCard(
            onTap: () => onTap(g.name),
            padding: const EdgeInsets.all(10),
            color: Color.alphaBlend(accent.withValues(alpha: 0.12), colors.card),
            borderColor: accent.withValues(alpha: 0.7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(g.icon, color: accent, size: 22),
                Text(
                  g.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(color: colors.textPrimary),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: (35 * i).ms, duration: 200.ms)
              .scale(
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1, 1),
                  delay: (35 * i).ms,
                  duration: 220.ms,
                  curve: Curves.easeOutBack);
        },
      );
    });
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader(this.title, this.count, this.color);
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.label(color: color)),
        const SizedBox(width: 8),
        Text('[$count]', style: AppTypography.caption()),
      ],
    );
  }
}

class _TrackResult extends ConsumerWidget {
  const _TrackResult(
      {required this.track, required this.queue, required this.index});
  final Track track;
  final List<Track> queue;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final audio = ref.watch(audioPlayerServiceProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelCard(
        onTap: () => audio.playTrack(track, queue: queue, index: index),
        padding: const EdgeInsets.all(10),
        radius: 12,
        shadowOffset: const Offset(4, 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: track.albumArtUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: colors.cardElevated),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(color: colors.textPrimary)),
                  Text('${track.artist} · ${track.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption()),
                ],
              ),
            ),
            Text(_fmt(track.duration), style: AppTypography.caption()),
          ],
        ),
      ),
    );
  }
}

class _ArtistResult extends StatelessWidget {
  const _ArtistResult({required this.artist});
  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelCard(
        onTap: () => context.push('/artist/${artist.id}'),
        padding: const EdgeInsets.all(10),
        radius: 12,
        shadowOffset: const Offset(4, 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.purple, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: artist.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: colors.cardElevated),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(color: colors.textPrimary)),
                  Text(artist.genres.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption()),
                ],
              ),
            ),
            Icon(PhosphorIconsRegular.caretRight,
                color: colors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PlaylistResult extends StatelessWidget {
  const _PlaylistResult({required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelCard(
        onTap: () => context.push('/playlist/${playlist.id}'),
        padding: const EdgeInsets.all(10),
        radius: 12,
        shadowOffset: const Offset(4, 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.green, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: playlist.coverUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: colors.cardElevated),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(color: colors.textPrimary)),
                  Text(playlist.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption()),
                ],
              ),
            ),
            Text('${playlist.trackIds.length}',
                style: AppTypography.caption(color: colors.green)),
          ],
        ),
      ),
    );
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
