import 'package:flutter/material.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'dart:async';
import '../../models/class_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/local_data_service.dart';
import 'attendance_confirmation_page.dart';

class SwipeAttendancePage extends StatefulWidget {
  final ClassModel classModel;
  const SwipeAttendancePage({super.key, required this.classModel});

  @override
  State<SwipeAttendancePage> createState() => _SwipeAttendancePageState();
}

class _SwipeAttendancePageState extends State<SwipeAttendancePage> {
  final AppinioSwiperController _controller = AppinioSwiperController();
  final Map<String, String> _attendanceStatus = {};

  double _swipeProgress = 0.0;
  double _panDx = 0.0;
  double _panDy = 0.0;
  String? _currentSwipeDirection; // 'left' or 'right'
  int _currentTopIndex = 0; // Only this card reacts to swipe overlays
  Timer? _tutorialTimer;
  bool _isShowingTutorial = false;

  @override
  void initState() {
    super.initState();
    _startTutorialTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tutorialTimer?.cancel();
    super.dispose();
  }

  void _onSwipeEnd(
      int previousIndex, int targetIndex, SwiperActivity activity) {
    final direction = activity.direction;

    final student = widget.classModel.students[previousIndex];
    setState(() {
      if (direction == AxisDirection.left) {
        _attendanceStatus[student.rno] = 'Absent';
      } else if (direction == AxisDirection.right) {
        _attendanceStatus[student.rno] = 'Present';
      }
      // Move overlay state to next top card
      _currentTopIndex = targetIndex;
      _swipeProgress = 0.0;
      _currentSwipeDirection = null;
    });
  }

