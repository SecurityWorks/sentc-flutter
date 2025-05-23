// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.9.0.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import '../frb_generated.dart';
import 'group.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

// These types are ignored because they are neither used by any `pub` functions nor (for structs and enums) marked `#[frb(unignore)]`: `PrepareLoginOtpOutput`
// These function are ignored because they are on traits that is not defined in current crate (put an empty `#[frb]` on it to unignore): `from`, `from`, `from`, `from`, `from`, `from`, `from`, `from`

Future<Claims> decodeJwt({required String jwt}) =>
    RustLib.instance.api.crateApiUserDecodeJwt(jwt: jwt);

///# Check if the identifier is available for this app
///
Future<bool> checkUserIdentifierAvailable(
        {required String baseUrl,
        required String authToken,
        required String userIdentifier}) =>
    RustLib.instance.api.crateApiUserCheckUserIdentifierAvailable(
        baseUrl: baseUrl, authToken: authToken, userIdentifier: userIdentifier);

///Generates identifier and password for a user or device
///
Future<GeneratedRegisterData> generateUserRegisterData() =>
    RustLib.instance.api.crateApiUserGenerateUserRegisterData();

///# Get the user input from the user client
///
///This is used when the register endpoint should only be called from the backend and not the clients.
///
///For the full register see register()
///
Future<String> prepareRegister(
        {required String userIdentifier, required String password}) =>
    RustLib.instance.api.crateApiUserPrepareRegister(
        userIdentifier: userIdentifier, password: password);

///# Validates the response of register
///
///Returns the new user id
///
Future<String> doneRegister({required String serverOutput}) =>
    RustLib.instance.api.crateApiUserDoneRegister(serverOutput: serverOutput);

///# Register a new user for the app
///
///Do the full req incl. req.
///No checking about spamming and just return the user id.
///
Future<String> register(
        {required String baseUrl,
        required String authToken,
        required String userIdentifier,
        required String password}) =>
    RustLib.instance.api.crateApiUserRegister(
        baseUrl: baseUrl,
        authToken: authToken,
        userIdentifier: userIdentifier,
        password: password);

Future<String> registerDeviceStart(
        {required String baseUrl,
        required String authToken,
        required String deviceIdentifier,
        required String password}) =>
    RustLib.instance.api.crateApiUserRegisterDeviceStart(
        baseUrl: baseUrl,
        authToken: authToken,
        deviceIdentifier: deviceIdentifier,
        password: password);

Future<void> doneRegisterDeviceStart({required String serverOutput}) =>
    RustLib.instance.api
        .crateApiUserDoneRegisterDeviceStart(serverOutput: serverOutput);

Future<void> registerDevice(
        {required String baseUrl,
        required String authToken,
        required String jwt,
        required String serverOutput}) =>
    RustLib.instance.api.crateApiUserRegisterDevice(
        baseUrl: baseUrl,
        authToken: authToken,
        jwt: jwt,
        serverOutput: serverOutput);

///# Log in the user to this app
///
///Does the login requests. 1. for auth, 2nd to get the keys.
///
///If there is more data in the backend, then it is possible to call it via the jwt what is returned by the done login request.
///
///The other backend can validate the jwt
///
Future<UserLoginOut> login(
        {required String baseUrl,
        required String authToken,
        required String userIdentifier,
        required String password}) =>
    RustLib.instance.api.crateApiUserLogin(
        baseUrl: baseUrl,
        authToken: authToken,
        userIdentifier: userIdentifier,
        password: password);

Future<UserDataExport> extractUserData({required String data}) =>
    RustLib.instance.api.crateApiUserExtractUserData(data: data);

Future<UserDataExport> mfaLogin(
        {required String baseUrl,
        required String authToken,
        required String masterKeyEncryption,
        required String authKey,
        required String userIdentifier,
        required String token,
        required bool recovery}) =>
    RustLib.instance.api.crateApiUserMfaLogin(
        baseUrl: baseUrl,
        authToken: authToken,
        masterKeyEncryption: masterKeyEncryption,
        authKey: authKey,
        userIdentifier: userIdentifier,
        token: token,
        recovery: recovery);

Future<String> getFreshJwt(
        {required String baseUrl,
        required String authToken,
        required String userIdentifier,
        required String password,
        String? mfaToken,
        bool? mfaRecovery}) =>
    RustLib.instance.api.crateApiUserGetFreshJwt(
        baseUrl: baseUrl,
        authToken: authToken,
        userIdentifier: userIdentifier,
        password: password,
        mfaToken: mfaToken,
        mfaRecovery: mfaRecovery);

