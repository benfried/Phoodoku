// Solve Every Sudoku Puzzle in Dart, optimized version
// A translation of: http://norvig.com/sudopy.shtml
// Translated and optimized by Brian Slesinsky

// See http://norvig.com/sudoku.html

// Throughout this program we have:
//   r is a row,     e.g. 'A'
//   c is a column,  e.g. '3'
//   s is a Square,  e.g. 'A3'
//   d is a Digit,   e.g. '9'
//   u is a Unit,    e.g. ['A1','B1','C1','D1','E1','F1','G1','H1','I1']
//   grid is a grid, e.g. 81 non-blank chars, e.g. starting with '.18...7...'
//   p is a Puzzle containing possible values for each square.

import 'dart:async' as async;
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:convert' as convert;

const rows = "ABCDEFGHI";
const cols = "123456789";

/// A Square is a key pointing to a square in the Sudoku grid.
class Square implements Comparable<Square> {
  final int index;
  final String col;
  final String row;
  
  Square.fromIndex(int i) : 
    index = i, 
    col = cols[i % cols.length], 
    row = rows[i ~/ cols.length];
  
  int compareTo(Square other) => Comparable.compare(index, other.index); 
  String toString() => row + col;
}

final squares = new List.generate(rows.length * cols.length, (i) => new Square.fromIndex(i));
final squaresByName = new Map.fromIterable(squares, key: (k) => k.toString());

/// A Unit is a set of Squares that must contain the digits 1-9.
class Unit {
  final List<Square> members;
  Unit(String rows, String cols) : 
    members = new List<Square>.from(squares.where((s) => rows.contains(s.row) && cols.contains(s.col)));
  bool contains(Square s) => members.contains(s);
  String toString() => "Unit(${members.join(", ")})";
}

final unitlist = new List<Unit>()
  ..addAll(rows.split("").map((r) => new Unit(r, cols)))
  ..addAll(cols.split("").map((c) => new Unit(rows, c)))
  ..addAll(["ABC", "DEF", "GHI"].expand((cs) => ["123", "456", "789"].map((rs) => new Unit(cs, rs))));

final units = new Map<Square, List<Unit>>.fromIterable(squares,
    value: (s) => new List.from(unitlist.where((u) => u.contains(s))));
final peers = new Map<Square, List<Square>>.fromIterable(squares,
    value: (s) => (new Set<Square>()..addAll(units[s].expand((u) => u.members))..remove(s)).toList()..sort());

const DIGIT_NAMES = "123456789";

/// A Digit is a possible value of a Square in a solved puzzle. When a puzzle is not yet solved,
/// we represent the set of digits that might appear in each square as a bitset.
class Digit implements Comparable<Digit> {
  static final all = new List<Digit>.from(DIGIT_NAMES.split("").map((d) => new Digit(d)));

  // The empty set contains no digits (as a bitset).
  static final int emptySet = 0;
  
  // The set of all possible digits (as a bitset).
  static final int allSet = all.map((d) => d.set).reduce((b1, b2) => b1 | b2);
  
  final String name;
  final int set; // The set containing only this digit, as a bitset with a single bit turned on.
  
  Digit(String digit) :
    name = digit,
    set = 1 << DIGIT_NAMES.indexOf(digit) {
    assert(DIGIT_NAMES.indexOf(digit) != -1);
  }
  
  // Returns true if this digit is a member of the given set of digits, represented as a bitset.
  bool present(int bitset) => (bitset & this.set) != 0;
  
  // Returns a new set of digits with this digit removed.
  int removeFrom(int bitset) => bitset & ~this.set;
  
  int compareTo(Digit other) => Comparable.compare(name, other.name);  
  String toString() => "Digit($name)";
  
  static List<Digit> setToList(int bitset) => new List.from(all.where((d) => d.present(bitset)));
  
  static String setToString(int bitset) => setToList(bitset).map((d) => d.name).join("");
}

// Unit tests

