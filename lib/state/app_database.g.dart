// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsageRowsTable extends UsageRows
    with TableInfo<$UsageRowsTable, UsageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputTokensMeta = const VerificationMeta(
    'inputTokens',
  );
  @override
  late final GeneratedColumn<int> inputTokens = GeneratedColumn<int>(
    'input_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputTokensMeta = const VerificationMeta(
    'outputTokens',
  );
  @override
  late final GeneratedColumn<int> outputTokens = GeneratedColumn<int>(
    'output_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasoningTokensMeta = const VerificationMeta(
    'reasoningTokens',
  );
  @override
  late final GeneratedColumn<int> reasoningTokens = GeneratedColumn<int>(
    'reasoning_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<bool> error = GeneratedColumn<bool>(
    'error',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("error" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    model,
    inputTokens,
    outputTokens,
    reasoningTokens,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('input_tokens')) {
      context.handle(
        _inputTokensMeta,
        inputTokens.isAcceptableOrUnknown(
          data['input_tokens']!,
          _inputTokensMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputTokensMeta);
    }
    if (data.containsKey('output_tokens')) {
      context.handle(
        _outputTokensMeta,
        outputTokens.isAcceptableOrUnknown(
          data['output_tokens']!,
          _outputTokensMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outputTokensMeta);
    }
    if (data.containsKey('reasoning_tokens')) {
      context.handle(
        _reasoningTokensMeta,
        reasoningTokens.isAcceptableOrUnknown(
          data['reasoning_tokens']!,
          _reasoningTokensMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      inputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_tokens'],
      )!,
      outputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_tokens'],
      )!,
      reasoningTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reasoning_tokens'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}error'],
      )!,
    );
  }

  @override
  $UsageRowsTable createAlias(String alias) {
    return $UsageRowsTable(attachedDatabase, alias);
  }
}

class UsageRow extends DataClass implements Insertable<UsageRow> {
  final int id;
  final int timestamp;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int reasoningTokens;
  final bool error;
  const UsageRow({
    required this.id,
    required this.timestamp,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.reasoningTokens,
    required this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<int>(timestamp);
    map['model'] = Variable<String>(model);
    map['input_tokens'] = Variable<int>(inputTokens);
    map['output_tokens'] = Variable<int>(outputTokens);
    map['reasoning_tokens'] = Variable<int>(reasoningTokens);
    map['error'] = Variable<bool>(error);
    return map;
  }

  UsageRowsCompanion toCompanion(bool nullToAbsent) {
    return UsageRowsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      model: Value(model),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      reasoningTokens: Value(reasoningTokens),
      error: Value(error),
    );
  }

