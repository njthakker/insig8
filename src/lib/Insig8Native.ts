import {NativeEventEmitter, NativeModules} from 'react-native'

class Insig8Native extends NativeEventEmitter {
  openFile: (path: string) => void
  openWithFinder: (path: string) => void
  hideWindow: typeof global.__Insig8Proxy.hideWindow
  getEvents: typeof global.__Insig8Proxy.getEvents
  getApps: () => Promise<Array<{name: string; url: string; isRunning: boolean}>>
  toggleDarkMode: () => void
  executeAppleScript: (source: string) => void
  getMediaInfo: () => Promise<
    | {
        title: string
        artist: string
        artwork: string
        bundleIdentifier: string
        url: string
      }
    | null
    | undefined
  >
  setGlobalShortcut: (key: 'command' | 'option' | 'control') => void
  getCalendarAuthorizationStatus: typeof global.__Insig8Proxy.getCalendarAuthorizationStatus
  requestCalendarAccess: () => Promise<void>
  requestAccessibilityAccess: () => Promise<void>
  setLaunchAtLogin: (v: boolean) => void
  getAccessibilityStatus: () => Promise<boolean>
  resizeFrontmostRightHalf: () => void
  resizeFrontmostLeftHalf: () => void
  resizeFrontmostTopHalf: () => void
  resizeFrontmostBottomHalf: () => void
  resizeFrontmostFullscreen: () => void
  moveFrontmostNextScreen: () => void
  moveFrontmostPrevScreen: () => void
  moveFrontmostCenter: () => void
  moveFrontmostToNextSpace: () => void
  moveFrontmostToPreviousSpace: () => void
  pasteToFrontmostApp: (content: string) => void
  insertToFrontmostApp: (content: string) => void

  turnOnHorizontalArrowsListeners: () => void
  turnOffHorizontalArrowsListeners: () => void
  turnOnVerticalArrowsListeners: () => void
  turnOffVerticalArrowsListeners: () => void
  turnOnEnterListener: () => void
  turnOffEnterListener: () => void
  checkForUpdates: () => void
  setWindowRelativeSize: (relativeSize: number) => void
  resetWindowSize: typeof global.__Insig8Proxy.resetWindowSize
  setWindowHeight: typeof global.__Insig8Proxy.setHeight
  openFinderAt: (path: string) => void
  resizeTopLeft: () => void
  resizeTopRight: () => void
  resizeBottomLeft: () => void
  resizeBottomRight: () => void
  searchFiles: typeof global.__Insig8Proxy.searchFiles
  setShowWindowOn: (on: 'screenWithFrontmost' | 'screenWithCursor') => void
  useBackgroundOverlay: (v: boolean) => void
  toggleDND: () => void
  securelyStore: (key: string, value: string) => Promise<void>
  securelyRetrieve: (key: string) => Promise<string | null>
  executeBashScript: (script: string) => Promise<void>
  showToast: (
    text: string,
    variant: 'success' | 'error',
    timeout?: number,
  ) => Promise<void>
  ls: typeof global.__Insig8Proxy.ls
  exists: typeof global.__Insig8Proxy.exists
  readFile: typeof global.__Insig8Proxy.readFile
  userName: typeof global.__Insig8Proxy.userName
  ps: typeof global.__Insig8Proxy.ps
  killProcess: typeof global.__Insig8Proxy.killProcess
  hideNotch: () => void
  hasFullDiskAccess: () => Promise<boolean>
  getSafariBookmarks: () => Promise<any>
  quit: () => void
  setStatusBarItemTitle: (title: string) => void
  setMediaKeyForwardingEnabled: (enabled: boolean) => Promise<void>
  getWifiPassword: typeof global.__Insig8Proxy.getWifiPassword
  getWifiInfo: typeof global.__Insig8Proxy.getWifiInfo
  restart: () => void
  openFilePicker: () => Promise<string | null>
  showWindow: typeof global.__Insig8Proxy.showWindow
  showWifiQR: (ssid: string, password: string) => void
  updateHotkeys: (v: Record<string, string>) => void

  log: (message: string) => void

  getApplications: typeof global.__Insig8Proxy.getApplications

  // Constants
  accentColor: string
  OSVersion: number

