class XAuth {
  // Private constructor
  XAuth._privateConstructor();

  static final XAuth _instance = XAuth._privateConstructor();


  static XAuth get instance => _instance;


  String? key;
  String? accessToken;
  String? folderId;


  void clear() {
    key = null;
    accessToken = null;
    folderId = null;
  }
}