  factory UsageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageRow(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      model: serializer.fromJson<String>(json['model']),
      inputTokens: serializer.fromJson<int>(json['inputTokens']),
      outputTokens: serializer.fromJson<int>(json['outputTokens']),
      reasoningTokens: serializer.fromJson<int>(json['reasoningTokens']),
      error: serializer.fromJson<bool>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<int>(timestamp),
      'model': serializer.toJson<String>(model),
      'inputTokens': serializer.toJson<int>(inputTokens),
      'outputTokens': serializer.toJson<int>(outputTokens),
      'reasoningTokens': serializer.toJson<int>(reasoningTokens),
      'error': serializer.toJson<bool>(error),
    };
  }

  UsageRow copyWith({
    int? id,
    int? timestamp,
    String? model,
    int? inputTokens,
    int? outputTokens,
    int? reasoningTokens,
    bool? error,
  }) => UsageRow(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    model: model ?? this.model,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    reasoningTokens: reasoningTokens ?? this.reasoningTokens,
    error: error ?? this.error,
  );
  UsageRow copyWithCompanion(UsageRowsCompanion data) {
    return UsageRow(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      model: data.model.present ? data.model.value : this.model,
      inputTokens: data.inputTokens.present
          ? data.inputTokens.value
          : this.inputTokens,
      outputTokens: data.outputTokens.present
          ? data.outputTokens.value
          : this.outputTokens,
      reasoningTokens: data.reasoningTokens.present
          ? data.reasoningTokens.value
          : this.reasoningTokens,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageRow(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('model: $model, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('reasoningTokens: $reasoningTokens, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    model,
    inputTokens,
    outputTokens,
    reasoningTokens,
    error,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageRow &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.model == this.model &&
          other.inputTokens == this.inputTokens &&
          other.outputTokens == this.outputTokens &&
          other.reasoningTokens == this.reasoningTokens &&
          other.error == this.error);
}

class UsageRowsCompanion extends UpdateCompanion<UsageRow> {
  final Value<int> id;
  final Value<int> timestamp;
  final Value<String> model;
  final Value<int> inputTokens;
  final Value<int> outputTokens;
  final Value<int> reasoningTokens;
  final Value<bool> error;
  const UsageRowsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.model = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.reasoningTokens = const Value.absent(),
    this.error = const Value.absent(),
  });
  UsageRowsCompanion.insert({
    this.id = const Value.absent(),
    required int timestamp,
    required String model,
    required int inputTokens,
    required int outputTokens,
    this.reasoningTokens = const Value.absent(),
    this.error = const Value.absent(),
  }) : timestamp = Value(timestamp),
       model = Value(model),
       inputTokens = Value(inputTokens),
       outputTokens = Value(outputTokens);
  static Insertable<UsageRow> custom({
    Expression<int>? id,
    Expression<int>? timestamp,
    Expression<String>? model,
    Expression<int>? inputTokens,
    Expression<int>? outputTokens,
    Expression<int>? reasoningTokens,
    Expression<bool>? error,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (model != null) 'model': model,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      if (reasoningTokens != null) 'reasoning_tokens': reasoningTokens,
      if (error != null) 'error': error,
    });
  }

  UsageRowsCompanion copyWith({
    Value<int>? id,
    Value<int>? timestamp,
    Value<String>? model,
    Value<int>? inputTokens,
    Value<int>? outputTokens,
    Value<int>? reasoningTokens,
    Value<bool>? error,
  }) {
    return UsageRowsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      model: model ?? this.model,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      reasoningTokens: reasoningTokens ?? this.reasoningTokens,
      error: error ?? this.error,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (inputTokens.present) {
      map['input_tokens'] = Variable<int>(inputTokens.value);
    }
    if (outputTokens.present) {
      map['output_tokens'] = Variable<int>(outputTokens.value);
    }
    if (reasoningTokens.present) {
      map['reasoning_tokens'] = Variable<int>(reasoningTokens.value);
    }
    if (error.present) {
      map['error'] = Variable<bool>(error.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageRowsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('model: $model, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('reasoningTokens: $reasoningTokens, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }
}

class $ScheduledTaskRowsTable extends ScheduledTaskRows
    with TableInfo<$ScheduledTaskRowsTable, ScheduledTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledTaskRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekdaysMaskMeta = const VerificationMeta(
    'weekdaysMask',
  );
  @override
  late final GeneratedColumn<int> weekdaysMask = GeneratedColumn<int>(
    'weekdays_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastRunAtMeta = const VerificationMeta(
    'lastRunAt',
  );
  @override
  late final GeneratedColumn<int> lastRunAt = GeneratedColumn<int>(
    'last_run_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    prompt,
    hour,
    minute,
    weekdaysMask,
    enabled,
    lastRunAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledTaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('weekdays_mask')) {
      context.handle(
        _weekdaysMaskMeta,
        weekdaysMask.isAcceptableOrUnknown(
          data['weekdays_mask']!,
          _weekdaysMaskMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('last_run_at')) {
      context.handle(
        _lastRunAtMeta,
        lastRunAt.isAcceptableOrUnknown(data['last_run_at']!, _lastRunAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledTaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledTaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      )!,
      weekdaysMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekdays_mask'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      lastRunAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_run_at'],
      ),
    );
  }

  @override
  $ScheduledTaskRowsTable createAlias(String alias) {
    return $ScheduledTaskRowsTable(attachedDatabase, alias);
  }
}

class ScheduledTaskRow extends DataClass
    implements Insertable<ScheduledTaskRow> {
  final String id;
  final String name;
  final String prompt;
  final int hour;
  final int minute;
  final int weekdaysMask;
  final bool enabled;
  final int? lastRunAt;
  const ScheduledTaskRow({
    required this.id,
    required this.name,
    required this.prompt,
    required this.hour,
    required this.minute,
    required this.weekdaysMask,
    required this.enabled,
    this.lastRunAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['prompt'] = Variable<String>(prompt);
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    map['weekdays_mask'] = Variable<int>(weekdaysMask);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || lastRunAt != null) {
      map['last_run_at'] = Variable<int>(lastRunAt);
    }
    return map;
  }

  ScheduledTaskRowsCompanion toCompanion(bool nullToAbsent) {
    return ScheduledTaskRowsCompanion(
      id: Value(id),
      name: Value(name),
      prompt: Value(prompt),
      hour: Value(hour),
      minute: Value(minute),
      weekdaysMask: Value(weekdaysMask),
      enabled: Value(enabled),
      lastRunAt: lastRunAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRunAt),
    );
  }

  factory ScheduledTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledTaskRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      prompt: serializer.fromJson<String>(json['prompt']),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
      weekdaysMask: serializer.fromJson<int>(json['weekdaysMask']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      lastRunAt: serializer.fromJson<int?>(json['lastRunAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'prompt': serializer.toJson<String>(prompt),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
      'weekdaysMask': serializer.toJson<int>(weekdaysMask),
      'enabled': serializer.toJson<bool>(enabled),
      'lastRunAt': serializer.toJson<int?>(lastRunAt),
    };
  }

  ScheduledTaskRow copyWith({
    String? id,
    String? name,
    String? prompt,
    int? hour,
    int? minute,
    int? weekdaysMask,
    bool? enabled,
    Value<int?> lastRunAt = const Value.absent(),
  }) => ScheduledTaskRow(
    id: id ?? this.id,
    name: name ?? this.name,
    prompt: prompt ?? this.prompt,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    weekdaysMask: weekdaysMask ?? this.weekdaysMask,
    enabled: enabled ?? this.enabled,
    lastRunAt: lastRunAt.present ? lastRunAt.value : this.lastRunAt,
  );
  ScheduledTaskRow copyWithCompanion(ScheduledTaskRowsCompanion data) {
    return ScheduledTaskRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      weekdaysMask: data.weekdaysMask.present
          ? data.weekdaysMask.value
          : this.weekdaysMask,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      lastRunAt: data.lastRunAt.present ? data.lastRunAt.value : this.lastRunAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTaskRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('prompt: $prompt, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('weekdaysMask: $weekdaysMask, ')
          ..write('enabled: $enabled, ')
          ..write('lastRunAt: $lastRunAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    prompt,
    hour,
    minute,
    weekdaysMask,
    enabled,
    lastRunAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledTaskRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.prompt == this.prompt &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.weekdaysMask == this.weekdaysMask &&
          other.enabled == this.enabled &&
          other.lastRunAt == this.lastRunAt);
}

class ScheduledTaskRowsCompanion extends UpdateCompanion<ScheduledTaskRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> prompt;
  final Value<int> hour;
  final Value<int> minute;
  final Value<int> weekdaysMask;
  final Value<bool> enabled;
  final Value<int?> lastRunAt;
  final Value<int> rowid;
  const ScheduledTaskRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.prompt = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.weekdaysMask = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastRunAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduledTaskRowsCompanion.insert({
    required String id,
    required String name,
    required String prompt,
    required int hour,
    required int minute,
    this.weekdaysMask = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastRunAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       prompt = Value(prompt),
       hour = Value(hour),
       minute = Value(minute);
  static Insertable<ScheduledTaskRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? prompt,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<int>? weekdaysMask,
    Expression<bool>? enabled,
    Expression<int>? lastRunAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (prompt != null) 'prompt': prompt,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (weekdaysMask != null) 'weekdays_mask': weekdaysMask,
      if (enabled != null) 'enabled': enabled,
      if (lastRunAt != null) 'last_run_at': lastRunAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduledTaskRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? prompt,
    Value<int>? hour,
    Value<int>? minute,
    Value<int>? weekdaysMask,
    Value<bool>? enabled,
    Value<int?>? lastRunAt,
    Value<int>? rowid,
  }) {
    return ScheduledTaskRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdaysMask: weekdaysMask ?? this.weekdaysMask,
      enabled: enabled ?? this.enabled,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (weekdaysMask.present) {
      map['weekdays_mask'] = Variable<int>(weekdaysMask.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (lastRunAt.present) {
      map['last_run_at'] = Variable<int>(lastRunAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTaskRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('prompt: $prompt, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('weekdaysMask: $weekdaysMask, ')
          ..write('enabled: $enabled, ')
          ..write('lastRunAt: $lastRunAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduledTaskRunRowsTable extends ScheduledTaskRunRows
    with TableInfo<$ScheduledTaskRunRowsTable, ScheduledTaskRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledTaskRunRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _okMeta = const VerificationMeta('ok');
  @override
  late final GeneratedColumn<bool> ok = GeneratedColumn<bool>(
    'ok',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ok" IN (0, 1))',
    ),
  );
  static const VerificationMeta _previewMeta = const VerificationMeta(
    'preview',
  );
  @override
  late final GeneratedColumn<String> preview = GeneratedColumn<String>(
    'preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, taskId, startedAt, ok, preview];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_task_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledTaskRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ok')) {
      context.handle(_okMeta, ok.isAcceptableOrUnknown(data['ok']!, _okMeta));
    } else if (isInserting) {
      context.missing(_okMeta);
    }
    if (data.containsKey('preview')) {
      context.handle(
        _previewMeta,
        preview.isAcceptableOrUnknown(data['preview']!, _previewMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledTaskRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledTaskRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      ok: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ok'],
      )!,
      preview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview'],
      )!,
    );
  }

  @override
  $ScheduledTaskRunRowsTable createAlias(String alias) {
    return $ScheduledTaskRunRowsTable(attachedDatabase, alias);
  }
}

class ScheduledTaskRunRow extends DataClass
    implements Insertable<ScheduledTaskRunRow> {
  final int id;
  final String taskId;
  final int startedAt;
  final bool ok;
  final String preview;
  const ScheduledTaskRunRow({
    required this.id,
    required this.taskId,
    required this.startedAt,
    required this.ok,
    required this.preview,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_id'] = Variable<String>(taskId);
    map['started_at'] = Variable<int>(startedAt);
    map['ok'] = Variable<bool>(ok);
    map['preview'] = Variable<String>(preview);
    return map;
  }

  ScheduledTaskRunRowsCompanion toCompanion(bool nullToAbsent) {
    return ScheduledTaskRunRowsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      startedAt: Value(startedAt),
      ok: Value(ok),
      preview: Value(preview),
    );
  }

  factory ScheduledTaskRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledTaskRunRow(
      id: serializer.fromJson<int>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      ok: serializer.fromJson<bool>(json['ok']),
      preview: serializer.fromJson<String>(json['preview']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskId': serializer.toJson<String>(taskId),
      'startedAt': serializer.toJson<int>(startedAt),
      'ok': serializer.toJson<bool>(ok),
      'preview': serializer.toJson<String>(preview),
    };
  }

  ScheduledTaskRunRow copyWith({
    int? id,
    String? taskId,
    int? startedAt,
    bool? ok,
    String? preview,
  }) => ScheduledTaskRunRow(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    startedAt: startedAt ?? this.startedAt,
    ok: ok ?? this.ok,
    preview: preview ?? this.preview,
  );
  ScheduledTaskRunRow copyWithCompanion(ScheduledTaskRunRowsCompanion data) {
    return ScheduledTaskRunRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      ok: data.ok.present ? data.ok.value : this.ok,
      preview: data.preview.present ? data.preview.value : this.preview,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTaskRunRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('startedAt: $startedAt, ')
          ..write('ok: $ok, ')
          ..write('preview: $preview')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, taskId, startedAt, ok, preview);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledTaskRunRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.startedAt == this.startedAt &&
          other.ok == this.ok &&
          other.preview == this.preview);
}

class ScheduledTaskRunRowsCompanion
    extends UpdateCompanion<ScheduledTaskRunRow> {
  final Value<int> id;
  final Value<String> taskId;
  final Value<int> startedAt;
  final Value<bool> ok;
  final Value<String> preview;
  const ScheduledTaskRunRowsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.ok = const Value.absent(),
    this.preview = const Value.absent(),
  });
  ScheduledTaskRunRowsCompanion.insert({
    this.id = const Value.absent(),
    required String taskId,
    required int startedAt,
    required bool ok,
    this.preview = const Value.absent(),
  }) : taskId = Value(taskId),
       startedAt = Value(startedAt),
       ok = Value(ok);
  static Insertable<ScheduledTaskRunRow> custom({
    Expression<int>? id,
    Expression<String>? taskId,
    Expression<int>? startedAt,
    Expression<bool>? ok,
    Expression<String>? preview,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (startedAt != null) 'started_at': startedAt,
      if (ok != null) 'ok': ok,
      if (preview != null) 'preview': preview,
    });
  }

  ScheduledTaskRunRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? taskId,
    Value<int>? startedAt,
    Value<bool>? ok,
    Value<String>? preview,
  }) {
    return ScheduledTaskRunRowsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      ok: ok ?? this.ok,
      preview: preview ?? this.preview,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (ok.present) {
      map['ok'] = Variable<bool>(ok.value);
    }
    if (preview.present) {
      map['preview'] = Variable<String>(preview.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTaskRunRowsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('startedAt: $startedAt, ')
          ..write('ok: $ok, ')
          ..write('preview: $preview')
          ..write(')'))
        .toString();
  }
}

class $PlanSpaceMetaRowsTable extends PlanSpaceMetaRows
    with TableInfo<$PlanSpaceMetaRowsTable, PlanSpaceMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanSpaceMetaRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _binMeta = const VerificationMeta('bin');
  @override
  late final GeneratedColumn<String> bin = GeneratedColumn<String>(
    'bin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, revision, bin];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_space_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanSpaceMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('bin')) {
      context.handle(
        _binMeta,
        bin.isAcceptableOrUnknown(data['bin']!, _binMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanSpaceMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanSpaceMetaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      bin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bin'],
      )!,
    );
  }

  @override
  $PlanSpaceMetaRowsTable createAlias(String alias) {
    return $PlanSpaceMetaRowsTable(attachedDatabase, alias);
  }
}

