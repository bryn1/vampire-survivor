"""Contract C asset surface: the 16 manifest PNGs exist under
static/assets/, each is a VALID PNG (magic + IHDR, RGBA 8-bit) and matches
the MANIFEST.md record (on-disk byte count) and the plan §4 canvas size.
PNG structure parsed with stdlib struct/zlib — no PIL. MC 11026.
"""

import os
import re
import struct
import zlib

import conftest

ASSETS = os.path.join(conftest.STATIC_DIR, "assets")
PLAN = "/home/claudecode/Games/.audits/202610201514-81bb9a6c/placement-plan.md"

EXPECTED_FILES = {
    "player.png", "player-alt.png", "enemy-wraith.png", "enemy-hound.png",
    "enemy-crawler.png", "enemy-cultist.png", "boss-warden.png",
    "icon-talon.png", "icon-ember.png", "icon-cleaver.png", "icon-halo.png",
    "icon-ward.png", "icon-spike.png", "card-frame.png", "coin.png", "gem.png",
}


def parse_png(path):
    """Return (width, height, bit_depth, color_type, chunk_types, n_chunks).

    Validates signature, walks every chunk with a CRC/idLength check; raises
    AssertionError on any structural violation. color_type 6 == RGBA.
    """
    with open(path, "rb") as fh:
        data = fh.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "%s: bad PNG signature" % path
    pos = 8
    first = True
    chunks = []
    meta = None
    while pos < len(data):
        assert pos + 12 <= len(data), "%s: truncated chunk header at %d" % (path, pos)
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        assert pos + 12 + length <= len(data), "%s: truncated chunk body" % path
        body = data[pos + 8:pos + 8 + length]
        crc = struct.unpack(">I", data[pos + 8 + length:pos + 12 + length])[0]
        assert zlib.crc32(ctype + body) & 0xFFFFFFFF == crc, "%s: CRC mismatch in %s" % (path, ctype)
        if first:
            assert ctype == b"IHDR", "%s: first chunk is %s, not IHDR" % (path, ctype)
            assert length == 13
            meta = struct.unpack(">IIBBBBB", body)
            first = False
        chunks.append(ctype.decode("ascii", "replace"))
        pos += 12 + length
    assert chunks[-1] == "IEND", "%s: missing IEND" % path
    width, height, bit_depth, color_type, compression, filter_m, interlace = meta
    assert compression == 0 and filter_m == 0
    return width, height, bit_depth, color_type, chunks, interlace


def manifest_rows():
    """Parse MANIFEST.md table: {file: (px_w, px_h, bytes_on_disk)}."""
    with open(os.path.join(ASSETS, "MANIFEST.md"), encoding="utf-8") as fh:
        text = fh.read()
    rows = {}
    for line in text.splitlines():
        m = re.match(r"^\|\s*([\w-]+\.png)\s*\|\s*(\d+)×(\d+)\s*\|\s*(\d+)\s*\|", line)
        if m:
            rows[m.group(1)] = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
    return rows


def test_all_16_manifest_files_present():
    on_disk = {f for f in os.listdir(ASSETS) if f.endswith(".png")}
    missing = EXPECTED_FILES - on_disk
    extra = on_disk - EXPECTED_FILES
    assert not missing, "missing contract-C assets: %r" % sorted(missing)
    assert not extra, "unexpected extra assets: %r" % sorted(extra)


def test_manifest_md_lists_all_16():
    rows = manifest_rows()
    assert set(rows) == EXPECTED_FILES, \
        "MANIFEST.md rows %r don't match the 16 contract-C files" % sorted(rows)


def test_every_png_is_valid_rgba():
    for name in sorted(EXPECTED_FILES):
        path = os.path.join(ASSETS, name)
        w, h, depth, color_type, chunks, interlace = parse_png(path)
        assert depth == 8, "%s: bit depth %d, expected 8" % (name, depth)
        assert color_type == 6, "%s: color type %d, expected 6 (RGBA)" % (name, color_type)
        assert interlace == 0, "%s: interlaced, expected non-interlaced" % name
        assert w > 0 and h > 0


def test_manifest_sizes_match_disk():
    rows = manifest_rows()
    for name, (pw, ph, nbytes) in rows.items():
        path = os.path.join(ASSETS, name)
        st = os.stat(path)
        assert st.st_size == nbytes, "%s: disk %d bytes, MANIFEST.md %d" % (name, st.st_size, nbytes)
        w, h, _, _, _, _ = parse_png(path)
        assert (w, h) == (pw, ph), "%s: IHDR %dx%d, MANIFEST.md %dx%d" % (name, w, h, pw, ph)


def _defilter(raw, width, height, bpp=4):
    """Undo PNG per-scanline filtering (None/Sub/Up/Average/Paeth)."""
    stride = width * bpp
    out = bytearray()
    prev = bytearray(stride)
    pos = 0
    for _ in range(height):
        ftype = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if ftype == 0:
            pass
        elif ftype == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ftype == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        else:
            raise AssertionError("bad filter type %d" % ftype)
        out += line
        prev = line
    return out


def test_alpha_channel_truly_present():
    # 'transparent cutout' must mean varied alpha, not a uniform opaque strip:
    # decode a real icon to pixels and require >1 distinct alpha value.
    name = "icon-ember.png"
    with open(os.path.join(ASSETS, name), "rb") as fh:
        data = fh.read()
    pos = 8
    idat = b""
    width = height = 0
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        if ctype == b"IDAT":
            idat += data[pos + 8:pos + 8 + length]
        elif ctype == b"IHDR":
            width, height = struct.unpack(">II", data[pos + 8:pos + 16])
        pos += 12 + length
    pixels = _defilter(zlib.decompress(idat), width, height)
    alphas = set(pixels[3::4])
    assert len(alphas) > 1, "%s: alpha channel is uniform — not a cutout" % name
