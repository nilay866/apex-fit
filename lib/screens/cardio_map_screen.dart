import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';
import 'tracking_summary_screen.dart';

typedef RunStateCallback =
    void Function({
      required bool active,
      required bool paused,
      required double distanceKm,
      required int elapsedSeconds,
      required double paceMinPerKm,
    });

class CardioMapScreen extends StatefulWidget {
  final Map<String, dynamic> workout;
  final VoidCallback onFinish;
  final RunStateCallback? onStateUpdate;

  const CardioMapScreen({
    super.key,
    required this.workout,
    required this.onFinish,
    this.onStateUpdate,
  });

  @override
  State<CardioMapScreen> createState() => _CardioMapScreenState();
}

class _CardioMapScreenState extends State<CardioMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;

  final List<LatLng> _routeCoords = [];
  double _totalDistanceMeters = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _isActive = false;
  bool _followUser = true;

  // Split tracking — list of (km number, seconds elapsed at that km)
  final List<Map<String, dynamic>> _splits = [];
  double _lastSplitKm = 0;

  // Live speed (m/s from GPS)
  double _currentSpeedMs = 0;
  
  // NEW: Store raw GPS points for the new tracking system
  final List<Map<String, dynamic>> _gpsPoints = [];

  // User profile weight for calorie calculation
  double _userWeightKg = 70.0;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await SupabaseService.getProfile(
        SupabaseService.requireUserId(action: 'load your cardio profile'),
      );
      if (p != null && p['weight_kg'] != null) {
        _userWeightKg = (p['weight_kg'] as num).toDouble();
      }
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    _moveToPos(pos);
  }

  void _moveToPos(Position pos) {
    if (_followUser) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 17);
    }
    if (mounted) {
      setState(() => _routeCoords.add(LatLng(pos.latitude, pos.longitude)));
    }
  }

  void _fireStateUpdate() {
    widget.onStateUpdate?.call(
      active: _isActive,
      paused: !_isActive && _elapsedSeconds > 0,
      distanceKm: _totalDistanceMeters / 1000,
      elapsedSeconds: _elapsedSeconds,
      paceMinPerKm: _paceMinPerKm,
    );
  }

  void _toggleTracking() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _startTracking();
      } else {
        _pauseTracking();
      }
    });
    _fireStateUpdate();
  }

  void _startTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 4, // update every 4 meters
          ),
        ).listen((Position position) {
          if (!mounted) return;
          setState(() {
            final newPoint = LatLng(position.latitude, position.longitude);
            if (_routeCoords.isNotEmpty) {
              final delta = Geolocator.distanceBetween(
                _routeCoords.last.latitude,
                _routeCoords.last.longitude,
                newPoint.latitude,
                newPoint.longitude,
              );
              _totalDistanceMeters += delta;
            }
            _routeCoords.add(newPoint);
            _currentSpeedMs = position.speed > 0
                ? position.speed
                : _currentSpeedMs;

            // NEW: Record GPS point for summary
            _gpsPoints.add({
              'lat': position.latitude,
              'lng': position.longitude,
              'elevation': position.altitude,
              'speed': position.speed,
              'heart_rate': null, // Need external HR sensor for this
              'cadence': null,
              'recorded_at': DateTime.now().toIso8601String(),
            });

            // Split tracking — record each completed km
            final currentKm = _totalDistanceMeters / 1000;
            if (currentKm - _lastSplitKm >= 1.0) {
              _lastSplitKm = currentKm.floorToDouble();
              _splits.add({
                'km': _lastSplitKm.toInt(),
                'seconds': _elapsedSeconds,
              });
              HapticFeedback.heavyImpact(); // buzz on each km milestone
            }
          });
          _moveToPos(position);
          _fireStateUpdate(); // Update live banner in main_shell
        });
  }

  void _pauseTracking() {
    _timer?.cancel();
    _positionStream?.cancel();
  }

  Future<void> _finishWorkout() async {
    HapticFeedback.heavyImpact();
    _pauseTracking();

    // Calculate total elevation gain/loss from _gpsPoints
    double elevationGain = 0;
    double elevationLoss = 0;
    for (var i = 1; i < _gpsPoints.length; i++) {
      final prev = (_gpsPoints[i - 1]['elevation'] as num?)?.toDouble() ?? 0;
      final curr = (_gpsPoints[i]['elevation'] as num?)?.toDouble() ?? 0;
      final diff = curr - prev;
      if (diff > 0) {
        elevationGain += diff;
      } else if (diff < 0) {
        elevationLoss += diff.abs();
      }
    }

    final distanceKm = _totalDistanceMeters / 1000;
    final maxSpeed = _gpsPoints.isEmpty 
      ? 0.0 
      : _gpsPoints.map((p) => (p['speed'] as num?)?.toDouble() ?? 0.0)
          .reduce((a, b) => a > b ? a : b) * 3.6; // m/s to km/h

    // Close the live map completely
    widget.onFinish();

    // Push the summary screen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TrackingSummaryScreen(
            activityType: widget.workout['activityType'] ?? 'run',
            distanceKm: distanceKm,
            durationSeconds: _elapsedSeconds,
            avgPace: _paceMinPerKm,
            maxSpeed: maxSpeed,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            splits: _splits,
            gpsPoints: _gpsPoints,
            userWeightKg: _userWeightKg,
          ),
        ),
      );
    }
  }

  // ─── Computed getters ────────────────────────────────────────────────────

  String get _formattedTime =>
      '${(_elapsedSeconds ~/ 3600).toString().padLeft(2, '0')}:'
      '${((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:'
      '${(_elapsedSeconds % 60).toString().padLeft(2, '0')}';

  double get _paceMinPerKm {
    if (_totalDistanceMeters < 10) return 0;
    return (_elapsedSeconds / 60) / (_totalDistanceMeters / 1000);
  }

  String get _formattedPace {
    if (_paceMinPerKm == 0 || _paceMinPerKm > 60) return '--:--';
    final m = _paceMinPerKm.floor();
    final s = ((_paceMinPerKm - m) * 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _liveSpeed {
    if (_currentSpeedMs <= 0) return '0.0';
    return (_currentSpeedMs * 3.6).toStringAsFixed(1); // m/s to km/h
  }

  double get _kcal {
    final hours = _elapsedSeconds / 3600;
    return 9.0 * _userWeightKg * hours;
  }

  // Split pace string for a split
  String _splitPace(int splitSecs, int km) {
    if (km == 0) return '--:--';
    final prev = km > 1
        ? (_splits.firstWhere(
                (s) => s['km'] == km - 1,
                orElse: () => {'seconds': 0},
              )['seconds']
              as int)
        : 0;
    final delta = splitSecs - prev;
    final m = (delta ~/ 60).toString().padLeft(2, '0');
    final s = (delta % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: Stack(
        children: [
          // ─── Map Layer ─────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(0, 0),
              initialZoom: 17,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (_routeCoords.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeCoords,
                      color: ApexColors.accent,
                      strokeWidth: 6,
                      strokeJoin: StrokeJoin.round,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              CurrentLocationLayer(),
            ],
          ),

          // ─── Top bar ────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_elapsedSeconds > 0) {
                      _showExitConfirm();
                    } else {
                      widget.onFinish();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xDD1C1C1F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _followUser = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xDD1C1C1F),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          color: _followUser
                              ? ApexColors.accent
                              : Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Center',
                          style: TextStyle(
                            color: _followUser
                                ? ApexColors.accent
                                : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Telemetry Panel ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 20),
              decoration: const BoxDecoration(
                color: Color(0xF51C1C1F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Big timer
                  Text(
                    _formattedTime,
                    style: GoogleFonts.inter(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat(
                        label: 'KM',
                        value: (_totalDistanceMeters / 1000).toStringAsFixed(2),
                        color: ApexColors.accent,
                      ),
                      _divider(),
                      _Stat(
                        label: 'PACE /KM',
                        value: _formattedPace,
                        color: ApexColors.blue,
                      ),
                      _divider(),
                      _Stat(
                        label: 'KCAL',
                        value: _kcal.round().toString(),
                        color: ApexColors.orange,
                      ),
                      _divider(),
                      _Stat(
                        label: 'KM/H',
                        value: _liveSpeed,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Splits
                  if (_splits.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_rounded,
                            color: ApexColors.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SPLITS',
                            style: TextStyle(
                              color: ApexColors.t3,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _splits.map((s) {
                                  final km = s['km'] as int;
                                  final secs = s['seconds'] as int;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'km $km',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          _splitPace(secs, km),
                                          style: TextStyle(
                                            color: ApexColors.t3,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Control buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _toggleTracking,
                          child: Container(
                            height: 58,
                            decoration: BoxDecoration(
                              color: _isActive
                                  ? const Color(0xFF2A2A2D)
                                  : ApexColors.accent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isActive
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: _isActive
                                        ? ApexColors.t1
                                        : Colors.black,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isActive
                                        ? 'PAUSE'
                                        : (_elapsedSeconds > 0
                                              ? 'RESUME'
                                              : 'START'),
                                    style: TextStyle(
                                      color: _isActive
                                          ? ApexColors.t1
                                          : Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_elapsedSeconds > 0) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _finishWorkout,
                          child: Container(
                            height: 58,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: ApexColors.red.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: ApexColors.red.withAlpha(80),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'FINISH',
                                style: TextStyle(
                                  color: ApexColors.red,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExitConfirm() {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1F),
        title: Text(
          'End Run?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Your run data will be lost.',
          style: TextStyle(color: ApexColors.t3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Continue', style: TextStyle(color: ApexColors.accent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onFinish();
            },
            child: Text(
              'Exit',
              style: TextStyle(
                color: ApexColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: Colors.white12);
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: ApexColors.t3,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}
