import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cherry.dart'; // Импортируем экран меню

class CherryGameScreen extends StatefulWidget {
  final String roomCode;
  final String gameResultId;

  const CherryGameScreen({
    super.key,
    required this.roomCode,
    required this.gameResultId,
  });

  @override
  State<CherryGameScreen> createState() => _CherryGameScreenState();
}

class _CherryGameScreenState extends State<CherryGameScreen> {
  final TextEditingController _letterController = TextEditingController();
  final TextEditingController _wordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _targetWord = '';
  List<bool> _guessedLetters = [];
  int _fallenCherries = 0;
  bool _gameOver = false;
  bool _isWin = false;

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    final gameDoc = await _firestore.collection('game_results').doc(widget.gameResultId).get();
    setState(() {
      _targetWord = gameDoc.data()?['word'] ?? '';
      _guessedLetters = List.filled(_targetWord.length, false);
    });
  }

  void _checkLetter() {
    final letter = _letterController.text.toLowerCase();
    if (letter.isEmpty || letter.length != 1) {
      _showSnackBar('Введите ровно одну букву');
      return;
    }

    setState(() {
      bool letterFound = false;
      for (int i = 0; i < _targetWord.length; i++) {
        if (_targetWord[i].toLowerCase() == letter) {
          _guessedLetters[i] = true;
          letterFound = true;
        }
      }

      if (!letterFound) {
        _fallenCherries++;
      }

      _letterController.clear();

      if (_fallenCherries >= 6) {
        _endGame(false);
      } else if (!_guessedLetters.contains(false)) {
        _endGame(true);
      }
    });
  }

  void _checkWord() {
    final guessedWord = _wordController.text.toLowerCase();
    if (guessedWord.isEmpty) {
      _showSnackBar('Введите слово');
      return;
    }

    setState(() {
      if (guessedWord == _targetWord.toLowerCase()) {
        for (int i = 0; i < _guessedLetters.length; i++) {
          _guessedLetters[i] = true;
        }
        _endGame(true);
      } else {
        _fallenCherries = 6;
        _endGame(false);
      }
      _wordController.clear();
    });
  }

  Future<void> _endGame(bool isWin) async {
    if (_gameOver) return;
    
    setState(() {
      _gameOver = true;
      _isWin = isWin;
    });

    final batch = _firestore.batch();
    final gameResultRef = _firestore.collection('game_results').doc(widget.gameResultId);
    final roomRef = _firestore.collection('rooms').doc(widget.roomCode);

    // Обновляем результат игры с timestamp
    batch.update(gameResultRef, {
      'result': isWin ? 'win' : 'lose',
      'timestamp': FieldValue.serverTimestamp(), // Добавлено здесь
    });

    if (isWin) {
      batch.update(roomRef, {
        'guessedCount': FieldValue.increment(1),
        'notGuessedCount': FieldValue.increment(-1),
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Ошибка batch: $e');
      // Fallback
      try {
        await gameResultRef.update({
          'result': isWin ? 'win' : 'lose',
          'timestamp': FieldValue.serverTimestamp(), // И здесь
        });
        if (isWin) {
          await roomRef.update({
            'guessedCount': FieldValue.increment(1),
            'notGuessedCount': FieldValue.increment(-1),
          });
        }
      } catch (e) {
        debugPrint('Ошибка при раздельном обновлении: $e');
      }
    }
  }

  String _getDisplayWord() {
    String display = '';
    for (int i = 0; i < _targetWord.length; i++) {
      display += _guessedLetters[i] ? _targetWord[i] : '*';
      display += ' ';
    }
    return display.trim();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Montserrat')),
      ),
    );
  }

  void _returnToMenu() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const CherryScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_gameOver) {
      return _buildGameOverScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Игра "Вишенки"'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _returnToMenu,
        ),
      ),
      body: Center(
        child: SizedBox(
          width: 393,
          height: 852,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Индикаторы вишенок
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Image.asset(
                      index < _fallenCherries 
                          ? 'assets/images/cherry_grey.png' 
                          : 'assets/images/cherry_red.png',
                      width: 28,
                      height: 28,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),

              // Поле для загаданного слова
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _targetWord.isEmpty ? 'Загрузка...' : _getDisplayWord(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 32,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Поле ввода буквы
              SizedBox(
                width: 303,
                child: TextField(
                  controller: _letterController,
                  maxLength: 1,
                  decoration: InputDecoration(
                    counterText: '',
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
              ),
              const SizedBox(height: 30),

              // Кнопки управления
              _buildGameButton(
                context,
                title: 'Проверить букву',
                onPressed: _checkLetter,
              ),
              const SizedBox(height: 20),
              _buildGameButton(
                context,
                title: 'Ответить слово',
                onPressed: _checkWord,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isWin ? 'Вы победили!' : 'Вы проиграли',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Загаданное слово: $_targetWord',
              style: const TextStyle(
                fontSize: 24,
                fontFamily: 'Montserrat',
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 50),
            _buildGameButton(
              context,
              title: 'Вернуться в меню',
              onPressed: _returnToMenu,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameButton(
    BuildContext context, {
    required String title,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFCECE),
        minimumSize: const Size(303, 54),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        elevation: 4,
      ),
      child: Text(
        title,
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
