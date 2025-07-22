import Foundation
import HotKey
// import LaunchAtLogin  // Temporarily removed due to Xcode beta package resolution issues

// Global concurrency-safe accessibility constant
nonisolated(unsafe) let trustedCheckKey = kAXTrustedCheckOptionPrompt.takeRetainedValue()

#if canImport(React)
import React
#else
// Mock React Native types when not available
typealias RCTPromiseResolveBlock = (Any?) -> Void
typealias RCTPromiseRejectBlock = (String?, String?, Error?) -> Void

@objc class RCTEventEmitter: NSObject {
    override init() {
        super.init()
    }
    
    @objc func sendEvent(withName name: String, body: Any?) {
        // Mock implementation - do nothing when React Native not available
    }
    
    @objc func constantsToExport() -> [AnyHashable: Any]! {
        return [:]
    }
    
    @objc func startObserving() {
        // Mock implementation
    }
    
    @objc func stopObserving() {
        // Mock implementation
    }
    
    @objc static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc func supportedEvents() -> [String]? {
        return []
    }
}
#endif

nonisolated(unsafe) private let keychain = Keychain(service: "Insig8")

@objc(Insig8Native)  
class Insig8Native: RCTEventEmitter {
  @MainActor let appDelegate = NSApp.delegate as? AppDelegate

  override init() {
    super.init()
    Insig8Emitter.sharedInstance.registerEmitter(emitter: self)
    ApplicationSearcher.shared.onApplicationsChanged = {
      self.sendEvent(
        withName: "applicationsChanged",
        body: nil)
    }

    ApplicationSearcher.shared.startWatchingFolders()
  }

  @objc override func constantsToExport() -> [AnyHashable: Any]! {
    return [
      "accentColor": NSColor.controlAccentColor.usingColorSpace(.sRGB)!
        .hexString,
      "OSVersion": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
    ]
  }

  @objc override func startObserving() {
    Insig8Emitter.sharedInstance.hasListeners = true
  }

  @objc override func stopObserving() {
    Insig8Emitter.sharedInstance.hasListeners = false
  }

  @objc override static func requiresMainQueueSetup() -> Bool {
    return true
  }

  func sendKeyDown(characters: String) {
    sendEvent(
      withName: "keyDown",
      body: [
        "key": characters
      ])
  }

  @objc override func supportedEvents() -> [String]? {
    return [
      "keyDown",
      "keyUp",
      "onShow",
      "onHide",
      "onTextCopied",
      "onFileCopied",
      "onFileSearch",
      "onStatusBarItemClick",
      "hotkey",
      "applicationsChanged",
    ]
  }

  @objc func getApps(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    do {
      let apps = try ApplicationSearcher.shared.getAllApplications()
      resolve(apps)
    } catch {
      reject(error.localizedDescription, error.localizedDescription, nil)
    }
  }

  @objc func openFile(_ path: String) {
    guard let url = URL(string: path) else { return }
    NSWorkspace.shared.open(url)
  }

