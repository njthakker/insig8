import Foundation

class Insig8Emitter {

  var hasListeners = false

  nonisolated(unsafe) public static let sharedInstance = Insig8Emitter()

  nonisolated(unsafe) private static var emitter: Insig8Native!

  func registerEmitter(emitter: Insig8Native) {
    Insig8Emitter.emitter = emitter
  }

  func dispatch(name: String, body: Any?) {
    if hasListeners {
      Insig8Emitter.emitter.sendEvent(withName: name, body: body)
    }
  }

  // You can add more typesafety here if you want to
  func keyDown(key: String?, keyCode: UInt16, meta: Bool, shift: Bool, control: Bool) {
    dispatch(
      name: "keyDown",
      body: [
        "key": key!,
        "keyCode": keyCode,
        "meta": meta,
        "shift": shift,
        "control": control,
      ])
  }

  func keyUp(key: String?, keyCode: UInt16, meta: Bool, shift: Bool, control: Bool) {
    dispatch(
      name: "keyUp",
      body: [
        "key": key!,
        "keyCode": keyCode,
        "meta": meta,
        "shift": shift,
        "control": control,
      ])
  }

  func onShow(target: String?) {
    dispatch(
      name: "onShow",
      body: [
        "target": target
      ])
  }

  func onHotkey(id: String) {
    dispatch(
      name: "hotkey",
      body: [
        "id": id
      ])
  }

  func onHide() {
    dispatch(name: "onHide", body: [])
  }

  func textCopied(_ txt: String, _ bundle: String?) {
    dispatch(
      name: "onTextCopied",
      body: [
        "text": txt,
        "bundle": bundle,
      ])
  }

  func fileCopied(_ text: String, _ url: String, _ bundle: String?) {
    dispatch(
      name: "onFileCopied",
      body: [
        "text": text,
        "url": url,
        "bundle": bundle,
      ])
  }

  func onStatusBarItemClick() {
    dispatch(name: "onStatusBarItemClick", body: [])
  }
}