  constructor(module: any) {
    super(module)

    if (global.__Insig8Proxy == null) {
      const installed = module.install()

      if (!installed || global.__Insig8Proxy == null) {
        throw new Error('Error installing JSI bindings!')
      }
    }

    this.getEvents = global.__Insig8Proxy.getEvents
    this.getApps = module.getApps
    this.openFile = module.openFile
    this.toggleDarkMode = module.toggleDarkMode
    this.executeBashScript = module.executeBashScript
    this.executeAppleScript = module.executeAppleScript
    this.openWithFinder = module.openWithFinder
    this.getMediaInfo = module.getMediaInfo
    this.setGlobalShortcut = module.setGlobalShortcut
    this.getCalendarAuthorizationStatus =
      global.__Insig8Proxy.getCalendarAuthorizationStatus
    this.requestAccessibilityAccess = module.requestAccessibilityAccess
    this.requestCalendarAccess = global.__Insig8Proxy.requestCalendarAccess
    this.setLaunchAtLogin = module.setLaunchAtLogin
    this.getAccessibilityStatus = module.getAccessibilityStatus
    this.resizeFrontmostRightHalf = module.resizeFrontmostRightHalf
    this.resizeFrontmostLeftHalf = module.resizeFrontmostLeftHalf
    this.resizeFrontmostTopHalf = module.resizeFrontmostTopHalf
    this.resizeFrontmostBottomHalf = module.resizeFrontmostBottomHalf
    this.resizeFrontmostFullscreen = module.resizeFrontmostFullscreen
    this.moveFrontmostNextScreen = module.moveFrontmostNextScreen
    this.moveFrontmostNextScreen = module.moveFrontmostNextScreen
    this.moveFrontmostPrevScreen = module.moveFrontmostPrevScreen
    this.moveFrontmostCenter = module.moveFrontmostCenter
    this.pasteToFrontmostApp = module.pasteToFrontmostApp
    this.insertToFrontmostApp = module.insertToFrontmostApp
    this.turnOnHorizontalArrowsListeners =
      module.turnOnHorizontalArrowsListeners
    this.turnOffHorizontalArrowsListeners =
      module.turnOffHorizontalArrowsListeners
    this.turnOnVerticalArrowsListeners = module.turnOnVerticalArrowsListeners
    this.turnOffVerticalArrowsListeners = module.turnOffVerticalArrowsListeners
    this.checkForUpdates = module.checkForUpdates
    this.turnOnEnterListener = module.turnOnEnterListener
    this.turnOffEnterListener = module.turnOffEnterListener
    this.setWindowRelativeSize = module.setWindowRelativeSize
    this.setWindowHeight = module.setWindowHeight
    this.openFinderAt = module.openFinderAt
    this.resizeTopLeft = module.resizeTopLeft
    this.resizeTopRight = module.resizeTopRight
    this.resizeBottomLeft = module.resizeBottomLeft
    this.resizeBottomRight = module.resizeBottomRight
    this.toggleDND = module.toggleDND
    this.searchFiles = global.__Insig8Proxy.searchFiles

    this.setWindowHeight = global.__Insig8Proxy.setHeight
    this.resetWindowSize = global.__Insig8Proxy.resetWindowSize
    this.hideWindow = global.__Insig8Proxy.hideWindow
    this.setShowWindowOn = module.setShowWindowOn
    this.useBackgroundOverlay = module.useBackgroundOverlay

    this.securelyRetrieve = module.securelyRetrieve
    this.securelyStore = module.securelyStore

    this.showToast = (text: string, variant = 'success', timeout = 4) =>
      module.showToast(text, variant, timeout)

    this.ls = global.__Insig8Proxy.ls
    this.exists = global.__Insig8Proxy.exists
    this.readFile = global.__Insig8Proxy.readFile
    this.userName = global.__Insig8Proxy.userName
    this.ps = global.__Insig8Proxy.ps
    this.killProcess = global.__Insig8Proxy.killProcess

    const constants = module.getConstants()

    this.accentColor = constants.accentColor
    this.OSVersion = constants.OSVersion

    this.hideNotch = module.hideNotch
    this.hasFullDiskAccess = module.hasFullDiskAccess
    this.getSafariBookmarks = module.getSafariBookmarks

    this.quit = module.quit

    this.setStatusBarItemTitle = module.setStatusBarItemTitle
    this.setMediaKeyForwardingEnabled = module.setMediaKeyForwardingEnabled
    this.getWifiPassword = global.__Insig8Proxy.getWifiPassword
    this.getWifiInfo = global.__Insig8Proxy.getWifiInfo

    this.restart = module.restart

    this.openFilePicker = module.openFilePicker
    this.showWindow = global.__Insig8Proxy.showWindow

    this.showWifiQR = module.showWifiQR
    this.updateHotkeys = module.updateHotkeys

    this.moveFrontmostToNextSpace = module.moveFrontmostToNextSpace
    this.moveFrontmostToPreviousSpace = module.moveFrontmostToPreviousSpace
    this.log = global.__Insig8Proxy.log
    this.getApplications = global.__Insig8Proxy.getApplications
  }
}

export const insig8Native = new Insig8Native(NativeModules.Insig8Native)
