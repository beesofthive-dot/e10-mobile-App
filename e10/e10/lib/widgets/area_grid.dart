import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

class AreaTileData {
  const AreaTileData({
    required this.label,
    required this.hint,
    required this.icon,
    required this.screen,
    this.count,
    this.canAdd = false,
  });

  final String label;
  final String hint;
  final IconData icon;
  final AppScreen screen;
  final String? count;
  final bool canAdd;
}

class AreaGrid extends StatelessWidget {
  const AreaGrid({
    super.key,
    required this.areas,
    required this.onOpen,
    this.onAdd,
  });

  final List<AreaTileData> areas;
  final ValueChanged<AppScreen> onOpen;
  final ValueChanged<AppScreen>? onAdd;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: areas.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 100,
      ),
      itemBuilder: (context, i) {
        final area = areas[i];
        return Material(
          color: AppSurface.card(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: () => onOpen(area.screen),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppSurface.line(context)),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppSurface.dark(context) ? AppColors.night : AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(area.icon, color: AppSurface.iconOnCard(context), size: 18),
                      ),
                      const Spacer(),
                      if (area.count != null)
                        Text(area.count!, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppSurface.text(context))),
                      if (area.canAdd)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => (onAdd ?? onOpen)(area.screen),
                          icon: Icon(Icons.add_rounded, size: 18, color: AppSurface.brand(context)),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(area.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, weight: FontWeight.w700)),
                  Text(area.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.caption),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MetricTile {
  const MetricTile({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.tiles});

  final List<MetricTile> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 72,
      ),
      itemBuilder: (context, i) {
        final tile = tiles[i];
        return Material(
          color: AppSurface.card(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: tile.onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppSurface.line(context)),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tile.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.number.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tile.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ActionGridItem {
  const ActionGridItem({
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
}

class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key, required this.items, this.extent = 104});

  final List<ActionGridItem> items;
  final double extent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return WhiteCard(
        padding: const EdgeInsets.all(14),
        child: Text('Nothing here yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: extent,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return Material(
          color: AppSurface.card(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppSurface.line(context)),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppSurface.brand(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 18, color: AppSurface.brand(context)),
                  ),
                  const Spacer(),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 14, weight: FontWeight.w700),
                  ),
                  Text(
                    item.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