  void _onEnd() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceConfirmationPage(
              classModel: widget.classModel,
              initialAttendanceStatus: _attendanceStatus,
            ),
          ),
        );
      }
    });
  }

  void _animateSwipeEffect(String direction, double targetProgress) {
    // Cancel tutorial if user interacts
    _cancelTutorial();

    // Set direction immediately
    setState(() {
      _currentSwipeDirection = direction;
    });

    // Animate progress smoothly
    const duration = Duration(milliseconds: 400);
    const steps = 20;
    final stepDuration =
        Duration(milliseconds: duration.inMilliseconds ~/ steps);
    final stepSize = targetProgress / steps;

    for (int i = 0; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: i * stepDuration.inMilliseconds),
          () {
        if (mounted) {
          setState(() {
            _swipeProgress = stepSize * i;
          });
        }
      });
    }

    // Execute actual swipe after animation completes
    Future.delayed(duration, () {
      if (mounted) {
        if (direction == 'left') {
          _controller.swipeLeft();
        } else {
          _controller.swipeRight();
        }
      }
    });
  }

  void _startTutorialTimer() {
    _tutorialTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isShowingTutorial) {
        _showTutorial();
      }
    });
  }

  void _cancelTutorial() {
    _tutorialTimer?.cancel();
    _isShowingTutorial = false;
  }

  void _showTutorial() {
    if (_isShowingTutorial) return;

    setState(() {
      _isShowingTutorial = true;
    });

    // Tutorial sequence: right swipe (Present) -> left swipe (Absent) -> reset
    _animateTutorialStep('right', 0.6, () {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _animateTutorialStep('left', -0.6, () {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                setState(() {
                  _swipeProgress = 0.0;
                  _currentSwipeDirection = null;
                  _isShowingTutorial = false;
                });
                // Restart timer for next tutorial
                _startTutorialTimer();
              }
            });
          });
        }
      });
    });
  }

  void _animateTutorialStep(
      String direction, double targetProgress, VoidCallback onComplete) {
    // Simulate realistic card movement with easing
    const duration = Duration(milliseconds: 1000);
    const steps = 50;
    final stepDuration =
        Duration(milliseconds: duration.inMilliseconds ~/ steps);

    for (int i = 0; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: i * stepDuration.inMilliseconds),
          () {
        if (mounted && _isShowingTutorial) {
          // Apply easing curve for realistic motion
          final progress = i / steps;
          final easedProgress = _easeOutCubic(progress);

          setState(() {
            _swipeProgress = targetProgress * easedProgress;
            _currentSwipeDirection = direction;
          });
        }
      });
    }

    // Hold the position briefly to show the effect
    Future.delayed(duration, () {
      if (mounted && _isShowingTutorial) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _isShowingTutorial) {
            // Animate back to center
            _animateBackToCenter(onComplete);
          }
        });
      }
    });
  }

  double _easeOutCubic(double t) {
    return 1 - (1 - t) * (1 - t) * (1 - t);
  }

  void _animateBackToCenter(VoidCallback onComplete) {
    const duration = Duration(milliseconds: 400);
    const steps = 20;
    final stepDuration =
        Duration(milliseconds: duration.inMilliseconds ~/ steps);
    final currentProgress = _swipeProgress;
    final stepSize = currentProgress / steps;

    for (int i = steps; i >= 0; i--) {
      Future.delayed(
          Duration(milliseconds: (steps - i) * stepDuration.inMilliseconds),
          () {
        if (mounted && _isShowingTutorial) {
          setState(() {
            _swipeProgress = stepSize * i;
            if (i == 0) {
              _currentSwipeDirection = null;
            }
          });
        }
      });
    }

    // Call completion callback after returning to center
    Future.delayed(duration, () {
      if (mounted && _isShowingTutorial) {
        onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen width once to normalize the swipe progress
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Manual Attendance')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate:
                    (_) {}, // capture vertical drags so swiper doesn't move vertically
                onVerticalDragEnd: (_) {
                  // Clear vertical swipe → Undo
                  _controller.unswipe();
                  if (_attendanceStatus.isNotEmpty) {
                    final lastKey = _attendanceStatus.keys.last;
                    setState(() {
                      _attendanceStatus.remove(lastKey);
                    });
                  }
                },
                onPanStart: (_) {
                  _panDx = 0.0;
                  _panDy = 0.0;
                },
                onPanUpdate: (details) {
                  _panDx += details.delta.dx.abs();
                  _panDy += details.delta.dy.abs();
                },
                onPanEnd: (_) {
                  // Only undo if the gesture was VERY vertical (slants stay horizontal)
                  const double minDistance = 14.0;
                  final bool verticalDominates = _panDy > (_panDx * 1.8);
                  if (verticalDominates && _panDy > minDistance) {
                    _controller.unswipe();
                    if (_attendanceStatus.isNotEmpty) {
                      final lastKey = _attendanceStatus.keys.last;
                      setState(() {
                        _attendanceStatus.remove(lastKey);
                      });
                    }
                  }
                  _panDx = 0.0;
                  _panDy = 0.0;
                },
                child: AppinioSwiper(
                  controller: _controller,
                  cardCount: widget.classModel.students.length,
                  onSwipeEnd: _onSwipeEnd,
                  onEnd: _onEnd,
                  onCardPositionChanged: (SwiperPosition position) {
                    // Cancel tutorial if user manually swipes
                    _cancelTutorial();

                    setState(() {
                      // Calculate progress from the horizontal offset
                      // A value from -1.0 (full left) to 1.0 (full right)
                      _swipeProgress = position.offset.dx / screenWidth;

                      // Determine swipe direction based on progress
                      if (_swipeProgress > 0.1) {
                        _currentSwipeDirection = 'right';
                      } else if (_swipeProgress < -0.1) {
                        _currentSwipeDirection = 'left';
                      } else {
                        _currentSwipeDirection = null;
                      }
                    });
                  },
                  cardBuilder: (BuildContext context, int index) {
                    final student = widget.classModel.students[index];
                    // Only show swipe effects for the top card
                    final bool isTopCard = index == _currentTopIndex;
                    final rawProgress = isTopCard ? _swipeProgress.abs() : 0.0;
                    // Smooth opacity curve: starts at 0, gradually increases
                    final swipeProgress =
                        rawProgress > 0.05 ? (rawProgress - 0.05) / 0.95 : 0.0;
                    final isRightSwipe =
                        isTopCard && _currentSwipeDirection == 'right';
                    final isLeftSwipe =
                        isTopCard && _currentSwipeDirection == 'left';

                    Widget cardContent = Container(
                      decoration: BoxDecoration(
                        color: isRightSwipe
                            ? Colors.green.withOpacity(swipeProgress)
                            : isLeftSwipe
                                ? Colors.red.withOpacity(swipeProgress)
                                : Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          // Original student card content
                          Opacity(
                            opacity: isRightSwipe || isLeftSwipe
                                ? 1.0 - (swipeProgress * 0.8)
                                : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Center(
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.blue.shade100,
                                      child: (student.photoUrl.isNotEmpty &&
                                              student.photoUrl
                                                  .startsWith('http'))
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl: student.photoUrl,
                                                cacheManager: LocalDataService
                                                    .imageCacheManager,
                                                imageBuilder:
                                                    (context, imageProvider) =>
                                                        Image(
                                                  image: imageProvider,
                                                  key: ValueKey(
                                                      student.photoUrl),
                                                  width: 120,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                ),
                                                placeholder: (context, url) =>
                                                    Container(
                                                  width: 120,
                                                  height: 120,
                                                  color: Colors.blue.shade50,
                                                ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        Center(
                                                  child: Text(
                                                    student.name.isNotEmpty
                                                        ? student.name[0]
                                                            .toUpperCase()
                                                        : 'S',
                                                    style: const TextStyle(
                                                      fontSize: 56,
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Text(
                                              student.name.isNotEmpty
                                                  ? student.name[0]
                                                      .toUpperCase()
                                                  : 'S',
                                              style: const TextStyle(
                                                fontSize: 56,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Center(
                                    child: Text(
                                      student.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text(
                                      'Roll No: ${student.rno}',
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Tinder-like overlay for right swipe (Present)
                          if (isRightSwipe)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      Colors.green.withOpacity(swipeProgress),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 120 * swipeProgress,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'PRESENT',
                                        style: TextStyle(
                                          fontSize: 32 * swipeProgress,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Tinder-like overlay for left swipe (Absent)
                          if (isLeftSwipe)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(swipeProgress),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cancel,
                                        size: 120 * swipeProgress,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'ABSENT',
                                        style: TextStyle(
                                          fontSize: 32 * swipeProgress,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );

                    // Apply transform only to top card for realistic movement
                    if (isTopCard) {
                      cardContent = Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..translate(_swipeProgress * screenWidth * 0.4, 0)
                          ..rotateZ(_swipeProgress * 0.3), // Realistic rotation
                        child: cardContent,
                      );
                    }

                    return Center(
                      child: SizedBox(
                        width: screenWidth * 0.85,
                        child: cardContent,
                      ),
                    );
                  },
                ),
              ),
            ),
            // On-screen control buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: 'absent_button',
                    onPressed: () {
                      // Animate swipe effect smoothly
                      _animateSwipeEffect('left', -0.8);
                    },
                    backgroundColor: Colors.white,
                    elevation: 4,
                    child: const Icon(Icons.close, color: Colors.red, size: 32),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _controller.unswipe();
                      if (_attendanceStatus.isNotEmpty) {
                        final lastStudentRno = _attendanceStatus.keys.last;
                        setState(() {
                          _attendanceStatus.remove(lastStudentRno);
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16)),
                    child: const Icon(Icons.rotate_left, size: 32),
                  ),
                  FloatingActionButton(
                    heroTag: 'present_button',
                    onPressed: () {
                      // Animate swipe effect smoothly
                      _animateSwipeEffect('right', 0.8);
                    },
                    backgroundColor: Colors.white,
                    elevation: 4,
                    child:
                        const Icon(Icons.check, color: Colors.green, size: 32),
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
