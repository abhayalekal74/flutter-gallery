import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class SettingsPage extends StatefulWidget {
  final String title;

  SettingsPage({Key key, this.title}) : super(key: key);

  @override
  _SettingsPageState createState() => new _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    debugPrint("Settings page state build called");
    // TODO: implement build
    return new Scaffold(
      appBar: new AppBar(
          title: new Text(
            widget.title,
            style: new TextStyle(
                fontSize: 20.0
            ),
          )
      ),
      body: new ListView(
        padding: EdgeInsets.all(20.0),
        children: <Widget>[
          new Container(
              height: 36.0,
              child: new Text(
                "Sort Order",
                style: new TextStyle(
                    color: Colors.black,
                    fontSize: 18.0
                ),
              )
          ),
          new Container(
              height: 36.0,
              child: new Text(
                "Display Order",
                style: new TextStyle(
                    color: Colors.black,
                    fontSize: 18.0
                ),
              )
          )
        ],
      ),
    );
  }
}