import 'dart:convert';
import 'dart:io';

import 'package:sentc/src/crypto/abstract_sym_crypto.dart';
import 'package:sentc/sentc.dart';
import '../src/generated.dart' as plugin;

PrepareKeysResult prepareKeys(List<GroupKey> keys, int page) {
  final offset = page * 50;
  int end = offset + 50;

  if (end > keys.length) {
    end = keys.length;
  }

  final keySlice = keys.sublist(offset, end);

  String str = "[";

  for (var i = 0; i < keySlice.length; ++i) {
    var key = keySlice[i].groupKey;

    str += "$key,";
  }

  //remove the trailing comma
  str = str.substring(0, str.length - 1);

  str += "]";

  return PrepareKeysResult(str, end < keys.length - 1);
}

class PrepareKeysResult {
  final String str;
  final bool end;

  PrepareKeysResult(this.str, this.end);
}

//______________________________________________________________________________________________________________________
Future<Group> getGroup(
  String groupId,
  String baseUrl,
  String appToken,
  User user, [
  bool parent = false,
  String groupAsMember = "",
  bool rek = false,
]) async {
  final storage = Sentc.getStorage();

  String userId;

  if (groupAsMember == "") {
    userId = user.userId;
  } else {
    userId = groupAsMember;
  }

  final groupKey = "group_data_user_${userId}_id_$groupId";

  final groupJson = await storage.getItem(groupKey);

  final jwt = await user.getJwt();

  if (groupJson != null) {
    final group = Group.fromJson(jsonDecode(groupJson), baseUrl, appToken, user, parent);

    if (group.lastCheckTime + 60000 * 5 < DateTime.now().millisecondsSinceEpoch) {
      //load the group from json data and just look for group updates
      final update = await Sentc.getApi().groupGetGroupUpdates(
        baseUrl: baseUrl,
        authToken: appToken,
        jwt: jwt,
        id: groupId,
        groupAsMember: groupAsMember,
      );

      group.rank = update.rank;
      group.keyUpdate = update.keyUpdate;
      group.lastCheckTime = DateTime.now().millisecondsSinceEpoch;

      //update the group data in the storage
      await storage.set(groupKey, jsonEncode(group));
    }

    return group;
  }

  //group data was not in the cache
  final out = await Sentc.getApi().groupGetGroupData(
    baseUrl: baseUrl,
    authToken: appToken,
    jwt: jwt,
    id: groupId,
    groupAsMember: groupAsMember,
  );

  final accessByGroupAsMember = out.accessByGroupAsMember ?? "";

  if (accessByGroupAsMember != "" && !rek) {
    //only load the group once even for rek. calls.
    //if group as member set. load this group first to get the keys
    //no group as member flag
    await getGroup(accessByGroupAsMember, baseUrl, appToken, user);
  }

  if (out.accessByParentGroup != null) {
    parent = true;
    //check if the parent group is fetched
    //rec here because the user might be in a parent of the parent group or so
    //check the tree until we found the group where the user access by user

    await getGroup(out.parentGroupId, baseUrl, appToken, user, false, groupAsMember, true);
  }

  final groupObj = Group._(
    baseUrl,
    appToken,
    user,
    groupId,
    out.parentGroupId,
    parent,
    out.rank,
    out.keyUpdate,
    out.createdTime,
    out.joinedTime,
    [],
    {},
    "_newestKeyId",
    out.accessByParentGroup,
    accessByGroupAsMember,
    [],
    DateTime.now().millisecondsSinceEpoch,
  );

  final keys = await groupObj.decryptKey(out.keys);
  Map<String, int> keyMap = {};

  for (var i = 0; i < keys.length; ++i) {
    var key = keys[i];
    keyMap[key.groupKeyId] = i;
  }

  groupObj._keys = keys;
  groupObj._keyMap = keyMap;
  groupObj._newestKeyId = keys[0].groupKeyId;

  if (keys.length >= 50) {
    //fetch the rest of the keys
    await groupObj.fetchKeys();
  }

  //now decrypt the hmac key for searchable encryption, the right key must be fetched before
  final decryptedHmacKeys = await groupObj.decryptHmacKeys(out.hmacKeys);
  groupObj._hmacKeys = decryptedHmacKeys;

  await Future.wait([
    //store the group data
    storage.set(groupKey, jsonEncode(groupObj)),
    //save always the newest public key
    storage.set("group_public_key_$groupId", jsonEncode(keys[0])),
  ]);

  return groupObj;
}

//______________________________________________________________________________________________________________________

class GroupKey extends plugin.GroupKeyData {
  GroupKey({
    required super.privateGroupKey,
    required super.publicGroupKey,
    required super.groupKey,
    required super.time,
    required super.groupKeyId,
    required super.exportedPublicKey,
  });

