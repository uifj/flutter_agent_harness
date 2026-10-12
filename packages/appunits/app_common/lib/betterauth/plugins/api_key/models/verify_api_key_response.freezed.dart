// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'verify_api_key_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApiKeyVerifyError {

 String get message; String get code;
/// Create a copy of ApiKeyVerifyError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiKeyVerifyErrorCopyWith<ApiKeyVerifyError> get copyWith => _$ApiKeyVerifyErrorCopyWithImpl<ApiKeyVerifyError>(this as ApiKeyVerifyError, _$identity);

  /// Serializes this ApiKeyVerifyError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiKeyVerifyError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,code);

@override
String toString() {
  return 'ApiKeyVerifyError(message: $message, code: $code)';
}


}

/// @nodoc
abstract mixin class $ApiKeyVerifyErrorCopyWith<$Res>  {
  factory $ApiKeyVerifyErrorCopyWith(ApiKeyVerifyError value, $Res Function(ApiKeyVerifyError) _then) = _$ApiKeyVerifyErrorCopyWithImpl;
@useResult
$Res call({
 String message, String code
});




}
/// @nodoc
class _$ApiKeyVerifyErrorCopyWithImpl<$Res>
    implements $ApiKeyVerifyErrorCopyWith<$Res> {
  _$ApiKeyVerifyErrorCopyWithImpl(this._self, this._then);

  final ApiKeyVerifyError _self;
  final $Res Function(ApiKeyVerifyError) _then;

/// Create a copy of ApiKeyVerifyError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? code = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiKeyVerifyError].
extension ApiKeyVerifyErrorPatterns on ApiKeyVerifyError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiKeyVerifyError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiKeyVerifyError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiKeyVerifyError value)  $default,){
final _that = this;
switch (_that) {
case _ApiKeyVerifyError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiKeyVerifyError value)?  $default,){
final _that = this;
switch (_that) {
case _ApiKeyVerifyError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  String code)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiKeyVerifyError() when $default != null:
return $default(_that.message,_that.code);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  String code)  $default,) {final _that = this;
switch (_that) {
case _ApiKeyVerifyError():
return $default(_that.message,_that.code);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  String code)?  $default,) {final _that = this;
switch (_that) {
case _ApiKeyVerifyError() when $default != null:
return $default(_that.message,_that.code);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiKeyVerifyError implements ApiKeyVerifyError {
  const _ApiKeyVerifyError({required this.message, required this.code});
  factory _ApiKeyVerifyError.fromJson(Map<String, dynamic> json) => _$ApiKeyVerifyErrorFromJson(json);

@override final  String message;
@override final  String code;

/// Create a copy of ApiKeyVerifyError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiKeyVerifyErrorCopyWith<_ApiKeyVerifyError> get copyWith => __$ApiKeyVerifyErrorCopyWithImpl<_ApiKeyVerifyError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiKeyVerifyErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiKeyVerifyError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,code);

@override
String toString() {
  return 'ApiKeyVerifyError(message: $message, code: $code)';
}


}

/// @nodoc
abstract mixin class _$ApiKeyVerifyErrorCopyWith<$Res> implements $ApiKeyVerifyErrorCopyWith<$Res> {
  factory _$ApiKeyVerifyErrorCopyWith(_ApiKeyVerifyError value, $Res Function(_ApiKeyVerifyError) _then) = __$ApiKeyVerifyErrorCopyWithImpl;
@override @useResult
$Res call({
 String message, String code
});




}
/// @nodoc
class __$ApiKeyVerifyErrorCopyWithImpl<$Res>
    implements _$ApiKeyVerifyErrorCopyWith<$Res> {
  __$ApiKeyVerifyErrorCopyWithImpl(this._self, this._then);

  final _ApiKeyVerifyError _self;
  final $Res Function(_ApiKeyVerifyError) _then;

/// Create a copy of ApiKeyVerifyError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? code = null,}) {
  return _then(_ApiKeyVerifyError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$VerifyApiKeyResponse {

 bool get valid; ApiKeyVerifyError? get error; ApiKeyModel? get key;
/// Create a copy of VerifyApiKeyResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VerifyApiKeyResponseCopyWith<VerifyApiKeyResponse> get copyWith => _$VerifyApiKeyResponseCopyWithImpl<VerifyApiKeyResponse>(this as VerifyApiKeyResponse, _$identity);

  /// Serializes this VerifyApiKeyResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VerifyApiKeyResponse&&(identical(other.valid, valid) || other.valid == valid)&&(identical(other.error, error) || other.error == error)&&(identical(other.key, key) || other.key == key));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,valid,error,key);

@override
String toString() {
  return 'VerifyApiKeyResponse(valid: $valid, error: $error, key: $key)';
}


}

/// @nodoc
abstract mixin class $VerifyApiKeyResponseCopyWith<$Res>  {
  factory $VerifyApiKeyResponseCopyWith(VerifyApiKeyResponse value, $Res Function(VerifyApiKeyResponse) _then) = _$VerifyApiKeyResponseCopyWithImpl;
@useResult
$Res call({
 bool valid, ApiKeyVerifyError? error, ApiKeyModel? key
});


$ApiKeyVerifyErrorCopyWith<$Res>? get error;$ApiKeyModelCopyWith<$Res>? get key;

}
/// @nodoc
class _$VerifyApiKeyResponseCopyWithImpl<$Res>
    implements $VerifyApiKeyResponseCopyWith<$Res> {
  _$VerifyApiKeyResponseCopyWithImpl(this._self, this._then);

  final VerifyApiKeyResponse _self;
  final $Res Function(VerifyApiKeyResponse) _then;

/// Create a copy of VerifyApiKeyResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? valid = null,Object? error = freezed,Object? key = freezed,}) {
  return _then(_self.copyWith(
valid: null == valid ? _self.valid : valid // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiKeyVerifyError?,key: freezed == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as ApiKeyModel?,
  ));
}
/// Create a copy of VerifyApiKeyResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiKeyVerifyErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $ApiKeyVerifyErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}/// Create a copy of VerifyApiKeyResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiKeyModelCopyWith<$Res>? get key {
    if (_self.key == null) {
    return null;
  }

  return $ApiKeyModelCopyWith<$Res>(_self.key!, (value) {
    return _then(_self.copyWith(key: value));
  });
}
}


/// Adds pattern-matching-related methods to [VerifyApiKeyResponse].
extension VerifyApiKeyResponsePatterns on VerifyApiKeyResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VerifyApiKeyResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VerifyApiKeyResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VerifyApiKeyResponse value)  $default,){
final _that = this;
switch (_that) {
case _VerifyApiKeyResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VerifyApiKeyResponse value)?  $default,){
final _that = this;
switch (_that) {
case _VerifyApiKeyResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool valid,  ApiKeyVerifyError? error,  ApiKeyModel? key)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VerifyApiKeyResponse() when $default != null:
return $default(_that.valid,_that.error,_that.key);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool valid,  ApiKeyVerifyError? error,  ApiKeyModel? key)  $default,) {final _that = this;
switch (_that) {
case _VerifyApiKeyResponse():
return $default(_that.valid,_that.error,_that.key);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool valid,  ApiKeyVerifyError? error,  ApiKeyModel? key)?  $default,) {final _that = this;
switch (_that) {
case _VerifyApiKeyResponse() when $default != null:
return $default(_that.valid,_that.error,_that.key);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VerifyApiKeyResponse implements VerifyApiKeyResponse {
  const _VerifyApiKeyResponse({required this.valid, this.error, this.key});
  factory _VerifyApiKeyResponse.fromJson(Map<String, dynamic> json) => _$VerifyApiKeyResponseFromJson(json);

@override final  bool valid;
@override final  ApiKeyVerifyError? error;
@override final  ApiKeyModel? key;

/// Create a copy of VerifyApiKeyResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyApiKeyResponseCopyWith<_VerifyApiKeyResponse> get copyWith => __$VerifyApiKeyResponseCopyWithImpl<_VerifyApiKeyResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VerifyApiKeyResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyApiKeyResponse&&(identical(other.valid, valid) || other.valid == valid)&&(identical(other.error, error) || other.error == error)&&(identical(other.key, key) || other.key == key));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,valid,error,key);

@override
String toString() {
  return 'VerifyApiKeyResponse(valid: $valid, error: $error, key: $key)';
}


}

/// @nodoc
abstract mixin class _$VerifyApiKeyResponseCopyWith<$Res> implements $VerifyApiKeyResponseCopyWith<$Res> {
  factory _$VerifyApiKeyResponseCopyWith(_VerifyApiKeyResponse value, $Res Function(_VerifyApiKeyResponse) _then) = __$VerifyApiKeyResponseCopyWithImpl;
@override @useResult
$Res call({
 bool valid, ApiKeyVerifyError? error, ApiKeyModel? key
});


@override $ApiKeyVerifyErrorCopyWith<$Res>? get error;@override $ApiKeyModelCopyWith<$Res>? get key;

}
/// @nodoc
class __$VerifyApiKeyResponseCopyWithImpl<$Res>
    implements _$VerifyApiKeyResponseCopyWith<$Res> {
  __$VerifyApiKeyResponseCopyWithImpl(this._self, this._then);

  final _VerifyApiKeyResponse _self;
  final $Res Function(_VerifyApiKeyResponse) _then;

/// Create a copy of VerifyApiKeyResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? valid = null,Object? error = freezed,Object? key = freezed,}) {
  return _then(_VerifyApiKeyResponse(
valid: null == valid ? _self.valid : valid // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiKeyVerifyError?,key: freezed == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as ApiKeyModel?,
  ));
}

/// Create a copy of VerifyApiKeyResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiKeyVerifyErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $ApiKeyVerifyErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}/// Create a copy of VerifyApiKeyResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiKeyModelCopyWith<$Res>? get key {
    if (_self.key == null) {
    return null;
  }

  return $ApiKeyModelCopyWith<$Res>(_self.key!, (value) {
    return _then(_self.copyWith(key: value));
  });
}
}

// dart format on
