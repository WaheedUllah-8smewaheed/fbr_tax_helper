part of 'asset_bloc.dart';

abstract class AssetState extends Equatable {
  const AssetState();

  @override
  List<Object> get props => [];
}

class AssetInitial extends AssetState {}

class AssetLoading extends AssetState {}

class AssetLoaded extends AssetState {
  final List<Asset> assets;
  const AssetLoaded({required this.assets});
  @override
  List<Object> get props => [assets];
}

class AssetError extends AssetState {
  final String message;
  const AssetError({required this.message});
  @override
  List<Object> get props => [message];
}