class PlanSpaceMetaRow extends DataClass
    implements Insertable<PlanSpaceMetaRow> {
  final String id;
  final int revision;
  final String bin;
  const PlanSpaceMetaRow({
    required this.id,
    required this.revision,
    required this.bin,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['revision'] = Variable<int>(revision);
    map['bin'] = Variable<String>(bin);
    return map;
  }

  PlanSpaceMetaRowsCompanion toCompanion(bool nullToAbsent) {
    return PlanSpaceMetaRowsCompanion(
      id: Value(id),
      revision: Value(revision),
      bin: Value(bin),
    );
  }

  factory PlanSpaceMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanSpaceMetaRow(
      id: serializer.fromJson<String>(json['id']),
      revision: serializer.fromJson<int>(json['revision']),
      bin: serializer.fromJson<String>(json['bin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'revision': serializer.toJson<int>(revision),
      'bin': serializer.toJson<String>(bin),
    };
  }

  PlanSpaceMetaRow copyWith({String? id, int? revision, String? bin}) =>
      PlanSpaceMetaRow(
        id: id ?? this.id,
        revision: revision ?? this.revision,
        bin: bin ?? this.bin,
      );
  PlanSpaceMetaRow copyWithCompanion(PlanSpaceMetaRowsCompanion data) {
    return PlanSpaceMetaRow(
      id: data.id.present ? data.id.value : this.id,
      revision: data.revision.present ? data.revision.value : this.revision,
      bin: data.bin.present ? data.bin.value : this.bin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanSpaceMetaRow(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('bin: $bin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, revision, bin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanSpaceMetaRow &&
          other.id == this.id &&
          other.revision == this.revision &&
          other.bin == this.bin);
}

class PlanSpaceMetaRowsCompanion extends UpdateCompanion<PlanSpaceMetaRow> {
  final Value<String> id;
  final Value<int> revision;
  final Value<String> bin;
  final Value<int> rowid;
  const PlanSpaceMetaRowsCompanion({
    this.id = const Value.absent(),
    this.revision = const Value.absent(),
    this.bin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanSpaceMetaRowsCompanion.insert({
    required String id,
    required int revision,
    this.bin = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       revision = Value(revision);
  static Insertable<PlanSpaceMetaRow> custom({
    Expression<String>? id,
    Expression<int>? revision,
    Expression<String>? bin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (revision != null) 'revision': revision,
      if (bin != null) 'bin': bin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanSpaceMetaRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? revision,
    Value<String>? bin,
    Value<int>? rowid,
  }) {
    return PlanSpaceMetaRowsCompanion(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      bin: bin ?? this.bin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (bin.present) {
      map['bin'] = Variable<String>(bin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanSpaceMetaRowsCompanion(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('bin: $bin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanRecordRowsTable extends PlanRecordRows
    with TableInfo<$PlanRecordRowsTable, PlanRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanRecordRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [kind, id, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, id};
  @override
  PlanRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanRecordRow(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $PlanRecordRowsTable createAlias(String alias) {
    return $PlanRecordRowsTable(attachedDatabase, alias);
  }
}

class PlanRecordRow extends DataClass implements Insertable<PlanRecordRow> {
  final String kind;
  final String id;
  final String payload;
  const PlanRecordRow({
    required this.kind,
    required this.id,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['id'] = Variable<String>(id);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  PlanRecordRowsCompanion toCompanion(bool nullToAbsent) {
    return PlanRecordRowsCompanion(
      kind: Value(kind),
      id: Value(id),
      payload: Value(payload),
    );
  }

  factory PlanRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanRecordRow(
      kind: serializer.fromJson<String>(json['kind']),
      id: serializer.fromJson<String>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'id': serializer.toJson<String>(id),
      'payload': serializer.toJson<String>(payload),
    };
  }

  PlanRecordRow copyWith({String? kind, String? id, String? payload}) =>
      PlanRecordRow(
        kind: kind ?? this.kind,
        id: id ?? this.id,
        payload: payload ?? this.payload,
      );
  PlanRecordRow copyWithCompanion(PlanRecordRowsCompanion data) {
    return PlanRecordRow(
      kind: data.kind.present ? data.kind.value : this.kind,
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanRecordRow(')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, id, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanRecordRow &&
          other.kind == this.kind &&
          other.id == this.id &&
          other.payload == this.payload);
}

class PlanRecordRowsCompanion extends UpdateCompanion<PlanRecordRow> {
  final Value<String> kind;
  final Value<String> id;
  final Value<String> payload;
  final Value<int> rowid;
  const PlanRecordRowsCompanion({
    this.kind = const Value.absent(),
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanRecordRowsCompanion.insert({
    required String kind,
    required String id,
    required String payload,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       id = Value(id),
       payload = Value(payload);
  static Insertable<PlanRecordRow> custom({
    Expression<String>? kind,
    Expression<String>? id,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanRecordRowsCompanion copyWith({
    Value<String>? kind,
    Value<String>? id,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return PlanRecordRowsCompanion(
      kind: kind ?? this.kind,
      id: id ?? this.id,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanRecordRowsCompanion(')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsageRowsTable usageRows = $UsageRowsTable(this);
  late final $ScheduledTaskRowsTable scheduledTaskRows =
      $ScheduledTaskRowsTable(this);
  late final $ScheduledTaskRunRowsTable scheduledTaskRunRows =
      $ScheduledTaskRunRowsTable(this);
  late final $PlanSpaceMetaRowsTable planSpaceMetaRows =
      $PlanSpaceMetaRowsTable(this);
  late final $PlanRecordRowsTable planRecordRows = $PlanRecordRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    usageRows,
    scheduledTaskRows,
    scheduledTaskRunRows,
    planSpaceMetaRows,
    planRecordRows,
  ];
}

typedef $$UsageRowsTableCreateCompanionBuilder =
    UsageRowsCompanion Function({
      Value<int> id,
      required int timestamp,
      required String model,
      required int inputTokens,
      required int outputTokens,
      Value<int> reasoningTokens,
      Value<bool> error,
    });
typedef $$UsageRowsTableUpdateCompanionBuilder =
    UsageRowsCompanion Function({
      Value<int> id,
      Value<int> timestamp,
      Value<String> model,
      Value<int> inputTokens,
      Value<int> outputTokens,
      Value<int> reasoningTokens,
      Value<bool> error,
    });

class $$UsageRowsTableFilterComposer
    extends Composer<_$AppDatabase, $UsageRowsTable> {
  $$UsageRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reasoningTokens => $composableBuilder(
    column: $table.reasoningTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $UsageRowsTable> {
  $$UsageRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reasoningTokens => $composableBuilder(
    column: $table.reasoningTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsageRowsTable> {
  $$UsageRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reasoningTokens => $composableBuilder(
    column: $table.reasoningTokens,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$UsageRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsageRowsTable,
          UsageRow,
          $$UsageRowsTableFilterComposer,
          $$UsageRowsTableOrderingComposer,
          $$UsageRowsTableAnnotationComposer,
          $$UsageRowsTableCreateCompanionBuilder,
          $$UsageRowsTableUpdateCompanionBuilder,
          (UsageRow, BaseReferences<_$AppDatabase, $UsageRowsTable, UsageRow>),
          UsageRow,
          PrefetchHooks Function()
        > {
  $$UsageRowsTableTableManager(_$AppDatabase db, $UsageRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> inputTokens = const Value.absent(),
                Value<int> outputTokens = const Value.absent(),
                Value<int> reasoningTokens = const Value.absent(),
                Value<bool> error = const Value.absent(),
              }) => UsageRowsCompanion(
                id: id,
                timestamp: timestamp,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                reasoningTokens: reasoningTokens,
                error: error,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int timestamp,
                required String model,
                required int inputTokens,
                required int outputTokens,
                Value<int> reasoningTokens = const Value.absent(),
                Value<bool> error = const Value.absent(),
              }) => UsageRowsCompanion.insert(
                id: id,
                timestamp: timestamp,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                reasoningTokens: reasoningTokens,
                error: error,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsageRowsTable,
      UsageRow,
      $$UsageRowsTableFilterComposer,
      $$UsageRowsTableOrderingComposer,
      $$UsageRowsTableAnnotationComposer,
      $$UsageRowsTableCreateCompanionBuilder,
      $$UsageRowsTableUpdateCompanionBuilder,
      (UsageRow, BaseReferences<_$AppDatabase, $UsageRowsTable, UsageRow>),
      UsageRow,
      PrefetchHooks Function()
    >;
typedef $$ScheduledTaskRowsTableCreateCompanionBuilder =
    ScheduledTaskRowsCompanion Function({
      required String id,
      required String name,
      required String prompt,
      required int hour,
      required int minute,
      Value<int> weekdaysMask,
      Value<bool> enabled,
      Value<int?> lastRunAt,
      Value<int> rowid,
    });
typedef $$ScheduledTaskRowsTableUpdateCompanionBuilder =
    ScheduledTaskRowsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> prompt,
      Value<int> hour,
      Value<int> minute,
      Value<int> weekdaysMask,
      Value<bool> enabled,
      Value<int?> lastRunAt,
      Value<int> rowid,
    });

class $$ScheduledTaskRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledTaskRowsTable> {
  $$ScheduledTaskRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekdaysMask => $composableBuilder(
    column: $table.weekdaysMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastRunAt => $composableBuilder(
    column: $table.lastRunAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduledTaskRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledTaskRowsTable> {
  $$ScheduledTaskRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekdaysMask => $composableBuilder(
    column: $table.weekdaysMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRunAt => $composableBuilder(
    column: $table.lastRunAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduledTaskRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledTaskRowsTable> {
  $$ScheduledTaskRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<int> get weekdaysMask => $composableBuilder(
    column: $table.weekdaysMask,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get lastRunAt =>
      $composableBuilder(column: $table.lastRunAt, builder: (column) => column);
}

class $$ScheduledTaskRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledTaskRowsTable,
          ScheduledTaskRow,
          $$ScheduledTaskRowsTableFilterComposer,
          $$ScheduledTaskRowsTableOrderingComposer,
          $$ScheduledTaskRowsTableAnnotationComposer,
          $$ScheduledTaskRowsTableCreateCompanionBuilder,
          $$ScheduledTaskRowsTableUpdateCompanionBuilder,
          (
            ScheduledTaskRow,
            BaseReferences<
              _$AppDatabase,
              $ScheduledTaskRowsTable,
              ScheduledTaskRow
            >,
          ),
          ScheduledTaskRow,
          PrefetchHooks Function()
        > {
  $$ScheduledTaskRowsTableTableManager(
    _$AppDatabase db,
    $ScheduledTaskRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledTaskRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduledTaskRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduledTaskRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> minute = const Value.absent(),
                Value<int> weekdaysMask = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int?> lastRunAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduledTaskRowsCompanion(
                id: id,
                name: name,
                prompt: prompt,
                hour: hour,
                minute: minute,
                weekdaysMask: weekdaysMask,
                enabled: enabled,
                lastRunAt: lastRunAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String prompt,
                required int hour,
                required int minute,
                Value<int> weekdaysMask = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int?> lastRunAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduledTaskRowsCompanion.insert(
                id: id,
                name: name,
                prompt: prompt,
                hour: hour,
                minute: minute,
                weekdaysMask: weekdaysMask,
                enabled: enabled,
                lastRunAt: lastRunAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduledTaskRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledTaskRowsTable,
      ScheduledTaskRow,
      $$ScheduledTaskRowsTableFilterComposer,
      $$ScheduledTaskRowsTableOrderingComposer,
      $$ScheduledTaskRowsTableAnnotationComposer,
      $$ScheduledTaskRowsTableCreateCompanionBuilder,
      $$ScheduledTaskRowsTableUpdateCompanionBuilder,
      (
        ScheduledTaskRow,
        BaseReferences<
          _$AppDatabase,
          $ScheduledTaskRowsTable,
          ScheduledTaskRow
        >,
      ),
      ScheduledTaskRow,
      PrefetchHooks Function()
    >;
typedef $$ScheduledTaskRunRowsTableCreateCompanionBuilder =
    ScheduledTaskRunRowsCompanion Function({
      Value<int> id,
      required String taskId,
      required int startedAt,
      required bool ok,
      Value<String> preview,
    });
typedef $$ScheduledTaskRunRowsTableUpdateCompanionBuilder =
    ScheduledTaskRunRowsCompanion Function({
      Value<int> id,
      Value<String> taskId,
      Value<int> startedAt,
      Value<bool> ok,
      Value<String> preview,
    });

class $$ScheduledTaskRunRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledTaskRunRowsTable> {
  $$ScheduledTaskRunRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduledTaskRunRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledTaskRunRowsTable> {
  $$ScheduledTaskRunRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduledTaskRunRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledTaskRunRowsTable> {
  $$ScheduledTaskRunRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<bool> get ok =>
      $composableBuilder(column: $table.ok, builder: (column) => column);

  GeneratedColumn<String> get preview =>
      $composableBuilder(column: $table.preview, builder: (column) => column);
}

class $$ScheduledTaskRunRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledTaskRunRowsTable,
          ScheduledTaskRunRow,
          $$ScheduledTaskRunRowsTableFilterComposer,
          $$ScheduledTaskRunRowsTableOrderingComposer,
          $$ScheduledTaskRunRowsTableAnnotationComposer,
          $$ScheduledTaskRunRowsTableCreateCompanionBuilder,
          $$ScheduledTaskRunRowsTableUpdateCompanionBuilder,
          (
            ScheduledTaskRunRow,
            BaseReferences<
              _$AppDatabase,
              $ScheduledTaskRunRowsTable,
              ScheduledTaskRunRow
            >,
          ),
          ScheduledTaskRunRow,
          PrefetchHooks Function()
        > {
  $$ScheduledTaskRunRowsTableTableManager(
    _$AppDatabase db,
    $ScheduledTaskRunRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledTaskRunRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduledTaskRunRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduledTaskRunRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<bool> ok = const Value.absent(),
                Value<String> preview = const Value.absent(),
              }) => ScheduledTaskRunRowsCompanion(
                id: id,
                taskId: taskId,
                startedAt: startedAt,
                ok: ok,
                preview: preview,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String taskId,
                required int startedAt,
                required bool ok,
                Value<String> preview = const Value.absent(),
              }) => ScheduledTaskRunRowsCompanion.insert(
                id: id,
                taskId: taskId,
                startedAt: startedAt,
                ok: ok,
                preview: preview,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduledTaskRunRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledTaskRunRowsTable,
      ScheduledTaskRunRow,
      $$ScheduledTaskRunRowsTableFilterComposer,
      $$ScheduledTaskRunRowsTableOrderingComposer,
      $$ScheduledTaskRunRowsTableAnnotationComposer,
      $$ScheduledTaskRunRowsTableCreateCompanionBuilder,
      $$ScheduledTaskRunRowsTableUpdateCompanionBuilder,
      (
        ScheduledTaskRunRow,
        BaseReferences<
          _$AppDatabase,
          $ScheduledTaskRunRowsTable,
          ScheduledTaskRunRow
        >,
      ),
      ScheduledTaskRunRow,
      PrefetchHooks Function()
    >;
typedef $$PlanSpaceMetaRowsTableCreateCompanionBuilder =
    PlanSpaceMetaRowsCompanion Function({
      required String id,
      required int revision,
      Value<String> bin,
      Value<int> rowid,
    });
typedef $$PlanSpaceMetaRowsTableUpdateCompanionBuilder =
    PlanSpaceMetaRowsCompanion Function({
      Value<String> id,
      Value<int> revision,
      Value<String> bin,
      Value<int> rowid,
    });

class $$PlanSpaceMetaRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PlanSpaceMetaRowsTable> {
  $$PlanSpaceMetaRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bin => $composableBuilder(
    column: $table.bin,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlanSpaceMetaRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanSpaceMetaRowsTable> {
  $$PlanSpaceMetaRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bin => $composableBuilder(
    column: $table.bin,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlanSpaceMetaRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanSpaceMetaRowsTable> {
  $$PlanSpaceMetaRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get bin =>
      $composableBuilder(column: $table.bin, builder: (column) => column);
}

class $$PlanSpaceMetaRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanSpaceMetaRowsTable,
          PlanSpaceMetaRow,
          $$PlanSpaceMetaRowsTableFilterComposer,
          $$PlanSpaceMetaRowsTableOrderingComposer,
          $$PlanSpaceMetaRowsTableAnnotationComposer,
          $$PlanSpaceMetaRowsTableCreateCompanionBuilder,
          $$PlanSpaceMetaRowsTableUpdateCompanionBuilder,
          (
            PlanSpaceMetaRow,
            BaseReferences<
              _$AppDatabase,
              $PlanSpaceMetaRowsTable,
              PlanSpaceMetaRow
            >,
          ),
          PlanSpaceMetaRow,
          PrefetchHooks Function()
        > {
  $$PlanSpaceMetaRowsTableTableManager(
    _$AppDatabase db,
    $PlanSpaceMetaRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanSpaceMetaRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanSpaceMetaRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanSpaceMetaRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> bin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanSpaceMetaRowsCompanion(
                id: id,
                revision: revision,
                bin: bin,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int revision,
                Value<String> bin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanSpaceMetaRowsCompanion.insert(
                id: id,
                revision: revision,
                bin: bin,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlanSpaceMetaRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanSpaceMetaRowsTable,
      PlanSpaceMetaRow,
      $$PlanSpaceMetaRowsTableFilterComposer,
      $$PlanSpaceMetaRowsTableOrderingComposer,
      $$PlanSpaceMetaRowsTableAnnotationComposer,
      $$PlanSpaceMetaRowsTableCreateCompanionBuilder,
      $$PlanSpaceMetaRowsTableUpdateCompanionBuilder,
      (
        PlanSpaceMetaRow,
        BaseReferences<
          _$AppDatabase,
          $PlanSpaceMetaRowsTable,
          PlanSpaceMetaRow
        >,
      ),
      PlanSpaceMetaRow,
      PrefetchHooks Function()
    >;
typedef $$PlanRecordRowsTableCreateCompanionBuilder =
    PlanRecordRowsCompanion Function({
      required String kind,
      required String id,
      required String payload,
      Value<int> rowid,
    });
typedef $$PlanRecordRowsTableUpdateCompanionBuilder =
    PlanRecordRowsCompanion Function({
      Value<String> kind,
      Value<String> id,
      Value<String> payload,
      Value<int> rowid,
    });

class $$PlanRecordRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PlanRecordRowsTable> {
  $$PlanRecordRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlanRecordRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanRecordRowsTable> {
  $$PlanRecordRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlanRecordRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanRecordRowsTable> {
  $$PlanRecordRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$PlanRecordRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanRecordRowsTable,
          PlanRecordRow,
          $$PlanRecordRowsTableFilterComposer,
          $$PlanRecordRowsTableOrderingComposer,
          $$PlanRecordRowsTableAnnotationComposer,
          $$PlanRecordRowsTableCreateCompanionBuilder,
          $$PlanRecordRowsTableUpdateCompanionBuilder,
          (
            PlanRecordRow,
            BaseReferences<_$AppDatabase, $PlanRecordRowsTable, PlanRecordRow>,
          ),
          PlanRecordRow,
          PrefetchHooks Function()
        > {
  $$PlanRecordRowsTableTableManager(
    _$AppDatabase db,
    $PlanRecordRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanRecordRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanRecordRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanRecordRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanRecordRowsCompanion(
                kind: kind,
                id: id,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String id,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => PlanRecordRowsCompanion.insert(
                kind: kind,
                id: id,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlanRecordRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanRecordRowsTable,
      PlanRecordRow,
      $$PlanRecordRowsTableFilterComposer,
      $$PlanRecordRowsTableOrderingComposer,
      $$PlanRecordRowsTableAnnotationComposer,
      $$PlanRecordRowsTableCreateCompanionBuilder,
      $$PlanRecordRowsTableUpdateCompanionBuilder,
      (
        PlanRecordRow,
        BaseReferences<_$AppDatabase, $PlanRecordRowsTable, PlanRecordRow>,
      ),
      PlanRecordRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsageRowsTableTableManager get usageRows =>
      $$UsageRowsTableTableManager(_db, _db.usageRows);
  $$ScheduledTaskRowsTableTableManager get scheduledTaskRows =>
      $$ScheduledTaskRowsTableTableManager(_db, _db.scheduledTaskRows);
  $$ScheduledTaskRunRowsTableTableManager get scheduledTaskRunRows =>
      $$ScheduledTaskRunRowsTableTableManager(_db, _db.scheduledTaskRunRows);
  $$PlanSpaceMetaRowsTableTableManager get planSpaceMetaRows =>
      $$PlanSpaceMetaRowsTableTableManager(_db, _db.planSpaceMetaRows);
  $$PlanRecordRowsTableTableManager get planRecordRows =>
      $$PlanRecordRowsTableTableManager(_db, _db.planRecordRows);
}
