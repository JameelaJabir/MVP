import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../core/app_colors.dart';
import '../../../data/models/player_search_model.dart';
import '../../../data/models/location_detail_model.dart';
import '../../../data/services/api_service.dart';
import 'booking_success_screen.dart';
import 'player_search_sheet.dart';
class CheckoutScreen extends StatefulWidget {
  final int locationId;
  final int courtId;
  final int? subCourtId;
  final int sportId;
  final int? reservationTypeId;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final List<PlayerSearchModel> players;
  final List<Map<String, dynamic>> guests;
  final bool clutchEnabled;
  final List<CourtAddonModel> addons;
  final double estimatedPrice;
  final String locationName;
  final String sportName;
  final String sportEmoji;
  final String courtName;
  final String reservationTypeName;
  const CheckoutScreen({
    super.key,
    required this.locationId,
    required this.courtId,
    this.subCourtId,
    required this.sportId,
    this.reservationTypeId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.players,
    required this.guests,
    required this.clutchEnabled,
    required this.addons,
    required this.estimatedPrice,
    required this.locationName,
    required this.sportName,
    required this.sportEmoji,
    this.courtName = '',
    this.reservationTypeName = '',
  });
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}
class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Map<String, dynamic>> _savedCards = [];
  List<Map<String, dynamic>> _allowedMethods = [];
  List<Map<String, dynamic>> _packages = [];
  int _punchBalance = 0;
  int _punchCost = 0;
  int? _selectedMethodEnumNumber;
  int? _selectedCardId;
  bool _useWallet = false;
  bool _loading = true;
  bool _booking = false;
  String? _error;
  int? _currentUserId;
  double _payYourPartPrice = 0;
  double _payEveryonePrice = 0;
  double _holdAmount = 0;
  double _walletBalance = 0;
  double _guestFeeTotal = 0;
  String _lastTimeToPay = '';
  bool _payForEveryone = false;
  Map<String, dynamic>? _appliedPackage;
  double _packageDiscount = 0;
  late List<PlayerSearchModel> _players;
  late List<Map<String, dynamic>> _guests;
  late List<CourtAddonModel> _addons;
  double get _addonTotal =>
      _addons.fold(0.0, (s, a) => s + a.price * a.quantity);
  double get _basePrice =>
      _payForEveryone ? _payEveryonePrice : _payYourPartPrice;
  double get _subtotal =>
      (_basePrice + _addonTotal - _packageDiscount).clamp(0, double.infinity);
  double get _walletDeduction =>
      _useWallet ? _walletBalance.clamp(0, _subtotal) : 0;
  double get _totalToAuthorize =>
      (_subtotal - _walletDeduction).clamp(0, double.infinity);
  String _fmt(double v) =>
      v % 1 == 0 ? '\$${v.toStringAsFixed(0)}' : '\$${v.toStringAsFixed(2)}';
  @override
  void initState() {
    super.initState();
    _players = List.from(widget.players);
    _guests = List.from(widget.guests);
    _addons = widget.addons
        .map((a) => CourtAddonModel(
              id: a.id,
              courtAttributeId: a.courtAttributeId,
              name: a.name,
              imageUrl: a.imageUrl,
              price: a.price,
              quantity: a.quantity,
            ))
        .toList();
    _payYourPartPrice = widget.estimatedPrice;
    _payEveryonePrice = widget.estimatedPrice;
    _loadData();
  }
  Future<void> _loadData() async {
    try {
      final futures = await Future.wait([
        ApiService.get(
          'v4/payment-gateways/consumer/allowed',
          query: {'court_id': widget.locationId.toString()},
          withAuth: true,
        ),
        ApiService.get(
          'v4/user-payment-methods/consumer/getList',
          query: {'per_page': '100'},
          withAuth: true,
        ),
        ApiService.get('mob_app/auth/autoLogin', withAuth: true),
      ]);
      _loadPackages();
      _fetchEstimateBreakdown();
      if (_addons.isEmpty) _fetchAddons();
      if (!mounted) return;
      final allMethods = (futures[0]['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final methods = allMethods.where((m) {
        final name = (m['name']?.toString() ??
                m['gateway']?.toString() ??
                m['type']?.toString() ??
                '')
            .toLowerCase();
        return !name.contains('apple') && !name.contains('google_pay');
      }).toList();
      final cards = (futures[1]['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final userRaw = futures[2]['data'] ?? futures[2]['user'] ?? futures[2];
      final userId = (userRaw is Map) ? (userRaw['id'] as num?)?.toInt() : null;
      setState(() {
        _allowedMethods = methods;
        _savedCards = cards;
        _currentUserId = userId;
        if (methods.isNotEmpty) {
          _selectedMethodEnumNumber =
              (methods.first['enum_number'] as num?)?.toInt() ??
                  (methods.first['id'] as num?)?.toInt();
        }
        if (cards.isNotEmpty) {
          final defaultCard = cards.firstWhere(
            (c) => c['is_default'] == true,
            orElse: () => cards.first,
          );
          _selectedCardId = (defaultCard['id'] as num?)?.toInt();
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
  static final _staticAddons = [
    CourtAddonModel(id: 1, courtAttributeId: 1, name: 'Padel Racket', imageUrl: 'assets/images/PadelTennis.png', price: 15),
    CourtAddonModel(id: 2, courtAttributeId: 2, name: 'Padel Balls x3', imageUrl: 'assets/images/Tennis Ball.png', price: 8),
    CourtAddonModel(id: 3, courtAttributeId: 3, name: 'Face Towel x3', imageUrl: 'assets/images/Towel.png', price: 6),
    CourtAddonModel(id: 4, courtAttributeId: 4, name: 'Tennis Ball', imageUrl: 'assets/images/Tennis Ball.png', price: 5),
    CourtAddonModel(id: 5, courtAttributeId: 5, name: 'Padel Tennis', imageUrl: 'assets/images/PadelTennis.png', price: 12),
    CourtAddonModel(id: 6, courtAttributeId: 6, name: 'Towel', imageUrl: 'assets/images/Towel.png', price: 4),
  ];
  Future<void> _fetchAddons() async {
    try {
      final data = await ApiService.get(
        'v3/locations/public/getByIdV2/${widget.locationId}',
        withAuth: false,
      );
      final location = LocationDetailModel.fromJson(data);
      if (!mounted) return;
      if (location.addons.isNotEmpty) {
        setState(() {
          _addons = location.addons
              .map((a) => CourtAddonModel(
                    id: a.id,
                    courtAttributeId: a.courtAttributeId,
                    name: a.name,
                    imageUrl: a.imageUrl,
                    price: a.price,
                    quantity: 0,
                  ))
              .toList();
        });
      } else {
        setState(() => _addons = _staticAddons.map((a) => CourtAddonModel(
              id: a.id, courtAttributeId: a.courtAttributeId,
              name: a.name, imageUrl: a.imageUrl, price: a.price,
            )).toList());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _addons = _staticAddons.map((a) => CourtAddonModel(
              id: a.id, courtAttributeId: a.courtAttributeId,
              name: a.name, imageUrl: a.imageUrl, price: a.price,
            )).toList());
      }
    }
  }
  Future<void> _fetchEstimateBreakdown() async {
    try {
      final body = <String, dynamic>{
        'court_id': widget.locationId,
        'sub_court_id': widget.subCourtId ?? widget.courtId,
        'sport_id': widget.sportId,
        'start_time': widget.startTime,
        'end_time': widget.endTime,
        'duration_in_minutes': widget.durationMinutes,
        if (widget.reservationTypeId != null)
          'reservation_type_id': widget.reservationTypeId,
      };
      final res =
          await ApiService.post('v3/bookings/estimate', body, withAuth: true);
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      if (!mounted) return;
      setState(() {
        _payYourPartPrice = (data['pay_your_part'] as num?)?.toDouble() ??
            (data['split_total'] as num?)?.toDouble() ??
            (data['subtotal'] as num?)?.toDouble() ??
            widget.estimatedPrice;
        _payEveryonePrice = (data['pay_everything'] as num?)?.toDouble() ??
            (data['total'] as num?)?.toDouble() ??
            _payYourPartPrice;
        _holdAmount = (data['hold_amount'] as num?)?.toDouble() ?? 0;
        _walletBalance = (data['wallet_amount'] as num?)?.toDouble() ??
            (res['wallet_balance'] as num?)?.toDouble() ?? 0;
        _lastTimeToPay = data['last_time_to_pay']?.toString() ?? '';
        final guestsList = (data['guests'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        _guestFeeTotal = guestsList.fold(
            0.0,
            (s, g) =>
                s +
                ((g['guestCharge'] as num?)?.toDouble() ??
                    (g['amount'] as num?)?.toDouble() ??
                    0));
      });
    } catch (_) {}
  }
  static const _staticPackages = [
    {
      'id': 101,
      'name': '3rd Jun Punch Package zero pricing',
      'type': 'punch',
      'remaining_punches': '20',
      'expires_at': 'July 16 - 2026',
      'discount_percentage': 15,
    },
    {
      'id': 102,
      'name': 'Monthly Punch Package',
      'type': 'punch',
      'remaining_punches': '30',
      'expires_at': 'Aug 1 - 2026',
      'discount_percentage': 20,
    },
    {
      'id': 103,
      'name': 'Founding Membership',
      'type': 'membership',
      'benefits': [
        'Book padel courts anytime',
        'Free rentals padel racquet and ball',
        '20 Court Reservation for free / month',
      ],
    },
  ];
  Future<void> _loadPackages() async {
    try {
      final dateOnly = widget.startTime.split(' ').first;
      final res = await ApiService.post(
        'v3/punch_package_purchases/redeemable-packages',
        {
          'type': [0],
          'booking_date': dateOnly,
          'court_id': widget.locationId,
          'sport_id': widget.sportId,
          'duration_in_minutes': widget.durationMinutes,
        },
        withAuth: true,
      );
      if (!mounted) return;
      final list = (res['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final balance = (res['punch_balance'] as num?)?.toInt() ??
          (res['balance'] as num?)?.toInt() ??
          (res['wallet_balance'] as num?)?.toInt() ?? 0;
      final cost = list.isNotEmpty
          ? (list.first['punch_cost'] as num?)?.toInt() ??
              (list.first['punches_to_redeem'] as num?)?.toInt() ??
              (list.first['remaining_punches'] as num?)?.toInt() ?? 0
          : 0;
      if (list.isNotEmpty) {
        setState(() {
          _packages = list;
          _punchBalance = balance;
          _punchCost = cost;
        });
      } else {
        setState(() {
          _packages = List<Map<String, dynamic>>.from(_staticPackages);
          _punchBalance = 852;
          _punchCost = 48;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _packages = List<Map<String, dynamic>>.from(_staticPackages);
          _punchBalance = 852;
          _punchCost = 48;
        });
      }
    }
  }
  Future<void> _book() async {
    setState(() {
      _booking = true;
      _error = null;
    });
    try {
      final registeredGuests = [
        ..._players.map((p) => {'id': p.id, 'name': p.name}),
        ..._guests
            .where((g) => g['id'] != null)
            .map((g) => {'id': g['id'], 'name': g['name'] ?? ''}),
      ];
      final externalGuests = _guests
          .where((g) => g['id'] == null)
          .map((g) => {
                'name': g['name'] ?? '',
                'email': g['email'] ?? '',
                'phone': g['phone'] ?? '',
                'country_code': g['country_code'] ?? '+1',
              })
          .toList();
      final body = <String, dynamic>{
        'court_id': widget.locationId,
        'sub_court_id': widget.subCourtId ?? widget.courtId,
        'sport_id': widget.sportId,
        'start_time': widget.startTime,
        'end_time': widget.endTime,
        'duration_in_minutes': widget.durationMinutes,
        'cluth_enable': widget.clutchEnabled,
        'split': !_payForEveryone,
        'number_players_count': _players.length + _guests.length,
        'payment_method': _selectedMethodEnumNumber ?? 1,
        'use_wallet': _useWallet,
        if (widget.reservationTypeId != null)
          'reservation_type_id': widget.reservationTypeId,
        if (registeredGuests.isNotEmpty) 'guest_users': registeredGuests,
        if (externalGuests.isNotEmpty) 'external_guest_users': externalGuests,
        if (_appliedPackage != null)
          'punch_package_id': _appliedPackage!['id'],
        if (_selectedCardId != null) 'payment_method_id': _selectedCardId,
        if (_addons.any((a) => a.quantity > 0))
          'attributes': _addons
              .where((a) => a.quantity > 0)
              .map((a) => {'court_attribute_id': a.id, 'value': a.quantity})
              .toList(),
      };
      final res =
          await ApiService.post('v3/bookings/create', body, withAuth: true);
      if (!mounted) return;
      final resData = res['data'];
      final booking = (resData is Map ? resData['booking'] ?? resData : null) ?? res;
      final bookingId = (booking['id'] ?? res['id'])?.toString() ?? '-';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            bookingId: bookingId,
            locationName: widget.locationName,
            sportName: widget.sportName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _booking = false;
      });
    }
  }
  String _formatTime(String raw) {
    try {
      final timeParts = raw.split(' ')[1].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = timeParts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      return '$hour:$minute $period';
    } catch (_) {
      return raw;
    }
  }
  String _formatLastTimeToPay(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw.replaceAll(' ', 'T'));
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      int hour = dt.hour;
      final min = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      return '${months[dt.month - 1]} ${dt.day}, $hour:$min $period';
    } catch (_) {
      return raw;
    }
  }
  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 14),
                        _buildHowYoullPaySection(),
                        const SizedBox(height: 14),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 14),
                        _buildAddOnsSection(),
                        const SizedBox(height: 14),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 14),
                        _buildInstantSavingsSection(),
                        const SizedBox(height: 14),
                        _buildPaymentMethodSection(),
                        const SizedBox(height: 14),
                        _buildSummaryBreakdown(),
                        if (_lastTimeToPay.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildWarningNote(),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _buildErrorBox(),
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                _buildAuthorizeButton(),
              ],
            ),
    );
  }
  Widget _buildSummaryCard() {
    final titleParts = [
      widget.sportName,
      if (widget.courtName.isNotEmpty) widget.courtName,
      if (widget.reservationTypeName.isNotEmpty) widget.reservationTypeName,
    ];
    final courtDisplay = widget.courtName.isNotEmpty
        ? widget.courtName
        : widget.locationName;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C5534)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCourtIconBox(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleParts.join(' - '),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.locationName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Directions',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          _buildDashedLine(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Court',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  courtDisplay,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: _dateTimeCol('Date', _formatDateCard(widget.startTime)),
                  ),
                ),
                _verticalDash(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: _dateTimeCol('Time', _formatTime(widget.startTime)),
                  ),
                ),
                _verticalDash(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: _dateTimeCol('Duration', '${widget.durationMinutes} Min'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildCourtIconBox() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: CustomPaint(painter: _CourtIconPainter()),
    );
  }
  Widget _buildDashedLine() {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: _DashedLinePainter(),
        size: const Size(double.infinity, 1),
      ),
    );
  }
  Widget _verticalDash() {
    return SizedBox(
      width: 1,
      child: CustomPaint(
        painter: _VerticalDashedLinePainter(),
        size: const Size(1, double.infinity),
      ),
    );
  }
  Widget _dateTimeCol(String label, String value) {
    return Column(
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
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
  String _formatDateCard(String raw) {
    try {
      final parts = raw.split(' ').first.split('-');
      final dt = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month]}';
    } catch (_) {
      return raw;
    }
  }
  Widget _buildHowYoullPaySection() {
    final totalPlayers = _players.length + _guests.length + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How you\'ll pay',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Priced by membership, not split evenly.',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1C5534)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _payOption(
                label: 'Pay your part',
                description: 'You owe ${_fmt(_payYourPartPrice)} now.'
                    '${_holdAmount > 0 ? ' ${_fmt(_holdAmount)} hold placed for others.' : ''}',
                amount: _payYourPartPrice,
                badgeCount: 1,
                icon: Icons.credit_card_outlined,
                selected: !_payForEveryone,
                onTap: () => setState(() => _payForEveryone = false),
              ),
              const SizedBox(height: 10),
              _buildPlayersInPaySection(disabled: _payForEveryone),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1C5534)),
          ),
          child: _payOption(
            label: 'Pay for everyone',
            description: 'Pay for everyone. Your card will be charged in full.',
            amount: _payEveryonePrice,
            badgeCount: totalPlayers,
            icon: Icons.people_outline,
            selected: _payForEveryone,
            onTap: () => setState(() => _payForEveryone = true),
          ),
        ),
      ],
    );
  }
  Widget _payOption({
    required String label,
    required String description,
    required double amount,
    required int badgeCount,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF1C5534)
                        : const Color(0xFFCCCCCC),
                    width: selected ? 6 : 2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _payBadgeIcon('x$badgeCount', icon, selected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.textDark : AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textGrey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fmt(amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF1C5534)
                    : AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _payBadgeIcon(String badge, IconData icon, bool selected) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1C5534)
                : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : AppColors.textGrey,
          ),
        ),
        Positioned(
          top: -5,
          left: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF1C5534)
                  : const Color(0xFF999999),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildPlayersInPaySection({bool disabled = false}) {
    final perPlayerAmt = _payYourPartPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._players.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _playerCard(
              name: p.name,
              photoUrl: p.photoUrl,
              membershipLabel: p.membershipTier ?? '',
              amount: perPlayerAmt,
              guestFee: 0,
              onRemove: disabled ? null : () => setState(() => _players.removeAt(i)),
            ),
          );
        }),
        ..._guests.asMap().entries.map((e) {
          final i = e.key;
          final g = e.value;
          final guestFee =
              (g['fee'] as num?)?.toDouble() ?? perPlayerAmt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _playerCard(
              name: g['name']?.toString() ?? 'Guest',
              photoUrl: null,
              membershipLabel: 'Pay to play',
              amount: perPlayerAmt,
              guestFee: guestFee,
              onRemove: disabled ? null : () => setState(() => _guests.removeAt(i)),
            ),
          );
        }),
        const SizedBox(height: 8),
        if (!disabled)
          GestureDetector(
            onTap: _openAddPlayerSheet,
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: CustomPaint(
                painter: _DashedRectPainter(
                  color: const Color(0xFF1C5534),
                  radius: 10,
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Color(0xFF1C5534)),
                      SizedBox(width: 6),
                      Text(
                        'Add Player',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C5534),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Player list can\'t be changed after paying for everyone.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textGrey,
            ),
          ),
        ),
      ],
    );
  }
  Widget _playerCard({
    required String name,
    String? photoUrl,
    required String membershipLabel,
    required double amount,
    required double guestFee,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(
                    _initials(name),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (membershipLabel.isNotEmpty)
                  Text(
                    membershipLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textGrey),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              if (guestFee > 0)
                Text(
                  '(+${_fmt(guestFee)} Guest Fee)',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textGrey),
                ),
            ],
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Future<void> _openAddPlayerSheet() async {
    final result = await showModalBottomSheet<List<PlayerSearchModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PlayerSearchSheet(
        initialSelected: _players,
        maxPlayers: 10,
      ),
    );
    if (result is List<PlayerSearchModel> && mounted) {
      setState(() => _players = result);
    }
  }
  Widget _buildAddOnsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add-ons',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 14),
        if (_addons.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          )
        else
          SizedBox(
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _addons.length,
              separatorBuilder: (_, i) => const SizedBox(width: 10),
              itemBuilder: (_, i) =>
                  SizedBox(width: 120, child: _addonCard(_addons[i])),
            ),
          ),
      ],
    );
  }
  Widget _addonCard(CourtAddonModel addon) {
    final active = addon.quantity > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          height: 110,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F0F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.all(10),
          child: _addonImage(addon),
        ),
        const SizedBox(height: 6),
        Text(
          addon.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  if (addon.quantity > 0) setState(() => addon.quantity--);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.textGrey,
                    ),
                  ),
                ),
              ),
              Text(
                '${addon.quantity}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => addon.quantity++),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '+',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.textGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _addonImage(CourtAddonModel addon) {
    if (addon.imageUrl == null) return _addonPlaceholder();
    if (addon.imageUrl!.startsWith('assets/')) {
      return Image.asset(
        addon.imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => _addonPlaceholder(),
      );
    }
    return Image.network(
      addon.imageUrl!,
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) => _addonPlaceholder(),
    );
  }
  Widget _addonPlaceholder() {
    return const Icon(Icons.sports, color: AppColors.textGrey, size: 32);
  }
  Widget _buildInstantSavingsSection() {
    final hasPackage = _appliedPackage != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Instant Savings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _openPackagesSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Packages & Membership',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPackage
                            ? '${_appliedPackage!['name'] ?? 'Package'} applied  −${_fmt(_packageDiscount)}'
                            : 'Select a package to save more!',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasPackage
                              ? AppColors.primary
                              : AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textDark, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
  void _openPackagesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PackagesSheet(
        packages: _packages,
        appliedPackage: _appliedPackage,
        punchBalance: _punchBalance,
        punchCost: _punchCost,
        onApply: (pkg, discount) {
          setState(() {
            _appliedPackage = pkg;
            _packageDiscount = discount;
          });
          Navigator.pop(context);
        },
        onRemove: () {
          setState(() {
            _appliedPackage = null;
            _packageDiscount = 0;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
  Widget _buildPaymentMethodSection() {
    final card = _savedCards.isNotEmpty
        ? _savedCards.firstWhere(
            (c) => (c['id'] as num?)?.toInt() == _selectedCardId,
            orElse: () => _savedCards.first,
          )
        : null;
    final last4 = card?['last4']?.toString() ?? '';
    final brand = card?['brand']?.toString() ?? '';
    final hasCard = last4.isNotEmpty;
    final showCardRow = _allowedMethods.isEmpty ||
        _allowedMethods.any((m) {
          final n = (m['name']?.toString() ??
                  m['type']?.toString() ??
                  m['gateway']?.toString() ??
                  '')
              .toLowerCase();
          return n.contains('card') ||
              n.contains('credit') ||
              n.contains('stripe') ||
              n.isEmpty;
        });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 14),
        if (showCardRow)
        GestureDetector(
          onTap: _openCardSelectionSheet,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hasCard
                  ? AppColors.primary.withValues(alpha: 0.03)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasCard
                    ? const Color(0xFF1C5534)
                    : const Color(0xFFE0E0E0),
                width: hasCard ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                _cardBrandBox(brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasCard
                            ? '${brand.isEmpty ? 'Card' : _capitalize(brand)} ••••$last4'
                            : 'Add a card',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: hasCard
                              ? AppColors.textDark
                              : AppColors.textGrey,
                        ),
                      ),
                      Text(
                        hasCard ? 'Debit / Credit card' : 'Tap to select or add a card',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textGrey, size: 20),
              ],
            ),
          ),
        ),
        if (showCardRow) const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _useWallet = !_useWallet),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _useWallet
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _useWallet
                    ? AppColors.primary
                    : const Color(0xFFE0E0E0),
                width: _useWallet ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _useWallet
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color:
                        _useWallet ? AppColors.primary : AppColors.textGrey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Available: ${_fmt(_walletBalance)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _useWallet
                              ? AppColors.primary
                              : AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: _useWallet,
                    onChanged: (v) => setState(() => _useWallet = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE0E0E0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _cardBrandBox(String brand) {
    final b = brand.toLowerCase();
    if (b.contains('master') || b == 'mc') {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              child: CircleAvatar(
                  radius: 9, backgroundColor: Color(0xFFEB001B)),
            ),
            Positioned(
              right: 8,
              child: CircleAvatar(
                  radius: 9, backgroundColor: Color(0xFFF79E1B)),
            ),
          ],
        ),
      );
    }
    if (b.contains('visa')) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F71).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'VISA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1F71),
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.credit_card, size: 20, color: AppColors.textGrey),
    );
  }
  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  void _openCardSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CardSelectionSheet(
        savedCards: _savedCards,
        selectedCardId: _selectedCardId,
        onSelect: (id) {
          setState(() => _selectedCardId = id);
          Navigator.pop(ctx);
        },
        onAddCard: () {
          Navigator.pop(ctx);
          _openAddCardSheet();
        },
      ),
    );
  }
  void _openAddCardSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddCardSheet(
        locationId: widget.locationId,
        courtId: widget.courtId,
        userId: _currentUserId,
        onCardAdded: (int newCardId) {
          if (newCardId > 0 && mounted) {
            setState(() => _selectedCardId = newCardId);
          }
          ApiService.get(
            'v4/user-payment-methods/consumer/getList',
            query: {'per_page': '100'},
            withAuth: true,
          ).then((res) {
            final cards = (res['data'] as List?)
                    ?.whereType<Map<String, dynamic>>()
                    .toList() ??
                [];
            if (mounted && cards.isNotEmpty) {
              setState(() {
                _savedCards = cards;
                if (newCardId > 0) _selectedCardId = newCardId;
              });
            }
          }).catchError((_) {});
        },
      ),
    );
  }
  Widget _buildSummaryBreakdown() {
    final walletDed = _walletDeduction;
    final subtotal = _basePrice + _guestFeeTotal + _addonTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 14),
        _breakdownRow('My Booking Fee', _fmt(_basePrice)),
        const SizedBox(height: 8),
        _breakdownRow('Guest Fee', _fmt(_guestFeeTotal)),
        const SizedBox(height: 8),
        _breakdownRowInfo(
          'Hold (other player\'s share)',
          _fmt(_holdAmount),
          'This amount is held and released if others pay their share on time.',
        ),
        const SizedBox(height: 8),
        _breakdownRow('Add-ons', _fmt(_addonTotal)),
        const SizedBox(height: 8),
        _breakdownRow('Subtotal', _fmt(subtotal), bold: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DashedLinePainter(),
          ),
        ),
        _breakdownRow(
          'Package Applied',
          _packageDiscount > 0 ? '-${_fmt(_packageDiscount)}' : '-',
          valueColor: _packageDiscount > 0 ? AppColors.primary : AppColors.textGrey,
        ),
        const SizedBox(height: 8),
        _breakdownRow(
          'Wallet',
          walletDed > 0 ? '-${_fmt(walletDed)}' : '-',
          valueColor: walletDed > 0 ? AppColors.primary : AppColors.textGrey,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total to authorize',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Tax inc.',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ],
            ),
            Text(
              _fmt(_totalToAuthorize),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _breakdownRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: bold ? AppColors.textDark : AppColors.textGrey,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }
  Widget _breakdownRowInfo(String label, String value, String tooltip) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppColors.textGrey),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Hold Amount',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  content: Text(tooltip,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textGrey)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              child: const Icon(Icons.info_outline,
                  size: 14, color: AppColors.textGrey),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
  Widget _buildWarningNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: Color(0xFFF57F17)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastTimeToPay.isNotEmpty
                  ? 'You\'ll be charged the balance if others don\'t pay by ${_formatLastTimeToPay(_lastTimeToPay)}'
                  : 'You\'ll be charged the balance if others don\'t pay their share',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFF57F17),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAuthorizeButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _booking ? null : _book,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            disabledBackgroundColor: Colors.black45,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27)),
            elevation: 0,
          ),
          child: _booking
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  'Authorize ${_fmt(_totalToAuthorize)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
class _PackagesSheet extends StatefulWidget {
  final List<Map<String, dynamic>> packages;
  final Map<String, dynamic>? appliedPackage;
  final int punchBalance;
  final int punchCost;
  final void Function(Map<String, dynamic> pkg, double discount) onApply;
  final VoidCallback onRemove;
  const _PackagesSheet({
    required this.packages,
    required this.appliedPackage,
    required this.punchBalance,
    required this.punchCost,
    required this.onApply,
    required this.onRemove,
  });
  @override
  State<_PackagesSheet> createState() => _PackagesSheetState();
}
class _PackagesSheetState extends State<_PackagesSheet> {
  int _currentPage = 0;
  @override
  Widget build(BuildContext context) {
    final punchPackages = widget.packages
        .where((p) =>
            (p['type']?.toString() ?? p['package_type']?.toString() ?? '') !=
            'membership')
        .toList();
    final memberships = widget.packages
        .where((p) =>
            (p['type']?.toString() ?? p['package_type']?.toString() ?? '') ==
            'membership')
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text(
              'Packages & Membership',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          if (widget.punchCost > 0 || widget.punchBalance > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "You'll pay ${widget.punchCost} Punches",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Balance: ${widget.punchBalance}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (punchPackages.isNotEmpty) ...[
                  SizedBox(
                    height: 96,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollUpdateNotification) {
                          final page =
                              (n.metrics.pixels / (MediaQuery.of(context).size.width - 40))
                                  .round()
                                  .clamp(0, punchPackages.length - 1);
                          if (page != _currentPage) {
                            setState(() => _currentPage = page);
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: punchPackages.length,
                        itemBuilder: (_, i) {
                          final pkg = punchPackages[i];
                          final isApplied =
                              widget.appliedPackage?['id'] == pkg['id'];
                          return _PunchPackageCard(
                            package: pkg,
                            isApplied: isApplied,
                            availableWidth: MediaQuery.of(context).size.width - 40,
                            onApply: () {
                              final discount =
                                  (pkg['discount_amount'] as num?)?.toDouble() ??
                                      (pkg['discount'] as num?)?.toDouble() ??
                                      0.0;
                              widget.onApply(pkg, discount);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  if (punchPackages.length > 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(punchPackages.length, (i) {
                        return Container(
                          width: i == _currentPage ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? AppColors.primary
                                : const Color(0xFFCCCCCC),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 16),
                ],
                if (memberships.isNotEmpty)
                  ...memberships.map((m) => _MembershipCard(membership: m)),
                if (widget.packages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No packages or memberships available',
                        style:
                            TextStyle(color: AppColors.textGrey, fontSize: 14),
                      ),
                    ),
                  ),
                if (widget.appliedPackage != null) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onRemove,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Remove Applied Package',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _PunchPackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final bool isApplied;
  final double availableWidth;
  final VoidCallback onApply;
  const _PunchPackageCard({
    required this.package,
    required this.isApplied,
    required this.availableWidth,
    required this.onApply,
  });
  @override
  Widget build(BuildContext context) {
    final name = package['name']?.toString() ??
        package['package_name']?.toString() ??
        'Package';
    final punches = package['remaining_punches']?.toString() ??
        package['punches']?.toString() ??
        package['punch_cost']?.toString() ??
        '';
    final expiry = package['expires_at']?.toString() ??
        package['expiry_date']?.toString() ??
        package['valid_until']?.toString() ??
        '';
    final discountPct = (package['discount_percentage'] as num?)?.toInt() ??
        (package['discount_percent'] as num?)?.toInt() ??
        0;
    return Container(
      width: availableWidth,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApplied ? AppColors.primary : const Color(0xFFE0E0E0),
          width: isApplied ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  discountPct > 0 ? '$discountPct%' : '···',
                  style: TextStyle(
                    fontSize: discountPct > 0 ? 22 : 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  'OFF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (punches.isNotEmpty || expiry.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (punches.isNotEmpty) '$punches Punches',
                      if (expiry.isNotEmpty) expiry,
                    ].join(' , '),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGrey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isApplied ? null : onApply,
            child: Text(
              isApplied ? 'APPLIED' : 'APPLY',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isApplied
                    ? AppColors.textGrey
                    : AppColors.primary,
                decoration: isApplied
                    ? TextDecoration.none
                    : TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _MembershipCard extends StatelessWidget {
  final Map<String, dynamic> membership;
  const _MembershipCard({required this.membership});
  @override
  Widget build(BuildContext context) {
    final name = membership['name']?.toString() ?? 'Membership';
    final rawBenefits = membership['benefits'] ??
        membership['perks'] ??
        membership['features'];
    final List<String> benefits = rawBenefits is List
        ? rawBenefits.map((b) => b.toString()).toList()
        : membership['description']?.toString().isNotEmpty == true
            ? membership['description'].toString().split('\n')
            : <String>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D87A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                const Text('👑', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const Text(
                  'AUTO APPLIED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB8860B),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(),
            ),
          ),
          if (benefits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: benefits
                    .map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            b,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
class _CardSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> savedCards;
  final int? selectedCardId;
  final void Function(int id) onSelect;
  final VoidCallback onAddCard;
  const _CardSelectionSheet({
    required this.savedCards,
    required this.selectedCardId,
    required this.onSelect,
    required this.onAddCard,
  });
  @override
  State<_CardSelectionSheet> createState() => _CardSelectionSheetState();
}
class _CardSelectionSheetState extends State<_CardSelectionSheet> {
  late int? _selectedId;
  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedCardId;
  }
  Widget _brandLogo(String brand) {
    final b = brand.toLowerCase();
    if (b.contains('master') || b == 'mc') {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              child: CircleAvatar(radius: 10, backgroundColor: Color(0xFFEB001B)),
            ),
            Positioned(
              right: 8,
              child: CircleAvatar(radius: 10, backgroundColor: Color(0xFFF79E1B)),
            ),
          ],
        ),
      );
    }
    if (b.contains('visa')) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F71).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'VISA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1F71),
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.credit_card, size: 22, color: AppColors.textGrey),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Payment method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.savedCards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No saved cards',
                    style: TextStyle(color: AppColors.textGrey)),
              ),
            ),
          ...widget.savedCards.asMap().entries.map((e) {
            final i = e.key;
            final card = e.value;
            final id = (card['id'] as num?)?.toInt() ?? i;
            final last4 = card['last4']?.toString() ?? '****';
            final brand = card['brand']?.toString() ?? 'Card';
            final selected = _selectedId == id;
            final displayName = brand.isEmpty
                ? 'Card'
                : brand[0].toUpperCase() + brand.substring(1).toLowerCase();
            return GestureDetector(
              onTap: () {
                setState(() => _selectedId = id);
                widget.onSelect(id);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    _brandLogo(brand),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Card ending with $last4',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : const Color(0xFFCCCCCC),
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 13)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: widget.onAddCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Add Card',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _AddCardSheet extends StatefulWidget {
  final int locationId;
  final int courtId;
  final int? userId;
  final Function(int cardId)? onCardAdded;
  const _AddCardSheet({
    required this.locationId,
    required this.courtId,
    this.userId,
    this.onCardAdded,
  });
  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}
class _AddCardSheetState extends State<_AddCardSheet> {
  final _numberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _loadingSetup = true;
  bool _submitting = false;
  String? _setupError;
  String? _submitError;
  String? _publishableKey;
  String? _clientSecret;
  @override
  void initState() {
    super.initState();
    _initSetup();
  }
  Future<void> _initSetup() async {
    try {
      final res = await ApiService.post(
        'v3/payment-provider/consumer/create-setup-intent-flutter',
        {},
        withAuth: true,
      );
      final data = res['data'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _publishableKey = data['publishable_key']?.toString();
          _clientSecret = data['client_secret']?.toString();
          _loadingSetup = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _setupError = e.toString().replaceAll('Exception: ', '');
          _loadingSetup = false;
        });
      }
    }
  }
  Future<void> _submit() async {
    final digits = _numberCtrl.text.replaceAll(' ', '');
    final name = _nameCtrl.text.trim();
    final expiry = _expiryCtrl.text.trim();
    final cvv = _cvvCtrl.text.trim();
    if (digits.length < 13 || name.isEmpty ||
        expiry.length < 5 || cvv.length < 3) {
      setState(() => _submitError = 'Please fill in all card details.');
      return;
    }
    if (_publishableKey == null || _clientSecret == null) {
      setState(() => _submitError = 'Payment setup not ready. Please try again.');
      return;
    }
    setState(() { _submitting = true; _submitError = null; });
    try {
      final parts = expiry.split('/');
      final expMonth = parts[0].trim();
      final expYear = parts.length > 1 ? '20${parts[1].trim()}' : '';
      final pmRes = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_methods'),
        headers: {
          'Authorization': 'Bearer $_publishableKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'type': 'card',
          'card[number]': digits,
          'card[exp_month]': expMonth,
          'card[exp_year]': expYear,
          'card[cvc]': cvv,
          'billing_details[name]': name,
        },
      );
      final pmData = jsonDecode(pmRes.body) as Map<String, dynamic>;
      if (pmRes.statusCode != 200) {
        throw Exception(
            pmData['error']?['message'] ?? 'Failed to create payment method');
      }
      final pmId = pmData['id'] as String;
      final siId = _clientSecret!.split('_secret_').first;
      await http.post(
        Uri.parse('https://api.stripe.com/v1/setup_intents/$siId/confirm'),
        headers: {
          'Authorization': 'Bearer $_publishableKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_secret': _clientSecret!,
          'payment_method': pmId,
        },
      );
      final linkRes = await ApiService.post(
        'v3/payment-provider/consumer/link-payment-method',
        {
          'payment_method_id': pmId,
          'is_default': true,
        },
        withAuth: true,
      );
      final linkData = linkRes['data'];
      final newCardId = (linkData is Map ? (linkData['id'] as num?) : null)?.toInt() ??
          (linkRes['id'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      widget.onCardAdded?.call(newCardId);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }
  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Add New Card',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 20),
          if (_loadingSetup)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else if (_setupError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_setupError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ),
            )
          else ...[
            _field(
              controller: _numberCtrl,
              label: 'Card Number',
              hint: '0000 0000 0000 0000',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                _CardNumberFormatter(),
              ],
            ),
            const SizedBox(height: 14),
            _field(
              controller: _nameCtrl,
              label: 'Cardholder Name',
              hint: 'Name on card',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _expiryCtrl,
                    label: 'Expiry',
                    hint: 'MM/YY',
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ExpiryFormatter()],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _cvvCtrl,
                    label: 'CVV',
                    hint: '•••',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
              ],
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_submitError!,
                    style:
                        TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Add Card',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textGrey, fontSize: 14),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits =
        newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited =
        digits.length > 4 ? digits.substring(0, 4) : digits;
    final isDeleting = newValue.text.length < oldValue.text.length;
    String formatted;
    if (limited.length > 2) {
      formatted = '${limited.substring(0, 2)}/${limited.substring(2)}';
    } else if (limited.length == 2 && !isDeleting) {
      formatted = '$limited/';
    } else {
      formatted = limited;
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
class _CourtIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final p = size.width * 0.18;
    final rect = Rect.fromLTRB(p, p, size.width - p, size.height - p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
    canvas.drawLine(
      Offset(size.width / 2, rect.top),
      Offset(size.width / 2, rect.bottom),
      paint,
    );
    final bandY = rect.height * 0.28;
    canvas.drawLine(
      Offset(rect.left, rect.top + bandY),
      Offset(rect.right, rect.top + bandY),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom - bandY),
      Offset(rect.right, rect.bottom - bandY),
      paint,
    );
  }
  @override
  bool shouldRepaint(_CourtIconPainter oldDelegate) => false;
}
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 1;
    double x = 0;
    const dashW = 6.0;
    const gap = 4.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashW, 0), paint);
      x += dashW + gap;
    }
  }
  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}
class _VerticalDashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 1;
    double y = 0;
    const dashH = 5.0;
    const gap = 4.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashH), paint);
      y += dashH + gap;
    }
  }
  @override
  bool shouldRepaint(_VerticalDashedLinePainter oldDelegate) => false;
}
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedRectPainter({required this.color, this.radius = 10});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
        Radius.circular(radius),
      ));
    canvas.drawPath(_dashPath(path), paint);
  }
  Path _dashPath(Path source) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = (dist + 6.0).clamp(0.0, metric.length);
        dest.addPath(metric.extractPath(dist, end), Offset.zero);
        dist += 10.0;
      }
    }
    return dest;
  }
  @override
  bool shouldRepaint(_DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}
