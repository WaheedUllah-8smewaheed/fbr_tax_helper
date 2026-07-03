import 'package:equatable/equatable.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../data/models/atl_status_model.dart';
import '../../data/models/cpr_status_model.dart';
import '../../data/models/ntn_profile_model.dart';

enum VerificationRequestStatus { initial, loading, success, failure }

class VerificationState extends Equatable {
  const VerificationState({
    this.atlStatus = VerificationRequestStatus.initial,
    this.ntnStatus = VerificationRequestStatus.initial,
    this.cprStatus = VerificationRequestStatus.initial,
    this.atlResult,
    this.ntnResult,
    this.cprResult,
    this.atlError,
    this.ntnError,
    this.cprError,
    this.atlErrorCode,
    this.ntnErrorCode,
    this.cprErrorCode,
  });

  final VerificationRequestStatus atlStatus;
  final VerificationRequestStatus ntnStatus;
  final VerificationRequestStatus cprStatus;
  final AtlStatusModel? atlResult;
  final NtnProfileModel? ntnResult;
  final CprStatusModel? cprResult;
  final String? atlError;
  final String? ntnError;
  final String? cprError;
  final ApiErrorCode? atlErrorCode;
  final ApiErrorCode? ntnErrorCode;
  final ApiErrorCode? cprErrorCode;

  VerificationState copyWith({
    VerificationRequestStatus? atlStatus,
    VerificationRequestStatus? ntnStatus,
    VerificationRequestStatus? cprStatus,
    AtlStatusModel? atlResult,
    NtnProfileModel? ntnResult,
    CprStatusModel? cprResult,
    String? atlError,
    String? ntnError,
    String? cprError,
    ApiErrorCode? atlErrorCode,
    ApiErrorCode? ntnErrorCode,
    ApiErrorCode? cprErrorCode,
    bool clearAtlError = false,
    bool clearNtnError = false,
    bool clearCprError = false,
  }) {
    return VerificationState(
      atlStatus: atlStatus ?? this.atlStatus,
      ntnStatus: ntnStatus ?? this.ntnStatus,
      cprStatus: cprStatus ?? this.cprStatus,
      atlResult: atlResult ?? this.atlResult,
      ntnResult: ntnResult ?? this.ntnResult,
      cprResult: cprResult ?? this.cprResult,
      atlError: clearAtlError ? null : atlError ?? this.atlError,
      ntnError: clearNtnError ? null : ntnError ?? this.ntnError,
      cprError: clearCprError ? null : cprError ?? this.cprError,
      atlErrorCode: clearAtlError ? null : atlErrorCode ?? this.atlErrorCode,
      ntnErrorCode: clearNtnError ? null : ntnErrorCode ?? this.ntnErrorCode,
      cprErrorCode: clearCprError ? null : cprErrorCode ?? this.cprErrorCode,
    );
  }

  @override
  List<Object?> get props => [
    atlStatus,
    ntnStatus,
    cprStatus,
    atlResult,
    ntnResult,
    cprResult,
    atlError,
    ntnError,
    cprError,
    atlErrorCode,
    ntnErrorCode,
    cprErrorCode,
  ];
}