  @objc func openWithFinder(_ path: String) {
    guard let URL = URL(string: path) else {
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.promptsUserIfNeeded = true

    let finder = NSWorkspace.shared
      .urlForApplication(withBundleIdentifier: "com.apple.finder")
    NSWorkspace.shared.open(
      [URL],
      withApplicationAt: finder!,
      configuration: configuration
    )
  }

  @objc func toggleDarkMode() {
    DarkMode.isEnabled = !DarkMode.isEnabled
  }

  @objc func executeAppleScript(
    _ source: String, resolve: RCTPromiseResolveBlock,
    reject: RCTPromiseRejectBlock
  ) {

    let error = AppleScriptHelper.runAppleScript(source)
    if error == nil {
      resolve(nil)
    } else {
      reject(
        "AppleScriptError",
        error!["NSAppleScriptErrorMessage"] as? String,
        nil
      )
    }
  }

  @objc func executeBashScript(
    _ source: String,
    resolver: RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    let output = ShellHelper.sh(source)
    resolver(output)
  }

  @objc func getMediaInfo(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    MediaHelper.getCurrentMedia(callback: { information in
      let pathUrl = NSWorkspace.shared
        .urlForApplication(
          withBundleIdentifier: information["bundleIdentifier"]! as! String
        )?
        .path
      let imageData =
        information["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data

      if imageData == nil {
        resolve([
          "title": information["kMRMediaRemoteNowPlayingInfoTitle"],
          "artist": information["kMRMediaRemoteNowPlayingInfoArtist"],
          "bundleIdentifier": information["bundleIdentifier"],
          "url": pathUrl,
        ])
      } else {
        let bitmap = NSBitmapImageRep(data: imageData!)
        let data = bitmap?.representation(using: .jpeg, properties: [:])
        let base64 =
          data != nil
          ? "data:image/jpeg;base64,"
            + data!
            .base64EncodedString() : nil
        resolve([
          "title": information["kMRMediaRemoteNowPlayingInfoTitle"],
          "artist": information["kMRMediaRemoteNowPlayingInfoArtist"],
          "artwork": base64,
          "bundleIdentifier": information["bundleIdentifier"],
          "url": pathUrl,
        ])
      }

    })
  }

  @objc func setGlobalShortcut(_ key: String) {
    HotKeyManager.shared.mainHotKey.isPaused = true
    if key == "command" {
      HotKeyManager.shared.mainHotKey = HotKey(
        key: .space,
        modifiers: [.command],
        keyDownHandler: PanelManager.shared.toggleFromNonisolated
      )
    } else if key == "option" {
      HotKeyManager.shared.mainHotKey = HotKey(
        key: .space,
        modifiers: [.option],
        keyDownHandler: PanelManager.shared.toggleFromNonisolated
      )
    } else if key == "control" {
      HotKeyManager.shared.mainHotKey = HotKey(
        key: .space,
        modifiers: [.control],
        keyDownHandler: PanelManager.shared.toggleFromNonisolated
      )
    }
  }

  @objc func getAccessibilityStatus(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    resolve(AXIsProcessTrusted())
  }

  @objc func requestAccessibilityAccess(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    let promptKey = trustedCheckKey as NSString
    let options: NSDictionary = [
      promptKey: true
    ]
    Task {
      let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
      await MainActor.run {
        resolve(accessibilityEnabled)
      }
    }
  }

  @objc func setLaunchAtLogin(_ enabled: Bool) {
    LaunchAtLoginHelper.shared.setEnabled(enabled)
  }
  
  @objc func isLaunchAtLoginEnabled(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    resolve(LaunchAtLoginHelper.shared.isEnabled)
  }

  @objc func resizeFrontmostTopHalf() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveHalf(.top)
    }
  }

