// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_operation_success.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationOperationSuccess {

 bool get success;
/// Create a copy of OrganizationOperationSuccess
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationOperationSuccessCopyWith<OrganizationOperationSuccess> get copyWith => _$OrganizationOperationSuccessCopyWithImpl<OrganizationOperationSuccess>(this as OrganizationOperationSuccess, _$identity);

  /// Serializes this OrganizationOperationSuccess to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationOperationSuccess&&(identical(other.success, success) || other.success == success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success);

@override
String toString() {
  return 'OrganizationOperationSuccess(success: $success)';
}


}

/// @nodoc
abstract mixin class $OrganizationOperationSuccessCopyWith<$Res>  {
  factory $OrganizationOperationSuccessCopyWith(OrganizationOperationSuccess value, $Res Function(OrganizationOperationSuccess) _then) = _$OrganizationOperationSuccessCopyWithImpl;
@useResult
$Res call({
 bool success
});




}
/// @nodoc
class _$OrganizationOperationSuccessCopyWithImpl<$Res>
    implements $OrganizationOperationSuccessCopyWith<$Res> {
  _$OrganizationOperationSuccessCopyWithImpl(this._self, this._then);

  final OrganizationOperationSuccess _self;
  final $Res Function(OrganizationOperationSuccess) _then;

/// Create a copy of OrganizationOperationSuccess
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [OrganizationOperationSuccess].
extension OrganizationOperationSuccessPatterns on OrganizationOperationSuccess {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationOperationSuccess value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationOperationSuccess() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationOperationSuccess value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationOperationSuccess():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationOperationSuccess value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationOperationSuccess() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationOperationSuccess() when $default != null:
return $default(_that.success);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success)  $default,) {final _that = this;
switch (_that) {
case _OrganizationOperationSuccess():
return $default(_that.success);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationOperationSuccess() when $default != null:
return $default(_that.success);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationOperationSuccess implements OrganizationOperationSuccess {
  const _OrganizationOperationSuccess({required this.success});
  factory _OrganizationOperationSuccess.fromJson(Map<String, dynamic> json) => _$OrganizationOperationSuccessFromJson(json);

@override final  bool success;

/// Create a copy of OrganizationOperationSuccess
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationOperationSuccessCopyWith<_OrganizationOperationSuccess> get copyWith => __$OrganizationOperationSuccessCopyWithImpl<_OrganizationOperationSuccess>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationOperationSuccessToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationOperationSuccess&&(identical(other.success, success) || other.success == success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success);

@override
String toString() {
  return 'OrganizationOperationSuccess(success: $success)';
}


}

/// @nodoc
abstract mixin class _$OrganizationOperationSuccessCopyWith<$Res> implements $OrganizationOperationSuccessCopyWith<$Res> {
  factory _$OrganizationOperationSuccessCopyWith(_OrganizationOperationSuccess value, $Res Function(_OrganizationOperationSuccess) _then) = __$OrganizationOperationSuccessCopyWithImpl;
@override @useResult
$Res call({
 bool success
});




}
/// @nodoc
class __$OrganizationOperationSuccessCopyWithImpl<$Res>
    implements _$OrganizationOperationSuccessCopyWith<$Res> {
  __$OrganizationOperationSuccessCopyWithImpl(this._self, this._then);

  final _OrganizationOperationSuccess _self;
  final $Res Function(_OrganizationOperationSuccess) _then;

/// Create a copy of OrganizationOperationSuccess
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,}) {
  return _then(_OrganizationOperationSuccess(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
