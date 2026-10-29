import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_colors.dart';
import '../../../data/models/location_detail_model.dart';
import '../../../data/models/time_slot_model.dart';
import '../../../data/models/reservation_type_model.dart';
import '../../../data/models/player_search_model.dart';
import '../../../data/models/sport_model.dart';
import '../../../data/models/country_model.dart';
import '../../../data/services/api_service.dart';
import 'checkout_screen.dart';
import 'player_search_sheet.dart';
class CourtReservationScreen extends StatefulWidget {
  final int locationId;
  final int sportId;
  final String locationName;
  final String sportName;
  final String sportEmoji;
  const CourtReservationScreen({
    super.key,
    required this.locationId,
    required this.sportId,
    required this.locationName,
    required this.sportName,
    required this.sportEmoji,
  });
  @override
  State<CourtReservationScreen> createState() =>
      _CourtReservationScreenState();
}
class _CourtReservationScreenState extends State<CourtReservationScreen> {
  LocationDetailModel? _location;
  List<SportModel> _sports = [];
  List<ReservationTypeModel> _reservationTypes = [];
  List<int> _durations = [];
  List<TimeSlotModel> _timeSlots = [];
  SportModel? _selectedSport;
  ReservationTypeModel? _selectedType;
  int _selectedDuration = 60;
  TimeSlotModel? _selectedSlot;
  SubCourtModel? _selectedCourt;
  DateTime _selectedDate = DateTime.now();
  List<PlayerSearchModel> _players = [];
  List<Map<String, dynamic>> _guests = [];
  PlayerSearchModel? _currentUserProfile;
  bool _clutchEnabled = true;
  bool _availableOnly = false;
  final List<CourtAddonModel> _staticAddons = [
    CourtAddonModel(id: 1, courtAttributeId: 1, name: 'Padel Racket', imageUrl: 'assets/images/PadelTennis.png', price: 10.0),
    CourtAddonModel(id: 2, courtAttributeId: 2, name: 'Tennis Ball', imageUrl: 'assets/images/Tennis Ball.png', price: 5.0),
    CourtAddonModel(id: 3, courtAttributeId: 3, name: 'Wristband', price: 3.0),
    CourtAddonModel(id: 4, courtAttributeId: 4, name: 'Towel', imageUrl: 'assets/images/Towel.png', price: 4.0),
    CourtAddonModel(id: 5, courtAttributeId: 5, name: 'Water Bottle', price: 2.0),
  ];
  bool _loadingSlots = false;
  bool _loadingInit = true;
  double _estimatedPrice = 0;
  int _tabIndex = 0;
  int get _activeSportId => _selectedSport?.id ?? widget.sportId;
  String get _activeSportName => _selectedSport?.name ?? widget.sportName;
  @override
  void initState() {
    super.initState();
    _init();
  }
  Future<void> _init() async {
    try {
      final locRes = await ApiService.get(
        'v3/locations/public/getByIdV2/${widget.locationId}',
        withAuth: true,
      );
      final location = LocationDetailModel.fromJson(locRes);
      if (!mounted) return;
      setState(() {
        _location = location;
        if (location.courts.isNotEmpty) {
          _selectedCourt = location.courts.first;
        }
      });
      await Future.wait([
        _fetchSports(),
        _fetchReservationTypes(),
        _fetchDurations(),
        _fetchCurrentUserProfile(),
      ]);
      if (mounted) await _fetchSlots();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingInit = false);
    }
  }
  Future<void> _fetchCurrentUserProfile() async {
    try {
      final res = await ApiService.get('mob_app/auth/autoLogin', withAuth: true);
      final data = res['user'] as Map<String, dynamic>?
          ?? res['data'] as Map<String, dynamic>?
          ?? res;
      if (!mounted) return;
      setState(() => _currentUserProfile = PlayerSearchModel.fromJson(data));
    } catch (_) {}
  }
  Future<void> _fetchReservationTypes() async {
    try {
      final res = await ApiService.get(
        'mob_app/auth/reservation-type/get-reservation-type',
        query: {
          'court_id': widget.locationId.toString(),
          'sport_id': _activeSportId.toString(),
        },
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      final types = list
          .whereType<Map<String, dynamic>>()
          .map(ReservationTypeModel.fromJson)
          .toList();
      setState(() {
        _reservationTypes = types;
        if (types.isNotEmpty) _selectedType = types.first;
      });
    } catch (_) {}
  }
  Future<void> _fetchDurations() async {
    try {
      final res = await ApiService.get(
        'v3/locations/consumer/${widget.locationId}/slot-durations',
        withAuth: true,
      );
      final data = res['data'];
      final rawList = data is Map<String, dynamic>
          ? (data['slot_durations'] as List? ?? [])
          : (data as List? ?? []);
      if (!mounted) return;
      final durations = rawList.whereType<int>().toList();
      if (durations.isNotEmpty) {
        setState(() {
          _durations = durations;
          if (!_durations.contains(_selectedDuration)) {
            _selectedDuration = _durations.first;
          }
        });
      }
    } catch (_) {}
  }
  Future<void> _fetchSports() async {
    try {
      final res = await ApiService.get(
        'v3/sports/consumer/getList',
        query: {
          'page': '1',
          'per_page': '20',
          'location_id': widget.locationId.toString(),
        },
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      final sports = list
          .whereType<Map<String, dynamic>>()
          .map(SportModel.fromJson)
          .toList();
      if (sports.isEmpty) return;
      setState(() {
        _sports = sports;
        _selectedSport = sports.firstWhere(
          (s) => s.id == _activeSportId,
          orElse: () => sports.first,
        );
      });
    } catch (_) {}
  }
  void _onSportSelected(SportModel sport) {
    setState(() {
      _selectedSport = sport;
      _selectedType = null;
      _reservationTypes = [];
      _selectedSlot = null;
    });
    _fetchReservationTypes();
    _fetchSlots();
  }
  void _openSportPicker() {
    final sports = _sports;
    if (sports.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Select Sport',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...sports.map((s) => ListTile(
                  title: Text(s.name),
                  trailing: _activeSportId == s.id
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _onSportSelected(s);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  Future<void> _fetchSlots() async {
    setState(() => _loadingSlots = true);
    try {
      final d = _selectedDate;
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} 00:00:00';
      final res = await ApiService.get(
        'v3/locations/public/suggestLocationSlots',
        query: {
          'court_id': widget.locationId.toString(),
          'sport_id': _activeSportId.toString(),
          'duration': _selectedDuration.toString(),
          'start_datetime': dateStr,
        },
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? (res['slots'] as List?) ?? [];
      if (!mounted) return;
      final slots = list
          .whereType<Map<String, dynamic>>()
          .map(TimeSlotModel.fromJson)
          .toList();
      setState(() {
        _timeSlots = slots;
        _selectedSlot = null;
        _loadingSlots = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }
  Future<void> _fetchEstimate() async {
    if (_selectedSlot == null) return;
    if (mounted && _selectedSlot!.price > 0 && _estimatedPrice == 0) {
      setState(() => _estimatedPrice = _selectedSlot!.price);
    }
    try {
      final body = <String, dynamic>{
        'court_id': widget.locationId,
        'sport_id': _activeSportId,
        'start_time': _selectedSlot!.startTime,
        'end_time': _selectedSlot!.endTime,
        'duration_in_minutes': _selectedDuration,
        if (_selectedCourt != null) 'sub_court_id': _selectedCourt!.id,
        if (_selectedType != null)
          'reservation_type_id': _selectedType!.id,
      };
      final res = await ApiService.post(
        'v3/bookings/estimate',
        body,
        withAuth: true,
      );
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      final price = (data['subtotal'] as num?)?.toDouble() ??
          (data['pay_your_part'] as num?)?.toDouble() ??
          (data['pay_everything'] as num?)?.toDouble() ??
          (data['total'] as num?)?.toDouble() ??
          (data['price'] as num?)?.toDouble() ??
          0.0;
      if (mounted && price > 0) setState(() => _estimatedPrice = price);
    } catch (_) {}
  }
  void _onSlotTap(TimeSlotModel slot) {
    if (!slot.isAvailable) return;
    if (slot.isPeak) {
      _showPeakDialog(slot);
      return;
    }
    setState(() => _selectedSlot = slot);
    _fetchEstimate();
  }
  void _showPeakDialog(TimeSlotModel slot) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Peak Hours',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'This is a peak hour slot and may be priced higher. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedSlot = slot);
              _fetchEstimate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  void _openTypePicker() {
    final types = _reservationTypes;
    if (types.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReservationTypeSheet(
        types: types,
        selected: _selectedType,
        onSelect: (t) {
          Navigator.pop(context);
          setState(() => _selectedType = t);
        },
      ),
    );
  }
  Future<void> _openPlayerSearch() async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => PlayerSearchSheet(
        initialSelected: _players,
        maxPlayers: _selectedType?.maxPlayers ?? 4,
      ),
    );
    if (!mounted) return;
    if (result is List<PlayerSearchModel>) {
      setState(() => _players = result);
    } else if (result == 'guests') {
      _openGuestDetails();
    }
  }
  Future<void> _openGuestDetails() async {
    final guests = await Navigator.of(context)
        .push<List<Map<String, dynamic>>>(MaterialPageRoute(
      builder: (_) => _GuestDetailsScreen(existingGuests: _guests),
    ));
    if (guests != null && mounted) {
      setState(() => _guests = guests);
    }
  }
  void _goToCheckout() async {
    if (_selectedSlot == null) return;
    if (_estimatedPrice == 0) await _fetchEstimate();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CheckoutScreen(
        locationId: widget.locationId,
        courtId: widget.locationId,
        subCourtId: _selectedCourt?.id,
        sportId: _activeSportId,
        reservationTypeId: _selectedType?.id,
        startTime: _selectedSlot!.startTime,
        endTime: _selectedSlot!.endTime,
        durationMinutes: _selectedDuration,
        players: _players,
        guests: _guests,
        clutchEnabled: _clutchEnabled,
        addons: _location?.addons ?? [],
        estimatedPrice: _estimatedPrice,
        locationName: widget.locationName,
        sportName: _activeSportName,
        sportEmoji: widget.sportEmoji,
        courtName: _selectedCourt?.name ?? '',
        reservationTypeName: _selectedType?.name ?? '',
      ),
    ));
  }
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _loadingInit
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(child: _buildContentCard()),
                ],
              ),
        bottomNavigationBar: _selectedSlot != null
            ? _buildStickyBookBar()
            : null,
      ),
    );
  }
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 150,
      pinned: false,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/1.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.primary,
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: 12,
                child: Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 12,
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.near_me,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.splitscreen,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      '$_activeSportName - Court Reservation',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      leading: const SizedBox.shrink(),
      actions: const [],
    );
  }
  Widget _buildContentCard() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _location?.name ?? widget.locationName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _location?.address ?? '',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTabBar(),
          IndexedStack(
            index: _tabIndex,
            children: [
              _buildBookTab(),
              _buildAboutTab(),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildTabBar() {
    const tabs = ['Book', 'About'];
    return Stack(
      children: [
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            height: 1.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1C5534), Colors.white],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final selected = _tabIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _tabIndex = i),
                child: selected
                    ? Container(
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF1C5534), Colors.white],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        padding: const EdgeInsets.only(left: 1, top: 1, right: 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(9),
                              topRight: Radius.circular(9),
                            ),
                          ),
                          child: Text(
                            tabs[i],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        margin: const EdgeInsets.only(right: 4),
                        child: Text(
                          tabs[i],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
              );
            }),
          ),
        ),
      ],
    );
  }
  Widget _buildBookTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSportTypeRow(),
          const SizedBox(height: 20),
          _buildSectionHeader('Select Date'),
          const SizedBox(height: 10),
          _buildDateRow(),
          const SizedBox(height: 20),
          _buildSectionHeader('Select Duration'),
          const SizedBox(height: 10),
          _buildDurationRow(),
          const SizedBox(height: 20),
          _buildSectionHeader('Select Time'),
          const SizedBox(height: 8),
          _buildAvailableToggleRow(),
          const SizedBox(height: 10),
          _buildTimeSlotsSection(),
          const SizedBox(height: 20),
          _buildSectionHeader('Select Court'),
          const SizedBox(height: 10),
          _buildCourtRow(),
          const SizedBox(height: 20),
          _buildPlayersRow(),
          if (_location?.addons.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            _buildSectionHeader('Add-ons Available'),
            const SizedBox(height: 10),
            _buildAddonsRow(_location!.addons),
          ],
          const SizedBox(height: 20),
          _buildClutchRow(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
  Widget _buildSportTypeRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openSportPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _activeSportName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 20, color: AppColors.textDark),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _openTypePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedType?.name ?? 'Singles',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 20, color: AppColors.textDark),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildDateRow() {
    final days = List.generate(30, (i) => DateTime.now().add(Duration(days: i)));
    const monthAbbrevs = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const dayAbbrevs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (_, i) {
          final day = days[i];
          final selected = day.year == _selectedDate.year &&
              day.month == _selectedDate.month &&
              day.day == _selectedDate.day;
          final monthAbbrev = monthAbbrevs[day.month - 1];
          final dayAbbrev = dayAbbrevs[day.weekday - 1];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = day;
                _selectedSlot = null;
              });
              _fetchSlots();
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.inputBorder,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthAbbrev,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : AppColors.textGrey,
                    ),
                  ),
                  Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    dayAbbrev,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : AppColors.textGrey,
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
  Widget _buildDurationRow() {
    final options = _durations.isNotEmpty ? _durations : [30, 60, 120];
    return Row(
      children: options.asMap().entries.map((entry) {
        final i = entry.key;
        final d = entry.value;
        final selected = d == _selectedDuration;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < options.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDuration = d;
                  _selectedSlot = null;
                });
                _fetchSlots();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.inputBorder,
                  ),
                ),
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$d',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        TextSpan(
                          text: ' mins',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: selected ? Colors.white : AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  Widget _buildAvailableToggleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Available slots',
            style:
                TextStyle(fontSize: 13, color: AppColors.textGrey)),
        Row(
          children: [
            const Text('Available only',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () =>
                  setState(() => _availableOnly = !_availableOnly),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 22,
                decoration: BoxDecoration(
                  color: _availableOnly
                      ? AppColors.primary
                      : AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: _availableOnly
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 3),
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _buildTimeSlotsSection() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final slots = _availableOnly
        ? _timeSlots.where((s) => s.isAvailable).toList()
        : _timeSlots;
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No time slots available for this date.',
          style: TextStyle(color: AppColors.textGrey, fontSize: 13),
        ),
      );
    }
    return _buildSlotGrid(slots);
  }
  Widget _buildSlotGrid(List<TimeSlotModel> slots) {
    final hasPeak = slots.any((s) => s.isPeak);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPeak)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'The yellow line indicate peak hours.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final isSelected = _selectedSlot?.startTime == slot.startTime;
            Color bgColor;
            Color textColor;
            BoxBorder? border;
            if (!slot.isAvailable) {
              bgColor = const Color(0xFFF5F5F5);
              textColor = AppColors.textGrey;
              border = Border.all(color: AppColors.inputBorder);
            } else if (isSelected) {
              bgColor = AppColors.primary;
              textColor = Colors.white;
              border = null;
            } else if (slot.isPeak) {
              bgColor = Colors.white;
              textColor = AppColors.textDark;
              border = Border.all(color: const Color(0xFFFFD700), width: 1.5);
            } else {
              bgColor = Colors.white;
              textColor = AppColors.textDark;
              border = Border.all(color: AppColors.inputBorder);
            }
            return GestureDetector(
              onTap: slot.isAvailable ? () => _onSlotTap(slot) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: border,
                ),
                child: Text(
                  slot.displayTime,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  Widget _buildCourtRow() {
    final courts = _location?.courts ?? [];
    if (courts.isEmpty) {
      return const Text('No courts available',
          style: TextStyle(color: AppColors.textGrey, fontSize: 13));
    }
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: courts.length,
        itemBuilder: (_, i) {
          final court = courts[i];
          final selected = _selectedCourt?.id == court.id;
          final bg = selected ? AppColors.primary : Colors.white;
          final textColor = selected ? Colors.white : AppColors.textDark;
          final subColor = selected ? Colors.white.withValues(alpha: 0.75) : AppColors.textGrey;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCourt = court;
                _selectedSlot = null;
              });
              _fetchSlots();
            },
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.inputBorder,
                  width: selected ? 0 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _activeSportName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: CustomPaint(
                        size: const Size(72, 52),
                        painter: _PadelCourtPainter(
                          lineColor: selected
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppColors.primary.withValues(alpha: 0.7),
                          bgColor: selected
                              ? Colors.transparent
                              : const Color(0xFFF0F7F4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    court.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _buildPlayersRow() {
    final maxPlayers = _selectedType?.maxPlayers ?? 4;
    final totalSelected = _players.length + 1; 
    final emptySlots = (maxPlayers - totalSelected).clamp(0, maxPlayers);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Number of Players',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
            Text(
              'min $totalSelected/$maxPlayers',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C5534)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Based on reservation type',
          style: TextStyle(fontSize: 12, color: AppColors.textDark),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: _buildPlayerChip(
                  photoUrl: _currentUserProfile?.photoUrl,
                  label: _currentUserProfile?.name.split(' ').first ?? '',
                  rating: _currentUserProfile?.rating,
                  isYou: true,
                  onRemove: null,
                ),
              ),
            ),
            ..._players.map((p) => Expanded(
                  child: Center(
                    child: _buildPlayerChip(
                      photoUrl: p.photoUrl,
                      label: p.name.split(' ').first,
                      rating: p.rating,
                      isYou: false,
                      onRemove: () => setState(() =>
                          _players = _players.where((x) => x.id != p.id).toList()),
                    ),
                  ),
                )),
            ...List.generate(
              emptySlots,
              (_) => Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _openPlayerSearch,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.inputBorder,
                              width: 1.5,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Icon(Icons.add,
                              color: AppColors.textGrey, size: 22),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _buildPlayerChip({
    required String? photoUrl,
    required String label,
    required double? rating,
    required bool isYou,
    required VoidCallback? onRemove,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      label.isNotEmpty ? label[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              isYou
                  ? (label.isNotEmpty ? '$label (You)' : '(You)')
                  : label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/WPR.png',
                    width: 14, height: 14),
                const SizedBox(width: 2),
                Text(
                  rating != null ? rating.toStringAsFixed(2) : 'N/A',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textGrey),
                ),
              ],
            ),
          ],
        ),
        if (onRemove != null)
          Positioned(
            top: 0,
            right: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.remove,
                    size: 13, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
  Widget _buildClutchRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE8D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'CLUTCH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clutch AI Camera',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Get instant access to your matches, highlights, and stats.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.info_outline,
              color: AppColors.textGrey, size: 20),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: _clutchEnabled,
              onChanged: (v) => setState(() => _clutchEnabled = v),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.inputBorder,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAboutTab() {
    final loc = _location;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          if (loc?.about != null && loc!.about!.isNotEmpty) ...[
            _buildSectionHeader('About Venue'),
            const SizedBox(height: 8),
            Text(
              loc.about!,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                  height: 1.5),
            ),
            const SizedBox(height: 20),
          ],
          if (loc?.facilities.isNotEmpty == true) ...[
            _buildSectionHeader('Our Facilities'),
            const SizedBox(height: 10),
            _buildFacilitiesGrid(loc!.facilities),
            const SizedBox(height: 20),
          ],
          if (loc?.instructors.isNotEmpty == true) ...[
            _buildSectionHeader('Instructors'),
            const SizedBox(height: 10),
            _buildInstructorRow(loc!.instructors),
            const SizedBox(height: 20),
          ],
          if (loc?.lessonTypes.isNotEmpty == true) ...[
            _buildSectionHeader('Featured Lessons'),
            const SizedBox(height: 10),
            _buildLessonRow(loc!.lessonTypes),
            const SizedBox(height: 20),
          ],
          _buildSectionHeader('Add-ons Available'),
          const SizedBox(height: 14),
          _buildAddonsRow(_staticAddons),
          const SizedBox(height: 14),
          _buildSectionHeader('Location'),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/location.png',
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.directions,
                  color: Colors.white, size: 18),
              label: const Text(
                'Get Directions',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  Widget _buildFacilitiesGrid(List<FacilityModel> facilities) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: facilities.map((f) {
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3EF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (f.iconUrl != null)
                Image.network(
                  f.iconUrl!,
                  width: 18,
                  height: 18,
                  errorBuilder: (_, _, _) => const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.primary),
                )
              else
                const Icon(Icons.check_circle_outline,
                    size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(f.name,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textDark)),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildInstructorRow(List<InstructorModel> instructors) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: instructors.length,
        itemBuilder: (_, i) {
          final ins = instructors[i];
          return Container(
            width: 100,
            height: 100,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.inputBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ins.photoUrl != null
                    ? Image.network(
                        ins.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _instructorFallback(ins.name),
                      )
                    : _instructorFallback(ins.name),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 5, horizontal: 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                    child: Text(
                      ins.name,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  Widget _instructorFallback(String name) {
    return Container(
      color: const Color(0xFFE8F5EE),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 28,
          ),
        ),
      ),
    );
  }
  Widget _buildLessonRow(List<LessonTypeModel> lessons) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: lessons.length,
        itemBuilder: (_, i) {
          final lesson = lessons[i];
          return Container(
            width: 130,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.inputBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/train.jpg',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0x88000000)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    lesson.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  Widget _buildAddonsRow(List<CourtAddonModel> addons) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: addons.length,
        itemBuilder: (_, i) {
          final addon = addons[i];
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  color: const Color(0xFFF8F8F8),
                  padding: const EdgeInsets.all(10),
                  child: addon.imageUrl != null
                      ? (addon.imageUrl!.startsWith('assets/')
                          ? Image.asset(
                              addon.imageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.textGrey,
                                size: 36,
                              ),
                            )
                          : Image.network(
                              addon.imageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.textGrey,
                                size: 36,
                              ),
                            ))
                      : const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.textGrey,
                          size: 36,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Text(
                    addon.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  String _formatSlotTime(String rawTime) {
    try {
      final parts = rawTime.split(' ');
      if (parts.length < 2) return rawTime;
      final timeParts = parts[1].split(':');
      if (timeParts.length < 2) return rawTime;
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final String period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      return '$hour:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return rawTime;
    }
  }
  String _formatSlotDate(String rawTime) {
    try {
      final datePart = rawTime.split(' ').first;
      final parts = datePart.split('-');
      if (parts.length < 3) return '';
      final day = int.parse(parts[2]);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final month = months[int.parse(parts[1]) - 1];
      return '$day $month';
    } catch (_) {
      return '';
    }
  }
  Widget _buildStickyBookBar() {
    final slot = _selectedSlot;
    if (slot == null) return const SizedBox.shrink();
    final sportLabel = _activeSportName;
    final courtLabel = _selectedCourt?.name ?? '';
    final typeLabel = _selectedType?.name ?? '';
    final titleParts = [
      if (sportLabel.isNotEmpty) sportLabel,
      if (courtLabel.isNotEmpty) courtLabel,
      if (typeLabel.isNotEmpty) typeLabel,
    ];
    final titleLine = titleParts.join(' - ');
    final dateStr = _formatSlotDate(slot.startTime);
    final startStr = _formatSlotTime(slot.startTime);
    final endStr = _formatSlotTime(slot.endTime);
    final subtitleLine = dateStr.isNotEmpty
        ? '$dateStr, $startStr - $endStr'
        : '$startStr - $endStr';
    final displayPrice =
        _estimatedPrice > 0 ? _estimatedPrice : slot.price;
    String fmtPrice(double p) =>
        p % 1 == 0 ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
    final priceLabel =
        displayPrice > 0 ? 'Book \$${fmtPrice(displayPrice)}' : 'Book Now';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (titleLine.isNotEmpty)
                  Text(
                    titleLine,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                Text(
                  subtitleLine,
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _goToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Text(
                priceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    );
  }
}
class _ReservationTypeSheet extends StatelessWidget {
  final List<ReservationTypeModel> types;
  final ReservationTypeModel? selected;
  final ValueChanged<ReservationTypeModel> onSelect;
  const _ReservationTypeSheet({
    required this.types,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Reservation Type',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          ...types.map((t) {
            final isSelected = selected?.id == t.id;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark)),
              subtitle: t.maxPlayers != null
                  ? Text('Max ${t.maxPlayers} players',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textGrey))
                  : null,
              trailing: isSelected
                  ? const Icon(Icons.check_circle,
                      color: AppColors.primary)
                  : const Icon(Icons.radio_button_unchecked,
                      color: AppColors.inputBorder),
              onTap: () => onSelect(t),
            );
          }),
        ],
      ),
    );
  }
}
class _GuestDetailsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> existingGuests;
  const _GuestDetailsScreen({required this.existingGuests});
  @override
  State<_GuestDetailsScreen> createState() => _GuestDetailsScreenState();
}
class _GuestDetailsScreenState extends State<_GuestDetailsScreen> {
  int _guestCount = 1;
  bool _saving = false;
  final List<Map<String, TextEditingController>> _controllers = [];
  List<CountryModel> _countries = [];
  final List<CountryModel?> _selectedCountries = [];
  @override
  void initState() {
    super.initState();
    final initial =
        widget.existingGuests.isNotEmpty ? widget.existingGuests.length : 1;
    _guestCount = initial;
    for (int i = 0; i < _guestCount; i++) {
      final ex =
          i < widget.existingGuests.length ? widget.existingGuests[i] : null;
      _controllers.add({
        'name': TextEditingController(text: ex?['name'] ?? ''),
        'email': TextEditingController(text: ex?['email'] ?? ''),
        'phone': TextEditingController(text: ex?['phone'] ?? ''),
      });
      _selectedCountries.add(null);
    }
    _loadCountries();
  }
  Future<void> _loadCountries() async {
    try {
      final res = await ApiService.get(
        'public/address/country/getAllCountries',
        query: {'page': '1', 'limit': '200'},
      );
      final list = (res['data'] as List?) ?? (res['countries'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _countries = list
            .whereType<Map<String, dynamic>>()
            .map(CountryModel.fromJson)
            .toList();
      });
    } catch (_) {}
  }
  @override
  void dispose() {
    for (final c in _controllers) {
      c['name']!.dispose();
      c['email']!.dispose();
      c['phone']!.dispose();
    }
    super.dispose();
  }
  void _setCount(int count) {
    if (count < 1 || count > 10) return;
    setState(() {
      while (_controllers.length < count) {
        _controllers.add({
          'name': TextEditingController(),
          'email': TextEditingController(),
          'phone': TextEditingController(),
        });
        _selectedCountries.add(null);
      }
      _guestCount = count;
    });
  }
  void _showCountryPicker(int index) {
    if (_countries.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GuestCountryPickerSheet(
        countries: _countries,
        selected: _selectedCountries[index],
        onSelect: (c) {
          setState(() => _selectedCountries[index] = c);
          Navigator.pop(context);
        },
      ),
    );
  }
  Future<void> _save() async {
    setState(() => _saving = true);
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < _guestCount; i++) {
      final fullName = _controllers[i]['name']!.text.trim();
      final email = _controllers[i]['email']!.text.trim();
      final phone = _controllers[i]['phone']!.text.trim();
      final countryCode = _selectedCountries[i]?.phoneCode ?? '+1';
      final countryId = _selectedCountries[i]?.id ?? 1;
      final parts = fullName.split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.skip(1).join(' ') : '';
      try {
        final res = await ApiService.post(
          'v3/consumer/addGuests',
          {
            'name': firstName,
            'last_name': lastName,
            'email': email,
            'country_code': countryCode,
            'country_id': countryId,
            'phone': phone,
          },
          withAuth: true,
        );
        final data = res['data'] as Map<String, dynamic>? ?? {};
        results.add({
          'id': data['id'],
          'name': fullName,
          'email': email,
          'phone': phone,
          'country_code': countryCode,
        });
      } catch (_) {
        results.add({
          'name': fullName,
          'email': email,
          'phone': phone,
          'country_code': countryCode,
        });
      }
    }
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, results);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Guest Details',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'How many guest?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _setCount(_guestCount - 1),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.remove,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$_guestCount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _setCount(_guestCount + 1),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_guestCount, _buildGuestForm),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(top: BorderSide(color: AppColors.inputBorder)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Add Guests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildGuestForm(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guest no. ${index + 1}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        _labeledField('Name', _controllers[index]['name']!,
            TextInputType.name),
        const SizedBox(height: 10),
        _labeledField('Email', _controllers[index]['email']!,
            TextInputType.emailAddress),
        const SizedBox(height: 10),
        _buildPhoneField(index),
        const SizedBox(height: 20),
      ],
    );
  }
  Widget _labeledField(
      String label, TextEditingController ctrl, TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textGrey)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
  Widget _buildPhoneField(int index) {
    final country = _selectedCountries[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Number',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
        const SizedBox(height: 4),
        TextField(
          controller: _controllers[index]['phone'],
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            prefixIcon: IntrinsicWidth(
              child: GestureDetector(
                onTap: () => _showCountryPicker(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_outlined,
                          color: AppColors.textGrey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        country != null
                            ? '${country.flag} (${country.phoneCode})'
                            : '(+1)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down,
                          color: AppColors.textGrey, size: 18),
                      Container(
                        width: 1,
                        height: 20,
                        color: AppColors.inputBorder,
                        margin: const EdgeInsets.only(left: 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
class _GuestCountryPickerSheet extends StatefulWidget {
  final List<CountryModel> countries;
  final CountryModel? selected;
  final ValueChanged<CountryModel> onSelect;
  const _GuestCountryPickerSheet({
    required this.countries,
    required this.selected,
    required this.onSelect,
  });
  @override
  State<_GuestCountryPickerSheet> createState() =>
      _GuestCountryPickerSheetState();
}
class _GuestCountryPickerSheetState extends State<_GuestCountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<CountryModel> _filtered = [];
  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = widget.countries
            .where((c) =>
                c.name.toLowerCase().contains(q) || c.phoneCode.contains(q))
            .toList();
      });
    });
  }
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search country',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final c = _filtered[i];
                  final sel = widget.selected?.id == c.id;
                  return ListTile(
                    leading:
                        Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(c.name),
                    trailing: Text(c.phoneCode,
                        style:
                            const TextStyle(color: AppColors.textGrey)),
                    selected: sel,
                    selectedColor: AppColors.primary,
                    onTap: () => widget.onSelect(c),
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
class _PadelCourtPainter extends CustomPainter {
  final Color lineColor;
  final Color bgColor;
  const _PadelCourtPainter({required this.lineColor, required this.bgColor});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(4)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, 2, w - 4, h - 4), const Radius.circular(3)),
      paint,
    );
    canvas.drawLine(Offset(2, h / 2), Offset(w - 2, h / 2), paint);
    canvas.drawLine(Offset(w / 2, 2), Offset(w / 2, h / 2), paint);
    canvas.drawLine(Offset(w / 2, h / 2), Offset(w / 2, h - 2), paint);
    final serviceGap = h * 0.28;
    canvas.drawLine(Offset(2, serviceGap), Offset(w - 2, serviceGap), paint);
    canvas.drawLine(Offset(2, h - serviceGap), Offset(w - 2, h - serviceGap), paint);
  }
  @override
  bool shouldRepaint(_PadelCourtPainter old) =>
      old.lineColor != lineColor || old.bgColor != bgColor;
}
