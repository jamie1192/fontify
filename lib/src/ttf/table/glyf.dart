import 'dart:typed_data';

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

    for (int i = 0; i < numGlyphs + 1; i++) {
      final headerOffset = entry.offset + locationTable.glyphOffsets[i];
      final header = GlyphHeader.fromByteData(byteData, headerOffset);

      if (header.isComposite) {
        print('Composite glyph unsupported (glyph header offset $headerOffset)');
      } else {
        final glyph = SimpleGlyph.fromByteData(byteData, header);
        glyphList.add(glyph);
      }
    }

    return GlyphDataTable(entry, glyphList);
  }

  factory GlyphDataTable.fromGlyphs(List<SimpleGlyph> glyphList) {
    return GlyphDataTable(null, glyphList);
  }

  final List<SimpleGlyph> glyphList;

  int get size => 
    glyphList.fold<int>(0, (p, v) => p + v.size) 
    - (glyphList.isNotEmpty ? glyphList.last.size : 0); // TODO: last glyph's size not taken in table's length?
}