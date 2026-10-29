import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../data/models/player_search_model.dart';
import '../../../data/services/api_service.dart';
import 'personal_info_screen.dart';
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}
class _ProfileTabState extends State<ProfileTab> {
  String _name = '';
  String? _profilePicture;
  String? _location;
  int _followersCount = 0;
  int _followingCount = 0;
  int _lucraMatchWins = 0;
  double _wprValue = 0;
  String _wprBadge = 'N/A';
  double _wprConfidence = 0;
  double _clutchValue = 0;
  double _clutchConfidence = 0;
  String _level = 'Novice';
  int _matchesPlayed = 0;
  double _winRate = 0;
  int _winStreak = 0;
  List<String> _sports = [];
  String? _playStyle;
  List<String> _days = [];
  String? _fromTime;
  String? _toTime;
  String? _hand;
  String? _courtSide;
  List<PlayerSearchModel> _commonPlayers = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }
  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.get('v2/profile', withAuth: true);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final header = data['profile_header'] as Map<String, dynamic>? ?? {};
      final stats = data['stats_cards'] as Map<String, dynamic>? ?? {};
      final prefs = data['preferences'] as Map<String, dynamic>? ?? {};
      final wpr = stats['wpr'] as Map<String, dynamic>? ?? {};
      final clutch = stats['clutch_ai_rating'] as Map<String, dynamic>? ?? {};
      final winRateData = stats['win_rate'] as Map<String, dynamic>? ?? {};
      final userId = (header['user_id'] as num?)?.toInt();
      if (!mounted) return;
      setState(() {
        _name = header['name']?.toString() ?? '';
        _profilePicture = header['profile_picture']?.toString();
        _location = header['location']?.toString();
        _followersCount = (header['followers_count'] as num?)?.toInt() ?? 0;
        _followingCount = (header['following_count'] as num?)?.toInt() ?? 0;
        _lucraMatchWins = (data['lucra_match_wins'] as num?)?.toInt() ?? 0;
        _wprValue = (wpr['value'] as num?)?.toDouble() ?? 0;
        _wprBadge = wpr['competitive_badge']?.toString() ?? 'N/A';
        _wprConfidence = (wpr['confidence_percentage'] as num?)?.toDouble() ?? 0;
        _clutchValue = (clutch['value'] as num?)?.toDouble() ?? 0;
        _clutchConfidence = (clutch['confidence_percentage'] as num?)?.toDouble() ?? 0;
        _level = stats['level']?.toString() ?? 'Novice';
        _matchesPlayed = (stats['matches_played'] as num?)?.toInt() ?? 0;
        _winRate = (winRateData['value'] as num?)?.toDouble() ?? 0;
        _winStreak = (stats['win_streak'] as num?)?.toInt() ?? 0;
        _playStyle = prefs['play_style']?.toString();
        _hand = prefs['hand']?.toString();
        _courtSide = prefs['court_side']?.toString();
        _fromTime = prefs['from_time']?.toString();
        _toTime = prefs['to_time']?.toString();
        final sportsRaw = prefs['sports'] as List? ?? [];
        _sports = sportsRaw.map((s) {
          if (s is Map) return s['name']?.toString() ?? '';
          return s.toString();
        }).where((s) => s.isNotEmpty).toList();
        final daysRaw = prefs['days'];
        if (daysRaw is List) {
          _days = daysRaw.map((d) => d.toString()).toList();
        } else if (daysRaw is String && daysRaw.isNotEmpty) {
          _days = daysRaw.split(',').map((d) => d.trim()).toList();
        }
        _loading = false;
      });
      if (userId != null) _loadCommonPlayers(userId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }
  Future<void> _loadCommonPlayers(int userId) async {
    try {
      final res = await ApiService.get(
        'v2/profile/$userId/most-common-players',
        query: {'page': '1', 'limit': '15'},
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _commonPlayers = list
            .whereType<Map<String, dynamic>>()
            .map(PlayerSearchModel.fromJson)
            .toList();
      });
    } catch (_) {}
  }
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
  String _formatDays(List<String> days) {
    const abbrev = {
      'monday': 'Mo', 'tuesday': 'Tu', 'wednesday': 'We',
      'thursday': 'Th', 'friday': 'Fr', 'saturday': 'Sa', 'sunday': 'Su',
      'mon': 'Mo', 'tue': 'Tu', 'wed': 'We', 'thu': 'Th',
      'fri': 'Fr', 'sat': 'Sa', 'sun': 'Su',
    };
    return days
        .map((d) => abbrev[d.toLowerCase()] ?? _capitalize(d))
        .join(', ');
  }
  String _formatHand(String? hand) {
    if (hand == null || hand.isEmpty) return '';
    return '${_capitalize(hand)} Hand';
  }
  String _formatSide(String? side) {
    if (side == null || side.isEmpty) return '';
    return '${_capitalize(side)} Side Only';
  }
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
  String _formatStat(double value) => value.toStringAsFixed(1);
  void _showMenu() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => _ProfileMenuSheet(
        onLogout: _logout,
        onPersonalInfo: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
          );
        },
      ),
      transitionBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }
  Future<void> _logout() async {
    try {
      await ApiService.post('v2/auth/logout', {}, withAuth: true);
    } catch (_) {}
    await StorageService.clearToken();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.textGrey),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildStatsSection(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildLucraBanner(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildPreferences(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
              child: _buildCommonPlayers(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3A2D), Color(0xFF2A5940)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showMenu,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        color: AppColors.textDark,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          _name.isNotEmpty ? _name : 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_location != null && _location!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _location!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildFollowStat(_followersCount, 'Followers'),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 14),
                              width: 1,
                              height: 18,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            _buildFollowStat(_followingCount, 'Following'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8860B).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD4A017).withValues(alpha: 0.7),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium,
                            color: Color(0xFFFFD700), size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Founding Member',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildAvatar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 82,
        height: 82,
        child: _profilePicture != null && _profilePicture!.isNotEmpty
            ? Image.network(
                _profilePicture!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }
  Widget _avatarFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          _initials(_name),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
  Widget _buildFollowStat(int count, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  Widget _buildStatsSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildWprCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildClutchCard()),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildSimpleStatCard('Level', _level)),
            const SizedBox(width: 12),
            Expanded(child: _buildSimpleStatCard('Matches Played', _matchesPlayed.toString())),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildSimpleStatCard('Win Rate', '${_winRate.toInt()}%')),
            const SizedBox(width: 12),
            Expanded(child: _buildSimpleStatCard('Win Streak', _winStreak.toString())),
          ],
        ),
      ],
    );
  }
  Widget _buildWprCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 2, color: const Color(0xFFE53935)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'WPR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _wprBadge,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatStat(_wprValue),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE53935),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Confidence: ${_wprConfidence.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textGrey,
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
  Widget _buildClutchCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 2, color: const Color(0xFFFFCA28)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Clutch Ai',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Rating',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatStat(_clutchValue),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Confidence: ${_clutchConfidence.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textGrey,
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
  Widget _buildSimpleStatCard(String label, String value) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 2, color: const Color(0xFF1C5534)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
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
  Widget _buildLucraBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.sports_tennis,
              color: Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LUCRA',
                  style: TextStyle(
                    color: Color(0xFF7A8A9A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Challenge Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$_lucraMatchWins',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(
                  text: ' Wins',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPreferences() {
    final items = <_PrefItem>[];
    if (_location != null && _location!.isNotEmpty) {
      items.add(_PrefItem('Club', _location!));
    }
    if (_sports.isNotEmpty) {
      items.add(_PrefItem('Sport', _sports.join(', ')));
    }
    if (_playStyle != null && _playStyle!.isNotEmpty) {
      items.add(_PrefItem('Play Style', _capitalize(_playStyle!)));
    }
    final hasTime = (_fromTime != null && _fromTime!.isNotEmpty) ||
        (_toTime != null && _toTime!.isNotEmpty);
    if (_days.isNotEmpty || hasTime) {
      final dayStr = _days.isNotEmpty ? _formatDays(_days) : '';
      final timeStr = hasTime
          ? '${_formatTime(_fromTime)} - ${_formatTime(_toTime)}'
          : '';
      final combined = [dayStr, timeStr].where((s) => s.isNotEmpty).join(' | ');
      if (combined.isNotEmpty) {
        items.add(_PrefItem('Date & Time', combined));
      }
    }
    if (_hand != null && _hand!.isNotEmpty) {
      items.add(_PrefItem('Hand', _formatHand(_hand)));
    }
    if (_courtSide != null && _courtSide!.isNotEmpty) {
      items.add(_PrefItem('Side', _formatSide(_courtSide)));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEAE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Preferences',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0EDE8)),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No preferences set yet.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
            )
          else
            ...List.generate(items.length, (i) {
              return _buildPrefRow(
                items[i].label,
                items[i].value,
                isLast: i == items.length - 1,
              );
            }),
        ],
      ),
    );
  }
  Widget _buildPrefRow(String label, String value, {bool isLast = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF0EDE8),
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
  Widget _buildCommonPlayers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Most Common Players',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: _commonPlayers.isEmpty
              ? const Center(
                  child: Text(
                    'No players yet',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _commonPlayers.length,
                  itemBuilder: (_, i) => Padding(
                    padding: EdgeInsets.only(
                      right: i < _commonPlayers.length - 1 ? 16 : 0,
                    ),
                    child: _buildPlayerCard(_commonPlayers[i]),
                  ),
                ),
        ),
      ],
    );
  }
  Widget _buildPlayerCard(PlayerSearchModel player) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEEEAE4),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: player.photoUrl != null && player.photoUrl!.isNotEmpty
                  ? Image.network(
                      player.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _playerFallback(player.name),
                    )
                  : _playerFallback(player.name),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            player.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          if (player.rating != null)
            Text(
              player.rating!.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
  Widget _playerFallback(String name) {
    return Container(
      color: const Color(0xFFF0EDE8),
      child: Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
class _PrefItem {
  final String label;
  final String value;
  const _PrefItem(this.label, this.value);
}
class _ProfileMenuSheet extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onPersonalInfo;
  const _ProfileMenuSheet({required this.onLogout, required this.onPersonalInfo});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 22,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _sectionHeader('Activity'),
                  _menuItem(
                    context,
                    icon: Icons.person_outline,
                    label: 'Personal Info',
                    onTap: () {
                      Navigator.of(context).pop();
                      onPersonalInfo();
                    },
                  ),
                  _menuItem(
                    context,
                    icon: Icons.calendar_month_outlined,
                    label: 'Bookings',
                  ),
                  _menuItem(
                    context,
                    icon: Icons.pending_actions_outlined,
                    label: 'Pending Payments',
                  ),
                  _menuItem(
                    context,
                    icon: Icons.loop,
                    label: 'Red Padel Ranking',
                    trailing: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Linked',
                          style: TextStyle(
                            color: Color(0xFFE57373),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Color(0xFFE57373),
                        ),
                      ],
                    ),
                  ),
                  _menuItem(
                    context,
                    icon: Icons.track_changes,
                    label: 'Clutch AI',
                  ),
                  const SizedBox(height: 6),
                  _sectionHeader('Preferences'),
                  _menuItem(
                    context,
                    icon: Icons.workspace_premium_outlined,
                    label: 'My Subscription',
                  ),
                  _menuItem(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: 'My Packages',
                  ),
                  _menuItem(
                    context,
                    icon: Icons.favorite_border,
                    label: 'Favorites',
                  ),
                  _menuItem(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                  ),
                  _menuItem(
                    context,
                    icon: Icons.credit_card_outlined,
                    label: 'Payment Methods',
                  ),
                  const SizedBox(height: 6),
                  _sectionHeader('Settings'),
                  _menuItem(
                    context,
                    icon: Icons.info_outlined,
                    label: 'About Epic',
                  ),
                  _menuItem(
                    context,
                    icon: Icons.notifications_outlined,
                    label: 'Notification',
                  ),
                  _menuItem(
                    context,
                    icon: Icons.headset_mic_outlined,
                    label: 'Support',
                  ),
                  _menuItem(
                    context,
                    icon: Icons.logout,
                    label: 'Logout',
                    isDestructive: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      onLogout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }
  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    Widget? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final iconColor =
        isDestructive ? const Color(0xFFD32F2F) : AppColors.primary;
    final textColor =
        isDestructive ? const Color(0xFFD32F2F) : AppColors.textDark;
    return Column(
      children: [
        InkWell(
          onTap: onTap ?? () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                trailing ??
                    (isDestructive
                        ? const SizedBox.shrink()
                        : const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppColors.textGrey,
                          )),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFF0EDE8),
          indent: 20,
          endIndent: 20,
        ),
      ],
    );
  }
}
