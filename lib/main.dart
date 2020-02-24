import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import 'package:Phoodoku/Board.dart';
import 'package:Phoodoku/skybrian2.dart';

void main() => runApp(new MyApp());

/// Steps: create a new puzzle and solve it, storing in p and solved
/// create a random puzzle (it's a string)
/// display puzzle-as-string in GUI
/// 

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Phoodoku',
      theme: new ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: new MyHomePage(
        title: 'Phoodoku'
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;
  
    @override
  HomePageState createState() => new HomePageState();
}

class HomePageState extends State<MyHomePage> {
  static String toImg(int s){
    return 'buttons/' + s.toString() + '.png';
  }

  Puzzle puzzle;

  List<List<int>> imgList = [
    [0,0,0,2,6,0,7,0,1],
    [6,8,0,0,7,0,0,9,0],
    [1,9,0,0,0,4,5,0,0],
    [8,2,0,1,0,0,0,4,0],
    [0,0,4,6,0,2,9,0,0],
    [0,5,0,0,0,3,0,2,8],
    [0,0,9,3,0,0,0,7,4],
    [0,4,0,0,5,0,0,3,6],
    [7,0,3,0,1,8,0,0,0],
  ];

  List<List<int>> initList = [
    [0,0,0,2,6,0,7,0,1],
    [6,8,0,0,7,0,0,9,0],
    [1,9,0,0,0,4,5,0,0],
    [8,2,0,1,0,0,0,4,0],
    [0,0,4,6,0,2,9,0,0],
    [0,5,0,0,0,3,0,2,8],
    [0,0,9,3,0,0,0,7,4],
    [0,4,0,0,5,0,0,3,6],
    [7,0,3,0,1,8,0,0,0],
  ];

  static int count = 0;
  static int cursor = 0;
  HashSet<RowCol> conflicts = new HashSet<RowCol>();

  void changeConflicts() {
    conflicts = Conflict.getConflicts(imgList);
  }

  static void changeCursor(i){
    cursor = i;
  }

  // Resets the whole board.
  void reset() {
    setState(() {
      imgList = new List<List<int>>.generate(9, (i) => new List<int>.from(initList[i]));
      changeConflicts();
    });
  }

  Color getHighlightColor(int r, int c) {
    bool isConflict = conflicts.contains(new RowCol(r, c));
    bool isChangable = initList[r][c] == 0;
    if (isConflict && !isChangable) return Colors.red[900];
    else if (isConflict)            return Colors.red[100];
    else if (!isChangable)          return Colors.grey;
    else                            return Colors.white;
  }

  List <TableRow> newGetTableRowList() {
    List<TableRow> _trl = List<TableRow>();
    for (int r = 0; r < 3; r++) {
      // make 9 3x3 subtables
      _trl.add(_newTableRow(r));
    }
    return _trl;
  }

  TableRow _newTableRow(int r) {
    List <Widget> _lst = List<Widget>();

    for (int c = 0; c < 3; c++) {
      // make the 3x3 table here
      _lst.add(_subTable(r, c));
    }
    return TableRow(children: _lst);
  }

  
  /// this is wrong, should be building & returning a table not a widget, and not returning a tablerow
  Table _subTable(int r, int c) {
    List<TableRow> _trl = List<TableRow>();
    for (int _r = (r*3); _r < (r*3) + 3; _r++) {
      List <Widget> _w = List<Widget>();
      for (int _c = c*3; _c < (c*3) + 3; _c++) {
        _w.add(Container(
          margin: const EdgeInsets.all(2.0),
          color:getHighlightColor(_r, _c),
          child: _iconButton(_r, _c)));
      }
      _trl.add(TableRow(children:_w));
    }
    return Table(children: _trl, 
                border: new TableBorder.all(
                      color: Colors.blueGrey,
                      width: 1.0)
    );
  }

  IconButton _iconButton(int r, int c) {
    return IconButton(
          icon: Image.asset(toImg(imgList[r][c])), 
          iconSize: 24.0,
          padding: EdgeInsets.all(3.0),
          onPressed: () {
            // should be: if puzzle[r][c] is unset, set it to the cursor
            if (initList[r][c] == 0) {
              setState(() {
                imgList[r][c] = cursor;
                changeConflicts();
              });
            }
          });
  }
  
      
  TableRow getKeyRow(int c) {
    List<Widget> lst = new List<Widget>();
    for (int i = 0; i <= 4; i++) {
      Color containerColor = Colors.white;
      if (cursor == i+c) containerColor = Colors.lightGreenAccent;
      lst.add(new Container(
        color: containerColor,
        child: new IconButton(
          icon: Image.asset('buttons/'+(i + c).toString()+'.png'),
          iconSize: 35.0,
          onPressed: () {
            setState(() {
              changeCursor(i + c);
            });
          },
        ),
      ),
      );
    }
    return new TableRow(children: lst);
  }
  List<TableRow> getKeyRowlst() {
    List<TableRow> lst = new List<TableRow>();
    lst.add(getKeyRow(0));
    lst.add(getKeyRow(5));
    return lst;
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text('Phoodoku'),
        ),
        drawer: new Drawer(
          child: new ListView(
            children: <Widget> [
              new DrawerHeader(child: new Text('Phoodoku'),),
              new ListTile(
                title: new Text('Reset'),
                onTap: () {
                  reset();
                  Navigator.pop(context);
                },
              ),
              new ListTile(
                title: new Text('New Game'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              new Divider(),
              new ListTile(
                title: new Text('About'),
                onTap: () {},
              )
            ]
          )
        ),
        backgroundColor: Colors.white,
        body: new Column(
          children:[
          new Table(
            children: newGetTableRowList(),
            border: TableBorder.symmetric(inside: BorderSide(color: Colors.yellow, width: 20.0))
          ),
          new Padding(
            padding: new EdgeInsets.only(top:70.0),
            child: new Table(
              children: getKeyRowlst(),
              border: new TableBorder.all(
                  color: Colors.redAccent,
              ),
            )
          )

          ]

        )
    );
  }
}
    
