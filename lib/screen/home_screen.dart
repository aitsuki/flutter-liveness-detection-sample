import 'dart:typed_data';

import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Uint8List>? images;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () async {
                      final result =
                          await Navigator.pushNamed(context, "/camera");
                      if (result != null && result is Uint8List) {
                        setState(() {
                          images = [result];
                        });
                      }
                    },
                    child: const Text("Camera"))),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, "/face");
                  if (result != null) {
                    setState(() {
                      images = result as List<Uint8List>;
                    });
                  }
                },
                child: const Text("Face"),
              ),
            ),
            Expanded(
                child: ListView(
              children: images?.map((e) => Image.memory(e)).toList() ?? [],
            ))
          ],
        ),
      ),
    );
  }
}
