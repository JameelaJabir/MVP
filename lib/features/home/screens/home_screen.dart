import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../core/widgets/epic_logo.dart';
import '../../../data/models/club_model.dart';
import '../../../data/models/sport_model.dart';
import '../../../data/services/api_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../reservation/screens/court_reservation_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeTab(),
          _PlaceholderTab('Matches'),
          _PlaceholderTab('Bookings'),
          _PlaceholderTab('Chat'),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}
class _HomeTabState extends State<_HomeTab> {
  List<ClubModel> _locations = [];
  List<SportModel> _sports = [];
  ClubModel? _selectedLocation;
  SportModel? _selectedSport;
  bool _loadingLocations = true;
  bool _loadingSports = false;
  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }
  Future<void> _fetchLocations() async {
    try {
      final res = await ApiService.get(
        'v3/locations/consumer/get-all',
        query: {'page': '1', 'per_page': '20'},
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      final locations = list.map((e) => ClubModel.fromJson(e)).toList();
      setState(() {
        _locations = locations;
        _loadingLocations = false;
        if (locations.isNotEmpty) {
          _selectedLocation = locations.first;
        }
      });
      if (locations.isNotEmpty) _fetchSports(locations.first.id);
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }
  Future<void> _fetchSports(int locationId) async {
    if (!mounted) return;
    setState(() => _loadingSports = true);
    try {
      final res = await ApiService.get(
        'v3/sports/consumer/getList',
        query: {
          'page': '1',
          'per_page': '20',
          'location_id': locationId.toString(),
        },
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      final sports = list.map((e) => SportModel.fromJson(e)).toList();
      setState(() {
        _sports = sports;
        _selectedSport = sports.isNotEmpty ? sports.first : null;
        _loadingSports = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSports = false);
    }
  }
  void _onReserveCourt() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first')),
      );
      return;
    }
    final sport = _selectedSport;
    final loc = _selectedLocation!;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CourtReservationScreen(
        locationId: loc.id,
        sportId: sport?.id ?? 0,
        locationName: loc.name,
        sportName: sport?.name ?? 'Sport',
        sportEmoji: sport?.emoji ?? '🏅',
      ),
    ));
  }
  void _openLocationPicker() {
    if (_locations.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LocationPickerSheet(
        locations: _locations,
        selected: _selectedLocation,
        onSelect: (loc) {
          Navigator.pop(context);
          setState(() {
            _selectedLocation = loc;
            _sports = [];
            _selectedSport = null;
          });
          _fetchSports(loc.id);
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const EpicLogo(),
                const Spacer(),
                _IconBtn(icon: Icons.search, onTap: () {}),
                const SizedBox(width: 8),
                const _NotificationBtn(),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openLocationPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 4),
                  _loadingLocations
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.primary),
                        )
                      : Text(
                          _selectedLocation?.name ?? 'Select Location',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                  const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textDark, size: 18),
                ],
              ),
            ),
          ),
          _buildSportTabs(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0EDE8)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const _BannerCarousel(),
                  const SizedBox(height: 20),
                  _ActionGrid(onReserve: _onReserveCourt),
                  const SizedBox(height: 16),
                  const _TournamentsSection(),
                  const SizedBox(height: 20),
                  const _PremiumBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSportTabs() {
    if (_loadingSports) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          height: 34,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: AppColors.primary),
            ),
          ),
        ),
      );
    }
    if (_sports.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏅', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                'Sports',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
        itemCount: _sports.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sport = _sports[i];
          final selected = sport.id == _selectedSport?.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedSport = sport),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.inputBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sport.emoji,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    sport.name,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
class _LocationPickerSheet extends StatefulWidget {
  final List<ClubModel> locations;
  final ClubModel? selected;
  final ValueChanged<ClubModel> onSelect;
  const _LocationPickerSheet({
    required this.locations,
    required this.selected,
    required this.onSelect,
  });
  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}
