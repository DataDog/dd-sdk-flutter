// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import '../sr_data_models.dart';

class Diff {
  List<SRIntrementalAdd> adds;
  List<SRIncrementalUpdate> updates;
  List<SRIncrementalRemove> removes;

  bool get isEmpty => adds.isEmpty && updates.isEmpty && removes.isEmpty;

  Diff(this.adds, this.updates, this.removes);
}

class TableEntry {
  bool inNew;
  int? indexInOld;

  TableEntry(this.inNew, this.indexInOld);
}

class Entry {
  bool isTableReference;
  int id; // Can be either an entry into the table or an index into na or oa.

  Entry(this.isTableReference, this.id);
}

/// Computes a diff between two arrays.
///
/// This implementation is based on Paul Heckel's algorithm for finding
/// differences between files. It isolates differences in a way that corresponds
/// closely to our intuitive notion of difference (it finds the longest common
/// subsequence). It is computationally efficient: `O(n)` in time and memory.
///
/// Unlike original Heckel's algorithm, our implementation assumes that elements
/// are unique within each of two arrays. It means that all elements in
/// `oldArray` are guaranteed to have different `id` (same for `newArray`).
/// Elements with the same `id` can appear in both arrays, which indicates one
/// of two things determined by `newElement.isDifferent(than: oldElement)`:
/// - either the element was not altered and can be skipped in diff,
/// - or the element was changed and it should be reflected in `Diff.Update`.
///
/// Like original algorithm, our implementation uses 6 passes over both arrays
/// to determine diff
///
/// Ref.:
/// - _"A technique for isolating differences between files"_ Paul Heckel (1978)
///   - https://dl.acm.org/citation.cfm?id=359467
///
/// - Parameters:
///   - oldArray: original array
///   - newArray: new array
/// - Returns: `Diff` describing changes from `oldArray` to `newArray`.
Diff computeDiff(List<SRWireframe> oldArray, List<SRWireframe> newArray) {
  var table = <int, TableEntry>{};
  var oldEntries = <Entry>[];
  var newEntries = <Entry>[];

  // 1st pass
  // Read `newArray` and store info on each element in symbols `table`:
  for (final e in newArray) {
    table[e.id] = TableEntry(true, null);
    newEntries.add(Entry(true, e.id));
  }

  // 2nd pass
  // Read `oldArray` and store info on each element in symbols `table`. If certain element already
  // exists, update its information (otherwise create new entry):
  for (var i = 0; i < oldArray.length; ++i) {
    final e = oldArray[i];
    final tableEntry = table[e.id];
    if (tableEntry != null) {
      tableEntry.indexInOld = i;
    } else {
      table[e.id] = TableEntry(false, e.id);
    }
    oldEntries.add(Entry(true, e.id));
  }

  // 3rd pass
  // Uses "Observation 1":
  // > If a line occurs only once in each file, then it must be the same line, although it may have been moved.
  // > We use this observation to locate unaltered lines that we subsequently exclude from further treatment.
  for (var i = 0; i < newEntries.length; ++i) {
    final entry = newEntries[i];
    if (entry.isTableReference) {
      final tableEntry = table[entry.id];
      if (tableEntry == null) {
        // TODO: Make a better error
        throw Error();
      }
      if (tableEntry.inNew) {
        final oldIndex = tableEntry.indexInOld;
        if (oldIndex != null) {
          newEntries[i] = Entry(false, oldIndex);
          oldEntries[oldIndex] = Entry(false, i);
        }
      }
    }
  }

  // 4th pass
  // > If a line has been found to be unaltered, and the lines immediately adjacent to it in both files are identical,
  // > then these lines must be the same line. This information can be used to find blocks of unchanged lines.
  for (var i = 0; i < newEntries.length - 1; ++i) {
    final currentEntry = newEntries[i];
    final j = currentEntry.id;
    if (!currentEntry.isTableReference && (j + 1) < oldEntries.length) {
      final nextNewEntry = newEntries[i + 1];
      final nextOldEntry = oldEntries[j + 1];
      if (nextNewEntry.isTableReference &&
          nextOldEntry.isTableReference &&
          nextNewEntry.id == nextOldEntry.id) {
        newEntries[i + 1] = Entry(false, j + 1);
        oldEntries[j + 1] = Entry(false, i + 1);
      }
    }
  }

  // 5th pass
  // Similar to 4th pass, except it processes entries in descending order.
  for (var i = newEntries.length - 1; i > 1; --i) {
    final currentEntry = newEntries[i];
    final j = currentEntry.id;
    if (!currentEntry.isTableReference && (j - 1) < oldEntries.length) {
      final nextNewEntry = newEntries[i - 1];
      final nextOldEntry = oldEntries[j - 1];
      if (nextNewEntry.isTableReference &&
          nextOldEntry.isTableReference &&
          nextNewEntry.id == nextOldEntry.id) {
        newEntries[i - 1] = Entry(false, j - 1);
        oldEntries[j - 1] = Entry(false, i - 1);
      }
    }
  }

  // Final pass
  // Constructing the actual diff from information stored in `oldEntries` and `newEntries`.
  var adds = <SRIntrementalAdd>[];
  var removes = <SRIncrementalRemove>[];
  var updates = <SRIncrementalUpdate>[];

  var removalOffsets = List<int>.filled(oldArray.length, 0);
  var runningOffset = 0;

  for (int i = 0; i < oldEntries.length; ++i) {
    final entry = oldEntries[i];
    removalOffsets[i] = runningOffset;
    if (entry.isTableReference) {
      removes.add(SRIncrementalRemove(id: oldArray[i].id));
      runningOffset += 1;
    }
  }

  runningOffset = 0;
  for (int i = 0; i < newEntries.length; ++i) {
    final entry = newEntries[i];
    if (entry.isTableReference) {
      final previousId = i > 0 ? newArray[i - 1].id : null;
      adds.add(
        SRIntrementalAdd(previousId: previousId, wireframe: newArray[i]),
      );
    } else {
      final indexInOld = entry.id;
      final removalOffset = removalOffsets[indexInOld];
      final newElement = newArray[i];
      final oldElement = oldArray[indexInOld];

      if ((indexInOld - removalOffset + runningOffset) != i) {
        // Old element was moved to another position
        final previousId = i > 0 ? newArray[i - 1].id : null;
        removes.add(SRIncrementalRemove(id: newArray[i].id));
        adds.add(
          SRIntrementalAdd(previousId: previousId, wireframe: newArray[i]),
        );
      } else if (newElement.isDifferent(oldElement)) {
        final mutations = newElement.mutationsFrom(oldElement);

        updates.add(mutations);
      }
    }
  }

  return Diff(adds, updates, removes);
}
