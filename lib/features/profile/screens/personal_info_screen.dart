import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/club_model.dart';
import '../../../data/models/country_model.dart';
import '../../../data/models/sport_model.dart';
import '../../../data/services/api_service.dart';
import '../../auth/screens/otp_screen.dart';
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});
  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}
class _PersonalInfoScreenState extends State<PersonalInfoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Personal Info',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _tabController,
              builder: (_, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      _tabPill(0, 'Personal Info'),
                      _tabPill(1, 'Preferences'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _PersonalInfoTab(),
                  _PreferencesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _tabPill(int index, String label) {
    final selected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textGrey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _PersonalInfoTab extends StatefulWidget {
  const _PersonalInfoTab();
  @override
  State<_PersonalInfoTab> createState() => _PersonalInfoTabState();
}
class _PersonalInfoTabState extends State<_PersonalInfoTab> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  String _originalPhone = '';
  int? _locationId;
  String _gender = 'MALE';
  CountryModel? _selectedCountry;
  List<CountryModel> _countries = [];
  String? _profileImageUrl;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }
  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.get('mob_app/auth/autoLogin', withAuth: true),
        ApiService.get(
          'public/address/country/getAllCountries',
          query: {'page': '1', 'limit': '200'},
        ),
      ]);
      if (!mounted) return;
      final loginRes = results[0];
      final userData = loginRes['data']?['user'] as Map<String, dynamic>? ??
          loginRes['user'] as Map<String, dynamic>? ??
          loginRes['data'] as Map<String, dynamic>? ??
          {};
      final countryList = (results[1]['data'] as List?) ??
          (results[1]['countries'] as List?) ?? [];
      final countries = countryList
          .whereType<Map<String, dynamic>>()
          .map(CountryModel.fromJson)
          .toList();
      final fullName = userData['name']?.toString() ?? '';
      final parts = fullName.trim().split(RegExp(r'\s+'));
      final firstName = userData['first_name']?.toString() ??
          (parts.isNotEmpty ? parts.first : '');
      final lastName = userData['last_name']?.toString() ??
          (parts.length > 1 ? parts.sublist(1).join(' ') : '');
      final userEmailRaw = userData['user_email'];
      final email = (userEmailRaw is Map
              ? userEmailRaw['email']?.toString()
              : userEmailRaw?.toString()) ??
          userData['email']?.toString() ?? '';
      final userPhoneRaw = userData['user_phone'];
      final String phone;
      final int? phoneCountryId;
      final String phoneCountryCode;
      if (userPhoneRaw is Map) {
        phone = userPhoneRaw['phone']?.toString() ??
            userPhoneRaw['number']?.toString() ?? '';
        phoneCountryId = (userPhoneRaw['country_id'] as num?)?.toInt();
        phoneCountryCode = userPhoneRaw['country']?.toString() ??
            userPhoneRaw['country_code']?.toString() ?? '';
      } else {
        phone = userPhoneRaw?.toString() ??
            userData['phone']?.toString() ?? '';
        phoneCountryId = (userData['country_id'] as num?)?.toInt();
        phoneCountryCode = userData['country']?.toString() ??
            userData['country_code']?.toString() ?? '';
      }
      final locationId = (userData['court_id'] as num?)?.toInt();
      final gender = userData['gender']?.toString() ?? 'MALE';
      final zip = userData['zip_code']?.toString() ?? '';
      final photo = userData['profile_image_url']?.toString() ??
          userData['profile_picture']?.toString() ??
          userData['photo_url']?.toString();
      CountryModel? selCountry;
      if (phoneCountryId != null) {
        try {
          selCountry = countries.firstWhere((c) => c.id == phoneCountryId);
        } catch (_) {}
      }
      if (selCountry == null && phoneCountryCode.isNotEmpty) {
        try {
          selCountry = countries.firstWhere(
            (c) => c.phoneCode == phoneCountryCode ||
                c.phoneCode == '+$phoneCountryCode',
          );
        } catch (_) {}
      }
      selCountry ??= countries.isNotEmpty ? countries.first : null;
      setState(() {
        _originalPhone = phone;
        _locationId = locationId;
        _countries = countries;
        _selectedCountry = selCountry;
        _firstNameCtrl.text = firstName;
        _lastNameCtrl.text = lastName;
        _phoneCtrl.text = phone;
        _emailCtrl.text = email;
        _zipCtrl.text = zip;
        _gender = gender.isEmpty ? 'MALE' : gender.toUpperCase();
        _profileImageUrl = photo;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final newPhone = _phoneCtrl.text.trim();
      final phoneChanged = newPhone.isNotEmpty && newPhone != _originalPhone;
      final body = <String, dynamic>{
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'gender': _gender,
        'zip_code': _zipCtrl.text.trim(),
        if (_locationId != null) 'location_id': _locationId,
      };
      if (phoneChanged) {
        body['otp_provider'] = 'WHATSAPP';
        body['update'] = 'PHONE';
        body['phone'] = newPhone;
        body['country'] = _selectedCountry?.phoneCode ?? '';
        body['country_id'] = _selectedCountry?.id ?? 1;
      }
      final res = await ApiService.post(
        'v2/profile/setup/send-otp',
        body,
        withAuth: true,
      );
      if (!mounted) return;
      final otpRequired = res['data']?['otp_required'] == true ||
          res['otp_required'] == true;
      if (phoneChanged && otpRequired) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              email: '',
              phone: newPhone,
              country: _selectedCountry?.phoneCode ?? '',
              countryId: _selectedCountry?.id ?? 1,
              isPhoneVerification: true,
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteAccount();
            },
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD32F2F)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    try {
      await ApiService.delete('v3/consumer/deleteAccount', withAuth: true);
    } catch (_) {}
    await StorageService.clearToken();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }
  void _openCountryPicker() {
    if (_countries.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CountryPickerSheet(
        countries: _countries,
        selected: _selectedCountry,
        onSelect: (c) {
          setState(() => _selectedCountry = c);
          Navigator.pop(context);
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhoto(),
          const SizedBox(height: 24),
          _label('First Name'),
          _inputField(
            controller: _firstNameCtrl,
            hint: 'First Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _label('Last Name'),
          _inputField(
            controller: _lastNameCtrl,
            hint: 'Last Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _label('Mobile number'),
          _phoneField(),
          const SizedBox(height: 14),
          _label('Email'),
          _inputField(
            controller: _emailCtrl,
            hint: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
          ),
          const SizedBox(height: 14),
          _label('Gender'),
          _genderSelector(),
          const SizedBox(height: 14),
          _label('Zip Code'),
          _inputField(
            controller: _zipCtrl,
            hint: 'Zip Code',
            icon: Icons.tag,
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Save',
            onPressed: _saving ? null : _save,
            isLoading: _saving,
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: _deleting ? null : _confirmDelete,
              child: Text(
                _deleting ? 'Deleting...' : 'Delete Account',
                style: TextStyle(
                  color: _deleting
                      ? AppColors.textGrey
                      : const Color(0xFFD32F2F),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPhoto() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 82,
            height: 82,
            child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                ? Image.network(
                    _profileImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _photoFallback(),
                  )
                : _photoFallback(),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Photo upload coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xF5F5F5F5)),
              ),
              child: const Icon(Icons.camera_alt_outlined,
                  size: 15, color: AppColors.textDark),
            ),
          ),
        ),
      ],
    );
  }
  Widget _photoFallback() {
    return Container(
      color: const Color(0xFFD0E8D8),
      child: const Center(
        child: Icon(Icons.person, size: 40, color: AppColors.primary),
      ),
    );
  }
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey)),
      );
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      readOnly: readOnly,
      decoration: _decoration(
          hint, Icon(icon, color: AppColors.textGrey, size: 20)),
    );
  }
  Widget _phoneField() {
    return TextField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _decoration(
        'Phone number',
        GestureDetector(
          onTap: _openCountryPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_outlined,
                    color: AppColors.textGrey, size: 18),
                const SizedBox(width: 4),
                Text(
                  _selectedCountry != null
                      ? '${_selectedCountry!.flag} (${_selectedCountry!.phoneCode})'
                      : '(+1)',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textDark),
                ),
                const Icon(Icons.arrow_drop_down,
                    color: AppColors.textGrey, size: 18),
                Container(
                  height: 20,
                  width: 1,
                  color: AppColors.inputBorder,
                  margin: const EdgeInsets.only(left: 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  InputDecoration _decoration(String hint, Widget prefix) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
  Widget _genderSelector() {
    return Row(
      children: [
        _genderPill('FEMALE', 'Female'),
        const SizedBox(width: 10),
        _genderPill('MALE', 'Male'),
      ],
    );
  }
  Widget _genderPill(String value, String label) {
    final sel = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: sel ? AppColors.primary : AppColors.inputBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
class _PreferencesTab extends StatefulWidget {
  const _PreferencesTab();
  @override
  State<_PreferencesTab> createState() => _PreferencesTabState();
}
class _PreferencesTabState extends State<_PreferencesTab> {
  bool _loading = true;
  bool _saving = false;
  List<ClubModel> _clubs = [];
  ClubModel? _selectedClub;
  List<SportModel> _sports = [];
  final Set<int> _selectedSportIds = {};
  int? _playStyleId;
  final Set<String> _selectedDays = {};
  String? _fromTime;
  String? _toTime;
  int? _handId;
  int? _courtSideId;
  static const _playStyleMap = {
    1: 'Strategist',
    2: 'Attacker',
    3: 'Defender',
    4: 'Counter-Puncher',
    5: 'Precision Player',
    6: 'All-Rounder',
    7: 'Team Player',
  };
  static const _handMap = {
    1: 'Right Hand',
    2: 'Left Hand',
    3: 'Both Hands',
  };
  static const _courtSideMap = {
    1: 'Right Side Only',
    2: 'Left Side Only',
    3: 'Both Sides',
  };
  static const _allDays = [
    'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'
  ];
  static const _dayNameToId = {
    'MON': 1, 'TUE': 2, 'WED': 3, 'THU': 4, 'FRI': 5, 'SAT': 6, 'SUN': 7,
  };
  static const _dayIdToName = {
    1: 'MON', 2: 'TUE', 3: 'WED', 4: 'THU', 5: 'FRI', 6: 'SAT', 7: 'SUN',
  };
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.get('v2/profile', withAuth: true),
        ApiService.get(
          'v3/locations/consumer/get-all',
          query: {'page': '1', 'per_page': '50'},
          withAuth: true,
        ),
      ]);
      if (!mounted) return;
      final profileData =
          results[0]['data'] as Map<String, dynamic>? ?? {};
      final header =
          profileData['profile_header'] as Map<String, dynamic>? ?? {};
      final prefs =
          profileData['preferences'] as Map<String, dynamic>? ?? {};
      final courtId = (header['court_id'] as num?)?.toInt();
      final clubsList = (results[1]['data'] as List?) ?? [];
      final clubs = clubsList
          .whereType<Map<String, dynamic>>()
          .map(ClubModel.fromJson)
          .toList();
      ClubModel? selClub;
      if (courtId != null) {
        try {
          selClub = clubs.firstWhere((c) => c.id == courtId);
        } catch (_) {}
      }
      if (selClub == null) {
        final locationName = header['location']?.toString() ?? '';
        if (locationName.isNotEmpty) {
          try {
            selClub = clubs.firstWhere(
              (c) => c.name.toLowerCase() == locationName.toLowerCase(),
            );
          } catch (_) {}
        }
      }
      final days = <String>{};
      final daysRaw = prefs['days'];
      if (daysRaw is List) {
        for (final d in daysRaw) {
          final id = d is num ? d.toInt() : int.tryParse(d.toString());
          if (id != null) {
            if (id == 8) {
              days.addAll(_allDays);
            } else {
              final name = _dayIdToName[id];
              if (name != null) days.add(name);
            }
          } else {
            final s = d.toString().toUpperCase();
            if (_allDays.contains(s)) days.add(s);
          }
        }
      } else if (daysRaw is String && daysRaw.isNotEmpty) {
        days.addAll(
            daysRaw.split(',').map((d) => d.trim().toUpperCase()).where(_allDays.contains));
      }
      final sportIds = <int>{};
      for (final s in (prefs['sports'] as List? ?? [])) {
        if (s is Map) {
          final id = (s['id'] as num?)?.toInt();
          if (id != null) sportIds.add(id);
        }
      }
      setState(() {
        _clubs = clubs;
        _selectedClub = selClub;
        _playStyleId = _resolveId(prefs['play_style'], _playStyleMap);
        _handId = _resolveId(prefs['hand'], _handMap);
        _courtSideId = _resolveId(prefs['court_side'], _courtSideMap);
        _fromTime = prefs['from_time']?.toString();
        _toTime = prefs['to_time']?.toString();
        _selectedDays.addAll(days);
        _selectedSportIds.addAll(sportIds);
        _loading = false;
      });
      if (selClub != null) await _loadSports(selClub.id);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _loadSports(int locationId) async {
    try {
      final res = await ApiService.get(
        'v3/sports/consumer/getList',
        query: {
          'page': '1',
          'per_page': '20',
          'location_id': locationId.toString()
        },
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _sports = list
            .whereType<Map<String, dynamic>>()
            .map(SportModel.fromJson)
            .toList();
      });
    } catch (_) {}
  }
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.post(
        'v2/profile/preferences',
        {
          'sports': _selectedSportIds.toList(),
          if (_playStyleId != null) 'play_style': _playStyleId,
          'days': _selectedDays
              .map((d) => _dayNameToId[d])
              .whereType<int>()
              .toList(),
          if (_fromTime != null) 'from_time': _fromTime,
          if (_toTime != null) 'to_time': _toTime,
          if (_handId != null) 'hand': _handId,
          if (_courtSideId != null) 'court_side': _courtSideId,
          if (_selectedClub != null) 'location_id': _selectedClub!.id,
        },
        withAuth: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  void _openClubPicker() {
    _showPicker<ClubModel>(
      title: 'Select Club',
      items: _clubs,
      labelOf: (c) => c.name,
      isSelectedFn: (c) => c.id == _selectedClub?.id,
      onSelect: (c) async {
        setState(() {
          _selectedClub = c;
          _sports = [];
          _selectedSportIds.clear();
        });
        await _loadSports(c.id);
      },
    );
  }
  void _openPlayStylePicker() {
    _showPicker<MapEntry<int, String>>(
      title: 'Select Play Style',
      items: _playStyleMap.entries.toList(),
      labelOf: (e) => e.value,
      isSelectedFn: (e) => e.key == _playStyleId,
      onSelect: (e) => setState(() => _playStyleId = e.key),
    );
  }
  void _openFromTimePicker() {
    final times = _timesMap();
    _showPicker<String>(
      title: 'From',
      items: times.keys.toList(),
      labelOf: (k) => times[k]!,
      isSelectedFn: (k) => k == _fromTime,
      onSelect: (k) => setState(() => _fromTime = k),
    );
  }
  void _openToTimePicker() {
    final times = _timesMap();
    _showPicker<String>(
      title: 'To',
      items: times.keys.toList(),
      labelOf: (k) => times[k]!,
      isSelectedFn: (k) => k == _toTime,
      onSelect: (k) => setState(() => _toTime = k),
    );
  }
  void _openHandPicker() {
    _showPicker<MapEntry<int, String>>(
      title: 'Select Hand',
      items: _handMap.entries.toList(),
      labelOf: (e) => e.value,
      isSelectedFn: (e) => e.key == _handId,
      onSelect: (e) => setState(() => _handId = e.key),
    );
  }
  void _openSidePicker() {
    _showPicker<MapEntry<int, String>>(
      title: 'Select Court Side',
      items: _courtSideMap.entries.toList(),
      labelOf: (e) => e.value,
      isSelectedFn: (e) => e.key == _courtSideId,
      onSelect: (e) => setState(() => _courtSideId = e.key),
    );
  }
  void _showPicker<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelOf,
    required bool Function(T) isSelectedFn,
    required void Function(T) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PickerSheet<T>(
        title: title,
        items: items,
        labelOf: labelOf,
        isSelectedFn: isSelectedFn,
        onSelect: (item) {
          Navigator.pop(context);
          onSelect(item);
        },
      ),
    );
  }
  Map<String, String> _timesMap() {
    final map = <String, String>{};
    for (var h = 5; h <= 23; h++) {
      for (var m = 0; m < 60; m += 30) {
        final period = h < 12 ? 'AM' : 'PM';
        final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        final key =
            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
        final display =
            '$displayH:${m.toString().padLeft(2, '0')} $period';
        map[key] = display;
      }
    }
    return map;
  }
  String? _displayTime(String? t) {
    if (t == null || t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length < 2) return t;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h < 12 ? 'AM' : 'PM';
    final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$dh:${m.toString().padLeft(2, '0')} $period';
  }
  static int? _resolveId(dynamic raw, Map<int, String> map) {
    if (raw == null) return null;
    if (raw is int && map.containsKey(raw)) return raw;
    if (raw is num) {
      final i = raw.toInt();
      return map.containsKey(i) ? i : null;
    }
    final lower = raw.toString().toLowerCase().trim();
    for (final e in map.entries) {
      if (e.value.toLowerCase() == lower) return e.key;
      if (e.value.toLowerCase().split(' ').first == lower.split(' ').first) {
        return e.key;
      }
    }
    return null;
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Club'),
          _dropdownTile(
            value: _selectedClub?.name,
            hint: 'Select Club',
            onTap: _openClubPicker,
          ),
          const SizedBox(height: 16),
          _label('Sports'),
          _sportsPills(),
          const SizedBox(height: 16),
          _label('Play Style'),
          _dropdownTile(
            value: _playStyleId != null ? _playStyleMap[_playStyleId] : null,
            hint: 'Select Play Style',
            onTap: _openPlayStylePicker,
          ),
          const SizedBox(height: 16),
          _label('Days'),
          _daysPills(),
          const SizedBox(height: 16),
          _label('Times'),
          Row(
            children: [
              Expanded(
                child: _dropdownTile(
                  value: _displayTime(_fromTime),
                  hint: 'From',
                  onTap: _openFromTimePicker,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdownTile(
                  value: _displayTime(_toTime),
                  hint: 'To',
                  onTap: _openToTimePicker,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Hand'),
          _dropdownTile(
            value: _handId != null ? _handMap[_handId] : null,
            hint: 'Select Hand',
            onTap: _openHandPicker,
          ),
          const SizedBox(height: 16),
          _label('Court side'),
          _dropdownTile(
            value: _courtSideId != null ? _courtSideMap[_courtSideId] : null,
            hint: 'Select Court Side',
            onTap: _openSidePicker,
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Save',
            onPressed: _saving ? null : _save,
            isLoading: _saving,
          ),
        ],
      ),
    );
  }
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey)),
      );
  Widget _dropdownTile({
    required String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null
                      ? AppColors.textDark
                      : AppColors.textGrey,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                color: AppColors.textGrey, size: 20),
          ],
        ),
      ),
    );
  }
  Widget _sportsPills() {
    if (_sports.isEmpty) {
      return Text(
        _selectedClub == null
            ? 'Select a club to load sports'
            : 'No sports available',
        style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _sports.map((s) {
          final sel = _selectedSportIds.contains(s.id);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                if (sel) {
                  _selectedSportIds.remove(s.id);
                } else {
                  _selectedSportIds.add(s.id);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: sel ? AppColors.primary : AppColors.inputBorder,
                  ),
                ),
                child: Text(
                  s.name,
                  style: TextStyle(
                    color: sel ? Colors.white : AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  Widget _daysPills() {
    final allSelected = _allDays.every(_selectedDays.contains);
    const dayOptions = [
      'Everyday', 'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: dayOptions.map((day) {
        final isEveryday = day == 'Everyday';
        final sel = isEveryday ? allSelected : _selectedDays.contains(day);
        return GestureDetector(
          onTap: () => setState(() {
            if (isEveryday) {
              if (allSelected) {
                _selectedDays.clear();
              } else {
                _selectedDays.addAll(_allDays);
              }
            } else {
              if (sel) {
                _selectedDays.remove(day);
              } else {
                _selectedDays.add(day);
              }
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: sel ? AppColors.primary : AppColors.inputBorder,
              ),
            ),
            child: Text(
              day,
              style: TextStyle(
                color: sel ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final bool Function(T) isSelectedFn;
  final ValueChanged<T> onSelect;
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.isSelectedFn,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ),
          ),
          const Divider(
              height: 1, thickness: 1, color: Color(0xFFF0EDE8)),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFF0EDE8),
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (_, i) {
                final item = items[i];
                final sel = isSelectedFn(item);
                return ListTile(
                  title: Text(
                    labelOf(item),
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          sel ? AppColors.primary : AppColors.textDark,
                      fontWeight:
                          sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: sel
                      ? const Icon(Icons.check,
                          color: AppColors.primary, size: 18)
                      : null,
                  onTap: () => onSelect(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class _CountryPickerSheet extends StatefulWidget {
  final List<CountryModel> countries;
  final CountryModel? selected;
  final ValueChanged<CountryModel> onSelect;
  const _CountryPickerSheet({
    required this.countries,
    required this.selected,
    required this.onSelect,
  });
  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}
class _CountryPickerSheetState extends State<_CountryPickerSheet> {
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
            .where((c) => c.name.toLowerCase().contains(q) ||
                c.phoneCode.contains(q))
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
                  borderSide:
                      const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.inputBorder),
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
                    leading: Text(c.flag,
                        style: const TextStyle(fontSize: 22)),
                    title: Text(c.name),
                    trailing: Text(c.phoneCode,
                        style: const TextStyle(
                            color: AppColors.textGrey)),
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
