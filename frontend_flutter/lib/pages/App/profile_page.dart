// lib/pages/App/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  final String token;

  const ProfilePage({
    super.key,
    required this.token,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  Map<String, dynamic>? _userData;
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  
  String? _selectedGender;
  DateTime? _selectedBirthDate;

  // Daftar bulan untuk format tanggal
  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _setStatusBarStyle();
    _loadUserData();
  }

  // Set status bar style
  void _setStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  // Format tanggal manual
  String _formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await AuthService.getUser(widget.token);
      
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _userData = response['data'];
          _initializeControllers();
        });
      } else {
        _showErrorSnackBar('Gagal memuat data profil');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal terhubung ke server');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: _userData?['name'] ?? '');
    _emailController = TextEditingController(text: _userData?['email'] ?? '');
    _phoneController = TextEditingController(text: _userData?['phone'] ?? '');
    _selectedGender = _userData?['gender'];
    
    if (_userData?['birth_date'] != null) {
      _selectedBirthDate = DateTime.tryParse(_userData!['birth_date']);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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
    
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    
    try {
      final response = await AuthService.updateUser(
        token: widget.token,
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        gender: _selectedGender,
        birthDate: _selectedBirthDate?.toIso8601String(),
      );
      
      if (response['success'] == true) {
        setState(() {
          _userData = response['data'];
          _isEditing = false;
        });
        
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
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Profil berhasil diperbarui',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        _showErrorSnackBar(response['message'] ?? 'Gagal memperbarui profil');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal terhubung ke server');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showErrorSnackBar(String message) {
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
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    if (_isEditing) {
      _nameController.dispose();
      _emailController.dispose();
      _phoneController.dispose();
    }
    // Kembalikan status bar ke style default
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ GUNAKAN SCAFFOLD LANGSUNG, TANPA MAINLAYOUT
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1E3A8A),
              size: 20,
            ),
          ),
        ),
        actions: [
          if (!_isLoading && _userData != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                    if (_isEditing) {
                      _initializeControllers();
                    }
                  });
                },
                icon: Icon(
                  _isEditing ? Icons.close_rounded : Icons.edit_outlined,
                  color: const Color(0xFF1E3A8A),
                  size: 20,
                ),
              ),
            ),
          if (_isEditing)
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E3A8A).withOpacity(0.08),
                          const Color(0xFF1E3A8A).withOpacity(0.15),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Memuat data profil...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          
          // Avatar Section dengan styling enhanced
          _buildAvatarSection(),
          
          const SizedBox(height: 32),
          
          // Profile Info Card
          _buildProfileInfoCard(),
          
          const SizedBox(height: 24),
          
          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    final String initial = _userData?['name'] != null && _userData!['name'].isNotEmpty
        ? _userData!['name'][0].toUpperCase()
        : 'U';
    
    return Column(
      children: [
        // Avatar dengan gradient border
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 70,
            backgroundColor: Colors.white,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Nama dengan styling
        Text(
          _userData?['name'] ?? 'Pengguna',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        
        const SizedBox(height: 6),
        
        // Email dengan chip style
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.email_outlined,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                _userData?['email'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Nama Lengkap',
            value: _userData?['name'],
            isEditing: _isEditing,
            controller: _nameController,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Alamat Email',
            value: _userData?['email'],
            isEditing: _isEditing,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Nomor Telepon',
            value: _userData?['phone'] ?? 'Belum diisi',
            isEditing: _isEditing,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          _buildDivider(),
          _buildGenderSelector(),
          _buildDivider(),
          _buildDateSelector(),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Bergabung Sejak',
            value: _userData?['created_at'] != null
                ? _formatDate(DateTime.parse(_userData!['created_at']))
                : '-',
            isEditing: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(
        color: Colors.grey.shade200,
        thickness: 1,
        height: 1,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String? value,
    required bool isEditing,
    TextEditingController? controller,
    TextInputType? keyboardType,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A8A).withOpacity(0.08),
                const Color(0xFF1E3A8A).withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF1E3A8A),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              if (isEditing && controller != null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF1E3A8A),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  value ?? '-',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A8A).withOpacity(0.08),
                const Color(0xFF1E3A8A).withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
            ),
          ),
          child: const Icon(
            Icons.people_outline_rounded,
            color: Color(0xFF1E3A8A),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jenis Kelamin',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              if (_isEditing)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildGenderOption(
                          title: 'Laki-laki',
                          value: 'male',
                        ),
                      ),
                      Expanded(
                        child: _buildGenderOption(
                          title: 'Perempuan',
                          value: 'female',
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    _selectedGender == 'male' ? 'Laki-laki' : 
                    _selectedGender == 'female' ? 'Perempuan' : 'Belum diisi',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderOption({
    required String title,
    required String value,
  }) {
    final isSelected = _selectedGender == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A8A).withOpacity(0.08),
                const Color(0xFF1E3A8A).withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
            ),
          ),
          child: const Icon(
            Icons.cake_outlined,
            color: Color(0xFF1E3A8A),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tanggal Lahir',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              if (_isEditing)
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedBirthDate != null
                              ? _formatDate(_selectedBirthDate!)
                              : 'Pilih tanggal lahir',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _selectedBirthDate != null
                                ? const Color(0xFF0F172A)
                                : Colors.grey.shade500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFF1E3A8A),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  _selectedBirthDate != null
                      ? _formatDate(_selectedBirthDate!)
                      : 'Belum diisi',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_rounded,
                size: 14,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 6),
              Text(
                'Data Anda Aman • v1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '© 2024 FinanceApp • All Rights Reserved',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}