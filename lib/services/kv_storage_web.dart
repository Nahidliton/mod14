import 'dart:html' as html;

class KvStorage {
  String? getItem(String key) => html.window.localStorage[key];

  void setItem(String key, String value) {
    html.window.localStorage[key] = value;
  }

  void removeItem(String key) {
    html.window.localStorage.remove(key);
  }
}
