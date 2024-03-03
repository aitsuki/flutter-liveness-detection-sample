import 'dart:typed_data';

import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Uint8List? imagebytes;

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
                          imagebytes = result;
                        });
                      }
                    },
                    child: const Text("Camera"))),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pushNamed(context, "/face");
                },
                child: const Text("Face"),
              ),
            ),
            if (imagebytes != null) Image.memory(imagebytes!),
          ],
        ),
      ),
    );
  }
}
