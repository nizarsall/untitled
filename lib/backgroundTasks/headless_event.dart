import 'events.dart';

class HeadlessEvent {
  String name;


  dynamic event;

  HeadlessEvent(String name, dynamic params) {
    this.name = name;

    try {
      if(name == Event.BOOT)
        event = params;
        else if(name == Event.TERMINATE)
          event = dynamic;

      }
     catch (e, stacktrace) {
      return;
    }
  }

  /// String representation of `HeadlessEvent` for `print` to logs.
  String toString() {
    return '[HeadlessEvent name: $name, event: $event]';
  }
}
