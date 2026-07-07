import 'dart:convert';
void main() {
  print(jsonEncode({'a': 50.0, 'b': 0.0}));
  print(jsonEncode({'a': 50, 'b': 0}));
  print(jsonEncode({'a': '79', 'b': 79}));
}
