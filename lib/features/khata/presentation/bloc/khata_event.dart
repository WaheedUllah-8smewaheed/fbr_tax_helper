part of 'khata_bloc.dart';

abstract class KhataEvent extends Equatable {
  const KhataEvent();

  @override
  List<Object> get props => [];
}

class LoadKhataEntries extends KhataEvent {
  final String userId;
  const LoadKhataEntries({required this.userId});
  @override
  List<Object> get props => [userId];
}

class AddKhataEntry extends KhataEvent {
  final KhataEntry entry;
  const AddKhataEntry({required this.entry});
  @override
  List<Object> get props => [entry];
}

class UpdateKhataEntry extends KhataEvent {
  final KhataEntry entry;
  const UpdateKhataEntry({required this.entry});
  @override
  List<Object> get props => [entry];
}

class DeleteKhataEntry extends KhataEvent {
  final int id;
  final String userId;
  const DeleteKhataEntry({required this.id, required this.userId});
  @override
  List<Object> get props => [id, userId];
}

class SettleKhataEntry extends KhataEvent {
  final KhataEntry entry;
  const SettleKhataEntry({required this.entry});
  @override
  List<Object> get props => [entry];
}
