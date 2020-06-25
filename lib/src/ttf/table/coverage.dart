import 'dart:typed_data';

import '../../common/codable/binary.dart';
import '../debugger.dart';

const kDefaultCoverageTable = CoverageTableFormat1(1, 0, []);

abstract class CoverageTable implements BinaryCodable {
  const CoverageTable();

  factory CoverageTable.fromByteData(ByteData byteData, int offset) {
    final format = byteData.getUint16(offset);

    switch (format) {
      case 1:
        return CoverageTableFormat1.fromByteData(byteData, offset);
      default:
        TTFDebugger.debugUnsupportedTableFormat('Coverage', format);
        return null;
    }
  }
}

class CoverageTableFormat1 extends CoverageTable {
  const CoverageTableFormat1(
    this.coverageFormat,
    this.glyphCount,
    this.glyphArray
  );

  factory CoverageTableFormat1.fromByteData(
    ByteData byteData,
    int offset
  ) {
    final coverageFormat = byteData.getUint16(offset);
    final glyphCount = byteData.getUint16(offset + 2);
    final glyphArray = List.generate(
      glyphCount,
      (i) => byteData.getUint16(offset + 4 + 2 * i)
    );

    return CoverageTableFormat1(
      coverageFormat,
      glyphCount,
      glyphArray
    );
  }

  final int coverageFormat;
  final int glyphCount;
  final List<int> glyphArray;

  @override
  int get size => 4 + 2 * glyphCount;

  @override
  void encodeToBinary(ByteData byteData, int offset) {
    byteData
      ..setUint16(offset, coverageFormat)
      ..setUint16(offset + 2, glyphCount);

    for (int i = 0; i < glyphCount; i++) {
      byteData.setInt16(offset + 4 + 2 * i, glyphArray[i]);
    }
  }
}