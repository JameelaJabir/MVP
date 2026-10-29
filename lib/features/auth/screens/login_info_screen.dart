import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_colors.dart';
import '../../../core/widgets/epic_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/country_model.dart';
import '../../../data/models/club_model.dart';
import '../../../data/services/api_service.dart';
import 'terms_screen.dart';
class LoginInfoScreen extends StatefulWidget {
  const LoginInfoScreen({super.key});
  @override
  State<LoginInfoScreen> createState() => _LoginInfoScreenState();
}
class _LoginInfoScreenState extends State<LoginInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _zipController = TextEditingController();
  String _gender = 'MALE';
  CountryModel? _selectedCountry;
  ClubModel? _selectedClub;
  bool _termsAccepted = false;
  bool _loading = false;
  bool _hasTerms = false;
  String _termsContent = '';
  List<CountryModel> _countries = [];
  List<ClubModel> _clubs = [];
  bool _loadingClubs = true;
  @override
  void initState() {
    super.initState();
    _fetchCountries();
    _fetchClubs();
  }
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    super.dispose();
  }
  Future<void> _fetchCountries() async {
    try {
      final res = await ApiService.get(
        'public/address/country/getAllCountries',
        query: {'page': '1', 'limit': '33'},
      );
      final list = (res['data'] as List?) ?? (res['countries'] as List?) ?? [];
      setState(() {
        _countries = list.map((e) => CountryModel.fromJson(e)).toList();
        if (_countries.isNotEmpty) _selectedCountry = _countries.first;
      });
    } catch (_) {}
  }
  Future<void> _fetchClubs() async {
    try {
      final res = await ApiService.get(
        'v3/locations/consumer/get-all',
        query: {'page': '1', 'per_page': '33'},
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? (res['locations'] as List?) ?? [];
      setState(() {
        _clubs = list.map((e) => ClubModel.fromJson(e)).toList();
        _loadingClubs = false;
      });
    } catch (_) {
      setState(() => _loadingClubs = false);
    }
  }
  Future<void> _onClubChanged(ClubModel? club) async {
    setState(() {
      _selectedClub = club;
      _hasTerms = false;
      _termsAccepted = false;
    });
    if (club == null) return;
    try {
      final res = await ApiService.get(
        'public/tcs',
        query: {'purpose': 'login', 'location_id': club.id.toString()},
      );
      final content = res['data']?['content']?.toString() ??
          res['content']?.toString() ??
          '';
      setState(() {
        _termsContent = content;
        _hasTerms = content.isNotEmpty;
      });
    } catch (_) {}
  }
  Future<void> _openTerms() async {
    if (_selectedClub == null) return;
    try {
      if (!mounted) return;
      final sig = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => TermsScreen(content: _termsContent),
        ),
      );
      if (sig != null) {
        setState(() => _termsAccepted = true);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClub == null) {
      _showError('Please select a preferred club');
      return;
    }
    final formData = <String, dynamic>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'gender': _gender,
      'zip_code': _zipController.text.trim(),
      'location_id': _selectedClub!.id,
      'otp_provider': 'WHATSAPP',
      'update': 'PHONE',
      'phone': _phoneController.text.trim(),
      'country': _selectedCountry?.phoneCode ?? '',
      'country_id': _selectedCountry?.id ?? 1,
    };
    if (_hasTerms) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TermsScreen(
            content: _termsContent,
            formData: formData,
          ),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.post(
        'v2/profile/setup/send-otp',
        formData,
        withAuth: true,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Center(child: EpicLogo()),
                const SizedBox(height: 32),
                const Text(
                  'Hello!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please complete your Profile and fill the missing details to continue using the app.',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                const SizedBox(height: 28),
                _label('First Name'),
                _inputField(
                  controller: _firstNameController,
                  hint: 'First Name',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _label('Last Name'),
                _inputField(
                  controller: _lastNameController,
                  hint: 'Last Name',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _label('Mobile number'),
                _phoneField(),
                const SizedBox(height: 14),
                _label('Gender'),
                _genderToggle(),
                const SizedBox(height: 14),
                _label('Zip Code'),
                _inputField(
                  controller: _zipController,
                  hint: 'Zip Code',
                  icon: Icons.tag,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _label('Preferred Club'),
                _clubDropdown(),
                if (_hasTerms) ...[
                  const SizedBox(height: 20),
                  _label('Terms of Use'),
                  _termsCheckbox(),
                ],
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: _submit,
                  isLoading: _loading,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textGrey,
        ),
      ),
    );
  }
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDecoration(hint, Icon(icon, color: AppColors.textGrey, size: 20)),
    );
  }
  Widget _phoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Required' : null,
      decoration: _inputDecoration(
        'Phone number',
        GestureDetector(
          onTap: _openCountryPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_outlined, color: AppColors.textGrey, size: 20),
                const SizedBox(width: 6),
                Text(
                  _selectedCountry != null
                      ? '${_selectedCountry!.flag} (${_selectedCountry!.phoneCode})'
                      : '(+1)',
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.textGrey, size: 18),
                Container(
                  height: 22,
                  width: 1,
                  color: AppColors.inputBorder,
                  margin: const EdgeInsets.only(left: 6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  InputDecoration _inputDecoration(String hint, Widget prefix) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
      prefixIcon: prefix,
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
  Widget _genderToggle() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: ['FEMALE', 'MALE'].map((g) {
          final selected = _gender == g;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _gender = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    g[0] + g.substring(1).toLowerCase(),
                    style: TextStyle(
                      color: selected ? AppColors.white : AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  Widget _clubDropdown() {
    if (_loadingClubs) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ClubModel>(
          value: _selectedClub,
          isExpanded: true,
          hint: const Row(
            children: [
              Icon(Icons.location_on_outlined, color: AppColors.textGrey, size: 20),
              SizedBox(width: 8),
              Text('Select club', style: TextStyle(color: AppColors.textGrey)),
            ],
          ),
          items: _clubs
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: AppColors.textGrey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(c.name,
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: _onClubChanged,
        ),
      ),
    );
  }
  Widget _termsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _termsAccepted,
          onChanged: (val) => setState(() => _termsAccepted = val ?? false),
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              children: [
                const TextSpan(text: 'I have read and signed the '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: _openTerms,
                    child: const Text(
                      'Terms and Conditions',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const TextSpan(
                    text: ' for the usage of the Epic mobile application.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
  void _openCountryPicker() {
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
  final _searchController = TextEditingController();
  List<CountryModel> _filtered = [];
  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
    _searchController.addListener(() {
      final q = _searchController.text.toLowerCase();
      setState(() {
        _filtered = widget.countries
            .where((c) => c.name.toLowerCase().contains(q))
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
      initialChildSize: 0.6,
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
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search country',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
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
                  final c = _filtered[i];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(c.name),
                    trailing: Text(
                      c.phoneCode,
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                    selected: widget.selected?.id == c.id,
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
