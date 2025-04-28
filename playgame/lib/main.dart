import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cherry.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Проверка сохраненной сессии
  final prefs = await SharedPreferences.getInstance();
  final savedUser = prefs.getString('userUid');
  
  if (savedUser != null) {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: prefs.getString('userEmail') ?? '',
        password: prefs.getString('userPassword') ?? '',
      );
    } catch (e) {
      await prefs.clear();
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Игровое меню',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
      routes: {
        '/cherry': (context) => const CherryScreen(),
        '/auth': (context) => const AuthScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  String _userName = 'Гость';

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    _auth.authStateChanges().listen((User? user) async {
      setState(() {
        _user = user;
        _userName = user == null ? 'Гость' : _userName;
      });
      
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        setState(() {
          _userName = doc.data()?['name'] ?? user.email?.split('@')[0] ?? 'Пользователь';
        });
      }
    });
  }

  void _navigateToAuth() {
    Navigator.pushNamed(context, '/auth');
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _userName = 'Гость';
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('Добро пожаловать, $_userName'),
        actions: [
          IconButton(
            icon: Icon(_user == null ? Icons.login : Icons.logout),
            onPressed: _user == null ? _navigateToAuth : _signOut,
            tooltip: _user == null ? 'Войти' : 'Выйти',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            width: screenWidth,
            height: screenHeight,
            decoration: const BoxDecoration(color: Colors.white),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: screenWidth * 0.11,
                  top: screenHeight * 0.4,
                  child: _buildGameButton(
                    context,
                    title: 'Вишенки',
                    onPressed: () {
                      Navigator.pushNamed(context, '/cherry');
                    },
                  ),
                ),
                Positioned(
                  left: screenWidth * 0.1,
                  top: screenHeight * 0.2,
                  child: Text(
                    'Выберите игру',
                    style: TextStyle(
                      fontSize: screenWidth * 0.08,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameButton(
    BuildContext context, {
    required String title,
    required VoidCallback onPressed,
  }) {
    final buttonWidth = MediaQuery.of(context).size.width * 0.77;
    const buttonHeight = 54.0;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFCECE),
        minimumSize: Size(buttonWidth, buttonHeight),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        elevation: 4,
      ),
      child: Text(
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

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _message;
  bool _isLogin = true;
  double _progressValue = 0.0;
  bool _rememberMe = false;

  Future<void> _authAction() async {
    setState(() => _progressValue = 0.3);
    try {
      if (_isLogin) {
        await _login();
      } else {
        await _register();
      }
      
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userUid', _auth.currentUser?.uid ?? '');
        await prefs.setString('userEmail', _emailController.text);
        await prefs.setString('userPassword', _passwordController.text);
      }
      
      setState(() => _progressValue = 1.0);
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _message = 'Ошибка: ${e.toString()}';
        _progressValue = 0.0;
      });
    }
  }

  Future<void> _login() async {
    await _auth.signInWithEmailAndPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _register() async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );
    await _firestore.collection('users').doc(userCredential.user?.uid).set({
      'email': _emailController.text,
      'name': _nameController.text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _progressValue = 0.3);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      // Если пользователь новый, сохраняем данные в Firestore
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'email': googleUser.email,
          'name': googleUser.displayName ?? googleUser.email?.split('@')[0],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      setState(() => _progressValue = 1.0);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _message = 'Ошибка Google Sign-In: $e';
        _progressValue = 0.0;
      });
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Вход' : 'Регистрация'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isLogin)
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (!_isLogin) const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                if (_isLogin)
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('Запомнить меня'),
                    ],
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _authAction,
                    child: Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 24,
                    ),
                    label: const Text('Войти через Google'),
                    onPressed: _signInWithGoogle,
                  ),
                ),
                TextButton(
                  onPressed: _toggleAuthMode,
                  child: Text(
                    _isLogin 
                      ? 'Создать новый аккаунт' 
                      : 'Уже есть аккаунт? Войти',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _message!.startsWith('Ошибка') 
                          ? Colors.red 
                          : Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_progressValue > 0)
            LinearProgressIndicator(
              value: _progressValue,
              backgroundColor: Colors.grey[200],
              minHeight: 4,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
        ],
      ),
    );
  }
}
