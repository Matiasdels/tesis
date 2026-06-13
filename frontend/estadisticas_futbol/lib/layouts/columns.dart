import 'package:flutter/material.dart';

class ColumnsExample extends StatelessWidget {
  const ColumnsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
          width: 100,
          height: 200,
          color: const Color.fromARGB(100, 100, 100, 100),
          child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("hola"),
                Text("matias"),
              ])),
    );
  }
}
