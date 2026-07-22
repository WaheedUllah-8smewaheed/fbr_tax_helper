part of 'signup_bloc.dart';

abstract class SignupEvent extends Equatable {
  const SignupEvent();

  @override
  List<Object> get props => [];
}

class SignUpButtonPressed extends SignupEvent {
  final String name;
  final String contactNumber;
  final String email;
  final String password;

  const SignUpButtonPressed({
    required this.name,
    required this.contactNumber,
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [name, contactNumber, email, password];
}

class SignUpWithGooglePressed extends SignupEvent {
  const SignUpWithGooglePressed();
}
