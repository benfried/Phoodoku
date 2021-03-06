library sudoku; 

import "dart:math" as Math;

wrap(value, fn(x)) => fn(value);

order(List seq, {Comparator by, List<Comparator> byAll, on(x), List<Function> onAll}) =>
  by != null ? 
    (seq..sort(by)) 
  : byAll != null ?
    (seq..sort((a,b) => byAll
      .firstWhere((compare) => compare(a,b) != 0, orElse:() => (x,y) => 0)(a,b)))
  : on != null ? 
    (seq..sort((a,b) => on(a).compareTo(on(b)))) 
  : onAll != null ?
    (seq..sort((a,b) =>
      wrap(onAll.firstWhere((_on) => _on(a).compareTo(_on(b)) != 0, orElse:() => (x) => 0),
        (_on) => _on(a).compareTo(_on(b)) 
    ))) 
  : (seq..sort()); 

List<List> zip(List a, List b) {
  var n = Math.min(a.length, b.length);
  var z = new List(n);
  for (var i=0; i<n; i++)
    z[i] = [a.elementAt(i), b.elementAt(i)];
  return z;
}

String repeat(String s, int n) {
  var sb = new StringBuffer();
  for (var i=0; i<n; i++)
    sb.write(s);
  return sb.toString();
}

String center(String s, int max, [String pad=" "]) {
  var padLen = max - s.length;
  if (padLen <= 0) return s;
  
  s = repeat(pad, (padLen~/2)) + s;
  return s + repeat(pad, max-s.length);
}
 
Map dict(Iterable seq) => seq.fold({}, (map, kv) => map..putIfAbsent(kv[0], () => kv[1]));
dynamic some(Iterable seq) => seq.firstWhere((e) => e != null, orElse:() => null);
bool all(Iterable seq) => seq.every((e) => e != null);

Math.Random rand = new Math.Random();
List shuffled(Iterable seq) => order(seq.toList(), on:(a) => rand.nextDouble());

log(s) {
  print(s);
  return s;
}
List<String> cross(String A, String B) =>
  A.split('').expand((a) => B.split('').map((b) => a+b)).toList();  

const String digits   = '123456789';
const String rows     = 'ABCDEFGHI';
const String cols     = digits;
final List<String> squares = cross(rows, cols);

final List unitlist = cols.split('').map((c) => cross(rows, c)).toList()
  ..addAll( rows.split('').map((r) => cross(r, cols)))
  ..addAll( ['ABC','DEF','GHI'].expand((rs) => ['123','456','789'].map((cs) => cross(rs, cs)) ));

final Map units = dict(squares.map((s) => 
    [s, unitlist.where((u) => u.contains(s)).toList()] ));

final Map peers = dict(squares.map((s) => 
    [s, units[s].expand((u) => u).toSet()..removeAll([s])]));    

/// Parse a Grid
Map parseGrid(String grid){
  var values = dict(squares.map((s) => [s, digits]));
  var gv = gridValues(grid);
  for (var s in gv.keys){
    var d = gv[s];
    if (digits.contains(d) && assign(values, s, d) == null)
      return null;
  }
  return values;
}

Map gridValues(String grid){
  var chars = grid.split('').where((c) => digits.contains(c) || '0.'.contains(c)).toList();
  return dict(zip(squares, chars));
}

/// Constraint Propagation
Map assign(Map values, String s, String d){
  var otherValues = values[s].replaceAll(d, '');
//  print("$s, $d, $other_values");
  if (all(otherValues.split('').map((d2) => eliminate(values, s, d2))))
    return values;
  return null;
}

Map eliminate(Map values, String s, String d){
  if (!values[s].contains(d))
    return values;
  values[s] = values[s].replaceAll(d,'');
  if (values[s].length == 0)
    return null;
  else if (values[s].length == 1){
    var d2 = values[s];
    if (!all(peers[s].map((s2) => eliminate(values, s2, d2))))
      return null;
  }
  for (var u in units[s]){
    var dplaces = u.where((s) => values[s].contains(d)); 
    if (dplaces.length == 0)
      return null;
    else if (dplaces.length == 1)
      if (assign(values, dplaces.elementAt(0), d) == null)
        return null;
  }
  return values;
}

/// Display as 2-D grid
/// bf: give dart type checker the hint that values is a map from string to string
void display(Map<String, String> values) {
  var width = 1 + squares.map((s) => values[s].length).reduce(Math.max);
  var line = repeat('+' + repeat('-', width*3), 3).substring(1);  
  rows.split('').forEach((r){
    print(cols.split('').map((c) => center(values[r+c], width) + ('36'.contains(c) ? '|' : '')).toList()
      .join(''));
    if ('CF'.contains(r))
      print(line);
  });
  print("");  
}

/// Search 
Map solve(String grid) => search(parseGrid(grid));

Map search(Map values){
  if (values == null)
    return null;
  if (squares.every((s) => values[s].length == 1))
    return values;
  var s2 = order(squares.where((s) => values[s].length > 1).toList(), on:(s) => values[s].length).first;
  return some(values[s2].split('').map((d) => search(assign(new Map.from(values), s2, d))));
}