abstract class UciEngine {
  Stream<String> get stdoutLines;

  Future<void> start();

  void send(String command);

  Future<void> dispose();
}
