import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/navigation/dpad.dart';
import '../core/theme/theme.dart';

/// Root navigation shell: sidebar + content area.
///
/// Mirrors the official sidebar (Home, Search, Library, Settings) with the
/// modern auto-collapse behavior. Sidebar items are focusable; D-pad left
/// from content focuses the sidebar, right returns to content.
enum NuvioTab { home, search, library, settings }

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.tabContentBuilders,
    this.initialTab = NuvioTab.home,
  });

  final Map<NuvioTab, WidgetBuilder> tabContentBuilders;
  final NuvioTab initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with DpadHandler {
  NuvioTab _tab = NuvioTab.home;
  bool _sidebarFocused = false;
  bool _sidebarExpanded = false;
  Timer? _collapseTimer;

  static const _collapseDelay = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  void _selectTab(NuvioTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_collapseDelay, () {
      if (mounted && !_sidebarFocused) {
        setState(() => _sidebarExpanded = false);
      }
    });
  }

  @override
  bool onDpadAction(NuvioKeyAction action, bool isRepeat) {
    // Shell-level: back on sidebar collapses it, left edge focuses sidebar.
    if (action == NuvioKeyAction.back && _sidebarFocused) {
      setState(() {
        _sidebarFocused = false;
        _sidebarExpanded = false;
      });
      _scheduleCollapse();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            currentTab: _tab,
            focused: _sidebarFocused,
            expanded: _sidebarExpanded || _sidebarFocused,
            onFocusChange: (focused) {
              setState(() => _sidebarFocused = focused);
              if (focused) {
                setState(() => _sidebarExpanded = true);
              } else {
                _scheduleCollapse();
              }
            },
            onTabSelected: (tab) {
              _selectTab(tab);
              setState(() => _sidebarFocused = false);
              _scheduleCollapse();
            },
          ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: widget.tabContentBuilders[_tab]!(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentTab,
    required this.focused,
    required this.expanded,
    required this.onFocusChange,
    required this.onTabSelected,
  });

  final NuvioTab currentTab;
  final bool focused;
  final bool expanded;
  final ValueChanged<bool> onFocusChange;
  final ValueChanged<NuvioTab> onTabSelected;

  static const _items = <(NuvioTab, String, IconData)>[
    (NuvioTab.home, 'Home', Icons.home_outlined),
    (NuvioTab.search, 'Search', Icons.search),
    (NuvioTab.library, 'Library', Icons.video_library_outlined),
    (NuvioTab.settings, 'Settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? 220 : 84,
      color: NuvioColors.bgElevated.withValues(alpha: 0.6),
      child: SafeArea(
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: NuvioSpacing.safeGutter),
              _BrandMark(expanded: expanded),
              const SizedBox(height: 24),
              ..._items.map((item) => _SidebarItem(
                    tab: item.$1,
                    label: item.$2,
                    icon: item.$3,
                    selected: currentTab == item.$1,
                    expanded: expanded,
                    onFocusChange: onFocusChange,
                    onSelected: () => onTabSelected(item.$1),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [NuvioColors.accent, NuvioColors.accent.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'N',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: expanded
                ? const Padding(
                    key: ValueKey('brand-text'),
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      'Nuvio',
                      style: TextStyle(
                        color: NuvioColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('brand-empty')),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selected,
    required this.expanded,
    required this.onFocusChange,
    required this.onSelected,
  });

  final NuvioTab tab;
  final String label;
  final IconData icon;
  final bool selected;
  final bool expanded;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback onSelected;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: Focus(
        onFocusChange: (f) {
          setState(() => _focused = f);
          if (f) widget.onFocusChange(true);
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              mapKey(event.logicalKey) == NuvioKeyAction.select) {
            widget.onSelected();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: NuvioSpacing.buttonHeight,
          decoration: BoxDecoration(
            color: active
                ? NuvioColors.cardFocused
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                widget.icon,
                size: 28,
                color: active ? NuvioColors.text : NuvioColors.textSecondary,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: widget.expanded
                    ? Padding(
                        key: ValueKey(widget.label),
                        padding: const EdgeInsets.only(left: 14),
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: widget.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: active
                                ? NuvioColors.text
                                : NuvioColors.textSecondary,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
