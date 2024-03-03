import 'package:face/screen/camera_screen.dart';
import 'package:face/screen/face_screen.dart';
import 'package:face/screen/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face',
      initialRoute: "/",
      routes: {
        "/": (context) => const HomeScreen(),
        "/camera": (context) => const CameraScreen(),
        "/face":(context) => const FaceScreen(),
      },
      theme: ThemeData.dark(
        useMaterial3: true,
      ),
    );
  }
}
