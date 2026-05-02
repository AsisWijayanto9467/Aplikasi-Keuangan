// lib/pages/App/financial_target_list_page.dart
import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/App/create_financial_target_page.dart';
import 'package:frontend_flutter/pages/App/financial_target_detail.dart';
import 'package:frontend_flutter/pages/auth/login_page.dart';
import 'package:frontend_flutter/services/financial_target_service.dart';

class FinancialTargetListPage extends StatefulWidget {
  final String token;

  const FinancialTargetListPage({super.key, required this.token});

  @override
  State<FinancialTargetListPage> createState() => _FinancialTargetListPageState();
}

class _FinancialTargetListPageState extends State<FinancialTargetListPage> {
  List<Map<String, dynamic>> _targets = [];
  bool _isLoading = true;
  String? _filterStatus; // null = all, 'active', 'completed', 'cancelled'
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Loading targets with filter: $_filterStatus');
      print('Token: ${widget.token.substring(0, 20)}...');

      final response = await FinancialTargetService.getTargets(
        token: widget.token,
        status: _filterStatus,
      );

      print('✅ Targets response received');
      print('Response keys: ${response.keys}');
      print('Data keys: ${response['data']?.keys}');

      if (mounted) {
        // Parse data dari response
        final responseData = response['data'];
        List<dynamic> targetList = [];

        if (responseData is Map) {
          // Response dengan pagination
          targetList = responseData['data'] ?? [];
        } else if (responseData is List) {
          // Response langsung list
          targetList = responseData;
        }

        setState(() {
          _targets = List<Map<String, dynamic>>.from(targetList);
          _isLoading = false;
        });

        print('📊 Loaded ${_targets.length} targets');
      }
    } catch (e) {
      print('❌ Error loading targets: $e');
      print('Error type: ${e.runtimeType}');

      String errorMsg = 'Gagal memuat data';

      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('timeout')) {
        errorMsg = 'Tidak dapat terhubung ke server';
      } else if (e.toString().contains('401') ||
                 e.toString().contains('Unauthenticated')) {
        errorMsg = 'Sesi berakhir, silakan login kembali';
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
          return;
        }
      } else {
        errorMsg = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _navigateToCreateTarget() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateFinancialTargetPage(
          token: widget.token,
        ),
      ),
    );

    // Refresh jika ada data baru
    if (result == true) {
      _loadTargets();
    }
  }

  Future<void> _navigateToTargetDetail(String targetId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialTargetDetailPage(
          token: widget.token,
          targetId: targetId,
        ),
      ),
    );

    // Refresh jika ada perubahan
    if (result == true) {
      _loadTargets();
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Target Finansial',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          // Tombol refresh
          IconButton(
            onPressed: _loadTargets,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _navigateToCreateTarget,
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Tambah Target',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
            ),
            SizedBox(height: 16),
            Text(
              'Memuat target...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadTargets,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state atau content
    return Column(
      children: [
        // Filter tabs
        _buildFilterTabs(),
        // Content
        Expanded(
          child: _targets.isEmpty ? _buildEmptyState() : _buildTargetList(),
        ),
      ],
    );
  }

  // Filter tabs
  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterTab('Semua', null),
            const SizedBox(width: 8),
            _buildFilterTab('Aktif', 'active'),
            const SizedBox(width: 8),
            _buildFilterTab('Selesai', 'completed'),
            const SizedBox(width: 8),
            _buildFilterTab('Dibatalkan', 'cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String? status) {
    final isSelected = _filterStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = status;
        });
        _loadTargets();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E3A8A)
              : const Color(0xFF1E3A8A).withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
          ),
        ),
      ),
    );
  }

  // Empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF59E0B).withOpacity(0.1),
                    const Color(0xFFF59E0B).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flag_rounded,
                size: 64,
                color: const Color(0xFFF59E0B).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _filterStatus == null
                  ? 'Belum Ada Target Finansial'
                  : 'Tidak Ada Target ${_getFilterLabel(_filterStatus)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filterStatus == null
                  ? 'Mulai rencanakan keuanganmu dengan membuat\ntarget tabungan pertama Anda'
                  : 'Tidak ada target dengan status ${_getFilterLabel(_filterStatus)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            if (_filterStatus == null || _filterStatus == 'active')
              GestureDetector(
                onTap: _navigateToCreateTarget,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Buat Target Pertama',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getFilterLabel(String? status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return '';
    }
  }

  // Target list
  Widget _buildTargetList() {
    return RefreshIndicator(
      onRefresh: _loadTargets,
      color: const Color(0xFF1E3A8A),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _targets.length,
        itemBuilder: (context, index) {
          final target = _targets[index];
          return _buildTargetCard(target);
        },
      ),
    );
  }

  // Target card
  Widget _buildTargetCard(Map<String, dynamic> target) {
    final progress = double.tryParse(
          target['progress_percentage']?.toString() ?? '0',
        ) ??
        0;
    final category = target['category'] ?? '';
    final icon = FinancialTargetService.getIconForCategory(category);
    final label = FinancialTargetService.getCategoryLabel(category);
    final currentAmount =
        double.tryParse(target['current_amount']?.toString() ?? '0') ?? 0;
    final targetAmount =
        double.tryParse(target['target_amount']?.toString() ?? '0') ?? 0;
    final remainingDays = target['remaining_days'] ?? 0;
    final status = target['status'] ?? 'active';
    final isOverdue = target['is_overdue'] == true;

    return GestureDetector(
      onTap: () => _navigateToTargetDetail(target['id'].toString()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: status == 'completed'
              ? Border.all(color: const Color(0xFF10B981).withOpacity(0.3))
              : isOverdue
                  ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                // Title & Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (status != 'active') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'completed'
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                FinancialTargetService.getStatusText(status),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: status == 'completed'
                                      ? const Color(0xFF10B981)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                          if (isOverdue && status == 'active') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Terlambat',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Progress percentage
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${progress.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(
                          FinancialTargetService.getProgressColor(progress),
                        ),
                      ),
                    ),
                    if (status == 'active')
                      Text(
                        remainingDays > 0
                            ? '$remainingDays hari lagi'
                            : 'Melebihi batas',
                        style: TextStyle(
                          fontSize: 10,
                          color: remainingDays > 0
                              ? Colors.grey.shade500
                              : const Color(0xFFEF4444),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                widthFactor: progress / 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(
                          FinancialTargetService.getProgressColor(progress),
                        ),
                        Color(
                          FinancialTargetService.getProgressColor(progress),
                        ).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Amount info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatCurrency(currentAmount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Target: ${_formatCurrency(targetAmount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}