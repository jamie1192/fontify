import 'dart:math' as math;
import 'dart:typed_data';

import '../debugger.dart';

import 'abstract.dart';
import 'glyph/header.dart';
import 'glyph/simple.dart';
import 'loca.dart';
import 'table_record_entry.dart';

class GlyphDataTable extends FontTable {
  GlyphDataTable(
    TableRecordEntry entry,
    this.glyphList,
  ) : super.fromTableRecordEntry(entry);

  factory GlyphDataTable.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
    IndexToLocationTable locationTable,
    int numGlyphs
  ) {
    final glyphList = <SimpleGlyph>[];

    for (int i = 0; i < numGlyphs; i++) {
      final headerOffset = entry.offset + locationTable.glyphOffsets[i];
      final nextHeaderOffset = entry.offset + locationTable.glyphOffsets[i + 1];
      final isEmpty = headerOffset == nextHeaderOffset;

      final header = GlyphHeader.fromByteData(byteData, headerOffset);

      if (header.isComposite) {
        TTFDebugger.debugUnsupportedFeature('Composite glyph (glyph header offset $headerOffset)');
      } else {
        final glyph = isEmpty ? SimpleGlyph.empty(header) : SimpleGlyph.fromByteData(byteData, header);
        glyphList.add(glyph);
      }
    }

    return GlyphDataTable(entry, glyphList);
  }

  factory GlyphDataTable.fromGlyphs(List<SimpleGlyph> glyphList) {
    return GlyphDataTable(null, glyphList);
  }

  final List<SimpleGlyph> glyphList;

  // TODO: subtract last glyph's size?
  @override
  int get size => glyphList.fold<int>(0, (p, v) => p + v.size);

  int get maxPoints =>
    glyphList.fold<int>(0, (p, g) => math.max(p, g.xCoordinates.length));

  int get maxContours =>
    glyphList.fold<int>(0, (p, g) => math.max(p, g.header.numberOfContours));

  int get maxSizeOfInstructions =>
    glyphList.fold<int>(0, (p, g) => math.max(p, g.instructions.length));

  @override
  void encodeToBinary(ByteData byteData) {
    // TODO: implement encode
    throw UnimplementedError();
  }
}