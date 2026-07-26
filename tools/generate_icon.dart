import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  const size = 256;
  final pixels = Int32List(size * size);
  final cx = size / 2, cy = size / 2;
  final halfS = size / 2;
  final radius = size * 0.22;

  // Background rounded square with purple gradient
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = (x - cx).abs(), dy = (y - cy).abs();
      final hi = halfS - radius;
      double dist;
      if (dx > hi && dy > hi) {
        dist = math.sqrt((dx - hi) * (dx - hi) + (dy - hi) * (dy - hi));
      } else if (dx > hi) {
        dist = dx - hi;
      } else if (dy > hi) {
        dist = dy - hi;
      } else {
        dist = -math.min(hi - dx, hi - dy);
      }
      if (dist < 2) {
        final t = (x + y) / (size * 2);
        final rr = (0x4F + (0x7C - 0x4F) * t).round();
        final gg = (0x46 + (0x3A - 0x46) * t).round();
        final bb = (0xE5 + (0xED - 0xE5) * t).round();
        final a = dist <= 0 ? 255 : ((2 - dist) / 2 * 255).round().clamp(0, 255);
        final existing = pixels[y * size + x];
        final na = a + ((existing >> 24) & 0xFF) * (255 - a) ~/ 255;
        final er = existing & 0xFF, eg = (existing >> 8) & 0xFF, eb = (existing >> 16) & 0xFF;
        final nr = na == 0 ? 0 : (rr * a + er * (255 - a)) ~/ 255;
        final ng = na == 0 ? 0 : (gg * a + eg * (255 - a)) ~/ 255;
        final nb = na == 0 ? 0 : (bb * a + eb * (255 - a)) ~/ 255;
        pixels[y * size + x] = (na << 24) | (nb << 16) | (ng << 8) | nr;
      }
    }
  }

  // Inner glow
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / (size * 0.38);
      if (d < 1) {
        final a = ((1 - d) * 28).round().clamp(0, 255);
        final existing = pixels[y * size + x];
        final ea = (existing >> 24) & 0xFF;
        final na = a + ea * (255 - a) ~/ 255;
        final er = existing & 0xFF, eg = (existing >> 8) & 0xFF, eb = (existing >> 16) & 0xFF;
        final nr = na == 0 ? 0 : (255 * a + er * (255 - a)) ~/ 255;
        final ng = na == 0 ? 0 : (255 * a + eg * (255 - a)) ~/ 255;
        final nb = na == 0 ? 0 : (255 * a + eb * (255 - a)) ~/ 255;
        pixels[y * size + x] = (na << 24) | (nb << 16) | (ng << 8) | nr;
      }
    }
  }

  // Draw W
  final w = size * 0.58, h = size * 0.46;
  final lx = (size - w) / 2, ty = (size - h) / 2 + size * 0.04;
  final sw = w * 0.16;

  void thickLine(double x1, double y1, double x2, double y2, double t, int r, int g, int b, int a) {
    final hf = t / 2;
    final mnx = (x1 < x2 ? x1 : x2) - hf;
    final mxx = (x1 > x2 ? x1 : x2) + hf;
    final mny = (y1 < y2 ? y1 : y2) - hf;
    final mxy = (y1 > y2 ? y1 : y2) + hf;
    final dx = x2 - x1, dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.1) return;
    for (int py = mny.ceil(); py <= mxy.floor(); py++) {
      for (int px = mnx.ceil(); px <= mxx.floor(); px++) {
        final tv = ((px - x1) * dx + (py - y1) * dy) / (len * len);
        final cx = x1 + tv.clamp(0.0, 1.0) * dx;
        final cy = y1 + tv.clamp(0.0, 1.0) * dy;
        final d = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
        final sd = ((px - cx) * (-dy / len) + (py - cy) * (dx / len)).abs();
        final dist = math.sqrt(d * d + sd * sd);
        if (dist < hf) {
          final existing = pixels[py * size + px];
          final ea = (existing >> 24) & 0xFF;
          final na = ((1 - dist / hf) * a).round().clamp(0, 255);
          final ra = na + ea * (255 - na) ~/ 255;
          final er = existing & 0xFF, eg = (existing >> 8) & 0xFF, eb = (existing >> 16) & 0xFF;
          final nr = ra == 0 ? 0 : (r * na + er * (255 - na)) ~/ 255;
          final ng = ra == 0 ? 0 : (g * na + eg * (255 - na)) ~/ 255;
          final nb = ra == 0 ? 0 : (b * na + eb * (255 - na)) ~/ 255;
          pixels[py * size + px] = (ra << 24) | (nb << 16) | (ng << 8) | nr;
        }
      }
    }
  }

  final pts = [
    (lx, ty + h),
    (lx + w * 0.33, ty),
    (lx + w * 0.5, ty + h * 0.55),
    (lx + w * 0.67, ty),
    (lx + w, ty + h),
  ];

  for (int i = 0; i < 4; i++) {
    final p1 = pts[i], p2 = pts[i + 1];
    thickLine(p1.$1 + size * 0.02, p1.$2 + size * 0.025, p2.$1 + size * 0.02, p2.$2 + size * 0.025, sw * 1.1, 0, 0, 0, 45);
    thickLine(p1.$1, p1.$2, p2.$1, p2.$2, sw, 0xE0, 0xE7, 0xFF, 230);
  }

  // Encode PNG
  final raw = BytesBuilder();
  for (int y = 0; y < size; y++) {
    raw.addByte(0);
    for (int x = 0; x < size; x++) {
      final p = pixels[y * size + x];
      raw.add([p & 0xFF, (p >> 8) & 0xFF, (p >> 16) & 0xFF, (p >> 24) & 0xFF]);
    }
  }
  final compressed = ZLibCodec(level: 9).encoder.convert(raw.toBytes());
  final png = _buildPng(size, size, compressed);

  // Build ICO (single image)
  final ico = _buildIco(png);
  final icoPath = 'windows\\runner\\resources\\app_icon.ico';
  File(icoPath).writeAsBytesSync(ico);
  print('Created ICO: $icoPath (${ico.length} bytes)');
}

Uint8List _buildPng(int w, int h, List<int> compressed) {
  final out = BytesBuilder();
  out.add([137, 80, 78, 71, 13, 10, 26, 10]);
  final ihdr = BytesBuilder();
  _u32(ihdr, w); _u32(ihdr, h);
  ihdr.add([8, 6, 0, 0, 0]);
  _chunk(out, 'IHDR', ihdr.toBytes());
  _chunk(out, 'IDAT', compressed);
  _chunk(out, 'IEND', Uint8List(0));
  return out.toBytes();
}

void _u32(BytesBuilder bb, int v) {
  bb.add([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);
}

void _chunk(BytesBuilder out, String type, List<int> data) {
  _u32(out, data.length);
  out.add(type.codeUnits);
  out.add(data);
  _u32(out, _crc32([...type.codeUnits, ...data]));
}

int _crc32(List<int> data) {
  int c = 0xFFFFFFFF;
  for (final b in data) {
    c ^= b;
    for (int i = 0; i < 8; i++) {
      c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _buildIco(Uint8List png) {
  final out = BytesBuilder();
  out.add([0, 0, 1, 0, 1, 0]); // header, type=ICO, count=1
  final ps = png.length;
  out.add([0, 0, 0, 0, 1, 0, 32, 0]); // w=256, h=256, 32bpp
  _u32le(out, ps); // size (little-endian)
  _u32le(out, 22); // offset (little-endian)
  out.add(png);
  return out.toBytes();
}

void _u32le(BytesBuilder bb, int v) {
  bb.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
}
