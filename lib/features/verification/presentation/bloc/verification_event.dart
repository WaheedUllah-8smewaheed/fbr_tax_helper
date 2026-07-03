import 'package:equatable/equatable.dart';

import '../../data/models/cpr_status_model.dart';

abstract class VerificationEvent extends Equatable {
  const VerificationEvent();

  @override
  List<Object?> get props => [];
}

class CheckAtlStatus extends VerificationEvent {
  const CheckAtlStatus(this.cnic, {this.forceRefresh = false});

  final String cnic;
  final bool forceRefresh;

  @override
  List<Object?> get props => [cnic, forceRefresh];
}

class LookupNtnProfile extends VerificationEvent {
  const LookupNtnProfile(this.cnic);

  final String cnic;

  @override
  List<Object?> get props => [cnic];
}

class StartTrackingCpr extends VerificationEvent {
  const StartTrackingCpr(this.cprNumber);

  final String cprNumber;

  @override
  List<Object?> get props => [cprNumber];
}

class CprStatusUpdated extends VerificationEvent {
  const CprStatusUpdated(this.status);

  final CprStatusModel status;

  @override
  List<Object?> get props => [status];
}

class CprStatusFailed extends VerificationEvent {
  const CprStatusFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
