import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fbr_tax_helper/features/khata/domain/entities/khata_entry.dart';
import 'package:fbr_tax_helper/core/database/tax_database.dart';

part 'khata_event.dart';
part 'khata_state.dart';

class KhataBloc extends Bloc<KhataEvent, KhataState> {
  final TaxDatabase _database;

  KhataBloc({required TaxDatabase database})
      : _database = database,
        super(KhataInitial()) {
    on<LoadKhataEntries>(_onLoadKhataEntries);
    on<AddKhataEntry>(_onAddKhataEntry);
    on<UpdateKhataEntry>(_onUpdateKhataEntry);
    on<DeleteKhataEntry>(_onDeleteKhataEntry);
    on<SettleKhataEntry>(_onSettleKhataEntry);
  }

  Future<void> _onLoadKhataEntries(
      LoadKhataEntries event, Emitter<KhataState> emit) async {
    emit(KhataLoading());
    try {
      final data = await _database.fetchKhataEntries(userId: event.userId);
      final entries = data.map((e) => KhataEntry.fromMap(e)).toList();
      emit(KhataLoaded(entries: entries));
    } catch (e) {
      emit(KhataError(message: e.toString()));
    }
  }

  Future<void> _onAddKhataEntry(
      AddKhataEntry event, Emitter<KhataState> emit) async {
    try {
      await _database.insertKhataEntry(event.entry.toMap());
      add(LoadKhataEntries(userId: event.entry.userId));
    } catch (e) {
      emit(KhataError(message: e.toString()));
    }
  }

  Future<void> _onUpdateKhataEntry(
      UpdateKhataEntry event, Emitter<KhataState> emit) async {
    try {
      await _database.updateKhataEntry(event.entry.toMap());
      add(LoadKhataEntries(userId: event.entry.userId));
    } catch (e) {
      emit(KhataError(message: e.toString()));
    }
  }

  Future<void> _onDeleteKhataEntry(
      DeleteKhataEntry event, Emitter<KhataState> emit) async {
    try {
      await _database.deleteKhataEntry(event.id);
      add(LoadKhataEntries(userId: event.userId));
    } catch (e) {
      emit(KhataError(message: e.toString()));
    }
  }

  Future<void> _onSettleKhataEntry(
      SettleKhataEntry event, Emitter<KhataState> emit) async {
    try {
      await _database.updateKhataEntry(event.entry.toMap());
      add(LoadKhataEntries(userId: event.entry.userId));
    } catch (e) {
      emit(KhataError(message: e.toString()));
    }
  }
}
