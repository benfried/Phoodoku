// Solve Every Sudoku Puzzle in Dart
// A translation of: http://norvig.com/sudopy.shtml
// Translated by Brian Slesinsky

// See http://norvig.com/sudoku.html

// Throughout this program we have:
//   r is a row,     e.g. 'A'
//   c is a column,  e.g. '3'
//   s is a square,  e.g. 'A3'
//   d is a digit,   e.g. '9'
//   u is a unit,    e.g. ['A1','B1','C1','D1','E1','F1','G1','H1','I1']
//   grid is a grid, e.g. 81 non-blank chars, e.g. starting with '.18...7...'
//   values is a map of possible values, e.g. {'A1':'12349', 'A2':'8', ...}

import 'dart:async' as async;
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:convert' as convert;

/// Cross-product of the characters in as and the characters in bs.
List<String> cross(String as, String bs) {
  return new List<String>.from(as.split("").expand((a) => bs.split("").map((b) => a + b)));
}

const digits = "123456789";
const rows = "ABCDEFGHI";
const cols = digits;
final squares = cross(rows, digits);
final unitlist = new List<List<String>>()
  ..addAll(cols.split("").map((c) => cross(rows, c)))
  ..addAll(rows.split("").map((r) => cross(r, cols)))
  ..addAll(["ABC", "DEF", "GHI"].expand((c) => ["123", "456", "789"].map((r) => cross(c,r))));
final units = new Map<String, List<List<String>>>.fromIterable(squares,
    value: (s) => new List.from(unitlist.where((u) => u.contains(s))));
final peers = new Map<String, Set<String>>.fromIterable(squares,
    value: (s) => new Set<String>()..addAll(units[s].expand((u) => u))..remove(s));

// Unit tests

void test() {
  assert(squares.length == 81);
  assert(unitlist.length == 27);
  assert(squares.every((s) => units[s].length == 3));
  assert(squares.every((s) => peers[s].length == 20));
  assert(equal(units['C2'], 
      [['A2', 'B2', 'C2', 'D2', 'E2', 'F2', 'G2', 'H2', 'I2'],
       ['C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9'],
       ['A1', 'A2', 'A3', 'B1', 'B2', 'B3', 'C1', 'C2', 'C3']]));
  assert(equal(peers['C2'], new Set.from(
      ['A2', 'B2', 'D2', 'E2', 'F2', 'G2', 'H2', 'I2',
       'C1', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9',
       'A1', 'A3', 'B1', 'B3'])));
  print('All tests pass.');
}

// Parse a grid

/// Convert grid to a map of possible values, {square: digits}, or
/// return null if a contradiction is detected.
Map<String, String> parse_grid(String grid) {
  // To start, every square can be any digit; then assign values from the grid.
  var values = new Map.fromIterable(squares, value: (s) => digits);
  grid_values(grid).forEach((s,d) {
    if (values != null && digits.contains(d)) {
      values = assign(values, s, d);
    }
  });
  return values;
}

/// Convert grid into a map of {square: char} with '0' or '.' for empties.
Map<String, String> grid_values(String grid) {
  var chars = new List<String>.from(grid.split("").where((c) => digits.contains(c) || "0.".contains(c))).toList();
  assert(chars.length == 81);
  return new Map.fromIterables(squares, chars);
}

// Constraint propagation

/// Eliminate all the other values (except d) from values[s] and propagate.
/// Return values, except return null if a contradiction is detected.
Map<String, String> assign(Map<String, String> values, String s, String d) {
  var other_values = values[s].replaceAll(d, "");
  if (other_values.split("").every((d2) => eliminate(values, s, d2))) {
    return values;
  } else {
    return null;
  }
}

/// Eliminate d from values[s]; propagate when values or places <= 2.
/// Return values, except return null if a contradiction is detected.
bool eliminate(Map<String, String> values, String s, String d) {
  if (!values[s].contains(d)) {
    return true;
  }
  values[s] = values[s].replaceAll(d, "");
  // (1) If a square s is reduced to one value d2, then eliminate d2 from the peers.
  if (values[s].length == 0) {
    return false; // Contradiction: removed last value
  } else if (values[s].length == 1) {
    var d2 = values[s];
    if (!peers[s].every((s2) => eliminate(values, s2, d2))) {
      return false;
    }
  }
  // (2) If a unit u is reduced to only one place for a value d, then put it there.
  for (var u in units[s]) {
    var dplaces = new List.from(u.where((s) => values[s].contains(d)));
    if (dplaces.length == 0) {
      return false; // Contradiction: no place for this value
    } else if (dplaces.length == 1) {
      // d can only be in one place in unit; assign it there
      if (assign(values, dplaces.first, d) == null) {
        return false;
      }
    }
  }
  return true;  
}

// Display as a 2-D grid

