String formatMoney(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < rounded.length; index++) {
    final positionFromEnd = rounded.length - index;
    buffer.write(rounded[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String formatNetBalance(double netBalance) {
  if (netBalance < 0) {
    return '-PKR ${formatMoney(netBalance.abs())}';
  } else if (netBalance > 0) {
    return '+PKR ${formatMoney(netBalance)}';
  } else {
    return 'PKR 0';
  }
}