  factory GroupKey.fromJson(Map<String, dynamic> json) => GroupKey(
        privateGroupKey: json['privateGroupKey'] as String,
        publicGroupKey: json['publicGroupKey'] as String,
        groupKey: json['groupKey'] as String,
        time: json['time'] as String,
        groupKeyId: json['groupKeyId'] as String,
        exportedPublicKey: json["exportedPublicKey"] as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'privateGroupKey': privateGroupKey,
        'publicGroupKey': publicGroupKey,
        'groupKey': groupKey,
        'time': time,
        'groupKeyId': groupKeyId,
        'exportedPublicKey': exportedPublicKey
      };

  factory GroupKey.fromServer(GroupKeyData key) => GroupKey(
        privateGroupKey: key.privateGroupKey,
        publicGroupKey: key.publicGroupKey,
        groupKey: key.groupKey,
        time: key.time,
        groupKeyId: key.groupKeyId,
        exportedPublicKey: key.exportedPublicKey,
      );
}

//______________________________________________________________________________________________________________________

class Group extends AbstractSymCrypto {
  final User _user;

  final String groupId;
  final String parentGroupId;
  final bool _fromParent;
  int rank;
  int lastCheckTime;
  bool keyUpdate;
  final String createdTime;
  final String joinedTime;

  List<GroupKey> _keys;
  List<String> _hmacKeys;
  Map<String, int> _keyMap;
  String _newestKeyId;
  final String? accessByParentGroup;
  final String accessByGroupAsMember;

  Group._(
    super.baseUrl,
    super.appToken,
    this._user,
    this.groupId,
    this.parentGroupId,
    this._fromParent,
    this.rank,
    this.keyUpdate,
    this.createdTime,
    this.joinedTime,
    this._keys,
    this._keyMap,
    this._newestKeyId,
    this.accessByParentGroup,
    this.accessByGroupAsMember,
    this._hmacKeys,
    this.lastCheckTime,
  );

  Group.fromJson(
    Map<String, dynamic> json,
    super.baseUrl,
    super.appToken,
    this._user,
    this._fromParent,
  )   : groupId = json["groupId"],
        lastCheckTime = json["lastCheckTime"],
        keyUpdate = json["keyUpdate"],
        parentGroupId = json["parentGroupId"],
        createdTime = json["createdTime"],
        joinedTime = json["joinedTime"],
        rank = json["rank"],
        _keyMap = jsonDecode(json["keyMap"]),
        _newestKeyId = json["newestKeyId"],
        accessByParentGroup = json["accessByParentGroup"],
        accessByGroupAsMember = json["accessByGroupAsMember"],
        _keys = (jsonDecode(json["keys"]) as List).map((e) => GroupKey.fromJson(e)).toList(),
        _hmacKeys = (json["hmacKeys"] as List<dynamic>).map((e) => e as String).toList();

  Map<String, dynamic> toJson() {
    return {
      "groupId": groupId,
      "parentGroupId": parentGroupId,
      "createdTime": createdTime,
      "joinedTime": joinedTime,
      "rank": rank,
      "keyMap": jsonEncode(_keyMap),
      "newestKeyId": _newestKeyId,
      "keys": jsonEncode(_keys),
      "accessByParentGroup": accessByParentGroup,
      "accessByGroupAsMember": accessByGroupAsMember,
      "hmacKeys": jsonEncode(_hmacKeys),
      "lastCheckTime": lastCheckTime,
      "keyUpdate": keyUpdate,
    };
  }

  @override
  Future<String> getJwt() {
    return _user.getJwt();
  }

  @override
  Future<String> getSignKey() {
    //always use the users sign key
    return _user.getSignKey();
  }

  @override
  Future<String> getSymKeyById(String keyId) async {
    final key = await getGroupKey(keyId);

    return key.groupKey;
  }

  @override
  Future<SymKeyToEncryptResult> getSymKeyToEncrypt() {
    final latestKey = _getNewestKey()!;

    return Future.value(SymKeyToEncryptResult(latestKey.groupKeyId, latestKey.groupKey));
  }

  String getNewestHmacKey() {
    return _hmacKeys[0];
  }

  //____________________________________________________________________________________________________________________

