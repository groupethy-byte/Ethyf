import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'app/modules/category/category_page.dart';
import 'app/modules/sub_category/sub_category_page.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:get/get.dart';
import 'app/modules/category/category_binding.dart';
import 'app/modules/saldo_awal/saldo_awal_screen.dart';
import 'services/local_database_service.dart';
import 'services/sync_service.dart';
import 'app/modules/transaksi/transaksi_screen.dart';
import 'app/modules/dashboard/dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'utils/number_formatter.dart';
import 'utils/user_utils.dart'; // New import
import 'models/family_model.dart'; // New import
import 'app/modules/family/family_management_page.dart'; // New import
import 'app/modules/family/family_binding.dart'; // New import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive untuk offline support
  await LocalDatabaseService.initHive();
  
  try {
    // Cek apakah instance Firebase sudah ada untuk menghindari error saat Hot Restart
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    // Sync data setelah Firebase initialized (atau jika sudah ada)
    await SyncService.syncAllData();
  } catch (e) {
    print('Firebase initialization/sync error: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledToast(
      child: GetMaterialApp(
        locale: const Locale('en', 'US'),
        title: 'Ethyf',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 46, 204, 113),
            primary: const Color.fromARGB(255, 46, 204, 113),
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.robotoTextTheme(),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromARGB(255, 46, 204, 113),
            foregroundColor: Colors.black87,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 46, 204, 113),
              foregroundColor: Colors.black87,
            ),
          ),
        ),
        home: const SplashScreen(),
        getPages: [
          GetPage(name: '/login', page: () => const LoginScreen()),
          GetPage(name: '/signup', page: () => const SignUpScreen()),
          GetPage(
            name: '/home',
            page: () => const HomeScreen(),
          ),
          GetPage(name: '/intro', page: () => const IntroScreen()),
          GetPage(
            name: '/category',
            page: () => const CategoryPage(),
            binding: CategoryBinding(),
          ),
          GetPage(name: '/sub-category', page: () => const SubCategoryPage()),
          GetPage(
            name: '/family-management', // New route
            page: () => const FamilyManagementPage(),
            binding: FamilyBinding(),
          ),
        ],
      ),
    );
  }
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Get.off(() => const AuthWrapper(), transition: Transition.fadeIn);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Image.asset(
            'assets/images/logo splash ethyf open.png',
          ),
        ),
      ),
    );
  }
}

// Auth Wrapper untuk mengecek status login
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User sudah login
          return const HomeScreen();
        }

        // User belum login, tampilkan intro
        return const IntroScreen();
      },
    );
  }
}