/// Display these values as a 2-D grid.
void display(Map<String, String> values) {
  int width = 1 + squares.map((s) => values[s].length).reduce(math.max);
  repeat(s, times, {join: ""}) => new List.filled(times, s).join(join); 
  var line = repeat(repeat("-", 3 * width), 3, join: "+");
  center(s) => (repeat(" ", (width - s.length)~/2) + s + repeat(" ", width)).substring(0, width);
  for (var r in rows.split("")) {
    print(cols.split("").map((c) => center(values[r + c]) + ("36".contains(c) ? "|" : "")).join(""));
    if ("CF".contains(r)) {
      print(line);
    }
  }
}

// Search

Map<String, String> solve(String grid) => search(parse_grid(grid));

/// Using depth-first search and propagation, try all possible values.
Map<String, String> search(Map<String, String> values) {
  if (values == null) {
    return null; // Failed earlier.
  }
  if (squares.every((s) => values[s].length == 1)) {
    return values; // Solved!
  }
  // Choose the unfilled square s with the fewest possibilities.
  var minS = squares.where((s) => values[s].length > 1).reduce((s1,s2) => values[s1].length < values[s2].length ? s1 : s2);
  for (var d in values[minS].split("")) {
    var answer = search(assign(new Map.from(values), minS, d));
    if (answer != null) {
      return answer;
    }
  }
  return null;
}

// Utilities

/// Parse a file into a list of strings, separated by sep.
async.Future<List<String>> from_file(String filename, {String sep: '\n'}) {
  var result = new async.Completer();
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

/// Compare two values for equality. Works with lists, sets, strings, and numbers.
bool equal(var a, var b) {
  if (a is List && b is List) {
    return a.length == b.length && new List.generate(a.length, (i) => equal(a[i], b[i])).every((b) => b);
  } else if (a is Set && b is Set) {
    return a.length == b.length && a.every(b.contains);
  } else {
    return a==b;
  }
}

// System test

/// Attempt to solve a sequence of grids. Report results.
/// When showif is a number of seconds, display puzzles that take longer.
/// When showif is null, don't display any puzzles."""
void solve_all(List<String> grids, {String name: "", num showif: null}) {
  fmt(num secs) => secs.toStringAsFixed(2);
  num sumTimes = 0;
  num maxTime = 0;
  int solvedCount = 0;
  time_solve(String grid) {
    var clock = new Stopwatch()..start();
    var values = solve(grid);
    num t = clock.elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (showif != null && t > showif) {
      display(grid_values(grid));
      if (values != null) {
        print('(${fmt(t)} seconds)');
      }
    }
    sumTimes += t;
    if (t > maxTime) {
      maxTime = t;
    }
    solvedCount += solved(values) ? 1 : 0;
  }
  grids.forEach(time_solve);
  var n = grids.length;
  if (n > 1) {
    print("Solved ${solvedCount} of ${n} ${name} puzzles (avg ${fmt(sumTimes/n)} secs (${n~/sumTimes} Hz), max ${maxTime} secs)");  
  }
}

/// A puzzle is solved if each unit is a permutation of the digits 1 to 9.
bool solved(Map<String, String> values) {
  bool unitsolved(var unit) => equal(new Set.from(unit.map((s) => values[s])), new Set.from(digits.split("")));
  return values != null && unitlist.every(unitsolved);
}

/// Make a random puzzle with N or more assignments. Restart on contradictions.
/// Note the resulting puzzle is not guaranteed to be solvable, but empirically
/// about 99.8% of them are solvable. Some have multiple solutions.
String random_puzzle({int n: 17}) {
  var values = new Map.fromIterable(squares, value: (s) => digits);
  for (var s in shuffled(squares)) {
    if (assign(values, s, values[s][random.nextInt(values[s].length)]) == null) {
      break;
    }
    var ds = squares.where((s) => values[s].length == 1);
    if (ds.length >= n && new Set.from(ds).length >= 8) {
      return squares.map((s) => values[s].length == 1 ? values[s][0] : ".").join("");
    } 
  }
  return random_puzzle(n: n); // Give up and make a new puzzle.
}

var grid1 = '003020600900305001001806400008102900700000008006708200002609500800203009005010300';
var grid2 = '4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......';
var hard1 = '.....6....59.....82....8....45........3........6..3.54...325..6..................';

void main() {
  test();
  solve_all([grid1, grid2, hard1]);    
  from_file("top95.txt").then((grids) {
    solve_all(grids, name: "hard");    
  }).then((x) => from_file("hardest.txt")).then((grids) {
    solve_all(grids, name: "hardest");        
  }).then((x) {
    solve_all(new List.generate(100, (i) => random_puzzle()), name: "random", showif: 1.0);    
  });
}

/* Output:
All tests pass.
Solved 3 of 3  puzzles (avg 0.06 secs (16 Hz), max 0.129563 secs)
Solved 95 of 95 hard puzzles (avg 0.02 secs (53 Hz), max 0.111003 secs)
Solved 11 of 11 hardest puzzles (avg 0.01 secs (122 Hz), max 0.024414 secs)
Solved 100 of 100 random puzzles (avg 0.01 secs (176 Hz), max 0.005931 secs)
*/