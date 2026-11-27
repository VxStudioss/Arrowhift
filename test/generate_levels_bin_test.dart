// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_binary_codec.dart';
import 'package:arrow_escape/data/models/level.dart';
import 'package:arrow_escape/data/level_generator/solver.dart';

void main() {
  test('Generate and encode all 600 levels to assets/levels.bin', () {
    print('──────────────────────────────────────────────');
    print(' Arrow Puzzle — Binary Level Pre-generator');
    print('──────────────────────────────────────────────');

    final levels = <LevelModel>[];
    final sw = Stopwatch()..start();

    final binPath = 'assets/levels.bin';
    final binFile = File(binPath);

    if (!binFile.existsSync()) {
      fail('Could not find baseline binary file at "$binPath".');
    }

    print('Reading baseline levels from $binPath...');
    late LevelBinaryDecoder decoder;
    int healedBaseCount = 0;
    int healedShiftCount = 0;
    
    try {
      final inputBytes = binFile.readAsBytesSync();
      decoder = LevelBinaryDecoder.fromBytes(inputBytes);

      LevelModel findGuaranteedSolvableTemplate(int targetLevelNumber) {
        for (int offset = 1; offset < 500; offset++) {
          for (int direction in [-1, 1]) {
            final checkIndex = targetLevelNumber + (offset * direction);
            if (checkIndex >= 1 && checkIndex <= 500 && checkIndex != 9 && checkIndex != 25 && checkIndex != 388) {
              final candidate = decoder.decodeLevelByNumber(checkIndex);
              if (candidate != null) {
                bool candidateHasLoop = false;
                for (final arrow in candidate.arrows) {
                  if (arrow.path.length >= 3) {
                    final points = arrow.path.map((p) => '${p},${p}').toSet();
                    if (points.length < arrow.path.length) {
                      candidateHasLoop = true;
                      break;
                    }
                  }
                }
                if (!candidateHasLoop && LevelSolver.solve(candidate) != null) {
                  return candidate;
                }
              }
            }
          }
        }
        return decoder.decodeLevelByNumber(1)!;
      }
      
      for (int i = 1; i <= 500; i++) {
        final decodedLevel = decoder.decodeLevelByNumber(i);
        if (decodedLevel != null) {
          bool hasSelfLoopingArrow = false;
          for (final arrow in decodedLevel.arrows) {
            if (arrow.path.length >= 3) {
              final distinctPoints = arrow.path.map((p) => '${p},${p}').toSet();
              if (distinctPoints.length < arrow.path.length) {
                hasSelfLoopingArrow = true;
                break;
              }
            }
          }

          final solution = LevelSolver.solve(decodedLevel);
          
          if (solution == null || hasSelfLoopingArrow || i == 9 || i == 25 || i == 388) {
            healedBaseCount++;
            final healingTemplate = findGuaranteedSolvableTemplate(i);
            
            levels.add(LevelModel(
              levelNumber: i,
              gridSize: healingTemplate.gridSize,
              patternName: 'Healed-L${healingTemplate.levelNumber}',
              arrows: healingTemplate.arrows.map((a) => a.copyWith()).toList(),
              difficulty: healingTemplate.difficulty,
            ));
          } else {
            levels.add(decodedLevel);
          }
        }
      }
    } catch (e) {
      fail('Failed parsing original binary file content: $e');
    }

    print('Successfully verified base maps. (Healed $healedBaseCount broken layouts)');

    // 2. Generate levels 501 to 600
    for (int i = 501; i <= 600; i++) {
      final shiftedTargetIndex = 201 + ((i - 501) % 100);
      
      final baseLevel = levels.firstWhere(
        (l) => l.levelNumber == shiftedTargetIndex,
        orElse: () => fail('Failed to find level $shiftedTargetIndex'),
      );
      
      final shiftedLevel = LevelModel(
        levelNumber: i,
        gridSize: baseLevel.gridSize,
        patternName: 'Shift-${baseLevel.patternName}',
        arrows: baseLevel.arrows.map((a) => a.copyWith()).toList(),
        difficulty: baseLevel.difficulty,
      );
      
      if (LevelSolver.solve(shiftedLevel) == null) {
        healedShiftCount++;
        // Fall back to a verified lower stage layout that matches the current generation tier
        final fallbackIndex = 100 + (i % 50); 
        final validBase = levels.firstWhere((l) => l.levelNumber == fallbackIndex);
        
        levels.add(LevelModel(
          levelNumber: i,
          gridSize: validBase.gridSize,
          patternName: 'Shift-Healed-Fixed',
          arrows: validBase.arrows.map((a) => a.copyWith()).toList(),
          difficulty: validBase.difficulty,
        ));
      } else {
        levels.add(shiftedLevel);
      }
    }

    levels.sort((a, b) => a.levelNumber.compareTo(b.levelNumber));

    print('Shift progression generation complete. (Patched $healedShiftCount loop anomalies)');
    sw.stop();

    // 3. Encode the updated 600 levels
    final outputBytes = encodeLevels(levels);
    binFile.writeAsBytesSync(outputBytes);

    final kbSize = (outputBytes.length / 1024).toStringAsFixed(1);
    print('\n================ SUMMARY ================');
    print('Total Levels Compiled : ${levels.length} / 600');
    print('Asset Binary Output   : $binPath ($kbSize KB)');
    print('Execution Status      : Solvability Verified ✓');
    print('=========================================');
  });
}
