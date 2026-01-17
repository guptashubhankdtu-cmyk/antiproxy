import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/student_data_service.dart';
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

    return Consumer<StudentDataService>(
      builder: (context, dataService, child) {
        if (dataService.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Validating student access...'),
                ],
              ),
            ),
          );
        }

        // Allow any signed-in user (registered or not)
        if (dataService.currentUser != null) {
          if (_isSigningIn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isSigningIn = false;
                });
              }
            });
          }
          
          // Photo upload no longer required
          return const HomeShell();
        }

        // Show error message if auth failed (not 403 - those are allowed now)
        if (dataService.authError != null) {
          if (_isSigningIn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isSigningIn = false;
                });
              }
            });
          }
          // Show error as snackbar instead of full screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(dataService.authError!),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: () {
                      context.read<StudentDataService>().clearAuthError();
                    },
                  ),
                ),
              );
              context.read<StudentDataService>().clearAuthError();
            }
          });
        }
        
        return _buildLoginScreen();
      },
    );
  }

  Widget _buildLoginScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/dtu_logo.png', width: 120, height: 120),
              const SizedBox(height: 24),
              const Text(
                'Anti Proxy Student',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'View your attendance and class information',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: _isSigningIn
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  _isSigningIn ? 'Signing in...' : 'Sign in with Google',
                ),
                onPressed: _isSigningIn ? null : _handleSignIn,
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
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
    });

    try {
      await context.read<StudentDataService>().signInWithGoogle();
    } catch (e) {
      print('Sign in error: $e');
      if (mounted) {
        _resetSignInState();

        String errorMessage = 'Sign in failed. Please try again.';

        if (e.toString().contains('PlatformException')) {
          errorMessage =
              'Google Sign-In temporarily unavailable. Please try again.';
        }

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
