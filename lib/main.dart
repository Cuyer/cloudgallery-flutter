import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const firebaseConfig = FirebaseOptions (
      apiKey: "AIzaSyDAokAJKQ25_qD7hWKZeyYYkIm0FlZQ4lk",
      authDomain: "cloudgallery-de527.firebaseapp.com",
      projectId: "cloudgallery-de527",
      storageBucket: "cloudgallery-de527.firebasestorage.app",
      messagingSenderId: "853787459533",
      appId: "1:853787459533:web:dc0513d2e11103e5c84e84",
      measurementId: "G-3S647LW30L"
  );

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: firebaseConfig
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const CloudGalleryApp());
}

class CloudGalleryApp extends StatelessWidget {
  const CloudGalleryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cloud Gallery',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Gallery'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Login to Cloud Gallery',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20.0),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24.0),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _images = [];
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _scrollController.addListener(_onScroll);
      _fetchInitialImages();
    } else {
      _scrollController.addListener(_onScroll);
      _fetchInitialImages();
    }
  }

  Future<void> _fetchInitialImages() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('nasa_images')
        .limit(5)
        .get();
    setState(() {
      _images.addAll(snapshot.docs);
    });
  }

  Future<void> _fetchMoreImages() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    final lastDocument = _images.last;
    final snapshot = await FirebaseFirestore.instance
        .collection('nasa_images')
        .startAfterDocument(lastDocument)
        .limit(5)
        .get();

    setState(() {
      _images.addAll(snapshot.docs);
      _isLoadingMore = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _fetchMoreImages();
    }
  }

  Future<void> _resizeAndShowImage(BuildContext context, String storagePath) async {
    final storageRef = FirebaseStorage.instance.ref(storagePath);
    try {
      final imageUrl = await storageRef.getDownloadURL();
      final Uri cloudFunctionUrl =
      Uri.parse('https://resize-image-cloud-function-3npvxzcqla-uc.a.run.app');
      final response = await http.post(
        cloudFunctionUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'imagePath': storagePath, 'width': 300, 'height': 300}),
      );

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Image.memory(
              response.bodyBytes,
              fit: BoxFit.cover,
            ),
          ),
        );
      } else {
        print(response.body);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _showImage(BuildContext context, String storagePath) async {
    final storageRef = FirebaseStorage.instance.ref(storagePath);
    try {
      final imageUrl = await storageRef.getDownloadURL();
      final Uri url =
      Uri.parse(imageUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'}
      );

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Image.memory(
              response.bodyBytes,
              fit: BoxFit.cover,
            ),
          ),
        );
      } else {
        print(response.body);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home - Cloud Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: kIsWeb
          ? _buildWebImageList()
          : _buildMobileImageList(),
    );
  }

  Widget _buildMobileImageList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('nasa_images').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final images = snapshot.data?.docs;

        return ListView.builder(
          itemCount: images?.length ?? 0,
          itemBuilder: (context, index) {
            final image = images?[index];
            final title = image?['title'] ?? 'No Title';
            final date = image?['date'] ?? 'No Date';
            final storagePath = image?['storage_path'] ?? '';

            return ListTile(
              title: Text(title),
              subtitle: Text(date),
              onTap: () => _resizeAndShowImage(context, storagePath),
            );
          },
        );
      },
    );
  }

  Widget _buildWebImageList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _images.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _images.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final image = _images[index];
        final title = image['title'] ?? 'No Title';
        final date = image['date'] ?? 'No Date';
        final storagePath = image['storage_path'] ?? '';

        return GestureDetector(
          onTap: () => _showImage(context, storagePath),
          child: Card(
            child: Column(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(date),
                FutureBuilder<String>(
                  future: FirebaseStorage.instance.ref(storagePath).getDownloadURL(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return const Icon(Icons.error);
                    }
                    return Image.network(snapshot.data ?? '', fit: BoxFit.cover);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