Future<String> refreshJwt(
        {required String baseUrl,
        required String authToken,
        required String jwt,
        required String refreshToken}) =>
    RustLib.instance.api.crateApiUserRefreshJwt(
        baseUrl: baseUrl,
        authToken: authToken,
        jwt: jwt,
        refreshToken: refreshToken);

Future<UserInitServerOutput> initUser(
        {required String baseUrl,
        required String authToken,
        required String jwt,
        required String refreshToken}) =>
    RustLib.instance.api.crateApiUserInitUser(
        baseUrl: baseUrl,
        authToken: authToken,
        jwt: jwt,
        refreshToken: refreshToken);

Future<List<UserDeviceList>> getUserDevices(
        {required String baseUrl,
        required String authToken,
        required String jwt,
        required String lastFetchedTime,
        required String lastFetchedId}) =>
    RustLib.instance.api.crateApiUserGetUserDevices(
        baseUrl: baseUrl,
        authToken: authToken,
        jwt: jwt,
        lastFetchedTime: lastFetchedTime,
        lastFetchedId: lastFetchedId);

Future<void> changePassword(
        {required String baseUrl,
        required String authToken,
        required String userIdentifier,
        required String oldPassword,
        required String newPassword,
        String? mfaToken,
        bool? mfaRecovery}) =>
    RustLib.instance.api.crateApiUserChangePassword(
        baseUrl: baseUrl,
        authToken: authToken,
        userIdentifier: userIdentifier,
        oldPassword: oldPassword,
        newPassword: newPassword,
        mfaToken: mfaToken,
        mfaRecovery: mfaRecovery);

Future<void> deleteUser(
        {required String baseUrl,
        required String authToken,
        required String freshJwt}) =>
    RustLib.instance.api.crateApiUserDeleteUser(
        baseUrl: baseUrl, authToken: authToken, freshJwt: freshJwt);

Future<void> deleteDevice(
        {required String baseUrl,
        required String authToken,
        required String freshJwt,
        required String deviceId}) =>
    RustLib.instance.api.crateApiUserDeleteDevice(
        baseUrl: baseUrl,
        authToken: authToken,
        freshJwt: freshJwt,
        deviceId: deviceId);

Future<void> updateUser(
        {required String baseUrl,
        required String authToken,
        required String jwt,
        required String userIdentifier}) =>
    RustLib.instance.api.crateApiUserUpdateUser(
        baseUrl: baseUrl,
        authToken: authToken,
        jwt: jwt,
        userIdentifier: userIdentifier);

Future<OtpRegister> registerRawOtp(
        {required String baseUrl,
        required String authToken,
        required String jwt}) =>
    RustLib.instance.api.crateApiUserRegisterRawOtp(
        baseUrl: baseUrl, authToken: authToken, jwt: jwt);

Future<OtpRegisterUrl> registerOtp(
        {required String baseUrl,
        required String authToken,
        required String jwt,
        required String issuer,
        required String audience}) =>
    RustLib.instance.api.crateApiUserRegisterOtp(
        baseUrl: baseUrl,
        authToken: authToken,
        jwt: jwt,
        issuer: issuer,
        audience: audience);

Future<OtpRecoveryKeysOutput> getOtpRecoverKeys(
        {required String baseUrl,
        required String authToken,
        required String jwt}) =>
    RustLib.instance.api.crateApiUserGetOtpRecoverKeys(
        baseUrl: baseUrl, authToken: authToken, jwt: jwt);

Future<OtpRegister> resetRawOtp(
        {required String baseUrl,
        required String authToken,
        required String jwt}) =>
    RustLib.instance.api.crateApiUserResetRawOtp(
        baseUrl: baseUrl, authToken: authToken, jwt: jwt);

Future<OtpRegisterUrl> resetOtp(
        {required String baseUrl,
        required String authToken,
        required String jwt,
        required String issuer,
        required String audience}) =>
    RustLib.instance.api.crateApiUserResetOtp(
        baseUrl: baseUrl,
        authToken: authToken,
        jwt: jwt,
        issuer: issuer,
        audience: audience);

Future<void> disableOtp(
        {required String baseUrl,
        required String authToken,
        required String jwt}) =>
    RustLib.instance.api.crateApiUserDisableOtp(
        baseUrl: baseUrl, authToken: authToken, jwt: jwt);

class Claims {
  final String aud;
  final String sub;
  final BigInt exp;
  final BigInt iat;
  final bool fresh;

  const Claims({
    required this.aud,
    required this.sub,
    required this.exp,
    required this.iat,
    required this.fresh,
  });