  @objc func resizeFrontmostBottomHalf() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveHalf(.bottom)
    }
  }

  @objc func resizeFrontmostRightHalf() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveHalf(.right)
    }
  }

  @objc func resizeFrontmostLeftHalf() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveHalf(.left)
    }
  }

  @objc func resizeFrontmostFullscreen() {
    Task { @MainActor in
      WindowManager.sharedInstance.fullscreen()
    }
  }

  @objc func resizeTopLeft() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveQuarter(.topLeft)
    }
  }

  @objc func resizeTopRight() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveQuarter(.topRight)
    }
  }

  @objc func resizeBottomLeft() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveQuarter(.bottomLeft)
    }
  }

  @objc func resizeBottomRight() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveQuarter(.bottomRight)
    }
  }

  @objc func moveFrontmostNextScreen() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveToNextScreen()
    }
  }

  @objc func moveFrontmostPrevScreen() {
    Task { @MainActor in
      WindowManager.sharedInstance.moveToPrevScreen()
    }
  }

  @objc func moveFrontmostCenter() {
    Task { @MainActor in
      WindowManager.sharedInstance.center()
    }
  }

  @objc func moveFrontmostToNextSpace() {
    Task { @MainActor in
      await WindowManager.sharedInstance.moveFrontmostToNextSpace()
    }
  }

  @objc func moveFrontmostToPreviousSpace() {
    Task { @MainActor in
      await WindowManager.sharedInstance.moveFrontmostToPreviousSpace()
    }
  }

  @objc func pasteToFrontmostApp(_ content: String) {
    Task { @MainActor in
      ClipboardHelper.pasteToFrontmostApp(content)
    }
  }

  @objc func insertToFrontmostApp(_ content: String) {
    Task { @MainActor in
      ClipboardHelper.insertToFrontmostApp(content)
    }
  }

  @objc func turnOnHorizontalArrowsListeners() {
    HotKeyManager.shared.catchHorizontalArrowsPress = true
  }

  @objc func turnOffHorizontalArrowsListeners() {
    HotKeyManager.shared.catchHorizontalArrowsPress = false
  }

  @objc func turnOnVerticalArrowsListeners() {
    HotKeyManager.shared.catchVerticalArrowsPress = true
  }

  @objc func turnOffVerticalArrowsListeners() {
    HotKeyManager.shared.catchVerticalArrowsPress = false
  }

  @objc func turnOnEnterListener() {
    HotKeyManager.shared.catchEnterPress = true
  }

  @objc func turnOffEnterListener() {
    HotKeyManager.shared.catchEnterPress = false
  }

  @MainActor @objc func checkForUpdates() {
    appDelegate?.checkForUpdates()
  }

  @objc func setWindowRelativeSize(_ relative: NSNumber) {
    DispatchQueue.main.async {
      PanelManager.shared.setRelativeSize(relative as! Double)
    }
  }

  @objc func openFinderAt(_ path: String) {
    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
  }

  @objc func setShowWindowOn(_ on: String) {
    switch on {
    case "screenWithFrontmost":
      PanelManager.shared.setPreferredScreen(.frontmost)
      break
    default:
      PanelManager.shared.setPreferredScreen(.withMouse)
      break
    }
  }

  @objc func toggleDND() {
    DoNotDisturb.toggle()
  }

  @objc func securelyStore(
    _ key: NSString,
    payload: NSString,
    resolver: RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    keychain[key as String] = payload as String
    resolver(true)
  }

  @objc func securelyRetrieve(
    _ key: NSString,
    resolver resolve: RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    let value = keychain[key as String]
    return resolve(value)
  }

  @objc func showToast(_ text: String, variant: String, timeout: NSNumber) {
    DispatchQueue.main.async {
      ToastManager.shared.showToast(
        text, variant: variant, timeout: timeout, image: nil)
    }
  }

  @objc func useBackgroundOverlay(_ v: Bool) {
    //    appDelegate?.useBackgroundOverlay = v
  }

  @objc func hideNotch() {
    NotchHelper.shared.hideNotch()
  }

  @objc func showWifiQR(_ SSID: String, password: String) {
    let image = WifiQR(name: SSID, password: password)
    DispatchQueue.main.async {
      let wifiInfo = "SSID: \(SSID)\nPassword: \(password)"
      ToastManager.shared.showToast(
        wifiInfo, variant: "none", timeout: 30, image: image)
    }
  }

  @objc func hasFullDiskAccess(
    _ resolve: RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    resolve(BookmarkHelper.hasFullDiskAccess())
  }

  @objc func getSafariBookmarks(
    _ resolve: RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    let bookmarks = BookmarkHelper.getSafariBookmars()
    resolve(bookmarks)
  }

  @objc func quit() {
    DispatchQueue.main.async {
      NSApplication.shared.terminate(self)
    }
  }

  @objc func setStatusBarItemTitle(_ title: String) {
    StatusBarItemManager.shared.setStatusBarTitle(title)
  }

  @objc func setMediaKeyForwardingEnabled(_ v: Bool) {
    DispatchQueue.main.async {
      self.appDelegate?.setMediaKeyForwardingEnabled(v)
    }
  }

  @objc func openFilePicker(
    _ resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    DispatchQueue.main.async {
      let panel = NSOpenPanel()
      panel.allowsMultipleSelection = false
      panel.canChooseDirectories = true
      panel.canChooseFiles = false
      if panel.runModal() == .OK {
        let fileName = panel.url?.absoluteString
        resolve(fileName)
      } else {
        reject(nil, nil, nil)
      }
    }
  }

  @objc func updateHotkeys(_ hotkeys: NSDictionary) {
    guard let hotkeys = hotkeys as? [String: String] else { return }
    HotKeyManager.shared.updateHotkeys(hotkeyMap: hotkeys)
  }

}
