import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'cherry.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  late final TextEditingController _wordController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isCreating = false;
  final Random _random = Random();

  String _generateNumericCode() {
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(_random.nextInt(10));
    }
    return buffer.toString();
  }

  Future<bool> _isCodeUnique(String code) async {
    final doc = await _firestore.collection('rooms').doc(code).get();
    return !doc.exists;
  }

  Future<String?> _getUserName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['name'] as String?;
    } catch (e) {
      debugPrint('Ошибка при получении имени пользователя: $e');
      return null;
    }
  }

  Future<void> _createRoom() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      _showSnackBar('Пожалуйста, введите слово');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      final userName = await _getUserName(user.uid);
      if (userName == null) throw Exception('Не удалось получить имя пользователя');

      String roomCode;
      bool isUnique;
      int attempts = 0;
      const maxAttempts = 5;

      do {
        roomCode = _generateNumericCode();
        isUnique = await _isCodeUnique(roomCode);
        attempts++;
        if (attempts >= maxAttempts) {
          throw Exception('Не удалось создать уникальный код комнаты');
        }
      } while (!isUnique);

      final roomData = {
        'word': word,
        'roomCode': roomCode,
        'author': {
          'uid': user.uid,
          'email': user.email,
          'name': userName,
        },
        'guessedCount': 0,
        'notGuessedCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _firestore.collection('rooms').doc(roomCode).set(roomData);
      
      // Перенаправление на CherryGameScreen после успешного создания
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CherryScreen()),
          (Route<dynamic> route) => false,
        );
      }

    } catch (e) {
      _showSnackBar('Ошибка: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Montserrat')),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController();
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Создать комнату'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.11),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _wordController,
              decoration: InputDecoration(
                labelText: 'Введите слово',
                labelStyle: const TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.black54,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(0),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              style: const TextStyle(
                fontSize: 20,
                fontFamily: 'Montserrat',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildCreateRoomButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateRoomButton(BuildContext context) {
    final buttonWidth = MediaQuery.of(context).size.width * 0.77;
    const buttonHeight = 54.0;

    return ElevatedButton(
      onPressed: _isCreating ? null : _createRoom,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFCECE),
        minimumSize: Size(buttonWidth, buttonHeight),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        elevation: 4,
      ),
      child: _isCreating
          ? const CircularProgressIndicator(color: Colors.black)
          : const Text(
              'Создать комнату',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 32,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w400,
              ),
            ),
    );
  }
}
