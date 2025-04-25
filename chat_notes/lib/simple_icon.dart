import 'package:flutter/material.dart';

void main() {
  runApp(const IconApp());
}

class IconApp extends StatelessWidget {
  const IconApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sajjel Icon',
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            width: 512,
            height: 512,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3F51B5),  // Indigo
                  Color(0xFF2196F3),  // Blue
                ],
              ),
              borderRadius: BorderRadius.circular(120),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.note_alt_rounded,
                    size: 200,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SAJJEL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 