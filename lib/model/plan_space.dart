// What a fresh plan space contains (ADR-0037 P2). The model owns this shape so
// `lib/model` never imports `lib/state`; the store reads a seed, the mock
// supplies one, and swapping the mock for a real source changes only which
// seed a provider hands over.

import 'plan_dataview.dart';
import 'plan_object_type.dart';
import 'plan_relation.dart';
import 'plan_struct.dart';
import 'plan_template.dart';
import 'plan_widget.dart';

class PlanSpaceSeed {
  const PlanSpaceSeed({
    this.objects = const [],
    this.collections = const [],
    this.types = const [],
    this.relations = const [],
    this.templates = const [],
    this.widgets = const [],
    this.bin = const {},
  });

  static const empty = PlanSpaceSeed();

  final List<PlanObject> objects;
  final List<PlanCollection> collections;
  final List<PlanObjectType> types;
  final List<PlanRelation> relations;
  final List<PlanTemplate> templates;
  final List<PlanWidget> widgets;
  final Set<String> bin;
}
