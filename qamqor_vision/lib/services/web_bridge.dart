import 'dart:js_interop';

@JS('jaryq.capture')
external JSPromise<JSString> captureWeb(JSString mode, JSString language);
