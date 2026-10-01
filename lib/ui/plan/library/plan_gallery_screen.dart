// The Gallery installation flow (ADR-0037 P6, module 6): the three states the
// client answers — idle, loading, done (`GalleryInstallationState.kt:8-13`) —
// with the manifest supplied as mock data (the build sheet's "mock 目录" line),
// the space picker reduced to this workspace's single vault, and the install
// itself = createSetOfType plus the manifest's starter records. Upstream's
// "not supported" alert is a dead destination in 7af5254 (`graph.xml:306-307`
// registers it, nothing navigates there); the desktop answer is a working
// install, and the parity ledger registers that reading.

import 'package:flutter/material.dart';

import '../../../l10n/locales.dart';
import '../../../model/plan_object_type.dart';
import '../../../state/plan_object_store.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/feedback.dart';
import '../../primitives/tappable.dart';

/// A bundled template pack: the manifest fields the flow reads, named after
/// the manifest info upstream parses. Data, not a network call.
class PlanGalleryPackage {
  const PlanGalleryPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceTypeKey,
    required this.starterRecords,
  });

  final String id;
  final String name;
  final String description;
  final String sourceTypeKey;
  final Map<String, Object?> starterRecords;
}

const planGalleryPackages = <PlanGalleryPackage>[
  PlanGalleryPackage(
    id: 'pack-reading',
    name: 'Reading list',
    description: 'Books to read, with status and rating.',
    sourceTypeKey: PlanObjectTypeIds.page,
    starterRecords: {'name': '', 'description': ''},
  ),
  PlanGalleryPackage(
    id: 'pack-projects',
    name: 'Projects',
    description: 'Ongoing work with a status column.',
    sourceTypeKey: PlanObjectTypeIds.project,
    starterRecords: {'name': ''},
  ),
];

enum PlanGalleryInstallState { idle, loading, done }

class PlanGalleryScreen extends StatefulWidget {
  const PlanGalleryScreen({super.key, required this.store});

  final PlanObjectStore store;

  @override
  State<PlanGalleryScreen> createState() => _PlanGalleryScreenState();
}

class _PlanGalleryScreenState extends State<PlanGalleryScreen> {
  PlanGalleryInstallState _state = PlanGalleryInstallState.idle;
  String? _installedName;

  Future<void> _install(PlanGalleryPackage pack) async {
    setState(() => _state = PlanGalleryInstallState.loading);
    final type = widget.store.types
        .where((candidate) => candidate.uniqueKey == pack.sourceTypeKey)
        .firstOrNull;
    final collection = type == null
        ? null
        : await widget.store.createSetOfType(type);
    if (!mounted) return;
    if (collection == null) {
      setState(() => _state = PlanGalleryInstallState.idle);
      showFeedback(context, context.tr('planGalleryUnsupported'));
      return;
    }
    await widget.store.createRecord(
      collectionId: collection.id,
      typeKey: pack.sourceTypeKey,
      values: {...pack.starterRecords, 'name': pack.name},
    );
    if (!mounted) return;
    setState(() {
      _state = PlanGalleryInstallState.done;
      _installedName = collection.name;
    });
    showFeedback(context, context.tr('planGalleryInstalled'));
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DswShape.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('planGalleryTitle'),
            style: DswType.l20.copyWith(color: color.labelPrimary),
          ),
          const SizedBox(height: DswShape.sm),
          if (_state == PlanGalleryInstallState.loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DswShape.lg),
              child: Row(
                children: [
                  const SizedBox(
                    width: DswShape.iconSm,
                    height: DswShape.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: DswShape.sm),
                  Text(
                    context.tr('planGalleryInstalling'),
                    style: DswType.xs13.copyWith(color: color.labelTertiary),
                  ),
                ],
              ),
            )
          else if (_state == PlanGalleryInstallState.done)
            Padding(
              padding: const EdgeInsets.only(bottom: DswShape.sm),
              child: Text(
                context.tr('planGalleryDone', {'name': _installedName ?? ''}),
                style: DswType.xs13.copyWith(color: color.stateSuccessPrimary),
              ),
            ),
          for (final pack in planGalleryPackages)
            Container(
              margin: const EdgeInsets.only(top: DswShape.xs),
              padding: const EdgeInsets.all(DswShape.sm),
              decoration: BoxDecoration(
                color: color.bgLayer2,
                borderRadius: BorderRadius.circular(DswShape.card),
                border: Border.all(color: color.borderL2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.name,
                          style: DswType.sStrong14.copyWith(
                            color: color.labelPrimary,
                          ),
                        ),
                        Text(
                          pack.description,
                          style: DswType.xs13.copyWith(
                            color: color.labelSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DswHoverTap(
                    onTap: _state == PlanGalleryInstallState.loading
                        ? null
                        : () => _install(pack),
                    semanticLabel: context.tr('planGalleryInstall'),
                    builder: (context, hovered, focused) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DswShape.sm,
                        vertical: DswShape.xs,
                      ),
                      decoration: BoxDecoration(
                        color: color.bgLayer3,
                        borderRadius: BorderRadius.circular(DswShape.inner),
                        border: Border.all(color: color.borderL2),
                      ),
                      child: Text(
                        context.tr('planGalleryInstall'),
                        style: DswType.xs13.copyWith(color: color.labelPrimary),
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