void test() {
  print("running tests");
  assert(squares.length == 81);
  assert(unitlist.length == 27);
  assert(squares.every((s) => units[s].length == 3));
  assert(squares.every((s) => peers[s].length == 20));
  assert(units[squaresByName["C2"]].toString() ==
      "[Unit(C1, C2, C3, C4, C5, C6, C7, C8, C9), " + 
      "Unit(A2, B2, C2, D2, E2, F2, G2, H2, I2), " + 
      "Unit(A1, A2, A3, B1, B2, B3, C1, C2, C3)]"); 
  assert(peers[squaresByName["C2"]].toString() ==
      "[A1, A2, A3, B1, B2, B3, C1, C3, C4, C5, C6, C7, C8, C9, D2, E2, F2, G2, H2, I2]"); 

  assert(Digit.all.length == 9);
  assert(Digit.setToString(Digit.emptySet) == "");
  assert(Digit.setToString(Digit.allSet) == "123456789");
  for (Digit d in Digit.all) {
    assert(Digit.setToString(d.set) == d.name);
  }
  assert(Digit.setToString(new Digit("2").removeFrom(Digit.allSet)) == "13456789");
  print('All tests pass.');
}

// Puzzles

/// Convert a grid into a map from Squares to digit names with '0' or '.' for empties.
Map<Square, String> gridValues(String grid) {
  // first make sure that what we were given only has [.0-9]
  Iterable<String> chars = List.from(grid.split("").where((c) => DIGIT_NAMES.contains(c) || "0.".contains(c)));
  assert(chars.length == 81);                       // if chars is not 81, the argument wasn't a valid puzzle
  return Map<Square,String>.fromIterables(squares, chars);
}

/// A Puzzle is a set of solutions (possibly empty) to a Sudoku puzzle.
/// We represent it as a map from a Square to a set of allowed Digits for that square.
/// (For efficiency, the map is actually a List and each set is represented as a bitset and stored in an int.)
class Puzzle {
  /// The key is a Square.index and the value is composed by doing a bitwise OR of Digit.set fields.
  final List<int> bitsets;
  /// Number of possible digits remaining for the given square.
  final List<int> digitCount;


  /// in a blank puzzle, each position can be filled by any of the 9 digits, so bitsets is set to 511 (all 8 bits set)
  /// the digitcount for each position is 9, meaning any of the digits 1-9 can go there
  Puzzle.blank() : 
    bitsets = new List.filled(rows.length * cols.length, Digit.allSet),
    digitCount = new List.filled(rows.length * cols.length, 9);
  
  Puzzle.copy(Puzzle original) :
    bitsets = List<int>.from(original.bitsets, growable:false),
    digitCount = List<int>.from(original.digitCount, growable:false);
  
  /// Parses a grid into a Puzzle. Returns null if the puzzle cannot be solved.
  /// (Otherwise we don't know yet.)
  factory Puzzle.parse(String grid) {  
    var p = new Puzzle.blank();
    gridValues(grid).forEach((s,d) {
      if (p != null && DIGIT_NAMES.contains(d)) {
        p = p.assign(s, new Digit(d)) ? p : null;
      }
    });
    return p;
  }
  
  /// Returns true if a digit is present in the given square.
  bool present(Square s, Digit d) => d.present(bitsets[s.index]);
  
  /// Returns the possible digits for the given square.
  List<Digit> choices(Square s) => Digit.setToList(bitsets[s.index]);

  /// Returns the possible digits for the given square as a string.
  String choicesString(Square s) => Digit.setToString(bitsets[s.index]);
  
  /// Sets the value in the given square to the given digit.
  /// Returns false if as a result, the Puzzle is unsolvable.
  /// If false is returned, the Puzzle should no longer be used.
  bool assign(Square s, Digit d) {
    int toRemove = d.removeFrom(bitsets[s.index]);
    for (Digit d in Digit.all) {
      if (d.present(toRemove) && !eliminate(s, d)) {
        return false;
      }
    }
    return true;
  }

