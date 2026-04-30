import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/pages/App/financial_target_detail.dart';
import 'package:frontend_flutter/pages/auth/login_page.dart';
import 'package:frontend_flutter/services/financial_target_service.dart';
import 'package:intl/intl.dart';

class CreateFinancialTargetPage extends StatefulWidget {
  final String token;
  

  const CreateFinancialTargetPage({super.key, required this.token});

  @override
  State<CreateFinancialTargetPage> createState() =>
      _CreateFinancialTargetPageState();
}

class _CreateFinancialTargetPageState extends State<CreateFinancialTargetPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedCategory = '';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;
  String? _createdTargetId; 

  final List<Map<String, dynamic>> _categories = [
    {
      'value': 'education',
      'icon': '🎓',
      'label': 'Pendidikan',
      'description': 'Biaya sekolah, kursus, buku',
      'color': const Color(0xFF3B82F6),
    },
    {
      'value': 'work',
      'icon': '💼',
      'label': 'Pekerjaan',
      'description': 'Modal usaha, peralatan kerja',
      'color': const Color(0xFF6366F1),
    },
    {
      'value': 'vacation',
      'icon': '🏖️',
      'label': 'Liburan',
      'description': 'Travel, hotel, jalan-jalan',
      'color': const Color(0xFFEC4899),
    },
    {
      'value': 'medical',
      'icon': '🏥',
      'label': 'Kesehatan',
      'description': 'Biaya dokter, obat, asuransi',
      'color': const Color(0xFF10B981),
    },
    {
      'value': 'emergency_fund',
      'icon': '🚨',
      'label': 'Dana Darurat',
      'description': 'Persiapan keadaan darurat',
      'color': const Color(0xFFEF4444),
    },
    {
      'value': 'property',
      'icon': '🏠',
      'label': 'Properti',
      'description': 'Beli/renovasi rumah, tanah',
      'color': const Color(0xFF8B5CF6),
    },
    {
      'value': 'vehicle',
      'icon': '🚗',
      'label': 'Kendaraan',
      'description': 'Beli mobil/motor, maintenance',
      'color': const Color(0xFFF97316),
    },
    {
      'value': 'business',
      'icon': '💼',
      'label': 'Bisnis',
      'description': 'Modal usaha, investasi bisnis',
      'color': const Color(0xFF14B8A6),
    },
    {
      'value': 'wedding',
      'icon': '💒',
      'label': 'Pernikahan',
      'description': 'Biaya nikah, resepsi',
      'color': const Color(0xFFE11D48),
    },
    {
      'value': 'other',
      'icon': '🎯',
      'label': 'Lainnya',
      'description': 'Target keuangan lainnya',
      'color': const Color(0xFF64748B),
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    // Validasi form
    if (!_formKey.currentState!.validate()) return;

    // Validasi kategori
    if (_selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Pilih kategori terlebih dahulu')),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('=== SUBMITTING TARGET ===');
      print('Token: ${widget.token.substring(0, 20)}...');
      print('Title: ${_titleController.text.trim()}');
      print('Category: $_selectedCategory');
      print('Reason: ${_reasonController.text.trim()}');
      print('Amount: ${_amountController.text.trim()}');
      print('Target Date: ${DateFormat('yyyy-MM-dd').format(_targetDate)}');
      print(
        'Notes: ${_notesController.text.trim().isNotEmpty ? _notesController.text.trim() : 'empty'}',
      );

      final response = await FinancialTargetService.createTarget(
        
        token: widget.token,
        title: _titleController.text.trim(),
        category: _selectedCategory,
        reason: _reasonController.text.trim(),
        targetAmount: double.parse(_amountController.text.trim()),
        targetDate: DateFormat('yyyy-MM-dd').format(_targetDate),
        notes:
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
      );

      print('✅ Create target SUCCESS: $response');
      _createdTargetId = response['data']['id'].toString();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      print('❌ Error creating target: $e');
      print('Error type: ${e.runtimeType}');

      String errorMessage = 'Gagal membuat target';

      // Handle berbagai jenis error
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('timeout')) {
        errorMessage =
            'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      } else if (e.toString().contains('Token tidak valid') ||
          e.toString().contains('Unauthenticated') ||
          e.toString().contains('401')) {
        errorMessage = 'Sesi Anda telah berakhir. Silakan login kembali.';
        if (mounted) {
          // Navigate to login page
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
        return;
      } else if (e.toString().contains('Validasi gagal')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else {
        errorMessage = 'Gagal: ${e.toString().replaceAll('Exception: ', '')}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 32,
                ),
                SizedBox(width: 12),
                Text(
                  'Berhasil!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: const Text(
              'Target finansial berhasil dibuat. Yuk mulai menabung!',
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Tutup dialog
                  Navigator.pop(context, true); // Kembali ke list
                },
                child: const Text('Nanti Saja'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Tutup dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => FinancialTargetDetailPage(
                            token: widget.token,
                            targetId: _createdTargetId!,
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Lihat Detail'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Buat Target Baru',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 28),

              // 1. Pilih Kategori
              _buildSectionTitle('1. Pilih Kategori'),
              const SizedBox(height: 12),
              _buildCategorySelector(),
              const SizedBox(height: 28),

              // 2. Judul Target
              _buildSectionTitle('2. Judul Target'),
              const SizedBox(height: 12),
              _buildTitleInput(),
              const SizedBox(height: 28),

              // 3. Alasan Menabung
              _buildSectionTitle('3. Alasan Menabung'),
              const SizedBox(height: 4),
              Text(
                'Ceritakan mengapa target ini penting untukmu',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 12),
              _buildReasonInput(),
              const SizedBox(height: 28),

              // 4. Target Dana
              _buildSectionTitle('4. Target Dana'),
              const SizedBox(height: 12),
              _buildAmountInput(),
              const SizedBox(height: 28),

              // 5. Tanggal Target
              _buildSectionTitle('5. Tanggal Target'),
              const SizedBox(height: 4),
              Text(
                'Kapan dana ini harus terkumpul?',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 28),

              // 6. Catatan (Optional)
              _buildSectionTitle('6. Catatan (Opsional)'),
              const SizedBox(height: 12),
              _buildNotesInput(),
              const SizedBox(height: 32),

              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.1),
            const Color(0xFFF59E0B).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Text('🎯', style: TextStyle(fontSize: 32)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Finansial Baru',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Rencanakan dan wujudkan impianmu dengan menabung secara teratur',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SECTION TITLE ====================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
    );
  }

  // ==================== CATEGORY SELECTOR ====================
  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          _categories.map((category) {
            final isSelected = _selectedCategory == category['value'];
            final color = category['color'] as Color;

            return GestureDetector(
              onTap:
                  _isLoading
                      ? null
                      : () {
                        setState(() {
                          _selectedCategory = category['value'];
                        });
                      },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade200,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category['icon'],
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category['label'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? color : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  // ==================== TITLE INPUT ====================
  Widget _buildTitleInput() {
    return TextFormField(
      controller: _titleController,
      enabled: !_isLoading,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Contoh: Dana Pendidikan Anak',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.title_rounded,
            color: Color(0xFF1E3A8A),
            size: 20,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: true,
        fillColor: _isLoading ? Colors.grey.shade100 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Judul target wajib diisi';
        }
        return null;
      },
    );
  }

  // ==================== REASON INPUT ====================
  Widget _buildReasonInput() {
    return TextFormField(
      controller: _reasonController,
      enabled: !_isLoading,
      maxLines: 3,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Contoh: Ingin memberikan pendidikan terbaik untuk anak...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFF1E3A8A),
            size: 20,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: true,
        fillColor: _isLoading ? Colors.grey.shade100 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.all(16),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Alasan menabung wajib diisi';
        }
        if (value.trim().length < 10) {
          return 'Alasan minimal 10 karakter';
        }
        return null;
      },
    );
  }

  // ==================== AMOUNT INPUT ====================
  Widget _buildAmountInput() {
    return TextFormField(
      controller: _amountController,
      enabled: !_isLoading,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A8A),
      ),
      decoration: InputDecoration(
        prefixText: 'Rp ',
        prefixStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E3A8A),
        ),
        hintText: '0',
        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: true,
        fillColor: _isLoading ? Colors.grey.shade100 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Target dana wajib diisi';
        }
        final amount = double.tryParse(value.trim());
        if (amount == null || amount < 1000) {
          return 'Minimal target Rp 1.000';
        }
        return null;
      },
    );
  }

  // ==================== DATE PICKER ====================
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap:
          _isLoading
              ? null
              : () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF1E3A8A),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _targetDate = picked);
                }
              },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _isLoading ? Colors.grey.shade100 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isLoading ? Colors.grey.shade300 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF1E3A8A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(_targetDate),
                    style: TextStyle(
                      fontSize: 15,
                      color: _isLoading ? Colors.grey : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_targetDate.difference(DateTime.now()).inDays} hari dari sekarang',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: _isLoading ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== NOTES INPUT ====================
  Widget _buildNotesInput() {
    return TextFormField(
      controller: _notesController,
      enabled: !_isLoading,
      maxLines: 3,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Tambahkan catatan atau reminder...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.notes_rounded,
            color: Color(0xFF1E3A8A),
            size: 20,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: true,
        fillColor: _isLoading ? Colors.grey.shade100 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  // ==================== SUBMIT BUTTON ====================
  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(_isLoading ? 0.1 : 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
            disabledBackgroundColor: const Color(0xFF1E3A8A).withOpacity(0.6),
          ),
          child:
              _isLoading
                  ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Menyimpan...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                  : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Buat Target',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.flag_rounded, size: 20),
                    ],
                  ),
        ),
      ),
    );
  }
}
