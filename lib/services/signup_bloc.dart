import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';

part 'signup_event.dart';
part 'signup_state.dart';

class SignupBloc extends Bloc<SignupEvent, SignupState> {
  final AuthService _authService;

  SignupBloc({required AuthService authService})
    : _authService = authService,
      super(SignupInitial()) {
    on<SignUpButtonPressed>(_onSignUpButtonPressed);
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
}
