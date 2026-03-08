import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_screen_header.dart';
import '../services/supabase_service.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});
  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _uploading = false;
  final _captionC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await SupabaseService.getProgressPhotos(SupabaseService.currentUser!.id);
      setState(() { _photos = p; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 75);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await FlutterImageCompress.compressWithFile(
            file.path,
            quality: 80,
            minWidth: 1400,
            minHeight: 1400,
            format: CompressFormat.jpeg,
          ) ??
          await file.readAsBytes();
      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await SupabaseService.createProgressPhoto(
        SupabaseService.currentUser!.id,
        base64,
        _captionC.text.trim().isNotEmpty ? _captionC.text.trim() : null,
      );
      _captionC.clear();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
    setState(() => _uploading = false);
  }

  Future<void> _deletePhoto(String id) async {
    await SupabaseService.deleteProgressPhoto(id);
    await _load();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final p in _photos) {
      final d = DateTime.tryParse(p['taken_at'] ?? '');
      final key = d != null ? '${_monthName(d.month)} ${d.year}' : 'Unknown';
      m.putIfAbsent(key, () => []).add(p);
    }
    return m;
  }

  String _monthName(int m) => ['January','February','March','April','May','June','July','August','September','October','November','December'][m - 1];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: ApexColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          ApexScreenHeader(
            eyebrow: 'Progress',
            title: 'Photos',
            subtitle: '${_photos.length} saved shots tracking your transformation.',
            trailing: _photos.length >= 2
                ? ApexButton(
                    text: 'Compare',
                    onPressed: () {},
                    sm: true,
                    color: ApexColors.purple,
                    tone: ApexButtonTone.outline,
                    icon: Icons.compare_arrows_rounded,
                  )
                : null,
          ),
          const SizedBox(height: 14),
          ApexCard(
            glow: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add progress photo', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: ApexColors.t1)),
                const SizedBox(height: 4),
                Text('Capture a new frame or pull one from your library.', style: GoogleFonts.inter(fontSize: 12, color: ApexColors.t2)),
                const SizedBox(height: 14),
                TextField(
                  controller: _captionC,
                  style: GoogleFonts.inter(fontSize: 13, color: ApexColors.t1),
                  decoration: const InputDecoration(hintText: 'Caption (optional) e.g. Week 4 front pose'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _uploadBtn('📷', 'Camera', 'Take new photo', ApexColors.accent, ApexColors.blue, () => _pickImage(ImageSource.camera))),
                    const SizedBox(width: 9),
                    Expanded(child: _uploadBtn('🖼️', 'Gallery', 'Choose from library', ApexColors.purple, ApexColors.pink, () => _pickImage(ImageSource.gallery))),
                  ],
                ),
                const SizedBox(height: 8),
                Center(child: Text('Photos are compressed automatically before upload.', style: TextStyle(fontSize: 10, color: ApexColors.t3))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator(color: ApexColors.accent)))
          else if (_photos.isEmpty)
            ApexCard(
              padding: const EdgeInsets.all(36),
              child: Column(
                children: [
                  const Icon(Icons.photo_camera_back_rounded, size: 48, color: ApexColors.accentSoft),
                  const SizedBox(height: 12),
                  Text('No photos yet', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ApexColors.t1)),
                  const SizedBox(height: 7),
                  Text('Take a photo today and start tracking\nyour transformation!', textAlign: TextAlign.center, style: TextStyle(color: ApexColors.t2, fontSize: 12, height: 1.6)),
                ],
              ),
            )
          else
            ..._grouped.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Divider(color: ApexColors.border)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(entry.key, style: TextStyle(fontSize: 11, color: ApexColors.t2, fontWeight: FontWeight.w700))),
                  Expanded(child: Divider(color: ApexColors.border)),
                ]),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  children: entry.value.map((p) => GestureDetector(
                    onTap: () => _showPhoto(p),
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: ApexColors.border)),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImage(p['photo_data']),
                          if (p['caption'] != null)
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(5, 12, 5, 5),
                                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54])),
                                child: Text(p['caption'], style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 18),
              ],
            )),
        ],
      ),
    );
  }

  Widget _buildImage(String? data) {
    if (data == null) return Container(color: ApexColors.surface);
    if (data.startsWith('data:')) {
      final base64Str = data.split(',').last;
      return Image.memory(base64Decode(base64Str), fit: BoxFit.cover);
    }
    return Image.network(data, fit: BoxFit.cover);
  }

  Widget _uploadBtn(String emoji, String label, String sub, Color c1, Color c2, VoidCallback onTap) {
    return GestureDetector(
      onTap: _uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1.withAlpha(24), c2.withAlpha(24)]),
          border: Border.all(color: c1.withAlpha(80), style: BorderStyle.solid, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _uploading
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c1))
                : Icon(emoji == '📷' ? Icons.photo_camera_rounded : Icons.photo_library_rounded, size: 28, color: c1),
            const SizedBox(height: 7),
            Text(_uploading ? 'Uploading...' : label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: c1)),
            Text(sub, style: TextStyle(fontSize: 9, color: ApexColors.t2)),
          ],
        ),
      ),
    );
  }

  void _showPhoto(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: ApexColors.t1), onPressed: () => Navigator.pop(ctx)),
          title: Text(_formatDate(photo['taken_at']), style: TextStyle(color: ApexColors.t2, fontSize: 10)),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(ctx); _deletePhoto(photo['id']); },
              child: Text('🗑 Delete', style: TextStyle(color: ApexColors.red, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(16), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildImage(photo['photo_data']))))),
            if (photo['caption'] != null) Padding(padding: const EdgeInsets.all(10), child: Text(photo['caption'], style: TextStyle(color: ApexColors.t2, fontSize: 12, fontStyle: FontStyle.italic), textAlign: TextAlign.center)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${_monthName(d.month).substring(0, 3)} ${d.year}';
    } catch (_) { return ''; }
  }

  @override
  void dispose() { _captionC.dispose(); super.dispose(); }
}
