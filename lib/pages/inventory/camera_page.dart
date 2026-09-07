import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/photo_storage_service.dart';

// ไอเทม Camera — ถ่ายรูปแล้วได้ "EcoQuest Moment" การ์ดที่มีกรอบเฉพาะของแอพ
// ต่างจากถ่ายรูปธรรมดาตรงที่แปะข้อมูลผู้เล่นจริง (ชื่อ / Lv. / Rank / วันที่) ลงไปในรูปเลย
// รูปที่เซฟคือ "รูปใหม่ที่ตกแต่งแล้ว" ไม่ใช่รูปดิบ — เรนเดอร์การ์ดทั้งใบเป็น PNG ด้วย RepaintBoundary
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final _picker = ImagePicker();
  final _storage = PhotoStorageService();
  // ใช้จับ widget การ์ดที่แสดงอยู่บนจอ แล้วแปลงเป็นรูป
  final _frameKey = GlobalKey();

  String? _shotPath; // รูปดิบที่เพิ่งถ่าย (ยังไม่ได้เซฟ)
  List<String> _savedPhotos = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final photos = await _storage.loadPhotos();
    if (mounted) setState(() => _savedPhotos = photos);
  }

  Future<void> _takePhoto(ImageSource source) async {
    try {
      final shot = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 90);
      if (shot != null && mounted) {
        setState(() => _shotPath = shot.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera')),
      );
    }
  }

  // เรนเดอร์การ์ดบนจอเป็น PNG bytes — ใช้ร่วมกันทั้งตอนเซฟเข้าแอพและเซฟลงเครื่อง
  Future<Uint8List> _renderFrame() async {
    final boundary = _frameKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Frame is not ready');

    // pixelRatio 3 เพื่อให้ไฟล์คมพอเอาไปใช้ต่อ ไม่ใช่ขนาดเท่าที่เห็นบนจอ
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Could not render the photo');

    return byteData.buffer.asUint8List();
  }

  // บันทึกลงแกลเลอรีของเครื่องจริงๆ (คนละที่กับ Save Moment ที่เก็บไว้ในแอพ)
  // gal จัดการ MediaStore + ขอ permission ให้เอง
  Future<void> _saveToDevice({Uint8List? bytes, String? filePath}) async {
    try {
      // toAlbum: true เพราะเราเซฟลงอัลบั้มชื่อ "EcoQuest" ไม่ใช่ที่เก็บรวมของแอพ
      if (!await Gal.hasAccess(toAlbum: true)) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo permission is required to save to your device')),
          );
          return;
        }
      }

      if (bytes != null) {
        await Gal.putImageBytes(bytes, album: 'EcoQuest');
      } else if (filePath != null) {
        await Gal.putImage(filePath, album: 'EcoQuest');
      }

      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your device gallery')),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save to device: ${e.type.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save to device')),
      );
    }
  }

  Future<void> _saveShotToDevice() async {
    try {
      await _saveToDevice(bytes: await _renderFrame());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // เรนเดอร์การ์ดที่เห็นบนจอเป็นไฟล์ PNG จริง
  Future<void> _saveMoment() async {
    setState(() => _isSaving = true);

    try {
      await _storage.savePhoto(await _renderFrame());
      await _loadSaved();

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _shotPath = null;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moment saved to your collection')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  Future<void> _confirmDelete(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete moment?'),
        content: const Text('This photo will be removed from your collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _storage.deletePhoto(path);
    await _loadSaved();
  }

  void _openPhoto(String path) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(File(path)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // รูปนี้เซฟไว้ในแอพแล้ว เลยส่ง path ไปให้ gal ตรงๆ ไม่ต้องเรนเดอร์ใหม่
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveToDevice(filePath: path);
                  },
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Save to device', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDelete(path);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  label: const Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final progress = context.watch<AuthProvider>().profile?.progress;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  _CircleBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  const Text('Camera',
                      style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: _shotPath == null
                  ? _CollectionView(
                      photos: _savedPhotos,
                      onTakePhoto: () => _takePhoto(ImageSource.camera),
                      onPickFromGallery: () => _takePhoto(ImageSource.gallery),
                      onOpenPhoto: _openPhoto,
                    )
                  : _PreviewView(
                      frameKey: _frameKey,
                      shotPath: _shotPath!,
                      displayName: user?.displayName ?? 'Player',
                      level: progress?.level ?? user?.level ?? 1,
                      rank: progress?.rankTier ?? user?.rank ?? 'Bronze',
                      isSaving: _isSaving,
                      onRetake: () => setState(() => _shotPath = null),
                      onSave: _saveMoment,
                      onSaveToDevice: _saveShotToDevice,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// หน้าพรีวิวก่อนเซฟ — โชว์การ์ดที่ตกแต่งแล้ว + ปุ่มถ่ายใหม่/เซฟ
// ---------------------------------------------------------------------------
class _PreviewView extends StatelessWidget {
  final GlobalKey frameKey;
  final String shotPath;
  final String displayName;
  final int level;
  final String rank;
  final bool isSaving;
  final VoidCallback onRetake;
  final VoidCallback onSave;
  final VoidCallback onSaveToDevice;

  const _PreviewView({
    required this.frameKey,
    required this.shotPath,
    required this.displayName,
    required this.level,
    required this.rank,
    required this.isSaving,
    required this.onRetake,
    required this.onSave,
    required this.onSaveToDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Center(
              // RepaintBoundary คือตัวที่ถูกแปลงเป็นไฟล์รูป — ต้องครอบเฉพาะการ์ด
              // ไม่ให้มีปุ่มหรือพื้นหลังหน้าจออื่นติดไปในรูปที่เซฟ
              child: RepaintBoundary(
                key: frameKey,
                child: _MomentFrame(
                  shotPath: shotPath,
                  displayName: displayName,
                  level: level,
                  rank: rank,
                  date: DateTime.now(),
                ),
              ),
            ),
          ),
        ),
        // เซฟลงแกลเลอรีของเครื่อง — คนละที่กับ Save Moment ที่เก็บไว้ในคอลเลกชันของแอพ
        TextButton.icon(
          onPressed: isSaving ? null : onSaveToDevice,
          icon: const Icon(Icons.download, size: 18, color: Colors.green),
          label: const Text('Save to device', style: TextStyle(color: Colors.green)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : onRetake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isSaving ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Moment',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ⭐ กรอบ "EcoQuest Moment" — ตัวที่ทำให้รูปต่างจากถ่ายธรรมดา
//
// ดีไซน์: การ์ดขาวทรงโพลารอยด์ + รูปสี่เหลี่ยมจัตุรัสด้านบน
//   - บนรูป: ป้ายเขียว EcoQuest มุมซ้ายบน, ไล่เฉดมืดด้านล่าง, ป้าย Lv./Rank มุมซ้ายล่าง
//   - ใต้รูป: ชื่อผู้เล่น + เมือง / วันที่ + ใบไม้เขียว
// ทั้งใบถูกเรนเดอร์เป็นไฟล์ PNG ตอนกดเซฟ
// ---------------------------------------------------------------------------
class _MomentFrame extends StatelessWidget {
  final String shotPath;
  final String displayName;
  final int level;
  final String rank;
  final DateTime date;

  const _MomentFrame({
    required this.shotPath,
    required this.displayName,
    required this.level,
    required this.rank,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(shotPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image_outlined, color: Colors.white70),
                    ),
                  ),
                  // ไล่เฉดมืดด้านล่าง ให้ป้ายที่ทับอยู่อ่านออกไม่ว่ารูปจะสว่างแค่ไหน
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 90,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ป้ายแบรนด์มุมซ้ายบน
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.eco, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'EcoQuest',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // แถบ Lv. / Rank มุมซ้ายล่างของรูป
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        _StatChip(text: 'Lv. ${level.toString().padLeft(2, '0')}'),
                        const SizedBox(width: 6),
                        _StatChip(text: rank),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ---- แถบข้อมูลใต้รูป ----
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Ebetsu City · ${_formatDate(date)}',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco, color: Colors.green, size: 17),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String text;
  const _StatChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// หน้ารวมรูปที่เซฟไว้ + ปุ่มถ่ายรูป
// ---------------------------------------------------------------------------
class _CollectionView extends StatelessWidget {
  final List<String> photos;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final ValueChanged<String> onOpenPhoto;

  const _CollectionView({
    required this.photos,
    required this.onTakePhoto,
    required this.onPickFromGallery,
    required this.onOpenPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: photos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No moments yet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Capture your eco moments — each photo gets an EcoQuest frame with your level and rank',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82, // ทรงเดียวกับการ์ด moment
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final path = photos[index];
                    return GestureDetector(
                      onTap: () => onOpenPhoto(path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey.shade200,
                            child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTakePhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  icon: const Icon(Icons.photo_camera, size: 20),
                  label: const Text('Take Photo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: onPickFromGallery,
                tooltip: 'Choose from gallery',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, color: Colors.green),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chevron_left, color: Colors.black54, size: 22),
      ),
    );
  }
}
