import 'dart:typed_data';

import '../../common/codable/binary.dart';
import '../../utils/ttf.dart';
import '../debugger.dart';
import 'coverage.dart';

const kLookupListTableSize = 4;

const _kDefaultSubtableList = [
  LigatureSubstitutionSubtable(1, 6, 0, [], kDefaultCoverageTable)
];

const _kDefaultLookupTableList = [
  LookupTable(4, 0, 1, [8], null, _kDefaultSubtableList)
];

abstract class SubstitutionSubtable implements BinaryCodable {
  const SubstitutionSubtable();

  factory SubstitutionSubtable.fromByteData(
    ByteData byteData, int offset, int lookupType
  ) {
    switch (lookupType) {
      case 4:
        return LigatureSubstitutionSubtable.fromByteData(byteData, offset);
      default:
        TTFDebugger.debugUnsupportedTableFormat('Lookup', lookupType);
        return null;
    }
  }

  int get maxContext;
}

class LigatureSubstitutionSubtable extends SubstitutionSubtable {
  const LigatureSubstitutionSubtable(
    this.substFormat,
    this.coverageOffset,
    this.ligatureSetCount,
    this.ligatureSetOffsets,
    this.coverageTable,
  );

  factory LigatureSubstitutionSubtable.fromByteData(
    ByteData byteData, 
    int offset
  ) {
    final coverageOffset = byteData.getUint16(offset + 2);
    final ligatureSetCount = byteData.getUint16(offset + 4);
    final subtableOffsets = List.generate(
      ligatureSetCount,
      (i) => byteData.getUint16(offset + 6 + 2 * i)
    );

    final coverageTable = CoverageTable.fromByteData(byteData, offset + coverageOffset);
    
    return LigatureSubstitutionSubtable(
      byteData.getUint16(offset),
      coverageOffset,
      ligatureSetCount,
      subtableOffsets,
      coverageTable,
    );
  }

  final int substFormat;
  final int coverageOffset;
  final int ligatureSetCount;
  final List<int> ligatureSetOffsets;

  final CoverageTable coverageTable;

  @override
  int get size => 6 + 2 * ligatureSetCount + coverageTable.size;

  /// NOTE: Should be calculated considering 'componentCount' of ligatures.
  /// 
  /// Not supported yet - generating 0 ligature sets by default.
  @override
  int get maxContext => 0;

  @override
  void encodeToBinary(ByteData byteData, int offset) {
    final coverageOffset = 6 + 2 * ligatureSetCount;

    byteData
      ..setUint16(offset, substFormat)
      ..setUint16(offset + 2, coverageOffset)
      ..setUint16(offset + 4, ligatureSetCount);

    for (int i = 0; i < ligatureSetCount; i++) {
      byteData.setInt16(offset + 6 + 2 * i, ligatureSetOffsets[i]);
    }

    coverageTable.encodeToBinary(byteData, offset + coverageOffset);
  }
}

class LookupTable implements BinaryCodable {
  const LookupTable(
    this.lookupType,
    this.lookupFlag,
    this.subTableCount,
    this.subtableOffsets,
    this.markFilteringSet,
    this.subtables,
  );

  factory LookupTable.fromByteData(
    ByteData byteData, 
    int offset
  ) {
    final lookupType = byteData.getUint16(offset);
    final lookupFlag = byteData.getUint16(offset + 2);
    final subTableCount = byteData.getUint16(offset + 4);
    final subtableOffsets = List.generate(
      subTableCount,
      (i) => byteData.getUint16(offset + 6 + 2 * i)
    );
    final useMarkFilteringSet = _useMarkFilteringSet(lookupFlag);
    final markFilteringSetOffset = offset + 6 + 2 * subTableCount;

    final subtables = List.generate(
      subTableCount,
      (i) => SubstitutionSubtable.fromByteData(
        byteData,
        offset + subtableOffsets[i],
        lookupType
      )
    );
    
    return LookupTable(
      lookupType,
      lookupFlag,
      subTableCount,
      subtableOffsets,
      useMarkFilteringSet ? byteData.getUint16(markFilteringSetOffset) : null,
      subtables,
    );
  }

  final int lookupType;
  final int lookupFlag;
  final int subTableCount;
  final List<int> subtableOffsets;
  final int markFilteringSet;

  final List<SubstitutionSubtable> subtables;

  static bool _useMarkFilteringSet(int lookupFlag) =>
    checkBitMask(lookupFlag, 0x0010);

  @override
  int get size {
    final subtableListSize = subtables.fold<int>(0, (p, t) => p + t.size);

    return 6 + 2 * subTableCount + subtableListSize;
  }

  @override
  void encodeToBinary(ByteData byteData, int offset) {
    byteData
      ..setUint16(offset, lookupType)
      ..setUint16(offset + 2, lookupFlag)
      ..setUint16(offset + 4, subTableCount);

    int currentRelativeOffset = 6 + 2 * subTableCount;
    final subtableOffsetList = <int>[];

    for (final subtable in subtables) {
      subtable.encodeToBinary(byteData, offset + currentRelativeOffset);
      subtableOffsetList.add(currentRelativeOffset);
      currentRelativeOffset += subtable.size;
    }

    for (int i = 0; i < subTableCount; i++) {
      byteData.setInt16(offset + 6 + 2 * i, subtableOffsetList[i]);
    }

    final useMarkFilteringSet = _useMarkFilteringSet(lookupFlag);

    if (useMarkFilteringSet) {
      byteData.setUint16(offset + 6 + 2 * subTableCount, markFilteringSet);
    }
  }
}

class LookupListTable implements BinaryCodable {
  LookupListTable(
    this.lookupCount,
    this.lookups,
    this.lookupTables
  );

  factory LookupListTable.fromByteData(ByteData byteData, int offset) {
    final lookupCount = byteData.getUint16(offset);
    final lookups = List.generate(
      lookupCount, 
      (i) => byteData.getUint16(offset + 2 + kLookupListTableSize * i)
    );
    final lookupTables = List.generate(
      lookupCount,
      (i) => LookupTable.fromByteData(byteData, offset + lookups[i])
    );
    
    return LookupListTable(lookupCount, lookups, lookupTables);
  }

  factory LookupListTable.create() => LookupListTable(1, [4], _kDefaultLookupTableList);

  final int lookupCount;
  final List<int> lookups;

  final List<LookupTable> lookupTables;

  @override
  int get size {
    final lookupListTableSize = lookupTables.fold<int>(0, (p, t) => p + t.size);

    return 2 + 2 * lookupCount + lookupListTableSize;
  }

  @override
  void encodeToBinary(ByteData byteData, int offset) {
    byteData.setUint16(offset, lookupCount);

    int tableRelativeOffset = 2 + 2 * lookupCount;

    for (int i = 0; i < lookupCount; i++) {
      final subtable = lookupTables[i]
        ..encodeToBinary(byteData, offset + tableRelativeOffset);

      byteData.setUint16(offset + 2 + 2 * i, tableRelativeOffset);
      tableRelativeOffset += subtable.size;
    }
  }
}