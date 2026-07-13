part of 'login_bloc.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object> get props => [];
}

class LoginWithEmailAndPasswordPressed extends LoginEvent {
  final String email;
  final String password;

  const LoginWithEmailAndPasswordPressed({
    required this.email,
    required this.password,
  });
}
