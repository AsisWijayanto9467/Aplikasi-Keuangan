// lib/pages/App/scan_receipt_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend_flutter/services/transaction_service.dart';
import 'transaction_page.dart';

class ScanReceiptPage extends StatefulWidget {
  final String token;

  const ScanReceiptPage({super.key, required this.token});

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  File? _selectedImage;
  Map<String, dynamic>? _scanResult;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _errorMessage = null;
        _scanResult = null;
      });

      await _scanReceipt();
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengambil gambar: $e';
      });
    }
  }

  Future<void> _scanReceipt() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await TransactionService.scanReceipt(
        token: widget.token,
        imageFile: _selectedImage!,
      );

      setState(() {
        _scanResult = result;
        _isProcessing = false;
      });

      _navigateToTransactionPage(result);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  void _navigateToTransactionPage(Map<String, dynamic> scanResult) {
    final transactionData = {
      'title': scanResult['title'] ?? '',
      'amount': scanResult['amount']?.toString() ?? '',
      'description': scanResult['description'] ?? '',
      'payment_method': scanResult['payment_method'] ?? 'cash',
      'type': scanResult['type'] ?? 'expense',
      'date': scanResult['date'] ?? DateTime.now().toString().split(' ')[0],
      'suggested_category_id': scanResult['suggested_category_id']?.toString() ?? '',
      'raw_text': scanResult['raw_text'] ?? '',
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionsPage(
          token: widget.token,
          transactionToEdit: null,
          scanData: transactionData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // ⭐ TOP BLUE SECTION - Mirip Dashboard
          _buildTopBlueSection(),
          
          // ⭐ CONTENT SECTION
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Preview area
                  _buildPreviewArea(),
                  const SizedBox(height: 20),
                  
                  // Action buttons
                  if (!_isProcessing && _scanResult == null) ...[
                    _buildActionButtons(),
                  ],
                  
                  // Processing indicator
                  if (_isProcessing) ...[
                    _buildProcessingCard(),
                  ],
                  
                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorCard(),
                  ],
                  
                  // Scan result preview
                  if (_scanResult != null && !_isProcessing) ...[
                    const SizedBox(height: 16),
                    _buildScanResultCard(),
                  ],
                  
                  // Tips section
                  if (!_isProcessing && _scanResult == null) ...[
                    const SizedBox(height: 24),
                    _buildTipsSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TOP BLUE SECTION ====================
  Widget _buildTopBlueSection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            children: [
              // Header dengan back button
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Scan Struk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance width
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Animated scan icon
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnimation, _rotateAnimation]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isProcessing ? _pulseAnimation.value : 1.0,
                    child: Transform.rotate(
                      angle: _isProcessing ? _rotateAnimation.value : 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isProcessing
                              ? Icons.hourglass_top_rounded
                              : Icons.document_scanner_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Title & description
              Text(
                _isProcessing ? 'Memproses Struk...' : 'Scan Struk Belanja',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isProcessing
                    ? 'AI sedang menganalisis struk Anda'
                    : 'Ambil foto struk untuk mencatat transaksi otomatis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PREVIEW AREA ====================
  Widget _buildPreviewArea() {
    if (_selectedImage == null) {
      return Container(
        height: 220,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 56,
                color: const Color(0xFF1E3A8A).withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada gambar struk',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gunakan kamera atau pilih dari galeri',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.0,
              child: Image.file(
                _selectedImage!,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            // Processing overlay
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Menganalisis struk...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mohon tunggu sebentar',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Retake button (visible only when not processing and no result)
            if (!_isProcessing && _scanResult == null)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons() {
    return Column(
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.camera_alt_rounded,
                label: 'Ambil Foto',
                subtitle: 'Gunakan kamera',
                color: const Color(0xFF1E3A8A),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                ),
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.photo_library_rounded,
                label: 'Dari Galeri',
                subtitle: 'Pilih foto struk',
                color: const Color(0xFF2563EB),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                ),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PROCESSING CARD ====================
  Widget _buildProcessingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI sedang bekerja',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Membaca dan mengekstrak data dari struk',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Processing',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ERROR CARD ====================
  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Gagal Memproses Struk',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _selectedImage = null;
                    _scanResult = null;
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== SCAN RESULT CARD ====================
  Widget _buildScanResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF059669).withOpacity(0.08),
            const Color(0xFF10B981).withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Struk Berhasil Dibaca',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  Text(
                    'Data siap diproses',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFD1FAE5)),
          const SizedBox(height: 12),
          
          // Result items
          _buildResultItem(
            icon: Icons.title_rounded,
            label: 'Judul',
            value: _scanResult!['title'] ?? '-',
          ),
          _buildResultItem(
            icon: Icons.attach_money_rounded,
            label: 'Jumlah',
            value: 'Rp ${(_scanResult!['amount'] ?? 0).toString()}',
            valueColor: const Color(0xFF059669),
          ),
          _buildResultItem(
            icon: Icons.calendar_today_rounded,
            label: 'Tanggal',
            value: _scanResult!['date'] ?? '-',
          ),
          _buildResultItem(
            icon: Icons.payment_rounded,
            label: 'Metode',
            value: _scanResult!['payment_method'] ?? '-',
          ),
          
          const SizedBox(height: 12),
          
          // Redirect info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF059669),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mengalihkan ke halaman transaksi...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 16),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TIPS SECTION ====================
  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A).withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1E3A8A).withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFF1E3A8A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tips Scan Struk',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            icon: Icons.check_circle_outline,
            text: 'Pastikan struk dalam kondisi rata dan tidak terlipat',
          ),
          _buildTipItem(
            icon: Icons.check_circle_outline,
            text: 'Gunakan pencahayaan yang cukup saat memotret',
          ),
          _buildTipItem(
            icon: Icons.check_circle_outline,
            text: 'Ambil gambar seluruh area struk dengan jelas',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E3A8A).withOpacity(0.5), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}