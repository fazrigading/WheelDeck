// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'discovered_server.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiscoveredServer {

/// IP address the WebSocket listener is reachable at.
 String get host;/// WebSocket port the desktop server listens on.
 int get port;/// Human-readable service instance name, for the selection UI.
 String get name;
/// Create a copy of DiscoveredServer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiscoveredServerCopyWith<DiscoveredServer> get copyWith => _$DiscoveredServerCopyWithImpl<DiscoveredServer>(this as DiscoveredServer, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DiscoveredServer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoveredServer&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.name, _this.name) || other.name == _this.name));
}


@override
int get hashCode {
  final _this = this as DiscoveredServer;
  return Object.hash(runtimeType,_this.host,_this.port,_this.name);
}

@override
String toString() {
  final _this = this as DiscoveredServer;
  return 'DiscoveredServer(host: ${_this.host}, port: ${_this.port}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $DiscoveredServerCopyWith<$Res>  {
  factory $DiscoveredServerCopyWith(DiscoveredServer value, $Res Function(DiscoveredServer) _then) = _$DiscoveredServerCopyWithImpl;
@useResult
$Res call({
 String host, int port, String name
});




}
/// @nodoc
class _$DiscoveredServerCopyWithImpl<$Res>
    implements $DiscoveredServerCopyWith<$Res> {
  _$DiscoveredServerCopyWithImpl(this._self, this._then);

  final DiscoveredServer _self;
  final $Res Function(DiscoveredServer) _then;

/// Create a copy of DiscoveredServer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? host = null,Object? port = null,Object? name = null,}) {
  return _then(DiscoveredServer(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DiscoveredServer].
extension DiscoveredServerPatterns on DiscoveredServer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiscoveredServer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiscoveredServer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiscoveredServer value)  $default,){
final _that = this;
switch (_that) {
case _DiscoveredServer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiscoveredServer value)?  $default,){
final _that = this;
switch (_that) {
case _DiscoveredServer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String host,  int port,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiscoveredServer() when $default != null:
return $default(_that.host,_that.port,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String host,  int port,  String name)  $default,) {final _that = this;
switch (_that) {
case _DiscoveredServer():
return $default(_that.host,_that.port,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String host,  int port,  String name)?  $default,) {final _that = this;
switch (_that) {
case _DiscoveredServer() when $default != null:
return $default(_that.host,_that.port,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class _DiscoveredServer extends DiscoveredServer {
  const _DiscoveredServer({required this.host, required this.port, required this.name}): super._();
  

/// IP address the WebSocket listener is reachable at.
@override final  String host;
/// WebSocket port the desktop server listens on.
@override final  int port;
/// Human-readable service instance name, for the selection UI.
@override final  String name;

/// Create a copy of DiscoveredServer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiscoveredServerCopyWith<_DiscoveredServer> get copyWith => __$DiscoveredServerCopyWithImpl<_DiscoveredServer>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiscoveredServer&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,host,port,name);
}

@override
String toString() {
    return 'DiscoveredServer(host: $host, port: $port, name: $name)';
}


}

/// @nodoc
abstract mixin class _$DiscoveredServerCopyWith<$Res> implements $DiscoveredServerCopyWith<$Res> {
  factory _$DiscoveredServerCopyWith(_DiscoveredServer value, $Res Function(_DiscoveredServer) _then) = __$DiscoveredServerCopyWithImpl;
@override @useResult
$Res call({
 String host, int port, String name
});




}
/// @nodoc
class __$DiscoveredServerCopyWithImpl<$Res>
    implements _$DiscoveredServerCopyWith<$Res> {
  __$DiscoveredServerCopyWithImpl(this._self, this._then);

  final _DiscoveredServer _self;
  final $Res Function(_DiscoveredServer) _then;

/// Create a copy of DiscoveredServer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? host = null,Object? port = null,Object? name = null,}) {
  return _then(_DiscoveredServer(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
