"""Generate a large, legal, silent test library for stress-testing Music Lab.

The files are real MP3 frames with real ID3 tags (title/artist/album/genre/
year/track/disc), just a couple of seconds of silence each. Perfect for
testing search ranking, library sync, streaming and playlist behaviour without
downloading copyrighted music.

Example
-------
    .venv\\Scripts\\python.exe generate_test_library.py --count 500

Then point MUSIC_DIR at the generated folder (or copy the folders into your
real music folder) and restart the server / call POST /api/scan.
"""

from __future__ import annotations

import argparse
import os
import random

from mutagen.id3 import ID3, TALB, TCON, TDRC, TIT2, TPE1, TPE2, TRCK

ARTISTS = [
    "M83", "The Killers", "The Temper Trap", "Cafe Noir", "Neon Harbour",
    "Paper Lanterns", "Kodama", "Aster Grove", "Midnight Transit", "Vela",
    "Glass Circuit", "Orange Skyline", "Low Tide Society", "Halcyon Drive",
    "Static Bloom", "Marble Arch", "Nightjar", "Polar Bloom", "Echo Park",
    "Velvet Antenna", "Sable Coast", "Iris Field", "Copper Sky", "Solace Unit",
]

ALBUM_WORDS = [
    "Midnight City", "Battle Born", "Soft Signals", "Paper Moons", "Blue Hour",
    "Northern Lights", "Glasshouse", "Slow Motion", "Afterimage", "Quiet Machine",
    "Neon Rain", "Long Way Home", "Parallel Lines", "Golden Hour", "Night Swim",
    "The Static Sea", "Small Hours", "Bright Static", "Comet Trail", "Low Tide",
]

TITLE_WORDS = [
    "Midnight", "City", "Navy", "Blue", "Silent", "Signal", "Paper", "Moon",
    "Neon", "Rain", "Slow", "Motion", "Golden", "Hour", "After", "Image",
    "Comet", "Trail", "Static", "Bloom", "Harbour", "Lantern", "Transit", "Vela",
    "Glass", "Circuit", "Skyline", "Tide", "Nightjar", "Polar", "Echo", "Velvet",
]

GENRES = [
    "Synth-Pop", "Indie", "Rock", "Jazz", "Electronic", "Ambient", "Dream Pop",
    "Shoegaze", "Post-Rock", "Lo-Fi", "Experimental", "Alternative", "Soul",
    "Funk", "Downtempo", "Chillwave",
]

# A few MPEG-1 Layer III frames. Enough for mutagen to report a duration.
_AUDIO = (b"\xff\xfb\x90\x64" + b"\x00" * 413) * 24


def make_track(path: str, title: str, artist: str, album: str, genre: str,
               track_no: int, disc_no: int, year: int) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(_AUDIO)
    tags = ID3()
    tags.add(TIT2(encoding=3, text=[title]))
    tags.add(TPE1(encoding=3, text=[artist]))
    tags.add(TPE2(encoding=3, text=[artist]))
    tags.add(TALB(encoding=3, text=[album]))
    tags.add(TCON(encoding=3, text=[genre]))
    tags.add(TDRC(encoding=3, text=[str(year)]))
    tags.add(TRCK(encoding=3, text=[str(track_no)]))
    if disc_no > 1:
        from mutagen.id3 import TPOS

        tags.add(TPOS(encoding=3, text=[str(disc_no)]))
    tags.save(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=300, help="number of tracks (default 300)")
    parser.add_argument(
        "--out",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test-music"),
        help="destination folder (default: music-lab/test-music)",
    )
    parser.add_argument("--seed", type=int, default=7, help="random seed")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)

    for i in range(1, args.count + 1):
        artist = rng.choice(ARTISTS)
        year = rng.randint(2008, 2025)
        album = f"{rng.choice(ALBUM_WORDS)} ({year})"
        genre = rng.choice(GENRES)
        disc = 1 if rng.random() < 0.8 else 2
        track_no = rng.randint(1, 12)
        words = rng.sample(TITLE_WORDS, rng.randint(2, 3))
        title = " ".join(words)
        filename = os.path.join(
            out, artist, album, f"{disc:02d}-{track_no:02d} - {title}.mp3"
        )
        make_track(filename, title, artist, album, genre, track_no, disc, year)

    print(f"Created {args.count} tagged MP3 files in {out}")
    print(f"Total size: ~{args.count * 11 / 1024:.1f} MB")
    print("Next: set MUSIC_DIR to that folder, restart the server, then try")
    print('  GET /api/search?q=midn   and   GET /api/status')


if __name__ == "__main__":
    main()
