bool isHexColor(String value) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value);

int? parseHexColor(String? value) => value != null && isHexColor(value)
    ? 0xFF000000 | int.parse(value.substring(1), radix: 16)
    : null;

String colorHex(int value) =>
    '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