  /// Forbids the given digit from appearing in the given square.
  /// Returns false if as a result, the Puzzle is unsolvable.
  /// If false is returned, the Puzzle should no longer be used.
  bool eliminate(Square s, Digit d) {
    int before = bitsets[s.index];
    int after = d.removeFrom(before);
    if (before == after) {
      return true; // Already eliminated.
    }
    if (after == Digit.emptySet) {
      return false; // We've removed every possible digit from this square, so this square is unsolvable.
    }
    bitsets[s.index] = after; 
    
    int remainingCount = digitCount[s.index] - 1;
    digitCount[s.index] = remainingCount;

    // (1) If there is one digit remaining, this square is solved.
    if (remainingCount == 1) {      
      for (Digit d2 in Digit.all) {
        if (d2.present(after)) {
          // Remove it from all its peers.
          if (!peers[s].every((s2) => eliminate(s2, d2))) {
            return false;
          }
          break;
        }
      }
    }
              
    // (2) If a unit u is reduced to only one place for a value d, then put it there.
    for (Unit u in units[s]) {
      Square dplace;
      int dplaceCount = 0;
      for (var s2 in u.members) {
        if (present(s2, d)) {
          dplaceCount++;
          if (dplaceCount > 1) {
            break; // Digit is in more than once place; doesn't matter how many.
          }
          dplace = s2;
        }
      }
      if (dplaceCount == 0) {
        return false; // Contradiction: no place for this value
      } else if (dplaceCount == 1) {
        // d can only be in one place in unit; assign it there
        if (!assign(dplace, d)) {
          return false;
        }
      }
    }
    return true;  
  }
  
  /// A puzzle is solved if each unit is solved.
  bool solved() {
    return unitlist.every((u) => solvedUnit(u));
  }

  /// A unit is solved if every square is solved and they contain a permutation of the digits 1 to 9.
  bool solvedUnit(Unit u) {
    List<Square> squares = new List.from(u.members.where((s) => solvedSquare(s)));
    if (squares.length != 9) {
      return false;
    }
    List<Digit> digits = new List.from(squares.map((s) => choices(s).single));
    digits.sort();
    return DIGIT_NAMES == digits.map((d) => d.name).join("");
  }
      
  /// A square is solved if there is one possible digit.
  bool solvedSquare(Square s) => digitCount[s.index] == 1;

  /// Returns the unsolved square with the fewest possible digits, or null if the puzzle is solved.
  Square minUnsolved() {
    Square best;
    int bestCount = 10;
    for (var s in squares) {
      int count = digitCount[s.index];
      if (count == 2) {
        return s;
      } else if (count > 1 && count < bestCount) {
        best = s;
        bestCount = count;
      }
    }
    return best;
  }

  /// Formats the puzzle as a 2-D grid.
  String toString() {
    int width = 1 + squares.map((s) => choicesString(s).length).reduce(math.max);
    final separatorLine = repeat(repeat("-", 3 * width), 3, join: "+") + "\n";
    StringBuffer out = new StringBuffer();
    out.write("\n");
    for (var s in squares) {
      out.write(center(choicesString(s), width));
      if ("36".contains(s.col)) {
        out.write("|");
      } else if (s.col == "9") {
        out.write("\n");
        if ("CF".contains(s.row)) {
          out.write(separatorLine);
        }
      }
    }
    return out.toString();
  }
}

// Search

Puzzle solve(String grid) {
  return search(new Puzzle.parse(grid));
}

Puzzle search(Puzzle p) {
  if (p == null) {
    return null;
  }
  if (squares.every((s) => p.solvedSquare(s))) {
    return p;
  }
  Square minS = p.minUnsolved();
  for (Digit d in p.choices(minS)) {
    var p2 = new Puzzle.copy(p);
    if (p2.assign(minS, d)) {
      var answer = search(p2);
      if (answer != null) {
        return answer;
      }
    }
  }
  return null;  
}

// Utilities

String repeat(String s, int times, {String join: ""}) => new List.filled(times, s).join(join); 

String center(String s, int width) {
  var before = repeat(" ", (width - s.length)~/2);
  var after = repeat(" ", width);
  return (before + s + after).substring(0, width);  
}

/// Copies a list. This is a bit faster than List.from().
List copyList(List original) {
  var copy = new List(original.length);
  for (int i = 0; i < original.length; i++) {
    copy[i] = original[i];
  }
  return copy;
}