class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchController = TextEditingController();
  late List<ClubModel> _filtered;
  @override
  void initState() {
    super.initState();
    _filtered = widget.locations;
    _searchController.addListener(() {
      final q = _searchController.text.toLowerCase();
      setState(() {
        _filtered = widget.locations
            .where((l) => l.name.toLowerCase().contains(q))
            .toList();
      });
    });
  }
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Location',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search location',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final loc = _filtered[i];
                  final isSelected = widget.selected?.id == loc.id;
                  return ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: isSelected ? AppColors.primary : AppColors.textGrey,
                    ),
                    title: Text(loc.name),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    onTap: () => widget.onSelect(loc),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _BannerData {
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color? borderColor;
  final Widget icon;
  const _BannerData({
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.icon,
    this.borderColor,
  });
}
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}
class _BannerCarouselState extends State<_BannerCarousel> {
  int _page = 0;
  late final PageController _controller;
  static final _items = [
    _BannerData(
      title: 'Play Better with Clutch Ai',
      subtitle: 'AI analyzes your gameplay to provide an accurate skill assessment.',
      bgColor: const Color(0xFFFFFDE8),
      icon: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            'CLUTCH',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
      ),
    ),
    _BannerData(
      title: 'Tennis And PB: The Week Ahead!',
      subtitle: 'Your Weekly Dose of Tennis & Pickleball Week 6 of Junior Morning Classes.',
      bgColor: const Color(0xFFE8F5EE),
      icon: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: Color(0xFF1B3A2D),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.campaign, color: Colors.white, size: 22),
      ),
    ),
    _BannerData(
      title: 'Get Competitive!',
      subtitle: 'Be The Number 1 Player In The World! Link Your Account Into Ranking System.',
      bgColor: const Color(0xFFFCE8E8),
      icon: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: Color(0xFFD32F2F),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            'WPR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
    _BannerData(
      title: 'Kyle Joined Match!',
      subtitle: 'Tuesday, May 5 • 8:00 PM',
      bgColor: const Color(0xFFFAFAF5),
      borderColor: AppColors.primary,
      icon: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFFFCDD2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.person, color: Color(0xFFD32F2F), size: 24),
      ),
    ),
  ];
  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 90,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final item = _items[i];
              return Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 2 : 6,
                  right: i == _items.length - 1 ? 2 : 6,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.borderColor ?? item.bgColor,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      item.icon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_items.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : const Color(0xFFD0CCC4),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}
