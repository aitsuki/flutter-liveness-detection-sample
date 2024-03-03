import 'package:flutter/material.dart';

class FaceScreen extends StatefulWidget {
  const FaceScreen({super.key});

  @override
  State<FaceScreen> createState() => _FaceScreenState();
}

class _FaceScreenState extends State<FaceScreen> {
  @override
  void initState() {
    super.initState();
    // white status bar
  }

  Widget _faceGuide(String text, double scale) {
    return Row(
      children: [
        Image.asset(
          "assets/images/face_warning.png",
          width: 32 * scale,
          height: 32 * scale,
        ),
        SizedBox(width: 4 * scale),
        Text(
          text,
          style: TextStyle(
            fontSize: 12 * scale,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.of(context).size.width / 375.0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(children: [
        Expanded(
          child: Container(),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 19),
          decoration: BoxDecoration(
            color: Color(0xFF17191C),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _faceGuide("Não está claro", ratio),
              _faceGuide("Incompleto", ratio),
              _faceGuide("Lente distante", ratio),
            ],
          ),
        )
      ]),
    );
  }
}
