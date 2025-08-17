import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _rotateController;
  late AnimationController _floatingController;
  late AnimationController _buttonController;
  late AnimationController _pulseController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _buttonFadeAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Set status bar to transparent for immersive experience
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    
    _initAnimations();
    _startAnimations();
  }
  
  void _initAnimations() {
    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Scale animation controller
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Slide animation controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    
    // Rotation animation controller
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    // Floating animation controller (continuous loop)
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    // Button animation controller
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Pulse animation controller for button glow effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Define animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeInOut,
    ));
    
    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
    
    _buttonFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));
    
    _buttonScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  void _startAnimations() async {
    // Start fade animation immediately
    _fadeController.forward();
    
    // Start scale animation after a small delay
    await Future.delayed(const Duration(milliseconds: 300));
    _scaleController.forward();
    
    // Start slide animation for text
    await Future.delayed(const Duration(milliseconds: 600));
    _slideController.forward();
    
    // Start rotation animation for logo
    await Future.delayed(const Duration(milliseconds: 200));
    _rotateController.forward();
    
    // Start floating animation (continuous loop)
    _floatingController.repeat(reverse: true);
    
    // Show button after all main animations complete
    await Future.delayed(const Duration(milliseconds: 1200));
    _buttonController.forward();
    
    // Start pulse animation for button after it appears
    await Future.delayed(const Duration(milliseconds: 400));
    _pulseController.repeat(reverse: true);
  }
  
  void _navigateToLogin() {
    // Add a slight fade out before navigation for smoother transition
    _fadeController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _rotateController.dispose();
    _floatingController.dispose();
    _buttonController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildFloatingElement({
    required double top,
    required double left,
    required IconData icon,
    required double size,
    required double delay,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: AnimatedBuilder(
        animation: _floatingAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              math.sin(_floatingAnimation.value * 2 * math.pi + delay) * 10,
              math.cos(_floatingAnimation.value * 2 * math.pi + delay) * 15,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Icon(
                icon,
                size: size,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E7D32), // Dark green
              Color(0xFF4CAF50), // Medium green
              Color(0xFF81C784), // Light green
              Color(0xFFC8E6C9), // Very light green
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Floating decorative elements
            _buildFloatingElement(
              top: 100,
              left: 50,
              icon: Icons.directions_car,
              size: 30,
              delay: 0,
            ),
            _buildFloatingElement(
              top: 150,
              left: MediaQuery.of(context).size.width - 80,
              icon: Icons.location_on,
              size: 25,
              delay: 1,
            ),
            _buildFloatingElement(
              top: 250,
              left: 30,
              icon: Icons.eco,
              size: 28,
              delay: 2,
            ),
            _buildFloatingElement(
              top: 350,
              left: MediaQuery.of(context).size.width - 100,
              icon: Icons.route,
              size: 24,
              delay: 3,
            ),
            _buildFloatingElement(
              top: MediaQuery.of(context).size.height - 200,
              left: 80,
              icon: Icons.speed,
              size: 26,
              delay: 4,
            ),
            _buildFloatingElement(
              top: MediaQuery.of(context).size.height - 150,
              left: MediaQuery.of(context).size.width - 120,
              icon: Icons.qr_code,
              size: 22,
              delay: 5,
            ),
            
            // Main content
            Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo with rotation and scale
              AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _rotateAnimation]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child:                       Transform.rotate(
                      angle: _rotateAnimation.value * 0.5, // Half rotation for subtle effect
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background circle
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Main parking icon
                            const Icon(
                              Icons.local_parking,
                              size: 50,
                              color: Color(0xFF2E7D32),
                            ),
                            // Small car icon overlay
                            Positioned(
                              bottom: 15,
                              right: 15,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.directions_car,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // Animated app name with slide effect
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'AutoSpot',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 3),
                          blurRadius: 6,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Animated tagline
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Smart Parking Solutions',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Animated loading indicator
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3.0,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Continue button
              FadeTransition(
                opacity: _buttonFadeAnimation,
                child: ScaleTransition(
                  scale: _buttonScaleAnimation,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          margin: const EdgeInsets.only(top: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 20 * _pulseAnimation.value,
                                spreadRadius: 5 * (_pulseAnimation.value - 1),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                      onPressed: _navigateToLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black26,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 20,
                          ),
                        ],
                      ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
            ),
          ],
        ),
      ),
    );
  }
}