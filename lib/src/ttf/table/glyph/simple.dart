import 'dart:typed_data';

import 'flag.dart';
import 'header.dart';

class SimpleGlyph {
  SimpleGlyph(
    this.header,
    this.endPtsOfContours,
    this.instructions,
    this.flags,
    this.xCoordinates,
    this.yCoordinates
  );

  factory SimpleGlyph.fromByteData(ByteData byteData, GlyphHeader header) {
    int offset = header.offset + kGlyphHeaderSize;

    final endPtsOfContours = [
      for (int i = 0; i < header.numberOfContours; i++)
        byteData.getUint16(offset + i * 2)
    ];
    offset += header.numberOfContours * 2;

    final instructionLength = byteData.getUint16(offset);
    offset += 2;

    final instructions = [
      for (int i = 0; i < instructionLength; i++)
        byteData.getUint8(offset + i)
    ];
    offset += instructionLength;

    final numberOfPoints = endPtsOfContours.isNotEmpty ? endPtsOfContours.last + 1 : 0;
    final flags = <SimpleGlyphFlag>[];

    for (int i = 0; i < numberOfPoints; i++) {
      final flag = SimpleGlyphFlag.fromByteData(byteData, offset);
      offset += flag.size;
      flags.add(flag);

      for (int j = 0; j < flag.repeatTimes; j++) {
        flags.add(flag);
      }

      i += flag.repeatTimes;
    }

    final xCoordinates = <int>[];

    for (int i = 0; i < numberOfPoints; i++) {
      final short = flags[i].xShortVector;
      final same = flags[i].xIsSameOrPositive;
      
      if (short) {
        xCoordinates.add((same ? 1 : -1) * byteData.getUint8(offset++));
      } else {
        if (same) {
          xCoordinates.add(0);
        } else {
          xCoordinates.add(byteData.getInt16(offset));
          offset += 2;
        }
      }
    }
    
    final yCoordinates = <int>[];

    for (int i = 0; i < numberOfPoints; i++) {
      final short = flags[i].yShortVector;
      final same = flags[i].yIsSameOrPositive;
      
      if (short) {
        yCoordinates.add((same ? 1 : -1) * byteData.getUint8(offset++));
      } else {
        if (same) {
          yCoordinates.add(0);
        } else {
          yCoordinates.add(byteData.getInt16(offset));
          offset += 2;
        }
      }
    }
    
    int x = 0, y = 0;
    for (int i = 0; i < numberOfPoints; i++) {
      x += xCoordinates[i];
      xCoordinates[i] = x;

      y += yCoordinates[i];
      yCoordinates[i] = y;
    }
    
    return SimpleGlyph(
      header,
      endPtsOfContours,
      instructions,
      flags,
      xCoordinates,
      yCoordinates
    );
  }

  final GlyphHeader header;
  final List<int> endPtsOfContours;
  final List<int> instructions;
  final List<SimpleGlyphFlag> flags;
  final List<int> xCoordinates;
  final List<int> yCoordinates;
}