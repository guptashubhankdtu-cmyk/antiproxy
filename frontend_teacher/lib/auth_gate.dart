import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/http_data_service.dart';
import 'ui/home_shell.dart';
import 'ui/splash_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showSplash = true;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const SplashScreen();

    return Consumer<HttpDataService>(
      builder: (context, dataService, child) {
        // Handle auth loading states
        if (dataService.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Validating teacher access...'),
                ],
              ),
            ),
          );
        }

        // Check for auth errors (unauthorized access)
        if (dataService.authError != null) {
          // Reset sign-in state when auth error occurs
          if (_isSigningIn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isSigningIn = false;
                });
              }
            });
          }
          return _buildUnauthorizedScreen(dataService.authError!);
        }

        // Check if user is authenticated and authorized
        if (dataService.currentUser != null && dataService.isTeacher) {
          // Reset sign-in state if we're successfully authenticated
          if (_isSigningIn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isSigningIn = false;
                });
              }
            });
          }
          return const HomeShell();
        }

        // User not authenticated - show login screen
        return _buildLoginScreen();
      },
    );
  }

  Widget _buildLoginScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6B46C1),
              Color(0xFF0891B2),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/dtu_logo.png', width: 120, height: 120),
                const SizedBox(height: 32),
                const Text(
                  'AttendEase Pro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Intelligent Attendance System',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF6B46C1),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  icon: _isSigningIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF6B46C1),
                            ),
                          ),
                        )
                      : const Icon(Icons.login_outlined),
                  label: Text(
                    _isSigningIn ? 'Signing in...' : 'Sign in with Google',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _isSigningIn ? null : _handleSignIn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthorizedScreen(String errorMessage) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        backgroundColor: Color(0xFF6B46C1),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<HttpDataService>().clearAuthError();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFEEE6),
                ),
                padding: EdgeInsets.all(24),
                child: Icon(Icons.block, size: 64, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Access Restricted',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF6B46C1), width: 1),
                ),
                padding: EdgeInsets.all(16),
                child: const Text(
                  'Only pre-registered teachers can access this app. Please contact the administrator to add your email to the teacher database.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    _resetSignInState();
                    await context.read<HttpDataService>().signOut();
                  } catch (e) {
                    print('Error during sign out: $e');
                    context.read<HttpDataService>().clearAuthError();
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Try Different Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetSignInState() {
    if (mounted) {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  void _handleSignIn() async {
    if (_isSigningIn) return; // Prevent multiple calls

    setState(() {
      _isSigningIn = true;
    });

    try {
      await context.read<HttpDataService>().signInWithGoogle();

      // HttpDataService will automatically handle validation
      // _isSigningIn will be reset when validation completes or fails
    } catch (e) {
      print('Sign in error: $e');
      if (mounted) {
        _resetSignInState();

        String errorMessage = 'Sign in failed. Please try again.';

        // Handle specific platform exceptions
        if (e.toString().contains('PlatformException')) {
          errorMessage =
              'Google Sign-In temporarily unavailable. Please try again.';
        }

        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
