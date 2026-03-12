import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../services/supabase_service.dart';

typedef RunStateCallback = void Function({
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
  final Completer<GoogleMapController> _controller = Completer();
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

  // User profile weight for calorie calculation
  double _userWeightKg = 70.0;

  // Dark map style
  static const String _darkMapStyle = '''
[{"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
{"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
{"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
{"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
{"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]}]
''';

  static const CameraPosition _initialCam = CameraPosition(
    target: LatLng(0, 0),
    zoom: 17,
  );

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await SupabaseService.getProfile(SupabaseService.currentUser!.id);
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

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _moveToPos(pos);
  }

  Future<void> _moveToPos(Position pos) async {
    if (!_controller.isCompleted) return;
    final GoogleMapController controller = await _controller.future;
    if (_followUser) {
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 17),
      ));
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
      if (_isActive) _startTracking();
      else _pauseTracking();
    });
    _fireStateUpdate();
  }

  void _startTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    _positionStream = Geolocator.getPositionStream(
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
            _routeCoords.last.latitude, _routeCoords.last.longitude,
            newPoint.latitude, newPoint.longitude,
          );
          _totalDistanceMeters += delta;
        }
        _routeCoords.add(newPoint);
        _currentSpeedMs = position.speed > 0 ? position.speed : _currentSpeedMs;

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
    try {
      await SupabaseService.createWorkoutLog({
        'user_id': SupabaseService.currentUser!.id,
        'workout_name': widget.workout['name'] ?? 'Outdoor Run',
        'duration_min': (_elapsedSeconds / 60).round(),
        'total_volume': 0,
        'intensity': 'moderate',
        'completed_at': DateTime.now().toIso8601String(),
        'notes': 'Distance: ${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km | '
            'Pace: $_formattedPace /km | '
            'Calories: ${_kcal.round()} kcal | '
            'Splits: ${_splits.map((s) => 'km${s['km']}=${_formatSeconds(s['seconds'])}').join(', ')}',
      });
    } catch (_) {}
    if (mounted) widget.onFinish();
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

  String _formatSeconds(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Split pace string for a split
  String _splitPace(int splitSecs, int km) {
    if (km == 0) return '--:--';
    final prev = km > 1 ? (_splits.firstWhere((s) => s['km'] == km - 1, orElse: () => {'seconds': 0})['seconds'] as int) : 0;
    final delta = splitSecs - prev;
    final m = (delta ~/ 60).toString().padLeft(2, '0');
    final s = (delta % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: Stack(
        children: [
          // ─── Google Map ─────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _initialCam,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (c) {
              _controller.complete(c);
              c.setMapStyle(_darkMapStyle);
            },
            onCameraMoveStarted: () => setState(() => _followUser = false),
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routeCoords,
                color: ApexColors.accent,
                width: 6,
                jointType: JointType.round,
                endCap: Cap.roundCap,
                startCap: Cap.roundCap,
              ),
            },
          ),

          // ─── Top bar ────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
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
                    decoration: BoxDecoration(color: const Color(0xDD1C1C1F), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _followUser = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xDD1C1C1F), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Icon(Icons.my_location_rounded, color: _followUser ? ApexColors.accent : Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text('Center', style: TextStyle(color: _followUser ? ApexColors.accent : Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // ─── Telemetry Panel ─────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
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
                    style: GoogleFonts.inter(fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -2),
                  ),
                  const SizedBox(height: 16),

                  // Main stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat(label: 'KM', value: (_totalDistanceMeters / 1000).toStringAsFixed(2), color: ApexColors.accent),
                      _divider(),
                      _Stat(label: 'PACE /KM', value: _formattedPace, color: ApexColors.blue),
                      _divider(),
                      _Stat(label: 'KCAL', value: _kcal.round().toString(), color: ApexColors.orange),
                      _divider(),
                      _Stat(label: 'KM/H', value: _liveSpeed, color: Colors.white70),
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
                          const Icon(Icons.flag_rounded, color: ApexColors.accent, size: 16),
                          const SizedBox(width: 8),
                          Text('SPLITS', style: TextStyle(color: ApexColors.t3, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('km $km', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                        Text(_splitPace(secs, km), style: TextStyle(color: ApexColors.t3, fontSize: 10)),
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
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _toggleTracking,
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: _isActive ? const Color(0xFF2A2A2D) : ApexColors.accent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: _isActive ? ApexColors.t1 : Colors.black,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isActive ? 'PAUSE' : (_elapsedSeconds > 0 ? 'RESUME' : 'START'),
                                style: TextStyle(
                                  color: _isActive ? ApexColors.t1 : Colors.black,
                                  fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1,
                                ),
                              ),
                            ],
                          )),
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
                            border: Border.all(color: ApexColors.red.withAlpha(80)),
                          ),
                          child: Center(child: Text('FINISH', style: TextStyle(color: ApexColors.red, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1))),
                        ),
                      ),
                    ],
                  ]),
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
        title: Text('End Run?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text('Your run data will be lost.', style: TextStyle(color: ApexColors.t3)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Continue', style: TextStyle(color: ApexColors.accent))),
          TextButton(onPressed: () { Navigator.pop(ctx); widget.onFinish(); }, child: Text('Exit', style: TextStyle(color: ApexColors.red, fontWeight: FontWeight.w700))),
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
        Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: ApexColors.t3, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
      ],
    );
  }
}
