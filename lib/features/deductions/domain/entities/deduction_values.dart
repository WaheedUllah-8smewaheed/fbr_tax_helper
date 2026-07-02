class DeductionValues {
  const DeductionValues({
    this.mobileTax = 0.0,
    this.electricityTax = 0.0,
    this.internetTax = 0.0,
    this.vehicleTax = 0.0,
  });

  final double mobileTax;
  final double electricityTax;
  final double internetTax;
  final double vehicleTax;

  static const zero = DeductionValues();

  double get total => mobileTax + electricityTax + internetTax + vehicleTax;

  bool get hasAnyValue => total > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeductionValues &&
          runtimeType == other.runtimeType &&
          mobileTax == other.mobileTax &&
          electricityTax == other.electricityTax &&
          internetTax == other.internetTax &&
          vehicleTax == other.vehicleTax;

  @override
  int get hashCode =>
      mobileTax.hashCode ^
      electricityTax.hashCode ^
      internetTax.hashCode ^
      vehicleTax.hashCode;
}
