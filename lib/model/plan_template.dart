// Templates (ADR-0037 §6). Upstream's five template use cases are
// `domain/.../templates/{ApplyTemplate,CreateTemplate,CreateTemplateFromObject,
// GetTemplates,OpenTemplate}.kt`, and `ApplyTemplate.kt:26-30` treats a null
// template as "create blank" — that behaviour is the first test here, because a
// picker that cannot produce an empty page is a picker with no escape hatch.
//
// Which types may hold a template is a property of the type, not of the picker
// (`ObjectTypeIds.kt:35 getTypesWithoutTemplates`), so the gate lives beside the
// model and the UI only asks.

import 'plan_block.dart';
import 'plan_object_type.dart';

/// A template is an object whose content is a block tree.
class PlanTemplate {
  const PlanTemplate({
    required this.id,
    required this.name,
    required this.typeKey,
    this.blocks = const [],
    this.bundled = false,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String typeKey;
  final List<PlanBlock> blocks;

  /// A shipped template, not a user's — upstream distinguishes them
  /// (`SmartBlockType.BUNDLED_TEMPLATE`).
  final bool bundled;

  /// The type's default (`SetObjectType.defaultTemplateId` points at it).
  final bool isDefault;

  PlanTemplate copyWith({
    String? name,
    List<PlanBlock>? blocks,
    bool? isDefault,
  }) => PlanTemplate(
    id: id,
    name: name ?? this.name,
    typeKey: typeKey,
    blocks: blocks ?? this.blocks,
    bundled: bundled,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'typeKey': typeKey,
    if (bundled) 'bundled': true,
    if (isDefault) 'isDefault': true,
    'blocks': [for (final block in blocks) block.toJson()],
  };

  static PlanTemplate fromJson(Map<String, Object?> json) => PlanTemplate(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    typeKey: json['typeKey'] as String? ?? '',
    bundled: json['bundled'] == true,
    isDefault: json['isDefault'] == true,
    blocks: [
      for (final entry in (json['blocks'] as List<Object?>? ?? const []))
        if (entry is Map<String, Object?>) PlanBlock.fromJson(entry),
    ],
  );
}

/// The five template operations, named after the use cases they mirror.
enum PlanTemplateAction { apply, create, createFromObject, get, open }

/// The blocks a new record starts with. Null (or an absent template id) means
/// blank — the same answer `ApplyTemplate` gives.
List<PlanBlock> planTemplateContent(PlanTemplate? template) =>
    template == null ? const [] : template.blocks;

/// Whether a type may carry templates at all.
bool planTypeAllowsTemplates(String typeKey) =>
    PlanObjectTypeIds.allowsTemplates(typeKey);

/// The picker's list for a type: bundled and user templates, default first.
List<PlanTemplate> planTemplatesForType(
  Iterable<PlanTemplate> templates,
  String typeKey,
) {
  if (!planTypeAllowsTemplates(typeKey)) return const [];
  final forType = [
    for (final template in templates)
      if (template.typeKey == typeKey) template,
  ];
  // A comparator must be antisymmetric: ranking the default first is a
  // comparison between the two sides, not a one-sided test.
  forType.sort((a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0));
  return forType;
}

/// A gallery package the user can install (ADR-0037 §6, mirroring
/// `gallery-experience/`): types plus templates plus a name.
class PlanGalleryPackage {
  const PlanGalleryPackage({
    required this.id,
    required this.name,
    this.types = const [],
    this.templates = const [],
  });

  final String id;
  final String name;
  final List<PlanObjectType> types;
  final List<PlanTemplate> templates;

  int get contentCount => types.length + templates.length;
}