class _ActionGrid extends StatelessWidget {
  final VoidCallback? onReserve;
  const _ActionGrid({this.onReserve});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  title: 'Reserve a Court',
                  subtitle: '8AM - 9PM',
                  icon: Icons.dashboard_outlined,
                  imagePath: 'assets/images/home_reserve_court.png',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D3B2E), Color(0xFF1A6040)],
                  ),
                  onTap: onReserve ?? () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  title: 'Open Play',
                  subtitle: 'Explore Matches',
                  icon: Icons.emoji_events_outlined,
                  imagePath: 'assets/images/home_open_play.jpg',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D1F3B), Color(0xFF1A3A6A)],
                  ),
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  title: 'Join a Program',
                  subtitle: 'Explore Programs',
                  icon: Icons.track_changes_outlined,
                  imagePath: 'assets/images/home_join_program.jpg',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1A0D), Color(0xFF3B3A1A)],
                  ),
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  title: 'Book a Lesson',
                  subtitle: '8AM - 9PM',
                  icon: Icons.school_outlined,
                  imagePath: 'assets/images/home_book_lesson.jpg',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D2B1F), Color(0xFF1B5040)],
                  ),
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final String imagePath;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.imagePath,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 148,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(decoration: BoxDecoration(gradient: gradient)),
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD000000)],
                    stops: [0.2, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _TournamentItem {
  final String title;
  final String prizePool;
  final String date;
  final String location;
  final int playersJoined;
  final int playersMax;
  final String daysLeft;
  final String joinPrice;
  final List<String> tags;
  final String imagePath;
  final bool badgeOnImage;
  const _TournamentItem({
    required this.title,
    required this.prizePool,
    required this.date,
    required this.location,
    required this.playersJoined,
    required this.playersMax,
    required this.daysLeft,
    required this.joinPrice,
    required this.tags,
    required this.imagePath,
    this.badgeOnImage = false,
  });
}
const _tournaments = [
  _TournamentItem(
    title: '2026 Padel Championship - Nike',
    prizePool: '\$100,000',
    date: 'Oct 14–18, 2026 · 9:00 AM',
    location: 'Prosperity Club · Charlotte, NC',
    playersJoined: 10,
    playersMax: 60,
    daysLeft: '2 days left',
    joinPrice: '\$250',
    tags: ['Advance', 'Open Reg', 'Mixed', 'Outdoor'],
    imagePath: 'assets/images/tournament01.png',
  ),
  _TournamentItem(
    title: '2026 Padel Championship - Nike',
    prizePool: '\$100,000',
    date: 'Oct 14–18, 2026 · 9:00 AM',
    location: 'Prosperity Club · Charlotte, NC',
    playersJoined: 10,
    playersMax: 60,
    daysLeft: '2 days left',
    joinPrice: '\$250',
    tags: ['Advance', 'Open Reg', 'Mixed', 'Outdoor'],
    imagePath: 'assets/images/tournament02.jpg',
  ),
  _TournamentItem(
    title: '2026 Padel Championship - Nike',
    prizePool: '\$100,000',
    date: 'Oct 14–18, 2026 · 9:00 AM',
    location: 'Prosperity Club · Charlotte, NC',
    playersJoined: 10,
    playersMax: 60,
    daysLeft: '2 days left',
    joinPrice: '\$250',
    tags: ['Advance', 'Open Reg', 'Mixed', 'Outdoor'],
    imagePath: 'assets/images/3.png',
    badgeOnImage: true,
  ),
  _TournamentItem(
    title: '2026 Padel Championship - Nike',
    prizePool: '\$100,000',
    date: 'Oct 14–18, 2026 · 9:00 AM',
    location: 'Prosperity Club · Charlotte, NC',
    playersJoined: 10,
    playersMax: 60,
    daysLeft: '2 days left',
    joinPrice: '\$250',
    tags: ['Advance', 'Open Reg', 'Mixed', 'Outdoor'],
    imagePath: 'assets/images/4.png',
    badgeOnImage: true,
  ),
];
class _TournamentsSection extends StatelessWidget {
  const _TournamentsSection();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C5534), Color(0xFFFFFFFF)],
        ),
      ),
      padding: const EdgeInsets.only(top: 22, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tournaments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'view all',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 420,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tournaments.length,
              itemBuilder: (ctx, i) => Padding(
                padding: EdgeInsets.only(right: i < _tournaments.length - 1 ? 16 : 0),
                child: _TournamentCard(item: _tournaments[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _TournamentCard extends StatelessWidget {
  final _TournamentItem item;
  const _TournamentCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 48;
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFF1B3A2D)),
                  Image.asset(
                    item.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  if (item.badgeOnImage)
                    Positioned(
                      top: 10,
                      left: 12,
                      child: _DaysLeftBadge(label: item.daysLeft),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Image.asset(
                        'assets/images/WPR.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text('WPR',
                              style: TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        'assets/images/Nike.png',
                        height: 40,
                        width: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.tags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFFDDD8D0)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF0EDE8)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.date,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textGrey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!item.badgeOnImage) ...[
                      const SizedBox(width: 8),
                      _DaysLeftBadge(label: item.daysLeft),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.location,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textGrey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F4F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PRIZE POOL',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textGrey,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Text('🏆',
                                    style: TextStyle(fontSize: 15)),
                                const SizedBox(width: 4),
                                Text(
                                  item.prizePool,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color.fromARGB(255, 48, 96, 51),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F4F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PLAYERS',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textGrey,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Text(
                                  '${item.playersJoined}/${item.playersMax}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color.fromARGB(255, 48, 96, 51),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 44,
                                  height: 22,
                                  child: Stack(
                                    children: [
                                      _PlayerAvatar(
                                          color: const Color(0xFFFFCDD2),
                                          left: 0),
                                      _PlayerAvatar(
                                          color: const Color(0xFFBBDEFB),
                                          left: 12),
                                      _PlayerAvatar(
                                          color: const Color(0xFFC8E6C9),
                                          left: 24),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Join ${item.joinPrice}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _DaysLeftBadge extends StatelessWidget {
  final String label;
  const _DaysLeftBadge({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFCAFF5B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time,
            size: 13,
            color: AppColors.textDark,
            shadows: [Shadow(color: AppColors.textDark, blurRadius: 0.8)],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
class _PlayerAvatar extends StatelessWidget {
  final Color color;
  final double left;
  const _PlayerAvatar({required this.color, required this.left});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(Icons.person, size: 13, color: Colors.white),
      ),
    );
  }
}
class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock Premium Features\nTo Elevate Your Game!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Exclusive access to courts and match insights',
                    style: TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.workspace_premium,
                  color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.currentIndex, required this.onTap});
  static const _items = [
    _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home'),
    _NavItem(
        icon: Icons.sports_tennis_outlined,
        activeIcon: Icons.sports_tennis,
        label: 'Matches'),
    _NavItem(
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today,
        label: 'Bookings'),
    _NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Chat',
        badge: '11'),
    _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile'),
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: Color(0xFFF0EDE8), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            active ? item.activeIcon : item.icon,
                            color: active
                                ? AppColors.primary
                                : AppColors.textGrey,
                            size: 22,
                          ),
                          if (item.badge != null)
                            Positioned(
                              right: -8,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.badge!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: active
                              ? AppColors.primary
                              : AppColors.textGrey,
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badge;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
}
class _PlaceholderTab extends StatelessWidget {
  final String name;
  const _PlaceholderTab(this.name);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name,
        style: const TextStyle(fontSize: 18, color: AppColors.textGrey),
      ),
    );
  }
}
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
class _NotificationBtn extends StatelessWidget {
  const _NotificationBtn();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_outlined,
                  size: 20, color: Colors.white),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
