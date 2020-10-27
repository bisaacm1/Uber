import 'package:flutter/material.dart';
import 'package:uber/Rotas.dart';
import 'package:uber/telas/Home.dart';

final ThemeData temaPadrao = ThemeData(
  primaryColor: Color(0xff37474f),
  accentColor: Color(0xff546e7a),
);

void main() {
  runApp(
    MaterialApp(
      title: "Uber",
      home: Home(),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: Rotas.gerarRotas,
      theme: temaPadrao,
    ),
  );
}
