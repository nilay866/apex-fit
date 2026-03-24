import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS tracking is not available in the web browser. Use the mobile app for cardio tracking.')),
        );
      }
      return;
    }

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
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
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
                      color: ApexColors.green,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: ApexColors.green.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'GPS Ready',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
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
              padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 12),
              decoration: BoxDecoration(
                color: ApexColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: ApexColors.shadow.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main metrics row (Distance, Pace, Time)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Stat(
                        label: 'DISTANCE',
                        value: (_totalDistanceMeters / 1609.34).toStringAsFixed(2),
                        suffix: ' mi',
                        color: ApexColors.t1,
                      ),
                      _Stat(
                        label: 'AVERAGE',
                        value: _formattedPace,
                        suffix: ' /mi',
                        color: ApexColors.t1,
                      ),
                      _Stat(
                        label: 'DURATION',
                        value: _formattedTime,
                        color: ApexColors.t1,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Secondary highlights (Calories, splits preview etc)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CompactStat(
                        icon: Icons.local_fire_department_rounded,
                        value: '${_kcal.round()} kcal',
                      ),
                      _CompactStat(
                        icon: Icons.trending_up_rounded,
                        value: '$_liveSpeed km/h',
                      ),
                      if (_splits.isNotEmpty)
                        _CompactStat(
                          icon: Icons.flag_rounded,
                          value: '${_splits.length} splits',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ─── Floating Controls Overlapping the Lip ───────────────────────
          Positioned(
            bottom: bottomPad + 115, // Positioned above the metrics
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_elapsedSeconds > 0) ...[
                  GestureDetector(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: ApexColors.yellow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ApexColors.yellow.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _toggleTracking,
                        icon: Icon(
                          _isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: ApexColors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ApexColors.red.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _finishWorkout,
                        icon: const Icon(
                          Icons.stop_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ] else
                  GestureDetector(
                    onTap: _toggleTracking,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: ApexColors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ApexColors.green.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
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
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final Color color;
  const _Stat({
    required this.label,
    required this.value,
    this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -1,
              ),
            ),
            if (suffix != null)
              Text(
                suffix!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ApexColors.t3,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            color: ApexColors.t3,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _CompactStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ApexColors.cardAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ApexColors.t2),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: ApexColors.t1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
