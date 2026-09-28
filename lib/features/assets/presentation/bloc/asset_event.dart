part of 'asset_bloc.dart';

abstract class AssetEvent extends Equatable {
  const AssetEvent();

  @override
  List<Object> get props => [];
}

class LoadAssets extends AssetEvent {
  final String userId;
  const LoadAssets({required this.userId});
  @override
  List<Object> get props => [userId];
}

class AddAsset extends AssetEvent {
  final Asset asset;
  const AddAsset({required this.asset});
  @override
  List<Object> get props => [asset];
}

class UpdateAsset extends AssetEvent {
  final Asset asset;
  const UpdateAsset({required this.asset});
  @override
  List<Object> get props => [asset];
}

class DeleteAsset extends AssetEvent {
  final int id;
  final String userId;
  const DeleteAsset({required this.id, required this.userId});
  @override
  List<Object> get props => [id, userId];
}
