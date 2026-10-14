import 'dart:async';

import 'package:cloud_board/src/app/feature/entitlement/domain/plan_limit_failure.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';

/// User copy is selected from known cases, never from exception text. Keep the
/// original exception and stack in controller/diagnostics state.
String workoutErrorMessage(
  Object? error, {
  String fallback = '작업을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.',
}) {
  final limit = PlanLimitFailure.from(error);
  if (limit != null) return limit.message;
  if (error is FirebaseFunctionsException &&
      error.details is Map &&
      (error.details as Map)['reason'] == 'entitlement-unavailable') {
    return '이용 권한을 확인하지 못했습니다. 작성 내용은 유지됩니다. 연결을 확인하고 다시 저장해 주세요.';
  }
  if (error is LibraryFailure) {
    if (error.cause != null) {
      return workoutErrorMessage(error.cause, fallback: fallback);
    }
    return switch (error.message) {
      '로그인 계정을 확인해 주세요.' => '로그인 계정이 변경되었거나 연결이 끊겼습니다. 계정을 확인한 뒤 다시 시도해 주세요.',
      '라이브러리를 불러온 뒤 저장해 주세요.' => '최신 라이브러리를 불러온 뒤 다시 저장해 주세요.',
      _ => fallback,
    };
  }
  if (error is TimeoutException) {
    return '응답을 받지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' ||
      'deadline-exceeded' ||
      'network-request-failed' ||
      'retry-limit-exceeded' => '서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
      'permission-denied' ||
      'unauthorized' => '이 자료를 사용할 권한이 없습니다. 자료 소유자나 관리자에게 권한을 확인해 주세요.',
      'unauthenticated' ||
      'user-token-expired' => '로그인 상태를 확인하지 못했습니다. 다시 로그인한 뒤 시도해 주세요.',
      'not-found' ||
      'object-not-found' => '자료가 삭제되었거나 더 이상 사용할 수 없습니다. 목록을 새로고침해 주세요.',
      'resource-exhausted' ||
      'quota-exceeded' => '요청이 많아 지금은 처리할 수 없습니다. 잠시 후 다시 시도해 주세요.',
      'aborted' => '다른 기기에서 자료가 변경되었습니다. 최신 내용을 불러온 뒤 다시 시도해 주세요.',
      _ => fallback,
    };
  }
  if (error is StateError) {
    return switch (error.message) {
      workoutPlayingEditMessage =>
        '수업 진행 중에는 편집할 수 없습니다. 수업을 종료한 뒤 다시 시도해 주세요.',
      '워크아웃을 찾을 수 없습니다.' => '워크아웃이 삭제되었거나 더 이상 사용할 수 없습니다. 목록을 새로고침해 주세요.',
      '수업 상태를 확인하지 못했습니다. 연결을 확인해 주세요.' =>
        '수업 상태를 확인하지 못했습니다. 연결을 확인한 뒤 다시 시도해 주세요.',
      '수업 상태를 확인하고 있습니다.' => '수업 상태를 확인하고 있습니다. 잠시 후 다시 시도해 주세요.',
      '로그인이 필요합니다.' ||
      '로그인 계정을 확인해 주세요.' ||
      '인증을 확인해 주세요.' ||
      '로그인 계정이 변경되었습니다.' ||
      '계정이 변경되었습니다. 다시 확인해 주세요.' =>
        '로그인 계정이 변경되었거나 연결이 끊겼습니다. 계정을 확인한 뒤 다시 시도해 주세요.',
      '진행 중인 수업이 없습니다.' => '진행 중인 수업이 없습니다. 목록에서 수업을 시작해 주세요.',
      _ => fallback,
    };
  }
  return fallback;
}

String playbackErrorMessage(Object? error) {
  if (error is PlaybackFailure) {
    return switch (error.code) {
      'display_update_required' => '연결된 디스플레이 앱을 업데이트한 뒤 수업을 시작해 주세요.',
      'invalid_timing' || 'invalid_position' => '수업의 타이머 설정을 확인한 뒤 다시 시작해 주세요.',
      'session_completed' => '이미 종료된 수업입니다. 목록에서 새 수업을 시작해 주세요.',
      'already_started' => '이미 진행 중인 수업이 있습니다. 현재 수업을 확인해 주세요.',
      'revision_conflict' ||
      'session_changed' ||
      'command_expired' ||
      'status_changed' => '수업 상태가 변경되었습니다. 최신 수업 상태를 확인한 뒤 다시 조작해 주세요.',
      _ => '수업을 제어하지 못했습니다. 연결과 현재 수업 상태를 확인한 뒤 다시 시도해 주세요.',
    };
  }
  if (error is StateError &&
      const [
        '프로필에서 휴대폰 인증과 이용 상태를 확인해 주세요. 프로그램 편집과 미리보기는 계속 사용할 수 있습니다.',
        // Compatibility with errors retained by an older running client.
        '프로필의 센터 정보 · 온보딩에서 무료 체험을 시작하거나 이용 상태를 확인해 주세요. 프로그램 편집과 미리보기는 계속 사용할 수 있습니다.',
      ].contains(error.message)) {
    return '프로필에서 휴대폰 인증과 이용 상태를 확인한 뒤 수업을 시작해 주세요.';
  }
  return workoutErrorMessage(
    error,
    fallback: '수업을 제어하지 못했습니다. 연결과 현재 수업 상태를 확인한 뒤 다시 시도해 주세요.',
  );
}
