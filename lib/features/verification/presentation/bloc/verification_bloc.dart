import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../data/models/cpr_status_model.dart';
import '../../data/repositories/verification_repository.dart';
import 'verification_event.dart';
import 'verification_state.dart';

class VerificationBloc extends Bloc<VerificationEvent, VerificationState> {
  VerificationBloc({VerificationRepository? repository})
    : _repository = repository ?? VerificationRepository(),
      super(const VerificationState()) {
    on<CheckAtlStatus>(_onCheckAtlStatus);
    on<LookupNtnProfile>(_onLookupNtnProfile);
    on<StartTrackingCpr>(_onStartTrackingCpr);
    on<CprStatusUpdated>(_onCprStatusUpdated);
    on<CprStatusFailed>(_onCprStatusFailed);
  }

  final VerificationRepository _repository;
  StreamSubscription<CprStatusModel>? _cprSubscription;

  Future<void> _onCheckAtlStatus(
    CheckAtlStatus event,
    Emitter<VerificationState> emit,
  ) async {
    emit(
      state.copyWith(
        atlStatus: VerificationRequestStatus.loading,
        clearAtlError: true,
      ),
    );

    try {
      final result = await _repository.checkAtlStatus(
        event.cnic,
        forceRefresh: event.forceRefresh,
      );
      emit(
        state.copyWith(
          atlStatus: VerificationRequestStatus.success,
          atlResult: result,
          clearAtlError: true,
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          atlStatus: VerificationRequestStatus.failure,
          atlError: error.message,
          atlErrorCode: error.code,
        ),
      );
    }
  }

  Future<void> _onLookupNtnProfile(
    LookupNtnProfile event,
    Emitter<VerificationState> emit,
  ) async {
    emit(
      state.copyWith(
        ntnStatus: VerificationRequestStatus.loading,
        clearNtnError: true,
      ),
    );

    try {
      final result = await _repository.lookupNtnProfile(event.cnic);
      emit(
        state.copyWith(
          ntnStatus: VerificationRequestStatus.success,
          ntnResult: result,
          clearNtnError: true,
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          ntnStatus: VerificationRequestStatus.failure,
          ntnError: error.message,
          ntnErrorCode: error.code,
        ),
      );
    }
  }

  Future<void> _onStartTrackingCpr(
    StartTrackingCpr event,
    Emitter<VerificationState> emit,
  ) async {
    emit(
      state.copyWith(
        cprStatus: VerificationRequestStatus.loading,
        clearCprError: true,
      ),
    );

    try {
      final result = await _repository.trackCpr(event.cprNumber);
      emit(
        state.copyWith(
          cprStatus: VerificationRequestStatus.success,
          cprResult: result,
          clearCprError: true,
        ),
      );

      await _cprSubscription?.cancel();
      _cprSubscription = _repository
          .watchCprStatus(event.cprNumber)
          .listen(
            (status) => add(CprStatusUpdated(status)),
            onError: (_) => add(
              const CprStatusFailed('Could not refresh CPR status. Try again.'),
            ),
          );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          cprStatus: VerificationRequestStatus.failure,
          cprError: error.message,
          cprErrorCode: error.code,
        ),
      );
    }
  }

  void _onCprStatusUpdated(
    CprStatusUpdated event,
    Emitter<VerificationState> emit,
  ) {
    emit(
      state.copyWith(
        cprStatus: VerificationRequestStatus.success,
        cprResult: event.status,
        clearCprError: true,
      ),
    );
  }

  void _onCprStatusFailed(
    CprStatusFailed event,
    Emitter<VerificationState> emit,
  ) {
    emit(
      state.copyWith(
        cprStatus: VerificationRequestStatus.failure,
        cprError: event.message,
        cprErrorCode: ApiErrorCode.unknown,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _cprSubscription?.cancel();
    return super.close();
  }
}
