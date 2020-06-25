import 'dart:typed_data';

import '../../common/codable/binary.dart';
import '../../utils/ttf.dart';
import 'language_system.dart';

const kScriptRecordSize = 6;

/// Alphabetically ordered (by tag) list of script records
final _defaultScriptRecordList = [
  /// Default
  ScriptRecord('DFLT', null),
  
  /// Latin
  ScriptRecord('latn', null),
];

const _kDefaultLangSys = LanguageSystemTable(
  0,
  0xFFFF, // no required features
  1,
  [0]
);

const _kDefaultScriptTable = ScriptTable(
  4,
  0,
  [],
  [], 
  _kDefaultLangSys
);

class ScriptRecord implements BinaryCodable {
  ScriptRecord(
    this.scriptTag,
    this.scriptOffset
  );

  factory ScriptRecord.fromByteData(ByteData byteData, int offset) {    
    return ScriptRecord(
      convertTagToString(Uint8List.view(byteData.buffer, offset, 4)),
      byteData.getUint16(offset + 4),
    );
  }

  final String scriptTag;
  int scriptOffset;

  @override
  int get size => kScriptRecordSize;

  @override
  void encodeToBinary(ByteData byteData, int offset) {
    byteData
      ..setTag(offset, scriptTag)
      ..setUint16(offset + 4, scriptOffset);
  }
}

class ScriptTable implements BinaryCodable {
  const ScriptTable(
    this.defaultLangSysOffset,
    this.langSysCount,
    this.langSysRecords,
    this.langSysTables,
    this.defaultLangSys,
  );

  factory ScriptTable.fromByteData(
    ByteData byteData, 
    int offset,
    ScriptRecord record
  ) {
    offset += record.scriptOffset;

    final defaultLangSysOffset = byteData.getUint16(offset);
    LanguageSystemTable defaultLangSys;
    if (defaultLangSysOffset != 0) {
      defaultLangSys = LanguageSystemTable.fromByteData(byteData, offset + defaultLangSysOffset);
    }

    final langSysCount = byteData.getUint16(offset + 2);
    final langSysRecords = List.generate(
      langSysCount,
      (i) => LanguageSystemRecord.fromByteData(byteData, offset + 4 + kLangSysRecordSize * i)
    );
    final langSysTables = langSysRecords
      .map((r) => LanguageSystemTable.fromByteData(byteData, offset + r.langSysOffset))
      .toList();
    
    return ScriptTable(
      defaultLangSysOffset,
      langSysCount,
      langSysRecords,
      langSysTables,
      defaultLangSys,
    );
  }

  final int defaultLangSysOffset;
  final int langSysCount;
  final List<LanguageSystemRecord> langSysRecords;

  final List<LanguageSystemTable> langSysTables;
  final LanguageSystemTable defaultLangSys;

  @override
  int get size {
    final recordListSize = langSysRecords.fold<int>(0, (p, r) => p + r.size);
    final tableListSize = langSysTables.fold<int>(0, (p, t) => p + t.size);

    return 4 + (defaultLangSys?.size ?? 0) + recordListSize + tableListSize;
  }

  @override
  void encodeToBinary(ByteData byteData, int offset) {
    byteData.setUint16(offset + 2, langSysCount);

    int recordOffset = offset + 4;
    int tableRelativeOffset = 4 + kLangSysRecordSize * langSysRecords.length;

    for (int i = 0; i < langSysRecords.length; i++) {
      final record = langSysRecords[i]
        ..langSysOffset = tableRelativeOffset
        ..encodeToBinary(byteData, recordOffset);

      final table = langSysTables[i]
        ..encodeToBinary(byteData, offset + tableRelativeOffset);

      recordOffset += record.size;
      tableRelativeOffset += table.size;
    }

    final defaultRelativeLangSysOffset = tableRelativeOffset;
    byteData.setUint16(offset, defaultRelativeLangSysOffset);

    defaultLangSys.encodeToBinary(byteData, offset + defaultRelativeLangSysOffset);
  }
}

class ScriptListTable implements BinaryCodable {
  ScriptListTable(
    this.scriptCount,
    this.scriptRecords,
    this.scriptTables
  );

  factory ScriptListTable.fromByteData(ByteData byteData, int offset) {
    final scriptCount = byteData.getUint16(offset);
    final scriptRecords = List.generate(
      scriptCount, 
      (i) => ScriptRecord.fromByteData(byteData, offset + 2 + kScriptRecordSize * i)
    );
    final scriptTables = List.generate(
      scriptCount,
      (i) => ScriptTable.fromByteData(byteData, offset, scriptRecords[i])
    );
    
    return ScriptListTable(scriptCount, scriptRecords, scriptTables);
  }

  factory ScriptListTable.create() {
    final scriptCount = _defaultScriptRecordList.length;

    return ScriptListTable(
      scriptCount,
      _defaultScriptRecordList,
      List.generate(scriptCount, (index) => _kDefaultScriptTable)
    );
  }

  final int scriptCount;
  final List<ScriptRecord> scriptRecords;

  final List<ScriptTable> scriptTables;

  @override
  int get size {
    final recordListSize = scriptRecords.fold<int>(0, (p, r) => p + r.size);
    final tableListSize = scriptTables.fold<int>(0, (p, t) => p + t.size);

    return 2 + recordListSize + tableListSize;
  }

  @override
  void encodeToBinary(ByteData byteData, int offset) {
    byteData.setUint16(offset, scriptCount);

    int recordOffset = offset + 2;
    int tableRelativeOffset = 2 + kScriptRecordSize * scriptCount;

    for (int i = 0; i < scriptCount; i++) {
      final record = scriptRecords[i]
        ..scriptOffset = tableRelativeOffset
        ..encodeToBinary(byteData, recordOffset);

      final table = scriptTables[i]
        ..encodeToBinary(byteData, offset + tableRelativeOffset);

      recordOffset += record.size;
      tableRelativeOffset += table.size;
    }
  }
}