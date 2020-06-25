import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../ttf/table/head.dart';
import 'misc.dart';

const String kHeadTag = 'head';
const String kGSUBTag = 'GSUB';
const String kOS2Tag  = 'OS/2';
const String kCmapTag = 'cmap';
const String kGlyfTag = 'glyf';
const String kHheaTag = 'hhea';
const String kHmtxTag = 'hmtx';
const String kLocaTag = 'loca';
const String kMaxpTag = 'maxp';
const String kNameTag = 'name';
const String kPostTag = 'post';

const kPlatformUnicode   = 0;
const kPlatformMacintosh = 1;
const kPlatformWindows   = 3;

final _longDateTimeStart = DateTime.parse('1904-01-01T00:00:00.000Z');

String convertTagToString(Uint8List bytes) => 
  String.fromCharCodes(bytes);

Uint8List convertStringToTag(String string) {
  assert(string.length == 4, "Tag's length must be equal 4");
  return Uint8List.fromList(string.codeUnits);
}

bool checkBitMask(int value, int mask) => 
  (value & mask) == mask;

int calculateTableChecksum(ByteData encodedTable) {
  final length = (encodedTable.lengthInBytes / 4).floor();

  int sum = 0;

  for (int i = 0; i < length; i++) {
    sum = (sum + encodedTable.getUint32(4 * i)).toUnsigned(32);
  }

  final notAlignedBytesLength = encodedTable.lengthInBytes % 4;
  
  if (notAlignedBytesLength > 0) {
    final endBytes = [
      // Reading remaining bytes
      for (int i = 4 * length; i < encodedTable.lengthInBytes; i++)
        encodedTable.getUint8(i),

      // Filling with zeroes
      for (int i = 0; i < 4 - notAlignedBytesLength; i++)
        0,
    ];

    int endValue = 0;

    for (final byte in endBytes) {
      endValue <<= 8;
      endValue += byte;
    }

    sum = (sum + endValue).toUnsigned(32);
  }

  return sum;
}

int calculateFontChecksum(ByteData byteData) {
  return (kChecksumMagicNumber - calculateTableChecksum(byteData)).toUnsigned(32);
}

int getPaddedTableSize(int actualSize) => (actualSize / 4).ceil() * 4;

extension TTFByteDateExt on ByteData {
  int getFixed(int offset) => getUint16(offset);

  void setFixed(int offset, int value) => setUint16(offset, value);
  
  int getFWord(int offset) => getInt16(offset);

  void setFWord(int offset, int value) => setInt16(offset, value);

  int getUFWord(int offset) => getUint16(offset);

  void setUFWord(int offset, int value) => setUint16(offset, value);

  String getTag(int offset) {
    return convertTagToString(Uint8List.view(buffer, offset, 4));
  }
  
  void setTag(int offset, String tag) {
    int currentOffset = offset;
    convertStringToTag(tag).forEach((b) => setUint8(currentOffset++, b));
  }

  DateTime getDateTime(int offset) {
    return _longDateTimeStart.add(Duration(seconds: getInt64(offset)));
  }

  void setDateTime(int offset, DateTime dateTime) {
    setInt64(offset, dateTime.difference(_longDateTimeStart).inSeconds);
  }
}

extension TTFStringExt on String {
  String getAsciiPrintable() =>
    replaceAll(RegExp(r'([^\x00-\x7E]|[\(\[\]\(\)\{\}<>\/%])'), '');
}


@immutable
class Revision {
  const Revision(int major, int minor) : 
    major = major ?? 0, 
    minor = minor ?? 0;

  const Revision.fromInt32(int revision) 
  : major = (revision >> 16) & 0xFFFF,
    minor = revision & 0xFFFF;

  final int major;
  final int minor;

  int get int32value => major * 0x10000 + minor;

  @override
  int get hashCode => combineHashCode(major.hashCode, minor.hashCode);

  @override
  bool operator==(Object other) {
    if (other is Revision) {
      return major == other.major && minor == other.minor;
    }

    return false;
  }
}