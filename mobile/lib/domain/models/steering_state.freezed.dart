// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'steering_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SteeringState {

 double get angle;
/// Create a copy of SteeringState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SteeringStateCopyWith<SteeringState> get copyWith => _$SteeringStateCopyWithImpl<SteeringState>(this as SteeringState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SteeringState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SteeringState&&(identical(other.angle, _this.angle) || other.angle == _this.angle));
}


@override
int get hashCode {
  final _this = this as SteeringState;
  return Object.hash(runtimeType,_this.angle);
}

@override
String toString() {
  final _this = this as SteeringState;
  return 'SteeringState(angle: ${_this.angle})';
}


}

/// @nodoc
abstract mixin class $SteeringStateCopyWith<$Res>  {
  factory $SteeringStateCopyWith(SteeringState value, $Res Function(SteeringState) _then) = _$SteeringStateCopyWithImpl;
@useResult
$Res call({
 double angle
});




}
/// @nodoc
class _$SteeringStateCopyWithImpl<$Res>
    implements $SteeringStateCopyWith<$Res> {
  _$SteeringStateCopyWithImpl(this._self, this._then);

  final SteeringState _self;
  final $Res Function(SteeringState) _then;

/// Create a copy of SteeringState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? angle = null,}) {
  return _then(SteeringState(
angle: null == angle ? _self.angle : angle // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SteeringState].
extension SteeringStatePatterns on SteeringState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SteeringState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SteeringState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SteeringState value)  $default,){
final _that = this;
switch (_that) {
case _SteeringState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SteeringState value)?  $default,){
final _that = this;
switch (_that) {
case _SteeringState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double angle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SteeringState() when $default != null:
return $default(_that.angle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double angle)  $default,) {final _that = this;
switch (_that) {
case _SteeringState():
return $default(_that.angle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double angle)?  $default,) {final _that = this;
switch (_that) {
case _SteeringState() when $default != null:
return $default(_that.angle);case _:
  return null;

}
}

}

/// @nodoc


class _SteeringState extends SteeringState {
  const _SteeringState({this.angle = 0.0}): super._();
  

@override@JsonKey() final  double angle;

/// Create a copy of SteeringState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SteeringStateCopyWith<_SteeringState> get copyWith => __$SteeringStateCopyWithImpl<_SteeringState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SteeringState&&(identical(other.angle, angle) || other.angle == angle));
}


@override
int get hashCode {
    return Object.hash(runtimeType,angle);
}

@override
String toString() {
    return 'SteeringState(angle: $angle)';
}


}

/// @nodoc
abstract mixin class _$SteeringStateCopyWith<$Res> implements $SteeringStateCopyWith<$Res> {
  factory _$SteeringStateCopyWith(_SteeringState value, $Res Function(_SteeringState) _then) = __$SteeringStateCopyWithImpl;
@override @useResult
$Res call({
 double angle
});




}
/// @nodoc
class __$SteeringStateCopyWithImpl<$Res>
    implements _$SteeringStateCopyWith<$Res> {
  __$SteeringStateCopyWithImpl(this._self, this._then);

  final _SteeringState _self;
  final $Res Function(_SteeringState) _then;

/// Create a copy of SteeringState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? angle = null,}) {
  return _then(_SteeringState(
angle: null == angle ? _self.angle : angle // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
