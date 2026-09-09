// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pedal_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PedalState {

 double get accelerator; double get brake; double get clutch;
/// Create a copy of PedalState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedalStateCopyWith<PedalState> get copyWith => _$PedalStateCopyWithImpl<PedalState>(this as PedalState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PedalState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PedalState&&(identical(other.accelerator, _this.accelerator) || other.accelerator == _this.accelerator)&&(identical(other.brake, _this.brake) || other.brake == _this.brake)&&(identical(other.clutch, _this.clutch) || other.clutch == _this.clutch));
}


@override
int get hashCode {
  final _this = this as PedalState;
  return Object.hash(runtimeType,_this.accelerator,_this.brake,_this.clutch);
}

@override
String toString() {
  final _this = this as PedalState;
  return 'PedalState(accelerator: ${_this.accelerator}, brake: ${_this.brake}, clutch: ${_this.clutch})';
}


}

/// @nodoc
abstract mixin class $PedalStateCopyWith<$Res>  {
  factory $PedalStateCopyWith(PedalState value, $Res Function(PedalState) _then) = _$PedalStateCopyWithImpl;
@useResult
$Res call({
 double accelerator, double brake, double clutch
});




}
/// @nodoc
class _$PedalStateCopyWithImpl<$Res>
    implements $PedalStateCopyWith<$Res> {
  _$PedalStateCopyWithImpl(this._self, this._then);

  final PedalState _self;
  final $Res Function(PedalState) _then;

/// Create a copy of PedalState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accelerator = null,Object? brake = null,Object? clutch = null,}) {
  return _then(PedalState(
accelerator: null == accelerator ? _self.accelerator : accelerator // ignore: cast_nullable_to_non_nullable
as double,brake: null == brake ? _self.brake : brake // ignore: cast_nullable_to_non_nullable
as double,clutch: null == clutch ? _self.clutch : clutch // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [PedalState].
extension PedalStatePatterns on PedalState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PedalState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PedalState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PedalState value)  $default,){
final _that = this;
switch (_that) {
case _PedalState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PedalState value)?  $default,){
final _that = this;
switch (_that) {
case _PedalState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double accelerator,  double brake,  double clutch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PedalState() when $default != null:
return $default(_that.accelerator,_that.brake,_that.clutch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double accelerator,  double brake,  double clutch)  $default,) {final _that = this;
switch (_that) {
case _PedalState():
return $default(_that.accelerator,_that.brake,_that.clutch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double accelerator,  double brake,  double clutch)?  $default,) {final _that = this;
switch (_that) {
case _PedalState() when $default != null:
return $default(_that.accelerator,_that.brake,_that.clutch);case _:
  return null;

}
}

}

/// @nodoc


class _PedalState extends PedalState {
  const _PedalState({this.accelerator = 0.0, this.brake = 0.0, this.clutch = 0.0}): super._();
  

@override@JsonKey() final  double accelerator;
@override@JsonKey() final  double brake;
@override@JsonKey() final  double clutch;

/// Create a copy of PedalState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PedalStateCopyWith<_PedalState> get copyWith => __$PedalStateCopyWithImpl<_PedalState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PedalState&&(identical(other.accelerator, accelerator) || other.accelerator == accelerator)&&(identical(other.brake, brake) || other.brake == brake)&&(identical(other.clutch, clutch) || other.clutch == clutch));
}


@override
int get hashCode {
    return Object.hash(runtimeType,accelerator,brake,clutch);
}

@override
String toString() {
    return 'PedalState(accelerator: $accelerator, brake: $brake, clutch: $clutch)';
}


}

/// @nodoc
abstract mixin class _$PedalStateCopyWith<$Res> implements $PedalStateCopyWith<$Res> {
  factory _$PedalStateCopyWith(_PedalState value, $Res Function(_PedalState) _then) = __$PedalStateCopyWithImpl;
@override @useResult
$Res call({
 double accelerator, double brake, double clutch
});




}
/// @nodoc
class __$PedalStateCopyWithImpl<$Res>
    implements _$PedalStateCopyWith<$Res> {
  __$PedalStateCopyWithImpl(this._self, this._then);

  final _PedalState _self;
  final $Res Function(_PedalState) _then;

/// Create a copy of PedalState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accelerator = null,Object? brake = null,Object? clutch = null,}) {
  return _then(_PedalState(
accelerator: null == accelerator ? _self.accelerator : accelerator // ignore: cast_nullable_to_non_nullable
as double,brake: null == brake ? _self.brake : brake // ignore: cast_nullable_to_non_nullable
as double,clutch: null == clutch ? _self.clutch : clutch // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
