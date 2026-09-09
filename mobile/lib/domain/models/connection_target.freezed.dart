// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_target.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConnectionTarget {

 ConnectionMode get mode; String? get ipAddress; int? get port;
/// Create a copy of ConnectionTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionTargetCopyWith<ConnectionTarget> get copyWith => _$ConnectionTargetCopyWithImpl<ConnectionTarget>(this as ConnectionTarget, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ConnectionTarget;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionTarget&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.ipAddress, _this.ipAddress) || other.ipAddress == _this.ipAddress)&&(identical(other.port, _this.port) || other.port == _this.port));
}


@override
int get hashCode {
  final _this = this as ConnectionTarget;
  return Object.hash(runtimeType,_this.mode,_this.ipAddress,_this.port);
}

@override
String toString() {
  final _this = this as ConnectionTarget;
  return 'ConnectionTarget(mode: ${_this.mode}, ipAddress: ${_this.ipAddress}, port: ${_this.port})';
}


}

/// @nodoc
abstract mixin class $ConnectionTargetCopyWith<$Res>  {
  factory $ConnectionTargetCopyWith(ConnectionTarget value, $Res Function(ConnectionTarget) _then) = _$ConnectionTargetCopyWithImpl;
@useResult
$Res call({
 ConnectionMode mode, String? ipAddress, int? port
});




}
/// @nodoc
class _$ConnectionTargetCopyWithImpl<$Res>
    implements $ConnectionTargetCopyWith<$Res> {
  _$ConnectionTargetCopyWithImpl(this._self, this._then);

  final ConnectionTarget _self;
  final $Res Function(ConnectionTarget) _then;

/// Create a copy of ConnectionTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? ipAddress = freezed,Object? port = freezed,}) {
  return _then(ConnectionTarget(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ConnectionMode,ipAddress: freezed == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ConnectionTarget].
extension ConnectionTargetPatterns on ConnectionTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectionTarget value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectionTarget() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectionTarget value)  $default,){
final _that = this;
switch (_that) {
case _ConnectionTarget():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectionTarget value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectionTarget() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ConnectionMode mode,  String? ipAddress,  int? port)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectionTarget() when $default != null:
return $default(_that.mode,_that.ipAddress,_that.port);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ConnectionMode mode,  String? ipAddress,  int? port)  $default,) {final _that = this;
switch (_that) {
case _ConnectionTarget():
return $default(_that.mode,_that.ipAddress,_that.port);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ConnectionMode mode,  String? ipAddress,  int? port)?  $default,) {final _that = this;
switch (_that) {
case _ConnectionTarget() when $default != null:
return $default(_that.mode,_that.ipAddress,_that.port);case _:
  return null;

}
}

}

/// @nodoc


class _ConnectionTarget extends ConnectionTarget {
  const _ConnectionTarget({required this.mode, this.ipAddress, this.port}): super._();
  

@override final  ConnectionMode mode;
@override final  String? ipAddress;
@override final  int? port;

/// Create a copy of ConnectionTarget
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionTargetCopyWith<_ConnectionTarget> get copyWith => __$ConnectionTargetCopyWithImpl<_ConnectionTarget>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectionTarget&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.ipAddress, ipAddress) || other.ipAddress == ipAddress)&&(identical(other.port, port) || other.port == port));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mode,ipAddress,port);
}

@override
String toString() {
    return 'ConnectionTarget(mode: $mode, ipAddress: $ipAddress, port: $port)';
}


}

/// @nodoc
abstract mixin class _$ConnectionTargetCopyWith<$Res> implements $ConnectionTargetCopyWith<$Res> {
  factory _$ConnectionTargetCopyWith(_ConnectionTarget value, $Res Function(_ConnectionTarget) _then) = __$ConnectionTargetCopyWithImpl;
@override @useResult
$Res call({
 ConnectionMode mode, String? ipAddress, int? port
});




}
/// @nodoc
class __$ConnectionTargetCopyWithImpl<$Res>
    implements _$ConnectionTargetCopyWith<$Res> {
  __$ConnectionTargetCopyWithImpl(this._self, this._then);

  final _ConnectionTarget _self;
  final $Res Function(_ConnectionTarget) _then;

/// Create a copy of ConnectionTarget
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? ipAddress = freezed,Object? port = freezed,}) {
  return _then(_ConnectionTarget(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ConnectionMode,ipAddress: freezed == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
