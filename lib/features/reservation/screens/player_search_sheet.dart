import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../data/models/player_search_model.dart';
import '../../../data/services/api_service.dart';
class PlayerSearchSheet extends StatefulWidget {
  final List<PlayerSearchModel> initialSelected;
  final int maxPlayers;
  const PlayerSearchSheet({
    super.key,
    required this.initialSelected,
    required this.maxPlayers,
  });
  @override
  State<PlayerSearchSheet> createState() => _PlayerSearchSheetState();
}
class _PlayerSearchSheetState extends State<PlayerSearchSheet> {
  final _searchController = TextEditingController();
  List<PlayerSearchModel> _selected = [];
  List<PlayerSearchModel> _favourites = [];
  List<PlayerSearchModel> _searchResults = [];
  List<PlayerSearchModel> _defaultPlayers = [];
  PlayerSearchModel? _currentUser;
  bool _loadingFavs = true;
  bool _loadingDefault = true;
  bool _searching = false;
  bool get _isSearching => _searchController.text.trim().isNotEmpty;
  @override
  void initState() {
    super.initState();
    _selected = [...widget.initialSelected];
    _fetchCurrentUser();
    _fetchFavourites();
    _fetchDefaultPlayers();
    _searchController.addListener(_onQueryChanged);
  }
  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }
  void _onQueryChanged() {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
    } else {
      _searchPlayers(q);
    }
  }
  Future<void> _fetchCurrentUser() async {
    try {
      final res = await ApiService.get('mob_app/auth/autoLogin', withAuth: true);
      final data = res['user'] as Map<String, dynamic>?
          ?? res['data'] as Map<String, dynamic>?
          ?? res;
      if (!mounted) return;
      setState(() => _currentUser = PlayerSearchModel.fromJson(data));
    } catch (_) {}
  }
  Future<void> _fetchFavourites() async {
    try {
      final res = await ApiService.get(
        'v1/favourites',
        query: {'page': '1', 'limit': '20'},
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _favourites = list
            .whereType<Map<String, dynamic>>()
            .map(PlayerSearchModel.fromJson)
            .toList();
        _loadingFavs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFavs = false);
    }
  }
  Future<void> _fetchDefaultPlayers() async {
    try {
      final res = await ApiService.get(
        'v3/consumer/search-user',
        query: {'search': 'a', 'page': '1', 'limit': '20'},
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      final players = list
          .whereType<Map<String, dynamic>>()
          .map(PlayerSearchModel.fromJson)
          .toList();
      setState(() {
        _defaultPlayers = players;
        if (_favourites.isEmpty) {
          _favourites = players.where((p) => p.isFavourite).toList();
        }
        _loadingDefault = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDefault = false);
    }
  }
  Future<void> _searchPlayers(String query) async {
    setState(() => _searching = true);
    try {
      final res = await ApiService.get(
        'v3/consumer/search-user',
        query: {'search': query, 'page': '1', 'limit': '20'},
        withAuth: true,
      );
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _searchResults = list
            .whereType<Map<String, dynamic>>()
            .map(PlayerSearchModel.fromJson)
            .toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }
  bool _isAdded(PlayerSearchModel p) =>
      _selected.any((x) => x.id == p.id);
  void _toggle(PlayerSearchModel p) {
    setState(() {
      if (_isAdded(p)) {
        _selected = _selected.where((x) => x.id != p.id).toList();
      } else if (_selected.length < widget.maxPlayers - 1) {
        _selected = [..._selected, p];
      }
    });
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
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          _buildSheetHeader(context),
          _buildSelectedRow(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildSearchField(),
          ),
          Expanded(
            child: _isSearching
                ? _buildSearchResults(scrollController)
                : _buildDefaultContent(scrollController),
          ),
          _buildSaveButton(context),
        ],
      ),
    );
  }
  Widget _buildSheetHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Add players',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context, 'guests'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Guests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildSelectedRow() {
    final maxOthers = widget.maxPlayers - 1;
    final emptySlots = (maxOthers - _selected.length).clamp(0, maxOthers);
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage: _currentUser?.photoUrl != null
                      ? NetworkImage(_currentUser!.photoUrl!)
                      : null,
                  child: _currentUser?.photoUrl == null
                      ? Text(
                          _currentUser != null
                              ? _initials(_currentUser!.name)
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(
                    _currentUser?.name.split(' ').first ?? 'You',
                    style: const TextStyle(fontSize: 10, color: AppColors.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const Text(
                  '(You)',
                  style: TextStyle(fontSize: 9, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          ..._selected.map((p) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          backgroundImage: p.photoUrl != null
                              ? NetworkImage(p.photoUrl!)
                              : null,
                          child: p.photoUrl == null
                              ? Text(
                                  _initials(p.name),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 56,
                          child: Text(
                            p.name.split(' ').first,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => _toggle(p),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          ...List.generate(
            emptySlots,
            (i) => Padding(
              padding: const EdgeInsets.only(right: 12),
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
                          style: BorderStyle.solid),
                    ),
                    child: const Icon(Icons.add,
                        color: AppColors.textGrey, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search name, email, or number',
        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
        suffixIcon: _searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        filled: true,
        fillColor: const Color(0xFFF5F3EF),
      ),
    );
  }
  Widget _buildDefaultContent(ScrollController scrollController) {
    if (_loadingFavs || _loadingDefault) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        const Text(
          'Favorite',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark),
        ),
        const SizedBox(height: 10),
        if (_favourites.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Currently no favourites available',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          )
        else ...[
          SizedBox(
            height: 172,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _favourites.length,
              itemBuilder: (_, i) => _buildFavCard(_favourites[i]),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_defaultPlayers.isNotEmpty) ...[
          const Text(
            'Players',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          ..._defaultPlayers.map(_buildPlayerTile),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.search, size: 36, color: AppColors.inputBorder),
                SizedBox(height: 10),
                Text(
                  'Search by name, email, or phone',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Type in the search box above to find players',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }
  Widget _buildSearchResults(ScrollController scrollController) {
    if (_searching) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No players found',
            style: TextStyle(color: AppColors.textGrey)),
      );
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        const Text(
          'Players',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        ..._searchResults.map(_buildPlayerTile),
      ],
    );
  }
  Widget _buildFavCard(PlayerSearchModel p) {
    final added = _isAdded(p);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 90,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: added ? AppColors.primary : AppColors.inputBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage:
                    p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                child: p.photoUrl == null
                    ? Text(
                        _initials(p.name),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                p.name.split(' ').first,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (p.rating != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 11, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      p.rating!.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton(
                  onPressed: () => _toggle(p),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        added ? const Color(0xFFE8F5E9) : AppColors.primary,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    added ? 'Added' : 'Add',
                    style: TextStyle(
                      color: added ? AppColors.primary : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (added)
          Positioned(
            top: -5,
            right: 5,
            child: GestureDetector(
              onTap: () => _toggle(p),
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 11, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
  Widget _buildPlayerTile(PlayerSearchModel p) {
    final added = _isAdded(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage:
              p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
          child: p.photoUrl == null
              ? Text(
                  _initials(p.name),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                )
              : null,
        ),
        title: Text(
          p.name,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark),
        ),
        subtitle: p.rating != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 12, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text(
                    p.rating!.toStringAsFixed(2),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textGrey),
                  ),
                ],
              )
            : null,
        trailing: GestureDetector(
          onTap: () => _toggle(p),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: added ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: added ? AppColors.primary : AppColors.inputBorder,
                width: 1.5,
              ),
            ),
            child: Icon(
              added ? Icons.remove : Icons.add,
              size: 18,
              color: added ? Colors.white : AppColors.textGrey,
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildSaveButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text(
            'Save',
            style: TextStyle(
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
