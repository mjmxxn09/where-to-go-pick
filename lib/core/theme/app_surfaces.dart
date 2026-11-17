import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 화면 공통 바탕: 연보라 세로 그라데이션 + 오른쪽 위 분홍 번짐(디자인 캔버스 시안 A).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.bgBottom],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.1,
            colors: [AppColors.blush.withValues(alpha: 0.7), AppColors.blush.withValues(alpha: 0)],
            stops: const [0, 0.55],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// 흰 둥근 카드(반경 24, 보랏빛 그림자).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: AppDecorations.card,
      child: onTap == null
          ? body
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                child: body,
              ),
            ),
    );
  }
}

/// 하단 메뉴 한 칸.
class AppBottomBarItem {
  const AppBottomBarItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// 하단 메뉴(디자인 캔버스 시안 B): 흰 바탕 + 위쪽 얇은 선, 지금 탭은 보라 글자와 아래 작은 점.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.items, required this.selectedIndex, required this.onSelected});

  final List<AppBottomBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _Item(item: items[i], selected: i == selectedIndex, onTap: () => onSelected(i))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.selected, required this.onTap});

  final AppBottomBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(fontSize: 12, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