  Future<GroupKey> getGroupKey(String keyId, [bool newKeys = false]) async {
    var keyIndex = _keyMap[keyId];

    if (keyIndex == null) {
      final jwt = await getJwt();

      final fetchedKey = await Sentc.getApi().groupGetGroupKey(
        baseUrl: baseUrl,
        authToken: appToken,
        jwt: jwt,
        id: groupId,
        keyId: keyId,
        groupAsMember: accessByGroupAsMember,
      );

      final decryptedKey = await decryptKey([fetchedKey]);

      final lastIndex = _keys.length;
      _keys.add(decryptedKey[0]);
      _keyMap[decryptedKey[0].groupKeyId] = lastIndex;

      final storage = Sentc.getStorage();

      if (newKeys) {
        _newestKeyId = decryptedKey[0].groupKeyId;

        //save also the newest key in the cache
        storage.set("group_public_key_$groupId", jsonEncode(decryptedKey[0]));
      }

      String actualUserId;
      if (accessByGroupAsMember == "") {
        actualUserId = _user.userId;
      } else {
        actualUserId = accessByGroupAsMember;
      }

      final groupKey = "group_data_user_${actualUserId}_id_$groupId";

      await storage.set(groupKey, jsonEncode(this));

      keyIndex = _keyMap[keyId];
      if (keyIndex == null) {
        throw Exception("Group key not found. Maybe done key rotation will help");
      }
    }

    try {
      return _keys[keyIndex];
    } catch (e) {
      throw Exception("Group key not found. Maybe done key rotation will help");
    }
  }

  GroupKey? _getNewestKey() {
    final index = _keyMap[_newestKeyId] ?? 0;

    try {
      return _keys[index];
    } catch (e) {
      return null;
    }
  }

  Future<Group> _getGroupRefFromParent() async {
    String userId;
    if (accessByGroupAsMember == "") {
      userId = _user.userId;
    } else {
      userId = accessByGroupAsMember;
    }

    final storage = Sentc.getStorage();
    final groupKey = "group_data_user_${userId}_id_$parentGroupId";
    final groupJson = await storage.getItem(groupKey);

    if (groupJson == null) {
      throw Exception(
        "Parent group not found. THis group was access from parent group but the parent group data is gone",
      );
    }

    return Group.fromJson(
      jsonDecode(groupJson),
      baseUrl,
      appToken,
      _user,
      false,
    );
  }

  Future<Group> _getGroupRefFromGroupAsMember() async {
    //access over group as member
    final storage = Sentc.getStorage();
    final groupKey = "group_data_user_${_user.userId}_id_$accessByGroupAsMember";
    final groupJson = await storage.getItem(groupKey);

    if (groupJson == null) {
      throw Exception(
        "Connected group not found. This group was access from a connected group but the group data is gone.",
      );
    }

    return Group.fromJson(
      jsonDecode(groupJson),
      baseUrl,
      appToken,
      _user,
      false,
    );
  }

  Future<String> _getPublicKey() async {
    if (!_fromParent && (accessByGroupAsMember == "")) {
      return _user.getNewestPublicKey();
    }

    if (_fromParent) {
      final parentGroup = await _getGroupRefFromParent();

      //get the newest key from parent
      final newestKey = parentGroup._getNewestKey();

      if (newestKey == null) {
        throw Exception(
          "Parent group not found. This group was access from parent group but the parent group data is gone.",
        );
      }

      return newestKey.publicGroupKey;
    }

    final connectedGroup = await _getGroupRefFromGroupAsMember();

    final newestKey = connectedGroup._getNewestKey();

    if (newestKey == null) {
      throw Exception(
        "Connected group not found. This group was access from a connected group but the group data is gone.",
      );
    }

    return newestKey.publicGroupKey;
  }

  Future<String> _getPrivateKey(String keyId) async {
    if (!_fromParent && (accessByGroupAsMember == "")) {
      return _user.getPrivateKey(keyId);
    }

    if (_fromParent) {
      final parentGroup = await _getGroupRefFromParent();

      final parentGroupKey = await parentGroup.getGroupKey(keyId);

      return parentGroupKey.privateGroupKey;
    }

    //access over group as member
    final connectedGroup = await _getGroupRefFromGroupAsMember();

    final connectedGroupKey = await connectedGroup.getGroupKey(keyId);

    return connectedGroupKey.privateGroupKey;
  }

  Future<List<GroupKey>> decryptKey(List<GroupOutDataKeys> keys) async {
    List<GroupKey> list = [];

    for (var i = 0; i < keys.length; ++i) {
      var key = keys[i];
      final privateKey = await _getPrivateKey(key.privateKeyId);

      final decryptedKeys = await Sentc.getApi().groupDecryptKey(privateKey: privateKey, serverKeyData: key.keyData);

      list.add(GroupKey.fromServer(decryptedKeys));
    }

    return list;
  }

  Future<List<String>> decryptHmacKeys(List<GroupOutDataHmacKeys> keys) async {
    List<String> list = [];

    for (var i = 0; i < keys.length; ++i) {
      var key = keys[i];

      final groupKey = await getSymKeyById(key.groupKeyId);

      final decryptedHmacKey = await Sentc.getApi().groupDecryptHmacKey(groupKey: groupKey, serverKeyData: key.keyData);

      list.add(decryptedHmacKey);
    }

    return list;
  }

