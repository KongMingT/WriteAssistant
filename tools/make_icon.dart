import 'dart:convert';
import 'dart:io';

void main() {
  final pngPath = '${Platform.environment['TEMP']}\\app_icon.png';
  final icoPath = 'windows\\runner\\resources\\app_icon.ico';

  final pngBytes = File(pngPath).readAsBytesSync();
  final pngSize = pngBytes.length;

  final header = <int>[
    0, 0, // reserved
    1, 0, // ICO type
    1, 0, // 1 image
  ];

  final entry = <int>[
    0,   // width (0=256)
    0,   // height (0=256)
    0,   // colors
    0,   // reserved
    1,   // planes
    0,   // bpp
    32, 0, // bpp continued
    (pngSize) & 0xFF,
    ((pngSize) >> 8) & 0xFF,
    ((pngSize) >> 16) & 0xFF,
    ((pngSize) >> 24) & 0xFF,
    22, 0, 0, 0, // offset (6 + 16 = 22)
  ];

  final icoBytes = [...header, ...entry, ...pngBytes];
  File(icoPath).writeAsBytesSync(icoBytes);
  print('Created ICO: $icoPath (${icoBytes.length} bytes)');
}
