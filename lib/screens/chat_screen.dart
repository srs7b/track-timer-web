import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../services/llm_service.dart';
import '../services/database_service.dart';
import '../services/navigation_provider.dart';
import '../theme/style_constants.dart';
import '../widgets/velocity_card.dart';
import '../models/run_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  final LLMService _llmService = LLMService();
  final DatabaseService _db = DatabaseService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [
    {'role': 'assistant', 'content': 'SYSTEM_INITIALIZED: READY FOR BIOMECHANICAL ANALYSIS.'}
  ];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 30.0, end: 70.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Initial check for pending analysis
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingAnalysis();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkPendingAnalysis() {
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    if (nav.pendingAnalysisRun != null) {
      final run = nav.pendingAnalysisRun!;
      nav.clearPendingAnalysis();
      _analyzeRun(run);
    }
  }

  Future<void> _analyzeRun(Run run) async {
    final prompt = "ANALYZE_SESSION: ${run.name.toUpperCase()} (${run.distanceClass}M). TOTAL_TIME: ${run.totalTimeSeconds.toStringAsFixed(2)}S. PEAK_VELOCITY: ${run.topSpeed.toStringAsFixed(2)}M/S. PROVIDE SEGMENT BREAKDOWN AND BIOMECHANICAL OPTIMIZATION STEPS.";
    
    setState(() {
      _messages.add({'role': 'user', 'content': prompt});
      _isTyping = true;
    });

    _executeAiCall(prompt);
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text.toUpperCase()});
      _isTyping = true;
      _textController.clear();
    });

    _executeAiCall(text);
  }

  Future<void> _executeAiCall(String text) async {
    try {
      final runs = await _db.getAllRuns();
      final response = await _llmService.getCoachResponse(text, runs: runs);
      
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response});
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'ERROR: ANALYTIC_LINK_FAILURE. Check API configuration.'});
          _isTyping = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    // Listen for changes in navigation provider to detect new runs sent for analysis
    final pendingRun = Provider.of<NavigationProvider>(context).pendingAnalysisRun;
    if (pendingRun != null) {
      // Re-trigger analysis if we just switched to this tab with a pending run
      _checkPendingAnalysis();
    }

    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('TRACK.TIME', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, letterSpacing: 4)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: _isTyping ? VelocityColors.primary : VelocityColors.textDim.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isTyping ? 'COMPUTING' : 'SECURE_LINK', 
                  style: VelocityTextStyles.technical.copyWith(
                    fontSize: 8, 
                    color: _isTyping ? VelocityColors.primary : VelocityColors.textDim
                  )
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                _buildCoachHeader(),
                const SizedBox(height: 32),
                ..._messages.map((msg) => _buildTerminalEntry(msg['role']!, msg['content']!)),
                if (_isTyping) _buildTerminalEntry('assistant', '_ANALYZING_KINEMATICS..._'),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildCoachHeader() {
    return Column(
      children: [
        Center(
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.transparent
                  ]),
                  boxShadow: [
                    BoxShadow(
                      color: VelocityColors.primary.withValues(alpha: _isTyping ? 0.8 : 0.3),
                      blurRadius: _glowAnimation.value,
                      spreadRadius: _isTyping ? 10 : 2,
                    )
                  ],
                ),
                child: Center(
                  child: Icon(
                    _isTyping ? Icons.biotech : Icons.auto_awesome_mosaic, 
                    color: Colors.white, 
                    size: 32
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('NEURAL PERFORMANCE COACH', style: VelocityTextStyles.technical.copyWith(fontSize: 12, letterSpacing: 3, color: VelocityColors.primary)),
        Text('VER: 2.0.4 - SPRINT_ENGINE', style: VelocityTextStyles.dimBody.copyWith(fontSize: 8, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildTerminalEntry(String role, String content) {
    bool isAssistant = role == 'assistant';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: VelocityCard(
        borderColor: isAssistant ? VelocityColors.primary.withOpacity(0.1) : Colors.transparent,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAssistant ? Icons.psychology : Icons.person, 
                  size: 14, 
                  color: isAssistant ? VelocityColors.primary : VelocityColors.secondary
                ),
                const SizedBox(width: 8),
                Text(
                  role.toUpperCase(), 
                  style: VelocityTextStyles.technical.copyWith(
                    fontSize: 9, 
                    color: isAssistant ? VelocityColors.primary : VelocityColors.secondary,
                    letterSpacing: 2
                  )
                ),
                const Spacer(),
                Text(
                  DateFormat('HH:mm').format(DateTime.now()), 
                  style: VelocityTextStyles.dimBody.copyWith(fontSize: 8)
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: VelocityColors.textDim, thickness: 0.1),
            ),
            if (isAssistant)
               MarkdownBody(
                 data: content,
                 styleSheet: MarkdownStyleSheet(
                   p: VelocityTextStyles.terminal.copyWith(fontSize: 12, height: 1.5, color: VelocityColors.textBody),
                   strong: VelocityTextStyles.terminal.copyWith(fontSize: 12, color: VelocityColors.primary, fontWeight: FontWeight.bold),
                   code: VelocityTextStyles.technical.copyWith(fontSize: 11, backgroundColor: VelocityColors.black, color: VelocityColors.secondary),
                   listBullet: VelocityTextStyles.terminal.copyWith(color: VelocityColors.primary),
                 ),
               )
            else
              Text(
                content, 
                style: VelocityTextStyles.terminal.copyWith(fontSize: 12, color: VelocityColors.textDim)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VelocityColors.surfaceLight,
        border: Border(top: BorderSide(color: VelocityColors.textDim.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Text('> ', style: TextStyle(color: VelocityColors.primary, fontFamily: 'Courier')),
            Expanded(
              child: TextField(
                controller: _textController,
                style: VelocityTextStyles.terminal.copyWith(color: VelocityColors.textBody, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ENTER COMMAND...',
                  hintStyle: VelocityTextStyles.terminal.copyWith(color: VelocityColors.textDim.withOpacity(0.5), fontSize: 13),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: VelocityColors.primary),
              onPressed: _handleSendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
