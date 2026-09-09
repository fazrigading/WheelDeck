import 'package:freezed_annotation/freezed_annotation.dart';

import 'pairing_method.dart';

part 'pairing_challenge.freezed.dart';

/// A prompt for the user to enter a PIN or scan a QR code.
@freezed
abstract class PairingChallenge with _$PairingChallenge {
  const factory PairingChallenge({required PairingMethod method}) =
      _PairingChallenge;
}
