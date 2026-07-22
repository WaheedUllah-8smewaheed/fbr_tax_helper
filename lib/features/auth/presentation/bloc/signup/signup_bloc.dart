import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';

part 'signup_event.dart';
part 'signup_state.dart';

class SignupBloc extends Bloc<SignupEvent, SignupState> {
  final AuthService _authService;

  SignupBloc({required AuthService authService})
    : _authService = authService,
      super(SignupInitial()) {
    on<SignUpButtonPressed>(_onSignUpButtonPressed);
    on<SignUpWithGooglePressed>(_onSignUpWithGooglePressed);
  }

  Future<void> _onSignUpButtonPressed(
    SignUpButtonPressed event,
    Emitter<SignupState> emit,
  ) async {
    emit(SignupLoading());
    try {
      await _authService.signUpWithEmail(
        name: event.name,
        contactNumber: event.contactNumber,
        email: event.email,
        password: event.password,
      );
      emit(SignupSuccess());
    } on AuthServiceException catch (e) {
      emit(SignupFailure(e.message));
    }
  }

  Future<void> _onSignUpWithGooglePressed(
    SignUpWithGooglePressed event,
    Emitter<SignupState> emit,
  ) async {
    emit(SignupLoading());
    try {
      await _authService.signInWithGoogle(requestDriveAccess: false);
      emit(SignupSuccess());
    } on TotpChallengeRequiredException {
      emit(
        const SignupFailure(
          'This Google account already has 2FA. Return to Sign in and enter your authenticator code.',
        ),
      );
    } on AuthServiceException catch (error) {
      emit(SignupFailure(error.message));
    } catch (_) {
      emit(const SignupFailure('Google sign up failed. Please try again.'));
    }
  }
}
