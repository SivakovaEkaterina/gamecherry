import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'cherry_game_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _roomCodeController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isJoining = false;
  bool _isRandomJoining = false;
  final Random _random = Random();

  Future<void> _joinRoom(String roomCode) async {
    if (roomCode.isEmpty) {
      _showSnackBar('Введите код комнаты');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Требуется авторизация');

      final roomDoc = await _firestore.collection('rooms').doc(roomCode).get();
      
      if (!roomDoc.exists || (roomDoc.data()?['isActive'] != true)) {
        throw Exception('Комната не найдена или неактивна');
      }

      // Увеличиваем счетчик неугаданных слов
      await _firestore.collection('rooms').doc(roomCode).update({
        'notGuessedCount': FieldValue.increment(1),
      });

      // Создаем запись о начале игры (по умолчанию result: 'lose')
      final gameResultRef = await _firestore.collection('game_results').add({
        'roomCode': roomCode,
        'word': roomDoc.data()?['word'] ?? '',
        'userId': user.uid,
        'authorId': roomDoc.data()?['author']?['uid'],
        'result': 'lose', // Дефолтное значение
      });

      _navigateToGameScreen(roomCode, gameResultRef.id);
    } catch (e) {
      _showSnackBar('Ошибка: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _joinRandomRoom() async {
    setState(() => _isRandomJoining = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Требуется авторизация');

      final activeRooms = await _firestore
          .collection('rooms')
          .where('isActive', isEqualTo: true)
          .limit(100)
          .get();

      if (activeRooms.docs.isEmpty) {
        throw Exception('Нет активных комнат');
      }

      final randomRoom = activeRooms.docs[_random.nextInt(activeRooms.docs.length)];
      final roomCode = randomRoom.id;

      await _firestore.collection('rooms').doc(roomCode).update({
        'notGuessedCount': FieldValue.increment(1),
      });

      // Создаем запись о игре с дефолтным статусом 'lose'
      final gameResultRef = await _firestore.collection('game_results').add({
        'roomCode': roomCode,
        'word': randomRoom.data()['word'],
        'userId': user.uid,
        'authorId': randomRoom.data()['author']['uid'],
        'result': 'lose',
      });

      _navigateToGameScreen(roomCode, gameResultRef.id);
    } catch (e) {
      _showSnackBar('Ошибка: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isRandomJoining = false);
    }
  }

  void _navigateToGameScreen(String roomCode, String gameResultId) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => CherryGameScreen(
          roomCode: roomCode,
          gameResultId: gameResultId,
        ),
      ),
      (Route<dynamic> route) => false,
    );
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
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: screenWidth * 0.8,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _roomCodeController,
                decoration: InputDecoration(
                  labelText: 'Код комнаты',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(0),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(0),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'Montserrat',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              _buildGameButton(
                context,
                title: 'Присоединиться к комнате',
                isLoading: _isJoining,
                onPressed: () => _joinRoom(_roomCodeController.text.trim()),
              ),
              const SizedBox(height: 20),
              _buildGameButton(
                context,
                title: 'Присоединиться к случайной комнате',
                isLoading: _isRandomJoining,
                onPressed: _joinRandomRoom,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameButton(
    BuildContext context, {
    required String title,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    final buttonWidth = MediaQuery.of(context).size.width * 0.77;
    const buttonHeight = 54.0;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFCECE),
        minimumSize: Size(buttonWidth, buttonHeight),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        elevation: 4,
      ),
      child: isLoading
          ? const CircularProgressIndicator(color: Colors.black)
          : Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 32,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w400,
              ),
            ),
    );
  }
}
