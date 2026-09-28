import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fbr_tax_helper/features/assets/domain/entities/asset.dart';
import 'package:fbr_tax_helper/core/database/tax_database.dart';

part 'asset_event.dart';
part 'asset_state.dart';

class AssetBloc extends Bloc<AssetEvent, AssetState> {
  final TaxDatabase _database;

  AssetBloc({required TaxDatabase database})
      : _database = database,
        super(AssetInitial()) {
    on<LoadAssets>(_onLoadAssets);
    on<AddAsset>(_onAddAsset);
    on<UpdateAsset>(_onUpdateAsset);
    on<DeleteAsset>(_onDeleteAsset);
  }

  Future<void> _onLoadAssets(
      LoadAssets event, Emitter<AssetState> emit) async {
    emit(AssetLoading());
    try {
      final data = await _database.fetchAssets(userId: event.userId);
      final assets = data.map((e) => Asset.fromMap(e)).toList();
      emit(AssetLoaded(assets: assets));
    } catch (e) {
      emit(AssetError(message: e.toString()));
    }
  }

  Future<void> _onAddAsset(
      AddAsset event, Emitter<AssetState> emit) async {
    try {
      await _database.insertAsset(event.asset.toMap());
      add(LoadAssets(userId: event.asset.userId));
    } catch (e) {
      emit(AssetError(message: e.toString()));
    }
  }

  Future<void> _onUpdateAsset(
      UpdateAsset event, Emitter<AssetState> emit) async {
    try {
      await _database.updateAsset(event.asset.toMap());
      add(LoadAssets(userId: event.asset.userId));
    } catch (e) {
      emit(AssetError(message: e.toString()));
    }
  }

  Future<void> _onDeleteAsset(
      DeleteAsset event, Emitter<AssetState> emit) async {
    try {
      await _database.deleteAsset(event.id);
      add(LoadAssets(userId: event.userId));
    } catch (e) {
      emit(AssetError(message: e.toString()));
    }
  }
}
