/// The server contract uses decimal bytes and KST period boundaries.
const imageUsagePolicyRevision = 'image-usage-2.1.5-v1';
const imageUsageLimits = {
  'free': (
    storage: 100000000,
    uploadDay: 30000000,
    downloadDay: 50000000,
    downloadMonth: 500000000,
  ),
  'premium': (
    storage: 1000000000,
    uploadDay: 500000000,
    downloadDay: 1000000000,
    downloadMonth: 20000000000,
  ),
};
const imageUsageWorkoutLimitBytes = 100000000;

Map<String, dynamic> usageMap(Object? value) {
  if (value is! Map) throw const FormatException('사용량 응답 형식을 확인하지 못했어요.');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

int usageInt(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > 9007199254740991 ||
      value != value.roundToDouble()) {
    throw const FormatException('사용량 응답 숫자를 확인하지 못했어요.');
  }
  return value.toInt();
}

String usageString(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const FormatException('사용량 응답을 확인하지 못했어요.');
  }
  return value;
}

void usageSchema(Map<String, dynamic> json) {
  if (json['schemaVersion'] != 1) throw const FormatException('앱 업데이트가 필요해요.');
}

class ImagePeriodUsage {
  ImagePeriodUsage.fromJson(Map<String, dynamic> json)
    : key = usageString(json['key']),
      resetsAtMs = usageInt(json['resetsAtMs']),
      limitBytes = usageInt(json['limitBytes']),
      grantedBytes = usageInt(json['grantedBytes']),
      usedBytes = usageInt(json['usedBytes']),
      reservedBytes = usageInt(json['reservedBytes']),
      unknownBytes = usageInt(json['unknownBytes']),
      remainingBytes = usageInt(json['remainingBytes']),
      protectedOverageBytes = usageInt(json['protectedOverageBytes']);
  final String key;
  final int resetsAtMs,
      limitBytes,
      grantedBytes,
      usedBytes,
      reservedBytes,
      unknownBytes,
      remainingBytes,
      protectedOverageBytes;
}

class ImageStorageUsage {
  ImageStorageUsage.fromJson(Map<String, dynamic> json)
    : limitBytes = json['limitBytes'] == null
          ? null
          : usageInt(json['limitBytes']),
      usedBytes = usageInt(json['usedBytes']),
      reservedBytes = usageInt(json['reservedBytes']),
      unknownBytes = usageInt(json['unknownBytes']),
      complete = json['complete'] == true;
  final int? limitBytes;
  final int usedBytes, reservedBytes, unknownBytes;
  final bool complete;
}

class ImageUsage {
  ImageUsage.fromJson(Map<String, dynamic> json)
    : mode = usageString(json['mode']),
      policyPlan = json['policyPlan'] as String?,
      policyRevision = usageString(json['policyRevision']),
      measuredAtMs = usageInt(json['measuredAtMs']),
      revision = usageInt(json['revision']),
      storage = ImageStorageUsage.fromJson(usageMap(json['storage'])),
      uploadDay = _period(json['uploadDay']),
      downloadDay = _period(json['downloadDay']),
      downloadMonth = _period(json['downloadMonth']),
      attribution = usageString(json['attribution']),
      nextEligibleAtMs = json['nextEligibleAtMs'] == null
          ? null
          : usageInt(json['nextEligibleAtMs']) {
    usageSchema(json);
    if (!const {'legacy', 'observe', 'enrolled'}.contains(mode) ||
        (policyPlan != null && !imageUsageLimits.containsKey(policyPlan)) ||
        policyRevision != imageUsagePolicyRevision) {
      throw const FormatException('앱 업데이트 후 사용량을 다시 확인해 주세요.');
    }
  }
  static ImagePeriodUsage? _period(Object? value) =>
      value == null ? null : ImagePeriodUsage.fromJson(usageMap(value));
  final String mode, policyRevision, attribution;
  final String? policyPlan;
  final int measuredAtMs, revision;
  final int? nextEligibleAtMs;
  final ImageStorageUsage storage;
  final ImagePeriodUsage? uploadDay, downloadDay, downloadMonth;
}

