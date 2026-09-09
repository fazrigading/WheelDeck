// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pairing_challenge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PairingChallenge {

 PairingMethod get method;
/// Create a copy of PairingChallenge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairingChallengeCopyWith<PairingChallenge> get copyWith => _$PairingChallengeCopyWithImpl<PairingChallenge>(this as PairingChallenge, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PairingChallenge;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingChallenge&&(identical(other.method, _this.method) || other.method == _this.method));
}


@override
int get hashCode {
  final _this = this as PairingChallenge;
  return Object.hash(runtimeType,_this.method);
}

@override
String toString() {
  final _this = this as PairingChallenge;
  return 'PairingChallenge(method: ${_this.method})';
}


}

/// @nodoc
abstract mixin class $PairingChallengeCopyWith<$Res>  {
  factory $PairingChallengeCopyWith(PairingChallenge value, $Res Function(PairingChallenge) _then) = _$PairingChallengeCopyWithImpl;
@useResult
$Res call({
 PairingMethod method
});




}
/// @nodoc
class _$PairingChallengeCopyWithImpl<$Res>
    implements $PairingChallengeCopyWith<$Res> {
  _$PairingChallengeCopyWithImpl(this._self, this._then);

  final PairingChallenge _self;
  final $Res Function(PairingChallenge) _then;

/// Create a copy of PairingChallenge
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? method = null,}) {
  return _then(PairingChallenge(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PairingMethod,
  ));
}

}


/// Adds pattern-matching-related methods to [PairingChallenge].
extension PairingChallengePatterns on PairingChallenge {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PairingChallenge value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PairingChallenge() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PairingChallenge value)  $default,){
final _that = this;
switch (_that) {
case _PairingChallenge():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PairingChallenge value)?  $default,){
final _that = this;
switch (_that) {
case _PairingChallenge() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PairingMethod method)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PairingChallenge() when $default != null:
return $default(_that.method);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PairingMethod method)  $default,) {final _that = this;
switch (_that) {
case _PairingChallenge():
return $default(_that.method);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PairingMethod method)?  $default,) {final _that = this;
switch (_that) {
case _PairingChallenge() when $default != null:
return $default(_that.method);case _:
  return null;

}
}

}

/// @nodoc


class _PairingChallenge implements PairingChallenge {
  const _PairingChallenge({required this.method});
  

@override final  PairingMethod method;

/// Create a copy of PairingChallenge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PairingChallengeCopyWith<_PairingChallenge> get copyWith => __$PairingChallengeCopyWithImpl<_PairingChallenge>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PairingChallenge&&(identical(other.method, method) || other.method == method));
}


@override
int get hashCode {
    return Object.hash(runtimeType,method);
}

@override
String toString() {
    return 'PairingChallenge(method: $method)';
}


}

/// @nodoc
abstract mixin class _$PairingChallengeCopyWith<$Res> implements $PairingChallengeCopyWith<$Res> {
  factory _$PairingChallengeCopyWith(_PairingChallenge value, $Res Function(_PairingChallenge) _then) = __$PairingChallengeCopyWithImpl;
@override @useResult
$Res call({
 PairingMethod method
});




}
/// @nodoc
class __$PairingChallengeCopyWithImpl<$Res>
    implements _$PairingChallengeCopyWith<$Res> {
  __$PairingChallengeCopyWithImpl(this._self, this._then);

  final _PairingChallenge _self;
  final $Res Function(_PairingChallenge) _then;

/// Create a copy of PairingChallenge
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,}) {
  return _then(_PairingChallenge(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PairingMethod,
  ));
}


}

// dart format on
