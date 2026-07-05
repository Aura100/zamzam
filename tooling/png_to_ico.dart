import 'dart:io';

int toUint16LE(int v, List<int> out, int offset) {
  out[offset] = v & 0xFF;
  out[offset + 1] = (v >> 8) & 0xFF;
  return offset + 2;
}

int toUint32LE(int v, List<int> out, int offset) {
  out[offset] = v & 0xFF;
  out[offset + 1] = (v >> 8) & 0xFF;
  out[offset + 2] = (v >> 16) & 0xFF;
  out[offset + 3] = (v >> 24) & 0xFF;
  return offset + 4;
}

void main() {
  final src = File('assets/images/logo.png');
  if (!src.existsSync()) {
    stderr.writeln('Source PNG not found: ${src.path}');
    exit(2);
  }
  final png = src.readAsBytesSync();

  // ICONDIR (6 bytes) + 1 ICONDIRENTRY (16 bytes)
  final header = List<int>.filled(6 + 16, 0);
  // Reserved 0
  header[0] = 0;
  header[1] = 0;
  // Type 1 (icon)
  header[2] = 1;
  header[3] = 0;
  // Count = 1
  header[4] = 1;
  header[5] = 0;

  // ICONDIRENTRY starts at offset 6
  int off = 6;
  // width (0 for 256)
  header[off++] = 0;
  // height (0 for 256)
  header[off++] = 0;
  // color count
  header[off++] = 0;
  // reserved
  header[off++] = 0;
  // planes (WORD) little endian
  off = toUint16LE(1, header, off);
  // bitcount (WORD)
  off = toUint16LE(32, header, off);
  // bytes in resource (DWORD)
  off = toUint32LE(png.length, header, off);
  // image offset (DWORD) - header size = 6 + 16 = 22
  off = toUint32LE(6 + 16, header, off);

  final outFile = File('windows/runner/resources/app_icon.ico');
  outFile.createSync(recursive: true);
  final outSink = outFile.openSync(mode: FileMode.write);
  outSink.writeFromSync(header);
  outSink.writeFromSync(png);
  outSink.closeSync();

  stdout.writeln('Wrote ${outFile.path} (${png.length} bytes)');
}