class ImageUsageFailure implements Exception {
  const ImageUsageFailure(
    this.reason, {
    this.retryable = false,
    this.usage,
    this.requiredBytes,
    this.nextEligibleAtMs,
  });
  factory ImageUsageFailure.fromJson(Object? value) {
    final json = usageMap(value);
    usageSchema(json);
    if (json['policyRevision'] != imageUsagePolicyRevision) {
      return const ImageUsageFailure('policy_or_client_upgrade_required');
    }
    return ImageUsageFailure(
      usageString(json['reason']),
      retryable: json['retryable'] == true,
      usage: json['usage'] == null
          ? null
          : ImageUsage.fromJson(usageMap(json['usage'])),
      requiredBytes: json['requiredBytes'] == null
          ? null
          : usageInt(json['requiredBytes']),
      nextEligibleAtMs: json['nextEligibleAtMs'] == null
          ? null
          : usageInt(json['nextEligibleAtMs']),
    );
  }
  final String reason;
  final bool retryable;
  final ImageUsage? usage;
  final int? requiredBytes, nextEligibleAtMs;
  bool get quotaDenied => const {
    'daily_transfer_limit',
    'monthly_transfer_limit',
    'both_transfer_limits',
    'insufficient_start_budget',
    'storage_limit',
    'daily_upload_limit',
    'workout_image_limit',
  }.contains(reason);
  String get message => switch (reason) {
    'daily_transfer_limit' ||
    'monthly_transfer_limit' ||
    'both_transfer_limits' ||
    'insufficient_start_budget' => '이미지 전송 한도에 도달해 새 수업을 시작할 수 없어요. 진행 중인 수업은 계속할 수 있어요. 사용량과 다음 이용 가능 시각을 확인해 주세요.',
    'storage_limit' => '이미지 보관 한도에 도달했어요. 사용량을 확인해 주세요. 선택한 파일과 초안은 유지됩니다.',
    'daily_upload_limit' =>
      '오늘의 이미지 업로드 한도에 도달했어요. 사용량을 확인해 주세요. 선택한 파일과 초안은 유지됩니다.',
    'workout_image_limit' => '수업당 이미지 한도는 100MB예요. 선택한 파일과 초안은 유지됩니다.',
    'usage_reconciliation_pending' =>
      '이미지 사용량을 확인 중이에요. 잠시 후 다시 확인해 주세요. 진행 중인 수업은 계속할 수 있어요.',
    'policy_or_client_upgrade_required' => '앱과 연결된 TV를 업데이트한 뒤 다시 확인해 주세요.',
    'legacy_asset_transition_required' =>
      '기존 이미지의 전환 확인이 필요해 새 수업을 준비할 수 없어요. 기존 자료와 진행 중인 수업은 유지됩니다.',
    'entitlement_unverified' => '이용 권한을 확인하지 못했어요. 프로필의 이용 상태를 확인해 주세요.',
    'session_changed' => '진행 중이거나 준비 중인 수업이 있어요. 현재 수업 상태를 확인해 주세요.',
    'admission_expired' => '수업 준비 시간이 만료됐어요. 수업 준비를 다시 확인해 주세요.',
    'upload_mismatch' => '이미지 파일을 확인하지 못했어요. 선택한 파일은 유지됩니다. 다시 시도해 주세요.',
    'start_pending' => '시작 상태 확인 중이에요. 현재 수업으로 돌아가거나 같은 요청을 다시 확인해 주세요.',
    _ => '사용량 확인 실패. 연결을 확인하고 다시 시도해 주세요. 선택한 파일과 초안은 유지됩니다.',
  };
  @override
  String toString() => message;
}

class ManagedImageAsset {
  ManagedImageAsset.fromJson(Map<String, dynamic> json)
    : assetId = usageString(json['assetId']),
      source = usageString(json['source']),
      generation = usageString(json['generation']),
      sizeBytes = usageInt(json['sizeBytes']),
      contentType = usageString(json['contentType']),
      sha256 = usageString(json['sha256']);
  final String assetId, source, generation, contentType, sha256;
  final int sizeBytes;
}

class ClassAdmission {
  ClassAdmission.fromJson(Map<String, dynamic> json)
    : admissionId = usageString(json['admissionId']),
      sessionId = usageString(json['sessionId']),
      epoch = usageInt(json['epoch']),
      manifestHash = usageString(json['manifestHash']),
      clientFingerprint = usageString(json['clientFingerprint']),
      policyRevision = usageString(json['policyRevision']),
      status = usageString(json['status']),
      prepareExpiresAtMs = usageInt(json['prepareExpiresAtMs']),
      targetDeviceIds = List<String>.from(json['targetDeviceIds'] as List),
      reservedDownloadBytes = usageInt(json['reservedDownloadBytes']),
      usage = ImageUsage.fromJson(usageMap(json['usage'])),
      session = json['session'] == null ? null : usageMap(json['session']) {
    usageSchema(json);
  }
  final String admissionId,
      sessionId,
      manifestHash,
      clientFingerprint,
      policyRevision,
      status;
  final int epoch, prepareExpiresAtMs, reservedDownloadBytes;
  final List<String> targetDeviceIds;
  final ImageUsage usage;
  final Map<String, dynamic>? session;
  bool get pending => status == 'committing';
}

class ImageUploadPermit {
  ImageUploadPermit.fromJson(Map<String, dynamic> json)
    : uploadId = usageString(json['uploadId']),
      expiresAtMs = usageInt(json['expiresAtMs']),
      status = usageString(json['status']),
      uploadUrl = json['uploadUrl'] as String?,
      asset = json['asset'] == null
          ? null
          : ManagedImageAsset.fromJson(usageMap(json['asset'])) {
    usageSchema(json);
  }
  final String uploadId, status;
  final int expiresAtMs;
  final String? uploadUrl;
  final ManagedImageAsset? asset;
}

String decimalImageBytes(int bytes) {
  if (bytes >= 1000000000) return '${_decimal(bytes / 1000000000)}GB';
  if (bytes >= 1000000) return '${_decimal(bytes / 1000000)}MB';
  if (bytes >= 1000) return '${_decimal(bytes / 1000)}KB';
  return '${bytes}B';
}

String _decimal(double value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