/// Parse a file into a list of strings, separated by sep.
async.Future<List<String>> fromFile(String filename, {String sep: '\n'}) {
  var result = new async.Completer<List<String>>();
  new io.File(filename).readAsString(encoding: convert.ascii).then((contents) {
    result.complete(contents.trim().split(sep));        
  });
  return result.future;
}

final random = new math.Random();

/// Returns a randomly shuffled copy of the input list.
List shuffled(List source) {
  var out = new List(source.length);
  for (var i = 0; i < out.length; i++) {
    var j = random.nextInt(i + 1);
    out[i] = out[j];
    out[j] = source[i];
  }
  return out;
}

// System test

/// Attempt to solve a sequence of grids. Report results.
/// When showif is a number of seconds, display puzzles that take longer.
/// When showif is null, don't display any puzzles."""
void solveAll(List<String> grids, {String name: "", num showif: 0.0}) {
  fmt(num secs) => secs.toStringAsFixed(2);
  num sumTimes = 0;
  num maxTime = 0;
  int solvedCount = 0;
  timeSolve(String grid) {
    var clock = new Stopwatch()..start();
    Puzzle p = solve(grid);
    num t = clock.elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (showif != null && t > showif) {
      print(new Puzzle.parse(grid));
      if (p != null) {
        print('(${fmt(t)} seconds)');
      }
    }
    sumTimes += t;
    if (t > maxTime) {
      maxTime = t;
    }
    solvedCount += p != null && p.solved() ? 1 : 0;
  }
  grids.forEach(timeSolve);
  var n = grids.length;
  if (n > 1) {
    print("Solved $solvedCount of $n $name puzzles (avg ${fmt(sumTimes/n)} secs (${n~/sumTimes} Hz), max $maxTime secs)");  
  }
}

/// Make a random puzzle with N or more assignments. Restart on contradictions.
/// Note the resulting puzzle is not guaranteed to be solvable, but empirically
/// about 99.8% of them are solvable. Some have multiple solutions.
String randomPuzzle({int n: 17}) {
  var p = new Puzzle.blank();
  for (var s in shuffled(squares)) {
    var choices = p.choices(s);
    var choice = choices[random.nextInt(choices.length)];
    if (!p.assign(s, choice)) {
      break;
    }
    var ds = squares.where((s) => p.solvedSquare(s));
    if (ds.length >= n && new Set.from(ds).length >= 8) {
      return squares.map((s) => p.solvedSquare(s) ? p.choices(s).single.toString() : ".").join("");
    } 
  }
  return randomPuzzle(n: n); // Give up and make a new puzzle.
}

var grid1 = '003020600900305001001806400008102900700000008006708200002609500800203009005010300';
var grid2 = '4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......';
var hard1 = '.....6....59.....82....8....45........3........6..3.54...325..6..................';

void main() {
  test();
  solveAll([grid1, grid2], showif: null);
  // solve_all([hard1]);
  fromFile("top95.txt").then((grids) {
    solveAll(grids, name: "hard", showif: null);    
  }).then((x) => fromFile("hardest.txt")).then((grids) {
    solveAll(grids, name: "hardest", showif: null);        
  }).then((x) {
    solveAll(new List.generate(100, (i) => randomPuzzle()), name: "random", showif: 1.0);    
  });
}

// Output in checked mode:

// running tests
// All tests pass.
// Solved 2 of 2  puzzles (avg 0.01 secs (87 Hz), max 0.015466 secs)
// Solved 95 of 95 hard puzzles (avg 0.00 secs (300 Hz), max 0.017949 secs)
// Solved 11 of 11 hardest puzzles (avg 0.00 secs (982 Hz), max 0.001596 secs)
// Solved 100 of 100 random puzzles (avg 0.00 secs (1196 Hz), max 0.001503 secs)

// Output in unchecked more:
// running tests
// All tests pass.
// Solved 2 of 2  puzzles (avg 0.02 secs (40 Hz), max 0.045424 secs)
// Solved 95 of 95 hard puzzles (avg 0.00 secs (535 Hz), max 0.011086 secs)
// Solved 11 of 11 hardest puzzles (avg 0.00 secs (1908 Hz), max 0.000768 secs)
// Solved 100 of 100 random puzzles (avg 0.00 secs (2384 Hz), max 0.000849 secs)