  Future<void> fetchKeys() async {
    final jwt = await getJwt();

    var lastItem = _keys[_keys.length - 1];

    bool nextFetch = true;

    final List<GroupKey> keys = [];

    while (nextFetch) {
      final fetchedKeys = await Sentc.getApi().groupGetGroupKeys(
        baseUrl: baseUrl,
        authToken: appToken,
        jwt: jwt,
        id: groupId,
        lastFetchedTime: lastItem.time,
        lastFetchedKeyId: lastItem.groupKeyId,
        groupAsMember: accessByGroupAsMember,
      );

      final decryptedKeys = await decryptKey(fetchedKeys);

      keys.addAll(decryptedKeys);

      nextFetch = fetchedKeys.length >= 50;

      lastItem = decryptedKeys[decryptedKeys.length - 1];
    }

    final lastInsertedIndex = _keys.length;

    for (var i = 0; i < keys.length; ++i) {
      var key = keys[i];

      _keyMap[key.groupKeyId] = i + lastInsertedIndex;
    }

    _keys.addAll(keys);
  }

  //____________________________________________________________________________________________________________________

  deleteGroup() async {
    final jwt = await getJwt();

    return Sentc.getApi().groupDeleteGroup(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      adminRank: rank,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<Group> getChildGroup(String groupId) {
    return getGroup(groupId, baseUrl, appToken, _user, true, accessByGroupAsMember);
  }

  Future<Group> getConnectedGroup(String groupId) {
    return getGroup(groupId, baseUrl, appToken, _user, false, this.groupId);
  }

  Future<List<GroupChildrenList>> getChildren(GroupChildrenList? lastFetchedItem) async {
    final jwt = await getJwt();

    final lastFetchedTime = lastFetchedItem?.time ?? "0";
    final lastFetchedGroupId = lastFetchedItem?.groupId ?? "none";

    return Sentc.getApi().groupGetAllFirstLevelChildren(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      lastFetchedTime: lastFetchedTime,
      lastFetchedGroupId: lastFetchedGroupId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<String> prepareCreateChildGroup() {
    final lastKey = _getNewestKey()!.publicGroupKey;

    return Sentc.getApi().groupPrepareCreateGroup(creatorsPublicKey: lastKey);
  }

  Future<String> createChildGroup() async {
    final jwt = await getJwt();
    final lastKey = _getNewestKey()!.publicGroupKey;

    return Sentc.getApi().groupCreateChildGroup(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      parentPublicKey: lastKey,
      parentId: groupId,
      adminRank: rank,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<String> createConnectedGroup() async {
    final jwt = await getJwt();
    final lastKey = _getNewestKey()!.publicGroupKey;

    return Sentc.getApi().groupCreateConnectedGroup(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      connectedGroupId: groupId,
      adminRank: rank,
      parentPublicKey: lastKey,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<void> groupUpdateCheck() async {
    final jwt = await getJwt();

    final update = await Sentc.getApi().groupGetGroupUpdates(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      groupAsMember: accessByGroupAsMember,
    );

    rank = update.rank;
    lastCheckTime = DateTime.now().millisecondsSinceEpoch;
  }

  Future<List<GroupUserListItem>> getMember(GroupUserListItem? lastFetchedItem) async {
    final jwt = await getJwt();

    final lastFetchedTime = lastFetchedItem?.joinedTime ?? "0";
    final lastFetchedId = lastFetchedItem?.userId ?? "none";

    return Sentc.getApi().groupGetMember(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      lastFetchedTime: lastFetchedTime,
      lastFetchedId: lastFetchedId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  //____________________________________________________________________________________________________________________
  //key rotation

  Future<String> prepareKeyRotation([bool sign = false]) async {
    final publicKey = await _getPublicKey();

    String signKey = "";

    if (sign) {
      signKey = await getSignKey();
    }

    return Sentc.getApi().groupPrepareKeyRotation(
      preGroupKey: _getNewestKey()!.groupKey,
      publicKey: publicKey,
      signKey: signKey,
      starter: _user.userId,
    );
  }

  Future<GroupKey> keyRotation([bool sign = false]) async {
    final jwt = await getJwt();
    final publicKey = await _getPublicKey();

    String signKey = "";

    if (sign) {
      signKey = await getSignKey();
    }

    final keyId = await Sentc.getApi().groupKeyRotation(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      publicKey: publicKey,
      preGroupKey: _getNewestKey()!.groupKey,
      signKey: signKey,
      starter: _user.userId,
      groupAsMember: accessByGroupAsMember,
    );

    return getGroupKey(keyId, true);
  }

  Future<void> finishKeyRotation([bool verify = false]) async {
    final jwt = await getJwt();

    final api = Sentc.getApi();

    var keys = await api.groupPreDoneKeyRotation(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      groupAsMember: accessByGroupAsMember,
    );

    if (keys.isEmpty) {
      return;
    }

    bool nextRound = false;
    int roundsLeft = 10;

    final publicKey = await _getPublicKey();

    do {
      List<KeyRotationGetOut> leftKeys = [];

      for (var i = 0; i < keys.length; ++i) {
        var key = keys[i];

        GroupKey preKey;

        try {
          preKey = await getGroupKey(key.preGroupKeyId);
        } catch (e) {
          leftKeys.add(key);
          continue;
        }

        //get the right used private key for each key
        final privateKey = await _getPrivateKey(key.encryptedEphKeyKeyId);

        String verifyKey = "";

        if (verify && key.signedByUserId != null && key.signedByUserSignKeyId != null) {
          try {
            verifyKey = await Sentc.getUserVerifyKey(key.signedByUserId!, key.signedByUserSignKeyId!);
          } catch (e) {
            final err = SentcError.fromJson(jsonDecode(e.toString()));

            //check if code == 100 -> user not found. if so ignore this error and use no verify key
            if (err.status != "server_100") {
              rethrow;
            }
          }
        }

        await api.groupFinishKeyRotation(
          baseUrl: baseUrl,
          authToken: appToken,
          jwt: jwt,
          id: groupId,
          serverOutput: key.serverOutput,
          preGroupKey: preKey.groupKey,
          publicKey: publicKey,
          privateKey: privateKey,
          verifyKey: verifyKey,
          groupAsMember: accessByGroupAsMember,
        );

        //now get the new key and safe it
        await getGroupKey(key.newGroupKeyId, true);
      }

      roundsLeft--;

      if (leftKeys.isNotEmpty) {
        keys = [];
        keys.addAll(leftKeys);

        nextRound = true;
      } else {
        nextRound = false;
      }
    } while (nextRound && roundsLeft > 0);

    String userId;
    if (accessByGroupAsMember == "") {
      userId = _user.userId;
    } else {
      userId = accessByGroupAsMember;
    }

    //after a key rotation -> save the new group data in the store
    final groupKey = "group_data_user_${userId}_id_$groupId";

    final storage = Sentc.getStorage();
    await storage.set(groupKey, jsonEncode(this));
  }

  //____________________________________________________________________________________________________________________
  //admin fn for user management

  Future<String> prepareUpdateRank(String userId, int newRank) {
    return Sentc.getApi().groupPrepareUpdateRank(userId: userId, rank: rank, adminRank: rank);
  }

  Future<void> updateRank(String userId, int newRank) async {
    final jwt = await getJwt();

    await Sentc.getApi().groupUpdateRank(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      userId: userId,
      rank: rank,
      adminRank: rank,
      groupAsMember: accessByGroupAsMember,
    );

    String actualUserId;
    if (accessByGroupAsMember == "") {
      actualUserId = _user.userId;
    } else {
      actualUserId = accessByGroupAsMember;
    }

    //check if the updated user is the actual user -> then update the group store

    if (actualUserId == userId) {
      final groupKey = "group_data_user_${actualUserId}_id_$groupId";

      final storage = Sentc.getStorage();

      rank = newRank;

      await storage.set(groupKey, jsonEncode(this));
    }
  }

  Future<void> kickUser(String userId) async {
    final jwt = await getJwt();

    return Sentc.getApi().groupKickUser(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      userId: userId,
      adminRank: rank,
      groupAsMember: accessByGroupAsMember,
    );
  }

  //____________________________________________________________________________________________________________________

  Future<void> leave() async {
    final jwt = await getJwt();

    return Sentc.getApi().leaveGroup(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  //____________________________________________________________________________________________________________________
  //group as member

  Future<List<ListGroups>> getGroups(ListGroups? lastFetchedItem) async {
    final jwt = await getJwt();

    final lastFetchedTime = lastFetchedItem?.time.toString() ?? "0";
    final lastFetchedGroupId = lastFetchedItem?.groupId ?? "none";

    return Sentc.getApi().groupGetGroupsForUser(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      lastFetchedTime: lastFetchedTime,
      lastFetchedGroupId: lastFetchedGroupId,
      groupId: groupId,
    );
  }

  Future<List<GroupInviteReqList>> getGroupInvites(GroupInviteReqList? lastItem) async {
    final jwt = await getJwt();

    final lastFetchedTime = lastItem?.time.toString() ?? "0";
    final lastFetchedGroupId = lastItem?.groupId ?? "none";

    return Sentc.getApi().groupGetInvitesForUser(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      lastFetchedTime: lastFetchedTime,
      lastFetchedGroupId: lastFetchedGroupId,
      groupId: groupId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<void> acceptGroupInvite(String groupIdToAccept) async {
    final jwt = await getJwt();

    return Sentc.getApi().groupAcceptInvite(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupIdToAccept,
      groupId: groupId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<void> rejectGroupInvite(groupIdToReject) async {
    final jwt = await getJwt();

    return Sentc.getApi().groupRejectInvite(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupIdToReject,
      groupId: groupId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  //join req to another group
  Future<void> groupJoinRequest(String groupIdToJoin) async {
    final jwt = await getJwt();

    return Sentc.getApi().groupJoinReq(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupIdToJoin,
      groupId: groupId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<List<GroupInviteReqList>> sentJoinReq(GroupInviteReqList? lastFetchedItem) async {
    final jwt = await getJwt();

    final lastFetchedTime = lastFetchedItem?.time.toString() ?? "0";
    final lastFetchedGroupId = lastFetchedItem?.groupId ?? "none";

    return Sentc.getApi().groupGetSentJoinReq(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      adminRank: rank,
      lastFetchedTime: lastFetchedTime,
      lastFetchedGroupId: lastFetchedGroupId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<void> deleteJoinReq(String id) async {
    final jwt = await getJwt();

    return Sentc.getApi().groupDeleteSentJoinReq(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      adminRank: rank,
      joinReqGroupId: id,
      groupAsMember: accessByGroupAsMember,
    );
  }

  //____________________________________________________________________________________________________________________
  //send invite to user

  Future<void> stopInvites() async {
    final jwt = await getJwt();

    return Sentc.getApi().groupStopGroupInvites(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      adminRank: rank,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<String> prepareKeysForNewMember(String userId, int? rank, [int page = 0, bool group = false]) async {
    final keyCount = _keys.length;

    String publicKey;

    if (group) {
      final k = await Sentc.getGroupPublicKeyData(userId);
      publicKey = k.key;
    } else {
      final k = await Sentc.getUserPublicKey(userId);
      publicKey = k.publicKey;
    }

    final keyString = prepareKeys(_keys, page).str;

    return Sentc.getApi().groupPrepareKeysForNewMember(
      userPublicKey: publicKey,
      groupKeys: keyString,
      keyCount: keyCount,
      adminRank: this.rank,
      rank: rank,
    );
  }

  Future<void> invite(String userId, int? rank) {
    return _inviteUserInternally(userId, rank);
  }

  Future<void> inviteAuto(String userId, int? rank) {
    return _inviteUserInternally(userId, rank, true);
  }

  Future<void> inviteGroup(String groupId, int? rank) {
    return _inviteUserInternally(groupId, rank, false, true);
  }

  Future<void> inviteGroupAuto(String groupId, int? rank) {
    return _inviteUserInternally(groupId, rank, true, true);
  }

  Future<void> reInviteUser(String userId) {
    return _inviteUserInternally(userId, null, false, false, true);
  }

  Future<void> reInviteGroup(String groupId) {
    return _inviteUserInternally(groupId, null, false, true, true);
  }

  Future<void> _inviteUserInternally(
    String userId,
    int? rank, [
    bool auto = false,
    bool group = false,
    bool reInvite = false,
  ]) async {
    String publicKey;

    if (group) {
      final k = await Sentc.getGroupPublicKeyData(userId);
      publicKey = k.key;
    } else {
      final k = await Sentc.getUserPublicKey(userId);
      publicKey = k.publicKey;
    }

    final keyCount = _keys.length;
    final keyString = prepareKeys(_keys, 0).str;

    final jwt = await getJwt();
    final api = Sentc.getApi();

    final sessionId = await api.groupInviteUser(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      userId: userId,
      keyCount: keyCount,
      rank: rank,
      adminRank: this.rank,
      autoInvite: auto,
      groupInvite: group,
      userPublicKey: publicKey,
      groupKeys: keyString,
      groupAsMember: accessByGroupAsMember,
      reInvite: reInvite,
    );

    if (sessionId == "") {
      return;
    }

    bool nextPage = true;
    int i = 1;
    final p = <Future>[];

    while (nextPage) {
      final nextKeys = prepareKeys(_keys, i);
      nextPage = nextKeys.end;

      p.add(api.groupInviteUserSession(
        baseUrl: baseUrl,
        authToken: appToken,
        jwt: jwt,
        id: groupId,
        autoInvite: auto,
        sessionId: sessionId,
        userPublicKey: publicKey,
        groupKeys: nextKeys.str,
        groupAsMember: accessByGroupAsMember,
      ));

      i++;
    }

    await Future.wait(p);
  }

  //____________________________________________________________________________________________________________________
  //join req

  Future<List<GroupJoinReqList>> getJoinRequests(GroupJoinReqList? lastFetchedItem) async {
    final jwt = await getJwt();

    final lastFetchedTime = lastFetchedItem?.time ?? "0";
    final lastFetchedId = lastFetchedItem?.userId ?? "none";

    return Sentc.getApi().groupGetJoinReqs(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      adminRank: rank,
      lastFetchedTime: lastFetchedTime,
      lastFetchedId: lastFetchedId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<void> rejectJoinRequest(String userId) async {
    final jwt = await getJwt();

    return Sentc.getApi().groupRejectJoinReq(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      adminRank: rank,
      rejectedUserId: userId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  Future<void> acceptJoinRequest(String userId, [int userType = 0, int? rank]) async {
    final jwt = await getJwt();
    final api = Sentc.getApi();

    final keyCount = _keys.length;
    final keyString = prepareKeys(_keys, 0).str;

    String publicKey;

    if (userType == 2) {
      final k = await Sentc.getGroupPublicKeyData(userId);
      publicKey = k.key;
    } else {
      final k = await Sentc.getUserPublicKey(userId);
      publicKey = k.publicKey;
    }

    final sessionId = await api.groupAcceptJoinReq(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      id: groupId,
      userId: userId,
      keyCount: keyCount,
      rank: rank,
      adminRank: this.rank,
      userPublicKey: publicKey,
      groupKeys: keyString,
      groupAsMember: accessByGroupAsMember,
    );

    if (sessionId == "") {
      return;
    }

    bool nextPage = true;
    int i = 1;
    final p = <Future>[];

    while (nextPage) {
      final nextKeys = prepareKeys(_keys, i);
      nextPage = nextKeys.end;

      p.add(api.groupJoinUserSession(
        baseUrl: baseUrl,
        authToken: appToken,
        jwt: jwt,
        id: groupId,
        sessionId: sessionId,
        userPublicKey: publicKey,
        groupKeys: nextKeys.str,
        groupAsMember: accessByGroupAsMember,
      ));

      i++;
    }

    await Future.wait(p);
  }

  //____________________________________________________________________________________________________________________
  //file handling

  /// Prepare the register of a file, The server input could be passed to the sentc api from your backend
  ///
  /// encrypted file name, key and master key id are only for the frontend to encrypt more date if necessary
  Future<FilePrepareCreateOutput> prepareRegisterFile(File file) async {
    final key = await registerKey();

    final uploader = Uploader(baseUrl, appToken, _user, groupId, null, null, accessByGroupAsMember);

    final out = await uploader.prepareFileRegister(file, key.key, key.masterKeyId);

    return FilePrepareCreateOutput(
      encryptedFileName: out.encryptedFileName,
      key: key,
      masterKeyId: key.masterKeyId,
      serverInput: out.serverInput,
    );
  }

  /// Validates the sentc file register output
  /// Returns the file id
  Future<FileDoneRegister> doneFileRegister(String serverOutput) {
    final uploader = Uploader(baseUrl, appToken, _user, groupId, null, null, accessByGroupAsMember);

    return uploader.doneFileRegister(serverOutput);
  }

  /// Upload a registered file.
  ///
  /// Session id is returned from the sentc api. The rest from @prepareRegisterFile
  ///
  /// upload the chunks signed by the creators sign key
  ///
  /// Show the upload progress of how many chunks are already uploaded with the uploadCallback
  Future<void> uploadFile({
    required File file,
    required SymKey contentKey,
    required String sessionId,
    bool sign = false,
    void Function(double progress)? uploadCallback,
  }) {
    final uploader = Uploader(baseUrl, appToken, _user, groupId, null, uploadCallback, accessByGroupAsMember);

    return uploader.checkFileUpload(file, contentKey.key, sessionId, sign);
  }

  //____________________________________________________________________________________________________________________

  Future<FileCreateOutput> createFileWithPath({
    required String path,
    bool sign = false,
    void Function(double progress)? uploadCallback,
  }) {
    final file = File(path);

    return createFile(file: file, sign: sign, uploadCallback: uploadCallback);
  }

  Future<FileCreateOutput> createFile({
    required File file,
    bool sign = false,
    void Function(double progress)? uploadCallback,
  }) async {
    final key = await registerKey();

    final uploader = Uploader(baseUrl, appToken, _user, groupId, null, uploadCallback, accessByGroupAsMember);

    final out = await uploader.uploadFile(file, key.key, key.masterKeyId, sign);

    return FileCreateOutput(out.fileId, key.masterKeyId, out.encryptedFileName);
  }

  Future<DownloadResult> _getFileMetaInfo(
    String fileId,
    Downloader downloader, [
    String verifyKey = "",
  ]) async {
    final fileMeta = await downloader.downloadFileMetaInformation(fileId);

    final keyId = fileMeta.keyId;
    final key = await fetchKey(keyId, fileMeta.masterKeyId);

    if (fileMeta.encryptedFileName != null && fileMeta.encryptedFileName != "") {
      fileMeta.fileName = await key.decryptString(fileMeta.encryptedFileName!, verifyKey);
    }

    return DownloadResult(fileMeta, key);
  }

  /// Get and encrypt file meta information like the real file name
  /// This wont download the file.
  ///
  /// This is usefully if the user wants to show information about the file (e.g. the file name) but not download the file
  /// The meta info is also needed for the download file functions
  Future<DownloadResult> downloadFileMetaInfo(String fileId, [String verifyKey = ""]) {
    final downloader = Downloader(baseUrl, appToken, _user, groupId, accessByGroupAsMember);

    return _getFileMetaInfo(fileId, downloader, verifyKey);
  }

  /// Download a file but with already downloaded file information and the file key to not fetch the info and the key again.
  ///
  /// This function can be used after the downloadFileMetaInfo function
  /// Keep in mind that you must use a file which doesn't exists yet.
  /// otherwise the decrypted bytes will be attached to the file
  Future<void> downloadFileWithMetaInfo({
    required File file,
    required SymKey key,
    required FileMetaInformation fileMeta,
    String verifyKey = "",
    void Function(double progress)? updateProgressCb,
  }) {
    final downloader = Downloader(baseUrl, appToken, _user, groupId, accessByGroupAsMember);

    return downloader.downloadFileParts(file, fileMeta.partList, key.key, updateProgressCb, verifyKey);
  }

  //____________________________________________________________________________________________________________________

  /// Downloads a file.
  ///
  /// This can be used if the user wants a specific file.
  /// Need to obtain a file object
  /// This will not check if the file exists
  Future<DownloadResult> downloadFileWithFile({
    required File file,
    required String fileId,
    String verifyKey = "",
    void Function(double progress)? updateProgressCb,
  }) async {
    final downloader = Downloader(baseUrl, appToken, _user, groupId, accessByGroupAsMember);

    final fileMeta = await _getFileMetaInfo(fileId, downloader, verifyKey);

    await downloader.downloadFileParts(file, fileMeta.meta.partList, fileMeta.key.key, updateProgressCb, verifyKey);

    return fileMeta;
  }

  /// Downloads a file
  ///
  /// to the given path. The path must be an directory
  /// This functions uses the real file name.
  /// An available file name will be selected based on the real file name
  Future<DownloadResult> downloadFile({
    required String path,
    required String fileId,
    String verifyKey = "",
    void Function(double progress)? updateProgressCb,
  }) async {
    final downloader = Downloader(baseUrl, appToken, _user, groupId, accessByGroupAsMember);

    final fileMeta = await _getFileMetaInfo(fileId, downloader, verifyKey);

    final fileName = fileMeta.meta.fileName ?? "unnamed";
    File file = File("$path${Platform.pathSeparator}$fileName");

    if (await file.exists()) {
      final availableFileName = await findAvailableFileName(file.path);

      file = File(availableFileName);
    }

    await downloader.downloadFileParts(file, fileMeta.meta.partList, fileMeta.key.key, updateProgressCb, verifyKey);

    return fileMeta;
  }

  Future<void> deleteFile(String fileId) async {
    final jwt = await getJwt();

    return Sentc.getApi().fileDeleteFile(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      fileId: fileId,
      groupId: groupId,
      groupAsMember: accessByGroupAsMember,
    );
  }

  //____________________________________________________________________________________________________________________
  //searchable encryption

  Future<SearchCreateDataLight> prepareCreateSearchableItemLight(String data, bool full, int? limit) {
    final key = getNewestHmacKey();

    return Sentc.getApi().prepareCreateSearchableLight(key: key, data: data, full: full, limit: limit);
  }

  Future<String> prepareCreateSearchableItem(String itemRef, String data, bool full, String? category, int? limit) {
    final key = getNewestHmacKey();

    return Sentc.getApi().prepareCreateSearchable(
      key: key,
      data: data,
      full: full,
      limit: limit,
      category: category ?? "",
      itemRef: itemRef,
    );
  }

  Future<String> prepareSearchItem(String data) {
    final key = getNewestHmacKey();

    return Sentc.getApi().prepareSearch(key: key, data: data);
  }

  Future<List<ListSearchItem>> searchItem(String data, ListSearchItem? lastFetchedItem, String? catId) async {
    final jwt = await getJwt();

    final lastTime = lastFetchedItem?.time ?? "0";
    final lastId = lastFetchedItem?.id ?? "none";

    return Sentc.getApi().search(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      groupId: groupId,
      groupAsMember: accessByGroupAsMember,
      key: getNewestHmacKey(),
      data: data,
      catId: catId ?? "",
      lastFetchedTime: lastTime,
      lastFetchedGroupId: lastId,
    );
  }

  Future<List<ListContentItem>> fetchContent(
    ListContentItem? lastFetchedItem,
    String? catId,
    ContentFetchLimit? limit,
  ) async {
    final jwt = await getJwt();

    final lastTime = lastFetchedItem?.time ?? "0";
    final lastId = lastFetchedItem?.id ?? "none";

    return Sentc.getApi().contentFetchForGroup(
      baseUrl: baseUrl,
      authToken: appToken,
      jwt: jwt,
      groupId: groupId,
      groupAsMember: accessByGroupAsMember,
      catId: catId ?? "",
      lastFetchedTime: lastTime,
      lastFetchedGroupId: lastId,
      limit: limit ?? ContentFetchLimit.Small,
    );
  }
}