// Intro Screen dengan 3 halaman cards
class IntroScreen extends StatefulWidget {
  const IntroScreen({Key? key}) : super(key: key);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<IntroCard> introCards = [
    IntroCard(
      title: 'Welcome to Ethyf',
      description: 'Discover amazing features and connect with people around the world.',
      icon: Icons.public,
      color: Colors.blue,
    ),
    IntroCard(
      title: 'Share & Connect',
      description: 'Share your moments, connect with friends, and build meaningful relationships.',
      icon: Icons.people,
      color: Colors.purple,
    ),
    IntroCard(
      title: 'Ready to Start?',
      description: 'Join our community today and explore endless possibilities.',
      icon: Icons.rocket_launch,
      color: Colors.orange,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: introCards.length,
              itemBuilder: (context, index) {
                return buildIntroCard(introCards[index]);
              },
            ),
          ),
          // Dot indicators
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                introCards.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  height: 12,
                  width: _currentPage == index ? 30 : 12,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? const Color.fromARGB(255, 46, 204, 113) : Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          // Buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  ElevatedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Previous'),
                  )
                else
                  const SizedBox(width: 100),
                if (_currentPage < introCards.length - 1)
                  ElevatedButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text('Get Started'),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget buildIntroCard(IntroCard card) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: card.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              card.icon,
              size: 60,
              color: card.color,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              card.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IntroCard {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  IntroCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        // Simpan credential untuk mendapatkan user info
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        
        // FIX: Pastikan data user tersimpan di Firestore agar bisa dicari saat invite family
        if (userCredential.user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
          if (!userDoc.exists) {
            await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
              'fullName': userCredential.user!.displayName ?? 'User',
              'email': userCredential.user!.email!.toLowerCase(), // Pastikan lowercase
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Google Sign In failed: $error');
        showToast(
          _errorMessage ?? '',
          context: context,
          animation: StyledToastAnimation.slideFromTop,
          reverseAnimation: StyledToastAnimation.slideToTop,
          position: StyledToastPosition.top,
          startOffset: const Offset(0.0, -3.0),
          reverseEndOffset: const Offset(0.0, -3.0),
          duration: const Duration(seconds: 4),
          //Animation duration   animDuration * 2 <= duration
          animDuration: const Duration(seconds: 1),
          curve: Curves.elasticOut,
          reverseCurve: Curves.fastOutSlowIn,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showToast('Silakan isi semua field', context: context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        print('Firebase Auth Error Code: ${e.code}');
        if (e.code == 'network-error') {
          showToast(
            'Kesalahan jaringan. Periksa koneksi internet Anda.',
            context: context,
            backgroundColor: Colors.orange,
          );
        } else {
          _showErrorDialog(e.code);
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(
          'Kesalahan: Periksa koneksi internet Anda.',
          context: context,
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String errorCode) {
    String title = 'Error Login';
    String message = 'Terjadi kesalahan. Silakan coba lagi.';
    IconData icon = Icons.error_outline;
    Color iconColor = Colors.red;

    if (errorCode == 'user-not-found') {
      title = 'Maaf Email Tidak Terdaftar';
      message = 'Email ini belum terdaftar di sistem kami.\n\nSilakan periksa kembali email Anda atau buat akun baru.';
      icon = Icons.person_off;
      iconColor = Colors.orange;
    } else if (errorCode == 'wrong-password' || errorCode == 'invalid-credential') {
      title = 'Password Salah';
      message = 'Password yang Anda masukkan tidak sesuai.\n\nSilakan coba lagi atau gunakan "Lupa Password" untuk mengaturnya.';
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.red;
    } else if (errorCode == 'invalid-email') {
      title = 'Email Tidak Valid';
      message = 'Format email yang Anda masukkan tidak valid.\n\nSilakan periksa kembali.';
      icon = Icons.mail_outline;
      iconColor = Colors.orange;
    } else if (errorCode == 'user-disabled') {
      title = 'Akun Dinonaktifkan';
      message = 'Akun ini telah dinonaktifkan.\n\nSilakan hubungi dukungan untuk bantuan lebih lanjut.';
      icon = Icons.lock;
      iconColor = Colors.red;
    } else if (errorCode == 'too-many-requests') {
      title = 'Terlalu Banyak Percobaan Login';
      message = 'Anda telah mencoba login terlalu banyak kali. Silakan coba lagi nanti atau atur ulang password.';
      icon = Icons.lock_clock;
      iconColor = Colors.red;
    }

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }


  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showToast('Please enter your email address', context: context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        showToast(
          'Password reset email sent successfully!',
          context: context,
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to send reset email';
        if (e.code == 'user-not-found') {
          errorMsg = 'No user found with this email address.';
        } else if (e.code == 'invalid-email') {
          errorMsg = 'The email address is not valid.';
        }
        showToast(
          errorMsg,
          context: context,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _handleForgotPassword();
              Navigator.pop(context);
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Image.asset(
                'assets/images/logo splash ethyf.png',
                height: 150,
              ),
              const SizedBox(height: 20),
              const Text(
                'Login to your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              // Email TextField
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              // Password TextField
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Color.fromARGB(255, 46, 204, 113),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleEmailLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: const Color.fromARGB(255, 46, 204, 113),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
              ),
              const SizedBox(height: 15),
              // Google Sign In Button
              OutlinedButton(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: const BorderSide(color: Color.fromARGB(255, 46, 204, 113)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      height: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.login, color: Color.fromARGB(255, 46, 204, 113));
                      },
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Sign Up Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Don\'t have an account? '),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/signup');
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Color.fromARGB(255, 46, 204, 113),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// Sign Up Screen
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        // Simpan credential untuk mendapatkan user info
        final UserCredential userCredential = await _auth.signInWithCredential(credential);

        // FIX: Pastikan data user tersimpan di Firestore saat Sign Up Google
        if (userCredential.user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
          if (!userDoc.exists) {
            await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
              'fullName': userCredential.user!.displayName ?? 'User',
              'email': userCredential.user!.email!.toLowerCase(),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Google Sign Up failed: $error');
        showToast(
          _errorMessage ?? '',
          context: context,
          animation: StyledToastAnimation.slideFromTop,
          reverseAnimation: StyledToastAnimation.slideToTop,
          position: StyledToastPosition.top,
          startOffset: const Offset(0.0, -3.0),
          reverseEndOffset: const Offset(0.0, -3.0),
          duration: const Duration(seconds: 4),
          //Animation duration   animDuration * 2 <= duration
          animDuration: const Duration(seconds: 1),
          curve: Curves.elasticOut,
          reverseCurve: Curves.fastOutSlowIn,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      showToast(
        'Please fill in all fields',
        context: context,
      );
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      showToast(
        'Passwords do not match',
        context: context,
      );
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      showToast(
        'Password must be at least 6 characters',
        context: context,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Buat akun dengan email dan password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update profile dengan nama
      await userCredential.user?.updateDisplayName(name);

      // Save user data to Firestore
      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'fullName': name,
          'email': email.toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (mounted) {
        showToast(
          'Account created successfully!',
          context: context,
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _getErrorMessage(e.code));
      if (mounted) {
        showToast(
          _errorMessage ?? '',
          context: context,
          animation: StyledToastAnimation.slideFromTop,
          reverseAnimation: StyledToastAnimation.slideToTop,
          position: StyledToastPosition.top,
          startOffset: const Offset(0.0, -3.0),
          reverseEndOffset: const Offset(0.0, -3.0),
          duration: const Duration(seconds: 4),
          //Animation duration   animDuration * 2 <= duration
          animDuration: const Duration(seconds: 1),
          curve: Curves.elasticOut,
          reverseCurve: Curves.fastOutSlowIn,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return 'Sign up failed: $code';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              Image.asset(
                'assets/images/logo.png',
                height: 100,
              ),
              const SizedBox(height: 30),
              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Join us today',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              // Name TextField
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter your full name',
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Email TextField
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              // Password TextField
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Confirm Password TextField
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  hintText: 'Confirm your password',
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              // Sign Up Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: const Color.fromARGB(255, 46, 204, 113),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
              ),
              const SizedBox(height: 15),
              // Google Sign Up Button
              OutlinedButton(
                onPressed: _isLoading ? null : _handleGoogleSignUp,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: const BorderSide(color: Color.fromARGB(255, 46, 204, 113)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      height: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.login, color: Color.fromARGB(255, 46, 204, 113));
                      },
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Sign up with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Color.fromARGB(255, 46, 204, 113),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// Tambahkan formatter custom
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Hapus semua karakter non-digit
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) return newValue.copyWith(text: '');
    final number = int.parse(newText);
    final formatted = _formatter.format(number);
    // Hitung posisi kursor baru
    int selectionIndex = formatted.length;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

// Home Screen (setelah login)
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isProMember = false;
  String? _currentUserFamilyId;

  @override
  void initState() {
    super.initState();
    _initializeProStatus(); // New method call
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeProStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    _currentUserFamilyId = await UserUtils.getCurrentUserFamilyId();
    await _checkAndCreateDefaultBank();
    setState(() {}); // Refresh UI after data is loaded
  }

  Future<void> _checkAndCreateDefaultBank() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    CollectionReference banksRef;

    if (_isProMember && _currentUserFamilyId != null) {
      banksRef = FirebaseFirestore.instance.collection('families').doc(_currentUserFamilyId!).collection('banks');
    } else {
      banksRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('banks');
    }

    try {
      final querySnapshot = await banksRef.where('namaBanks', isEqualTo: 'CASH').limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        final idBank = 'BANK${DateTime.now().millisecondsSinceEpoch}';
        await banksRef.add({
          'idBank': idBank,
          'namaBanks': 'CASH',
          'userId': user.uid,
          'saldoAwal': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating default bank: $e');
    }
  }

  // Helper untuk judul AppBar berdasarkan tab aktif
  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Pendapatan';
      case 2:
        return 'Pengeluaran';
      default:
        return 'Ethyf';
    }
  }

  Color _getNavBarColor(int index) {
    switch (index) {
      case 0:
        return Colors.grey[800]!; // Dashboard: Abu-abu gelap
      case 1:
        return Colors.green; // Pendapatan: Hijau
      case 2:
        return Colors.red; // Pengeluaran: Merah
      default:
        return const Color.fromARGB(255, 46, 204, 113);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Sign out dari Firebase
      await FirebaseAuth.instance.signOut();
      
      // Coba sign out dari Google SignIn (jika ada)
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        // Google SignIn error bisa diabaikan untuk web
        print('Google SignIn logout error (ignored): $e');
      }
      
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/intro');
      }
    } catch (e) {
      if (context.mounted) {
        showToast(
          'Logout failed: $e',
          context: context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(_selectedIndex)),
        centerTitle: true,
        actions: [
          if (_selectedIndex == 0) ...[
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Get.toNamed('/family-management');
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: user != null
                      ? FirebaseFirestore.instance
                          .collection('invitations')
                          .where('inviteeUid', isEqualTo: user.uid)
                          .where('status', isEqualTo: 'pending')
                          .snapshots()
                      : const Stream.empty(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      // Ini akan mencetak link pembuatan index di console jika index belum ada
                      print("Error Undangan: ${snapshot.error}");
                    }
                    if (snapshot.hasData) {
                      print("DEBUG BADGE: Ditemukan ${snapshot.data!.docs.length} undangan untuk ${user?.uid}");
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final count = snapshot.data!.docs.length;
                    return Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? 'User'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user?.displayName ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24.0, color: Color.fromARGB(255, 46, 204, 113)),
                ),
              ),
              decoration: const BoxDecoration(color: Color.fromARGB(255, 46, 204, 113)),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const ProfilScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Data Master'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DataMasterScreen()));
              },
            ),
            if (true) // Conditionally show for Pro members
              ListTile(
                leading: const Icon(Icons.family_restroom, color: Color.fromARGB(255, 46, 204, 113)),
                title: const Text('Manajemen Keluarga'),
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed('/family-management'); // Navigate using GetX
                },
              ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const AboutScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout(context);
              },
            ),
          ],
        ),
      ),
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _getNavBarColor(_selectedIndex),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Pendapatan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_down),
            label: 'Pengeluaran',
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const TransaksiScreen(type: 'pendapatan');
      case 2:
        return const TransaksiScreen(type: 'pengeluaran');
      default:
        return const DashboardScreen();
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildPendapatan();
      case 2:
        return _buildPengeluaran();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final user = FirebaseAuth.instance.currentUser;
    
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.2),
              child: const Icon(
                Icons.person,
                size: 60,
                color: Color.fromARGB(255, 46, 204, 113),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You have successfully logged in',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow('Name', user?.displayName ?? 'Not set'),
                  const SizedBox(height: 10),
                  _buildDetailRow('Email', user?.email ?? 'Not set'),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    'Account Type',
                    user?.providerData.isNotEmpty == true
                        ? user!.providerData.first.providerId == 'google.com'
                            ? 'Google Account'
                            : 'Email Account'
                        : 'Email Account',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _handleLogout(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendapatan() {
    return const TransaksiScreen(type: 'pendapatan');
  }

  Widget _buildPengeluaran() {
    return const TransaksiScreen(type: 'pengeluaran');
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// Profil Screen
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({Key? key}) : super(key: key);

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  bool _isUploading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _pickAndUploadImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      // Simpan foto profil secara lokal
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');

      // Update User Profile
      await user.updatePhotoURL(savedImage.path);
      await user.reload(); // Reload user data

      if (mounted) {
        setState(() => _isUploading = false);
        showToast(
          'Foto profil berhasil diperbarui',
          context: context,
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        showToast(
          'Gagal mengupload foto: $e',
          context: context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundColor: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.2),
                      backgroundImage: user?.photoURL != null
                          ? (user!.photoURL!.startsWith('http')
                              ? NetworkImage(user!.photoURL!)
                              : FileImage(File(user!.photoURL!)) as ImageProvider)
                          : null,
                      child: user?.photoURL == null
                          ? const Icon(
                              Icons.person,
                              size: 80,
                              color: Color.fromARGB(255, 46, 204, 113),
                            )
                          : null,
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: CircularProgressIndicator(),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 46, 204, 113),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Informasi Profil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildProfileCard('Nama', user?.displayName ?? 'Tidak diatur'),
              const SizedBox(height: 15),
              _buildProfileCard('Email', user?.email ?? 'Tidak diatur'),
              const SizedBox(height: 15),
              _buildProfileCard(
                'Jenis Akun',
                user?.providerData.isNotEmpty == true
                    ? user!.providerData.first.providerId == 'google.com'
                        ? 'Google Account'
                        : 'Email Account'
                    : 'Email Account',
              ),
              const SizedBox(height: 15),
              _buildProfileCard(
                'Email Terverifikasi',
                user?.emailVerified == true ? 'Ya' : 'Tidak',
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Kembali'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// About Screen
class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              // App Icon
              Container(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 100,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Ethyf',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tentang Aplikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Ethyf adalah aplikasi manajemen keuangan yang dirancang untuk membantu Anda mengelola keuangan pribadi dengan lebih efisien. Dengan fitur-fitur lengkap, Anda dapat melacak pengeluaran, mengelola budget, dan mencapai tujuan finansial Anda.',
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                '© 2026 Ethyf. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Kembali'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Data Master Screen
class DataMasterScreen extends StatelessWidget {
  const DataMasterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<DataMasterItem> items = [
      DataMasterItem(
        title: 'Saldo Awal',
        icon: Icons.account_balance_wallet,
        color: const Color.fromARGB(255, 46, 204, 113),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SaldoAwalScreen()),
          );
        },
      ),
      DataMasterItem(
        title: 'Bank',
        icon: Icons.account_balance,
        color: Colors.green,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BankListScreen()),
          );
        },
      ),
      DataMasterItem(
        title: 'Kategori',
        icon: Icons.category,
        color: Colors.orange,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const KategoriListScreen()),
          );
        },
      ),
      DataMasterItem(
        title: 'Sub Kategori',
        icon: Icons.label,
        color: Colors.purple,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SubKategoriListScreen()),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Master'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kelola Data Master',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildDataMasterCard(context, item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataMasterCard(BuildContext context, DataMasterItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [
                item.color.withOpacity(0.2),
                item.color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: item.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 50,
                color: item.color,
              ),
              const SizedBox(height: 15),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Kategori List Screen
class KategoriListScreen extends StatefulWidget {
  const KategoriListScreen({Key? key}) : super(key: key);

  @override
  State<KategoriListScreen> createState() => _KategoriListScreenState();
}

class _KategoriListScreenState extends State<KategoriListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  bool _isProMember = false;
  String? _currentUserFamilyId;

  @override
  void initState() {
    super.initState();
    _checkFamilyStatus();
  }

  Future<void> _checkFamilyStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    _currentUserFamilyId = await UserUtils.getCurrentUserFamilyId();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Logic view: Jika Pro, tampilkan gabungan. Jika tidak, hanya user.
    if (_isProMember && _currentUserFamilyId != null) {
      final familyRef = _firestore.collection('families').doc(_currentUserFamilyId!).collection('kategori');
      final userRef = _firestore.collection('users').doc(user?.uid).collection('kategori');

      return Scaffold(
        appBar: AppBar(title: const Text('Daftar Kategori'), centerTitle: true),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildKategoriList(familyRef, 'Kategori Keluarga'),
              _buildKategoriList(userRef, 'Kategori Pribadi'),
              _buildAddButton(),
            ],
          ),
        ),
      );
    } else {
      final userRef = _firestore.collection('users').doc(user?.uid).collection('kategori');
      return Scaffold(
        appBar: AppBar(title: const Text('Daftar Kategori'), centerTitle: true),
        body: Column(
          children: [
            Expanded(child: _buildKategoriList(userRef, null, isScrollable: true)),
            _buildAddButton(),
          ],
        ),
      );
    }
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddKategoriScreen()),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Tambah Kategori'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
      ),
    );
  }

  Widget _buildKategoriList(Query collectionRef, String? title, {bool isScrollable = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: collectionRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');

        final data = snapshot.data?.docs ?? [];
        if (data.isEmpty) {
          if (title != null) return const SizedBox.shrink(); // Hide section if empty in merged view
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada data kategori')));
        }

        Widget listContent = ListView.builder(
          shrinkWrap: !isScrollable,
          physics: isScrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final doc = data[index];
            final kategori = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.category, color: Colors.orange),
                title: Text(kategori['namaKategori'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${kategori['idKategori'] ?? 'N/A'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteKategori(doc.reference),
                ),
              ),
            );
          },
        );

        if (title != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              listContent,
            ],
          );
        }
        return listContent;
      },
    );
  }

  void _deleteKategori(DocumentReference docRef) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content:
            const Text('Apakah Anda yakin ingin menghapus data kategori ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              docRef.delete();
              Navigator.pop(context);
              showToast(
                'Data kategori berhasil dihapus',
                context: context,
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Add Kategori Screen
class AddKategoriScreen extends StatefulWidget {
  const AddKategoriScreen({Key? key}) : super(key: key);

  @override
  State<AddKategoriScreen> createState() => _AddKategoriScreenState();
}

class _AddKategoriScreenState extends State<AddKategoriScreen> {
  final _namaKategoriController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  bool _isProMember = false;
  String? _currentUserFamilyId;

  @override
  void initState() {
    super.initState();
    _checkFamilyStatus();
  }

  Future<void> _checkFamilyStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    _currentUserFamilyId = await UserUtils.getCurrentUserFamilyId();
  }

  @override
  void dispose() {
    _namaKategoriController.dispose();
    super.dispose();
  }

  void _addKategori() async {
    if (_namaKategoriController.text.isEmpty) {
      showToast(
        'Nama kategori tidak boleh kosong',
        context: context,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generate ID Kategori otomatis (KATEGORI + timestamp)
      final idKategori = 'KATEGORI${DateTime.now().millisecondsSinceEpoch}';

      CollectionReference collectionRef;
      if (_isProMember && _currentUserFamilyId != null) {
        collectionRef = _firestore.collection('families').doc(_currentUserFamilyId!).collection('kategori');
      } else {
        collectionRef = _firestore.collection('users').doc(user?.uid).collection('kategori');
      }

      await collectionRef.add({
        'idKategori': idKategori,
        'namaKategori': _namaKategoriController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showToast(
          'Kategori berhasil ditambahkan',
          context: context,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showToast(
          'Error: $e',
          context: context,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Kategori'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Nama Kategori',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _namaKategoriController,
                decoration: InputDecoration(
                  hintText: 'Masukkan nama kategori',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.3),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Otomatis',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 46, 204, 113),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'ID Kategori: Akan dibuat otomatis',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addKategori,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan Kategori'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sub Kategori List Screen
class SubKategoriListScreen extends StatefulWidget {
  const SubKategoriListScreen({Key? key}) : super(key: key);

  @override
  State<SubKategoriListScreen> createState() => _SubKategoriListScreenState();
}

class _SubKategoriListScreenState extends State<SubKategoriListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  bool _isProMember = false;
  String? _currentUserFamilyId;

  @override
  void initState() {
    super.initState();
    _checkFamilyStatus();
  }

  Future<void> _checkFamilyStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    _currentUserFamilyId = await UserUtils.getCurrentUserFamilyId();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Logic view: Jika Pro, tampilkan gabungan. Jika tidak, hanya user.
    if (_isProMember && _currentUserFamilyId != null) {
      final familyRef = _firestore.collection('families').doc(_currentUserFamilyId!).collection('subkategori');
      final userRef = _firestore.collection('users').doc(user?.uid).collection('subkategori');

      return Scaffold(
        appBar: AppBar(title: const Text('Daftar Sub Kategori'), centerTitle: true),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildSubKategoriList(familyRef, 'Sub Kategori Keluarga'),
              _buildSubKategoriList(userRef, 'Sub Kategori Pribadi'),
              _buildAddButton(),
            ],
          ),
        ),
      );
    } else {
      final userRef = _firestore.collection('users').doc(user?.uid).collection('subkategori');
      return Scaffold(
        appBar: AppBar(title: const Text('Daftar Sub Kategori'), centerTitle: true),
        body: Column(
          children: [
            Expanded(child: _buildSubKategoriList(userRef, null, isScrollable: true)),
            _buildAddButton(),
          ],
        ),
      );
    }
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddSubKategoriScreen()),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Tambah Sub Kategori'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
      ),
    );
  }

  Widget _buildSubKategoriList(Query collectionRef, String? title, {bool isScrollable = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: collectionRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');

        final data = snapshot.data?.docs ?? [];
        if (data.isEmpty) {
          if (title != null) return const SizedBox.shrink();
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada data sub kategori')));
        }

        Widget listContent = ListView.builder(
          shrinkWrap: !isScrollable,
          physics: isScrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final doc = data[index];
            final subKategori = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.label, color: Colors.purple),
                title: Text(subKategori['namaSubKategori'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${subKategori['idSubKategori'] ?? 'N/A'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editSubKategori(doc.reference, subKategori['namaSubKategori'] ?? ''),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteSubKategori(doc.reference),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        if (title != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              listContent,
            ],
          );
        }
        return listContent;
      },
    );
  }

  void _editSubKategori(DocumentReference docRef, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Nama Sub Kategori'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nama Sub Kategori'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await docRef.update({
                  'namaSubKategori': controller.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) showToast('Nama sub kategori berhasil diubah', context: context);
              } catch (e) {
                if (mounted) showToast('Error: $e', context: context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteSubKategori(DocumentReference docRef) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Sub Kategori'),
        content: const Text(
            'Apakah Anda yakin ingin menghapus data sub kategori ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              docRef.delete();
              Navigator.pop(context);
              showToast(
                'Data sub kategori berhasil dihapus',
                context: context,
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Add Sub Kategori Screen
class AddSubKategoriScreen extends StatefulWidget {
  const AddSubKategoriScreen({Key? key}) : super(key: key);

  @override
  State<AddSubKategoriScreen> createState() => _AddSubKategoriScreenState();
}

class _AddSubKategoriScreenState extends State<AddSubKategoriScreen> {
  final _namaSubKategoriController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  bool _isProMember = false;
  String? _currentUserFamilyId;

  @override
  void initState() {
    super.initState();
    _checkFamilyStatus();
  }

  Future<void> _checkFamilyStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    _currentUserFamilyId = await UserUtils.getCurrentUserFamilyId();
  }

  @override
  void dispose() {
    _namaSubKategoriController.dispose();
    super.dispose();
  }

  void _addSubKategori() async {
    if (_namaSubKategoriController.text.isEmpty) {
      showToast(
        'Nama sub kategori tidak boleh kosong',
        context: context,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generate ID Sub Kategori otomatis (SUBKATEGORI + timestamp)
      final idSubKategori =
          'SUBKATEGORI${DateTime.now().millisecondsSinceEpoch}';

      CollectionReference collectionRef;
      if (_isProMember && _currentUserFamilyId != null) {
        collectionRef = _firestore.collection('families').doc(_currentUserFamilyId!).collection('subkategori');
      } else {
        collectionRef = _firestore.collection('users').doc(user?.uid).collection('subkategori');
      }

      await collectionRef.add({
        'idSubKategori': idSubKategori,
        'namaSubKategori': _namaSubKategoriController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showToast(
          'Sub Kategori berhasil ditambahkan',
          context: context,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showToast(
          'Error: $e',
          context: context,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Sub Kategori'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Nama Sub Kategori',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _namaSubKategoriController,
                decoration: InputDecoration(
                  hintText: 'Masukkan nama sub kategori',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.3),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Otomatis',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 46, 204, 113),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'ID Sub Kategori: Akan dibuat otomatis',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addSubKategori,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan Sub Kategori'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Data Master Item Model
class DataMasterItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  DataMasterItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

// Bank List Screen
class BankListScreen extends StatefulWidget {
  const BankListScreen({Key? key}) : super(key: key);

  @override
  State<BankListScreen> createState() => _BankListScreenState();
}

class _BankListScreenState extends State<BankListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  bool _isProMember = false;
  String? _currentUserFamilyId;

  @override
  void initState() {
    super.initState();
    _checkFamilyStatus();
  }

  Future<void> _checkFamilyStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    _currentUserFamilyId = await UserUtils.getCurrentUserFamilyId();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Logic view: Jika Pro, tampilkan gabungan. Jika tidak, hanya user.
    if (_isProMember && _currentUserFamilyId != null) {
      final familyRef = _firestore.collection('families').doc(_currentUserFamilyId!).collection('banks');
      final userRef = _firestore.collection('users').doc(user?.uid).collection('banks');

      return Scaffold(
        appBar: AppBar(title: const Text('Daftar Bank'), centerTitle: true),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildBankList(familyRef, 'Bank Keluarga'),
              _buildBankList(userRef, 'Bank Pribadi'),
              _buildAddButton(),
            ],
          ),
        ),
      );
    } else {
      final userRef = _firestore.collection('users').doc(user?.uid).collection('banks');
      return Scaffold(
        appBar: AppBar(title: const Text('Daftar Bank'), centerTitle: true),
        body: Column(
          children: [
            Expanded(child: _buildBankList(userRef, null, isScrollable: true)),
            _buildAddButton(),
          ],
        ),
      );
    }
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddBankScreen()),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Tambah Bank'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
      ),
    );
  }

  Widget _buildBankList(Query collectionRef, String? title, {bool isScrollable = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: collectionRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');

        final data = snapshot.data?.docs ?? [];
        if (data.isEmpty) {
          if (title != null) return const SizedBox.shrink();
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada data bank')));
        }

        Widget listContent = ListView.builder(
          shrinkWrap: !isScrollable,
          physics: isScrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final doc = data[index];
            final bank = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.account_balance, color: Colors.green),
                title: Text(bank['namaBanks'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${bank['idBank'] ?? 'N/A'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editBank(doc.reference, bank['namaBanks'] ?? ''),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteBank(doc.reference),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        if (title != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              listContent,
            ],
          );
        }
        return listContent;
      },
    );
  }

  void _editBank(DocumentReference docRef, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Nama Bank'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nama Bank'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await docRef.update({
                  'namaBanks': controller.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) showToast('Nama bank berhasil diubah', context: context);
              } catch (e) {
                if (mounted) showToast('Error: $e', context: context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteBank(DocumentReference docRef) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Bank'),
        content: const Text('Apakah Anda yakin ingin menghapus data bank ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              docRef.delete();
              Navigator.pop(context);
              showToast(
                'Data bank berhasil dihapus',
                context: context,
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Add Bank Screen
class AddBankScreen extends StatefulWidget {
  const AddBankScreen({Key? key}) : super(key: key);

  @override
  State<AddBankScreen> createState() => _AddBankScreenState();
}

class _AddBankScreenState extends State<AddBankScreen> {
  final _namaBankController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  bool _isProMember = false;
  String? _currentUserFamilyId;

  @override
  void initState() {
    super.initState();
    _checkFamilyStatus();
  }

  Future<void> _checkFamilyStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    _currentUserFamilyId = await UserUtils.getCurrentUserFamilyId();
  }

  @override
  void dispose() {
    _namaBankController.dispose();
    super.dispose();
  }

  void _addBank() async {
    if (_namaBankController.text.isEmpty) {
      showToast(
        'Nama bank tidak boleh kosong',
        context: context,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generate ID Bank otomatis (BANK + timestamp)
      final idBank = 'BANK${DateTime.now().millisecondsSinceEpoch}';

      CollectionReference collectionRef;
      if (_isProMember && _currentUserFamilyId != null) {
        collectionRef = _firestore.collection('families').doc(_currentUserFamilyId!).collection('banks');
      } else {
        collectionRef = _firestore.collection('users').doc(user?.uid).collection('banks');
      }

      await collectionRef.add({
        'idBank': idBank,
        'namaBanks': _namaBankController.text.trim(),
        'userId': user?.uid, // Simpan userId untuk filter di Saldo Awal
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showToast(
          'Bank berhasil ditambahkan',
          context: context,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showToast(
          'Error: $e',
          context: context,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Bank'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Nama Bank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _namaBankController,
                decoration: InputDecoration(
                  hintText: 'Masukkan nama bank',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.3),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Otomatis',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 46, 204, 113),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'ID Bank: Akan dibuat otomatis',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addBank,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan Bank'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Data Master'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DataMasterScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Tentang'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              _handleLogout(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        print('Google SignIn logout error (ignored): $e');

      }
      
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/intro');
      }
    } catch (e) {
      if (context.mounted) {
        showToast(
          'Logout failed: $e',
          context: context,
        );
      }
    }
  }
}