  @override
  int get hashCode =>
      aud.hashCode ^
      sub.hashCode ^
      exp.hashCode ^
      iat.hashCode ^
      fresh.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Claims &&
          runtimeType == other.runtimeType &&
          aud == other.aud &&
          sub == other.sub &&
          exp == other.exp &&
          iat == other.iat &&
          fresh == other.fresh;
}

class DeviceKeyData {
  final String privateKey;
  final String publicKey;
  final String signKey;
  final String verifyKey;
  final String exportedPublicKey;
  final String exportedVerifyKey;

  const DeviceKeyData({
    required this.privateKey,
    required this.publicKey,
    required this.signKey,
    required this.verifyKey,
    required this.exportedPublicKey,
    required this.exportedVerifyKey,
  });

  @override
  int get hashCode =>
      privateKey.hashCode ^
      publicKey.hashCode ^
      signKey.hashCode ^
      verifyKey.hashCode ^
      exportedPublicKey.hashCode ^
      exportedVerifyKey.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceKeyData &&
          runtimeType == other.runtimeType &&
          privateKey == other.privateKey &&
          publicKey == other.publicKey &&
          signKey == other.signKey &&
          verifyKey == other.verifyKey &&
          exportedPublicKey == other.exportedPublicKey &&
          exportedVerifyKey == other.exportedVerifyKey;
}

class GeneratedRegisterData {
  final String identifier;
  final String password;

  const GeneratedRegisterData({
    required this.identifier,
    required this.password,
  });

  @override
  int get hashCode => identifier.hashCode ^ password.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeneratedRegisterData &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier &&
          password == other.password;
}

class OtpRecoveryKeysOutput {
  final List<String> keys;

  const OtpRecoveryKeysOutput({
    required this.keys,
  });

  @override
  int get hashCode => keys.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpRecoveryKeysOutput &&
          runtimeType == other.runtimeType &&
          keys == other.keys;
}

class OtpRegister {
  final String secret;
  final String alg;
  final List<String> recover;

  const OtpRegister({
    required this.secret,
    required this.alg,
    required this.recover,
  });

  @override
  int get hashCode => secret.hashCode ^ alg.hashCode ^ recover.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpRegister &&
          runtimeType == other.runtimeType &&
          secret == other.secret &&
          alg == other.alg &&
          recover == other.recover;
}

class OtpRegisterUrl {
  final String url;
  final List<String> recover;

  const OtpRegisterUrl({
    required this.url,
    required this.recover,
  });

  @override
  int get hashCode => url.hashCode ^ recover.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpRegisterUrl &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          recover == other.recover;
}

class UserDataExport {
  final String jwt;
  final String userId;
  final String deviceId;
  final String refreshToken;
  final DeviceKeyData deviceKeys;

  const UserDataExport({
    required this.jwt,
    required this.userId,
    required this.deviceId,
    required this.refreshToken,
    required this.deviceKeys,
  });

  @override
  int get hashCode =>
      jwt.hashCode ^
      userId.hashCode ^
      deviceId.hashCode ^
      refreshToken.hashCode ^
      deviceKeys.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDataExport &&
          runtimeType == other.runtimeType &&
          jwt == other.jwt &&
          userId == other.userId &&
          deviceId == other.deviceId &&
          refreshToken == other.refreshToken &&
          deviceKeys == other.deviceKeys;
}

class UserDeviceList {
  final String deviceId;
  final String time;
  final String deviceIdentifier;

  const UserDeviceList({
    required this.deviceId,
    required this.time,
    required this.deviceIdentifier,
  });

  @override
  int get hashCode =>
      deviceId.hashCode ^ time.hashCode ^ deviceIdentifier.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDeviceList &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          time == other.time &&
          deviceIdentifier == other.deviceIdentifier;
}

class UserInitServerOutput {
  final String jwt;
  final List<GroupInviteReqList> invites;

  const UserInitServerOutput({
    required this.jwt,
    required this.invites,
  });

  @override
  int get hashCode => jwt.hashCode ^ invites.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInitServerOutput &&
          runtimeType == other.runtimeType &&
          jwt == other.jwt &&
          invites == other.invites;
}

class UserLoginOut {
  final String? direct;
  final String? masterKey;
  final String? authKey;

  const UserLoginOut({
    this.direct,
    this.masterKey,
    this.authKey,
  });

  @override
  int get hashCode => direct.hashCode ^ masterKey.hashCode ^ authKey.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLoginOut &&
          runtimeType == other.runtimeType &&
          direct == other.direct &&
          masterKey == other.masterKey &&
          authKey == other.authKey;
}
