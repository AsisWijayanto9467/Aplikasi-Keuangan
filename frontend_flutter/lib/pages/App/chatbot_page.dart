import 'package:flutter/material.dart';
import 'package:frontend_flutter/services/chat_service.dart';

class AiChatPage extends StatefulWidget {
  final String token;

  const AiChatPage({super.key, required this.token});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGreeting();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Load greeting awal
  Future<void> _loadGreeting() async {
    setState(() => _isInitialLoading = true);
    try {
      final response = await ChatService.getGreeting(widget.token);
      if (response['success'] == true && mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: response['reply'] ?? 'Halo! Ada yang bisa saya bantu?',
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  // Kirim pesan user
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Tambahkan pesan user ke list
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    // Kirim ke API
    try {
      final response = await ChatService.sendMessage(
        token: widget.token,
        message: text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(
            text: response['reply'] ?? 'Maaf, terjadi kesalahan',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(
            text: 'Maaf, gagal terhubung ke server. Silakan coba lagi.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Greeting info card
          _buildInfoCard(),
          // Chat messages
          Expanded(child: _buildChatList()),
          // AI typing indicator
          if (_isLoading) _buildTypingIndicator(),
          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  // AppBar dengan gradient
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(120),
      child: Container(
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
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Tombol kembali
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    // Avatar AI
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        child: const Icon(
                          Icons.smart_toy_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FinansialKu AI',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Asisten Keuangan Pintar',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    // Status online
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                          SizedBox(width: 6),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Info card fitur AI
  Widget _buildInfoCard() {
    if (_messages.length > 1) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Coba tanyakan:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip('💰 Berapa saldo saya?'),
              _buildSuggestionChip('📊 Berapa pengeluaran bulan ini?'),
              _buildSuggestionChip('🎯 Bagaimana progress target saya?'),
              _buildSuggestionChip('💡 Tips menghemat uang'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  // List chat
  Widget _buildChatList() {
    if (_isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  // Bubble chat
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                )
              : null,
          color: isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
          ),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: isUser ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy_rounded, size: 14, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 6),
                    Text(
                      'FinansialKu AI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                color: isUser ? Colors.white : const Color(0xFF0F172A),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white60 : Colors.grey.shade500,
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Typing indicator
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI sedang mengetik...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Input area
  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ketik pesan...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
                suffixIcon: _messageController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 20),
                        onPressed: () {
                          setState(() => _messageController.clear());
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// Model ChatMessage
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}