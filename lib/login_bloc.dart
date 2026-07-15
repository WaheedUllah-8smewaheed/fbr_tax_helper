import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AuthService _authService;

  LoginBloc({required AuthService authService})
    : _authService = authService,
      super(LoginInitial()) {
    on<LoginWithEmailAndPasswordPressed>(_onLoginWithEmailAndPasswordPressed);
    on<LoginWithGooglePressed>(_onLoginWithGooglePressed);
  }

  Future<void> _onLoginWithEmailAndPasswordPressed(
    LoginWithEmailAndPasswordPressed event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());
    try {
      await _authService.signInWithEmail(event.email, event.password);
      emit(LoginSuccess());
    } on TotpChallengeRequiredException catch (error) {
      emit(LoginTotpRequired(error.challenge));
    } on AuthServiceException catch (e) {
      emit(LoginFailure(e.message));
    } catch (_) {
      emit(
        const LoginFailure(
          'Email login failed. Check Firebase Email/Password sign-in setup.',
        ),
      );
    }
  }

  Future<void> _onLoginWithGooglePressed(
    LoginWithGooglePressed event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());
    try {
      await _authService.signInWithGoogle(requestDriveAccess: false);
      emit(LoginSuccess());
    } on TotpChallengeRequiredException catch (error) {
      emit(LoginTotpRequired(error.challenge));
    } on AuthServiceException catch (error) {
      emit(LoginFailure(error.message));
    } catch (_) {
      emit(const LoginFailure('Google sign in failed. Please try again.'));
    }
  }
}
