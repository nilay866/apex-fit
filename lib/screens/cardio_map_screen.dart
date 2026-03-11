import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../services/supabase_service.dart';

class CardioMapScreen extends StatefulWidget {
  final Map<String, dynamic> workout;
  final VoidCallback onFinish;

  const CardioMapScreen({super.key, required this.workout, required this.onFinish});

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
  
  // User profile weight for calorie calculation
  double _userWeightKg = 70.0; // default

  static const CameraPosition _initialCam = CameraPosition(
    target: LatLng(0, 0),
    zoom: 15,
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    _moveToPos(pos);
  }

  Future<void> _moveToPos(Position pos) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 17),
    ));
    setState(() {
      _routeCoords.add(LatLng(pos.latitude, pos.longitude));
    });
  }

  void _toggleTracking() {
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _startTracking();
      } else {
        _pauseTracking();
      }
    });
  }

  void _startTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 meters
      ),
    ).listen((Position position) {
      setState(() {
        final newPoint = LatLng(position.latitude, position.longitude);
        if (_routeCoords.isNotEmpty) {
          _totalDistanceMeters += Geolocator.distanceBetween(
            _routeCoords.last.latitude,
            _routeCoords.last.longitude,
            newPoint.latitude,
            newPoint.longitude,
          );
        }
        _routeCoords.add(newPoint);
      });
      _moveToPos(position);
    });
  }

  void _pauseTracking() {
    _timer?.cancel();
    _positionStream?.cancel();
  }

  Future<void> _finishWorkout() async {
    _pauseTracking();
    
    // Save to DB
    try {
      await SupabaseService.createWorkoutLog({
        'user_id': SupabaseService.currentUser!.id,
        'workout_name': widget.workout['name'] ?? 'Outdoor Run',
        'duration_min': (_elapsedSeconds / 60).round(),
        'total_volume': 0,
        'intensity': 'moderate',
        'completed_at': DateTime.now().toIso8601String(),
        'notes': 'Distance: ${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km. Calories: ${_kcal.round()} kcal.',
      });
    } catch (_) {}
    
    if (mounted) widget.onFinish();
  }

  // Telemetry getters
  String get _formattedTime => '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}';
  
  double get _paceMinPerKm {
    if (_totalDistanceMeters == 0) return 0;
    return (_elapsedSeconds / 60) / (_totalDistanceMeters / 1000);
  }

  String get _formattedPace {
    if (_paceMinPerKm == 0 || _paceMinPerKm > 60) return '--:--';
    final m = _paceMinPerKm.floor();
    final s = ((_paceMinPerKm - m) * 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _kcal {
    // Basic approximation: Calories = METs x bodyWeightKg x durationHours
    // Running MET approx 8-10. Let's assume 9 for simplicity.
    final hours = _elapsedSeconds / 3600;
    return 9.0 * _userWeightKg * hours;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _initialCam,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routeCoords,
                color: ApexColors.accent,
                width: 6,
              )
            },
          ),
          
          // Header / Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: widget.onFinish,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: ApexColors.card, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: ApexColors.t1),
              ),
            ),
          ),

          // Telemetry Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
              decoration: BoxDecoration(
                color: ApexColors.bg.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formattedTime,
                    style: ApexTheme.mono(size: 64, color: ApexColors.t1).copyWith(fontWeight: FontWeight.w300),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TelemetryStat(label: 'DISTANCE (KM)', value: (_totalDistanceMeters / 1000).toStringAsFixed(2)),
                      _TelemetryStat(label: 'PACE (/KM)', value: _formattedPace),
                      _TelemetryStat(label: 'KCAL', value: _kcal.round().toString()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _toggleTracking,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: _isActive ? ApexColors.card : ApexColors.accent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                _isActive ? 'PAUSE' : (_elapsedSeconds > 0 ? 'RESUME' : 'START'),
                                style: TextStyle(
                                  color: _isActive ? ApexColors.t1 : ApexColors.bg,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_elapsedSeconds > 0) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: _finishWorkout,
                          child: Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'FINISH',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
}

class _TelemetryStat extends StatelessWidget {
  final String label;
  final String value;
  
  const _TelemetryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: ApexTheme.mono(size: 28, color: ApexColors.t1).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: ApexColors.t3, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }
}
