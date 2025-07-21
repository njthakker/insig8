import {Assets} from 'assets'
import {IRootStore} from 'store'
import {ItemType, Widget} from './ui.store'
import {insig8Native} from 'lib/Insig8Native'
import {Clipboard, Linking, Text, View} from 'react-native'
import {FileIcon} from 'components/FileIcon'
import {nanoid} from 'nanoid'
import {v4 as uuidv4} from 'uuid'
import {systemPreferenceItems} from './systemPreferences'
import Chance from 'chance'

const chance = new Chance()

export function createBaseItems(store: IRootStore) {
  let items: Item[] = [
    {
      id: 'toggle_appearance',
      iconImage: Assets.toggle,
      name: 'Toggle system appearance',
      alias: 'dark',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.toggleDarkMode()
        insig8Native.restart()
      },
    },
    {
      id: 'sleep',
      iconImage: Assets.SleepIcon,
      name: 'Sleep',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        try {
          await insig8Native.executeAppleScript(
            'tell application "Finder" to sleep',
          )
        } catch (e) {
          insig8Native.showToast(`Could not sleep: ${e}`, 'error')
        }
      },
    },
    {
      id: 'restart',
      iconImage: Assets.restart,
      name: 'Restart',
      preventClose: true,
      type: ItemType.CONFIGURATION,
      callback: async () => {
        store.ui.confirm('Restart Computer', async () => {
          try {
            await insig8Native.executeAppleScript(
              'tell application "Finder" to restart',
            )
            insig8Native.showToast('Restarting', 'success')
          } catch (e) {
            insig8Native.showToast(`Could not restart: ${e}`, 'error')
          }
        })
      },
    },
    {
      id: 'shut_down',
      iconImage: Assets.power,
      name: 'Shut Down',
      type: ItemType.CONFIGURATION,
      preventClose: true,
      callback: async () => {
        try {
          store.ui.confirm('Shut Down', async () => {
            await insig8Native.executeAppleScript(
              'tell application "Finder" to shut down',
            )
            insig8Native.showToast('Shutting down', 'success')
          })
        } catch (e) {
          insig8Native.showToast(`Could not power off: ${e}`, 'error')
        }
      },
    },
    {
      id: 'airdrop',
      iconImage: Assets.Airdrop,
      name: 'AirDrop',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.executeAppleScript(`tell application "Finder"
          if exists window "AirDrop" then
                  tell application "System Events" to ¬
                          tell application process "Finder" to ¬
                                  perform action "AXRaise" of ¬
                                          (windows whose title is "AirDrop")
          else if (count Finder windows) > 0 then
                  make new Finder window
                  tell application "System Events" to ¬
                          click menu item "AirDrop" of menu 1 of menu bar item ¬
                                  "Go" of menu bar 1 of application process "Finder"
          else
                  tell application "System Events" to ¬
                          click menu item "AirDrop" of menu 1 of menu bar item ¬
                                  "Go" of menu bar 1 of application process "Finder"
          end if
          activate
        end tell`)
      },
    },
    {
      id: 'lock',
      iconImage: Assets.LockIcon,
      name: 'Lock',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        try {
          await insig8Native.executeAppleScript(
            `tell application "System Events" to keystroke "q" using {control down, command down}`,
          )
        } catch (e) {
          insig8Native.showToast(`Could not lock: ${e}`, 'error')
        }
      },
    },
    {
      id: 'settings',
      iconImage: Assets.SettingsIcon,
      name: 'Insig8 Settings',
      alias: 'preferences',
      type: ItemType.CONFIGURATION,
      callback: () => {
        store.ui.focusWidget(Widget.SETTINGS)
        store.ui.setQuery('')
      },
      preventClose: true,
    },
    {
      id: 'create_shorcut',
      icon: '✳️',
      name: 'Create shortcut or script',
      type: ItemType.CONFIGURATION,
      callback: () => {
        store.ui.focusWidget(Widget.CREATE_ITEM)
      },
      preventClose: true,
    },
    {
      id: 'resize_fullscreen',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded items-center bg-black">
            <View className="w-5 h-5 rounded bg-white" />
          </View>
        )
      },
      name: 'Resize window to full-screen',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.resizeFrontmostFullscreen()
      },
    },
    {
      id: 'resize_right_half',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded items-end bg-black">
            <View className="w-3 h-5 rounded-sm bg-white" />
          </View>
        )
      },
      name: 'Resize window to right-half',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.resizeFrontmostRightHalf()
      },
    },
    {
      id: 'resize_left_half',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded items-start bg-black">
            <View className="w-[50%] h-5 rounded-sm bg-white" />
          </View>
        )
      },
      name: 'Resize window to left-half',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.resizeFrontmostLeftHalf()
      },
    },
    {
      id: 'resize_top_half',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded items-start bg-black">
            <View className="w-5 h-[50%] rounded-sm bg-white" />
          </View>
        )
      },
      name: 'Resize window to top-half',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.resizeFrontmostTopHalf()
      },
    },
    {
      id: 'resize_bottom_half',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded justify-end bg-black">
            <View className="w-5 h-[50%] rounded-sm bg-white" />
          </View>
        )
      },
      name: 'Resize window to bottom-half',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.resizeFrontmostBottomHalf()
      },
    },
    {
      id: 'resize_top_left',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded items-start bg-black">
            <View className="w-1 h-1 p-1 rounded-sm bg-white" />
          </View>
        )
      },
      name: 'Resize window to top-left',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.resizeTopLeft()
      },
    },
    {
      id: 'resize_top_right',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded items-end bg-black">
            <View className="w-1 h-1 p-1 rounded-sm bg-white" />
          </View>
        )
      },
      name: 'Resize window to top-right',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.resizeTopRight()
      },
    },
    {
      id: 'resize_bottom_left',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded items-start justify-end bg-black">
            <View className="w-1 h-1 p-1 rounded-sm bg-white" />
          </View>
        )
      },
      name: 'Resize window to bottom-left',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.resizeBottomLeft()
      },
    },
    {
      id: 'resize_bottom_right',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded items-end justify-end bg-black">
            <View className="w-1 h-1 p-1 rounded-sm bg-white" />
          </View>
        )
      },
      name: 'Resize window to bottom-right',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.resizeBottomRight()
      },
    },
    {
      id: 'move_next_screen',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 rounded items-center justify-center bg-black">
            <Text className="text-white">→</Text>
          </View>
        )
      },
      name: 'Move window to next screen',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.moveFrontmostNextScreen()
      },
    },
    {
      id: 'move_prev_screen',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 rounded items-center justify-center bg-black">
            <Text className="text-white">←</Text>
          </View>
        )
      },
      name: 'Move window to previous screen',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.moveFrontmostPrevScreen()
      },
    },
    {
      id: 'move_to_previous_space',
      icon: '⬅️',
      name: 'Move window to previous space',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.moveFrontmostToPreviousSpace()
      },
    },
    {
      id: 'move_to_next_space',
      icon: '➡️',
      name: 'Move window to next space',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.moveFrontmostToNextSpace()
      },
    },
    {
      id: 'move_center',
      IconComponent: () => {
        return (
          <View className="w-6 h-6 p-0.5 rounded items-center justify-center bg-black">
            <View className="w-1 h-1 p-1 rounded-sm bg-white" />
          </View>
        )
      },
      name: 'Move window to center',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.moveFrontmostCenter()
      },
    },
    {
      id: 'scratchpad',
      icon: '🗒️',
      name: 'Scratchpad',
      preventClose: true,
      type: ItemType.CONFIGURATION,
      callback: () => {
        store.ui.showScratchpad()
      },
    },
    {
      id: 'emoji_picker',
      icon: '😎',
      name: 'Emoji Picker',
      preventClose: true,
      type: ItemType.CONFIGURATION,
      callback: () => {
        store.ui.showEmojiPicker()
      },
    },
    {
      id: 'check_for_updates',
      icon: '🆙',
      name: 'Check for Insig8 updates',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.checkForUpdates()
      },
    },
    {
      id: 'clipboard_manager',
      icon: '📋',
      name: 'Clipboard Manager',
      type: ItemType.CONFIGURATION,
      callback: () => {
        store.ui.showClipboardManager()
      },
      preventClose: true,
    },
    {
      id: 'process_manager',
      icon: '🔫',
      name: 'Kill process',
      type: ItemType.CONFIGURATION,
      callback: () => {
        store.ui.showProcessManager()
      },
      preventClose: true,
    },
    {
      id: 'file_search',
      icon: '📁',
      name: 'File Search',
      type: ItemType.CONFIGURATION,
      callback: () => {
        store.ui.showFileSearch()
      },
      preventClose: true,
    },
    {
      id: 'downloads_folder',
      IconComponent: (...props: any[]) => (
        <FileIcon {...props} url="~/Downloads" className="w-6 h-6" />
      ),
      name: 'Downloads',
      type: ItemType.CONFIGURATION,
      callback: () => {
        Linking.openURL('~/Downloads')
      },
    },
    {
      id: 'desktop_folder',
      IconComponent: (...props: any[]) => {
        return <FileIcon {...props} url="~/Desktop" className="w-6 h-6" />
      },
      type: ItemType.CONFIGURATION,
      name: 'Desktop',
      callback: () => {
        Linking.openURL('~/Desktop')
      },
    },
    {
      id: 'applications_folder',
      IconComponent: (...props: any[]) => (
        <FileIcon {...props} url="/Applications" className="w-6 h-6" />
      ),
      name: 'Applications',
      alias: 'application',
      type: ItemType.CONFIGURATION,
      callback: () => {
        Linking.openURL('/Applications')
      },
    },
    {
      id: 'pictures_folder',
      IconComponent: (...props: any[]) => (
        <FileIcon {...props} url="~/Pictures" className="w-6 h-6" />
      ),
      name: 'Pictures',
      type: ItemType.CONFIGURATION,
      callback: () => {
        Linking.openURL('~/Pictures')
      },
    },
    {
      id: 'developer_folder',
      IconComponent: (...props: any[]) => (
        <FileIcon {...props} url="~/Developer" className="w-6 h-6" />
      ),
      name: 'Developer',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        try {
          await Linking.openURL('~/Developer')
        } catch (e) {
          insig8Native.showToast(
            'Developer folder not found, try creating ~/Developer 😉',
            'error',
          )
        }
      },
    },
    {
      id: 'documents_folder',
      IconComponent: (...props: any[]) => (
        <FileIcon {...props} url="~/Documents" className="w-6 h-6" />
      ),
      name: 'Documents',
      type: ItemType.CONFIGURATION,
      callback: () => {
        Linking.openURL('~/Documents')
      },
    },
    {
      id: 'start_google_meet',
      iconImage: Assets.googleLogo,
      name: 'Start Google Meet',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        await Linking.openURL(`https://meet.google.com/new`)

        insig8Native.executeAppleScript(`if application "Safari" is running then
          delay 3
          tell application "Safari"
            set myurl to URL of front document as string
          end tell

          set baseUrl to "https://meet.google.com/new"

          if (myurl contains baseUrl) then
            delay 3
            tell application "Safari"
              set myurl to URL of front document as string
            end tell
          else
            set the clipboard to myurl as string
            display notification "Google Meet link copied to clipboard" with title "Link Copied" sound name "Frog"
            return
          end if

          if (myurl contains baseUrl) then
            delay 3
            tell application "Safari"
              set myurl to URL of front document as string
            end tell
          else
            set the clipboard to myurl as string
            display notification "Google Meet link copied to clipboard" with title "Link Copied" sound name "Frog"
            return
          end if

          if (myurl contains baseUrl) then
            delay 3
            tell application "Safari"
              set myurl to URL of front document as string
            end tell
          else
            set the clipboard to myurl as string
            display notification "Google Meet link copied to clipboard" with title "Link Copied" sound name "Frog"
            return
          end if

          if (myurl contains baseUrl) then
            display notification "Google Meet could not be copied" with title "Couldn't copy Google Meet link" sound name "Frog"
          else
            set the clipboard to myurl as string
            display notification "Google Meet link copied to clipboard" with title "Link Copied" sound name "Frog"
          end if
        end if
        `)
      },
    },
    {
      id: 'clear_derived_data',
      IconComponent: () => (
        <FileIcon url="/Applications/Xcode.app" className="w-6 h-6" />
      ),
      name: 'Remove derived data folder',
      alias: 'Clear xcode',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        await insig8Native.executeBashScript(
          'rm -rf ~/Library/Developer/Xcode/DerivedData',
        )

        insig8Native.showToast('Cleared', 'success')
      },
    },
    {
      id: 'generate_nano_id',
      icon: '🍔',
      name: 'Generate Nano ID',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        const id = nanoid()
        insig8Native.pasteToFrontmostApp(id)
        insig8Native.showToast('Generated and pasted', 'success')
      },
    },
    {
      id: 'generate_uuid',
      icon: '🍔',
      name: 'Generate UUID',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        const id = uuidv4()
        insig8Native.pasteToFrontmostApp(id)
        insig8Native.showToast('Generated and pasted', 'success')
      },
    },
    {
      id: 'generate_lorem_ipsum',
      icon: '👴',
      name: 'Generate Lorem Ipsum',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        const paragraph = chance.paragraph()
        insig8Native.pasteToFrontmostApp(paragraph)
        insig8Native.showToast('Generated', 'success')
      },
    },
    {
      id: 'quit_insig8',
      icon: '💀',
      name: 'Quit/Exit Insig8',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        insig8Native.quit()
      },
    },
    {
      id: 'paste_as_json',
      icon: '📟',
      name: 'Paste as JSON',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        let latestString = await Clipboard.getString()
        if (latestString)
          try {
            latestString = JSON.parse(latestString)
            insig8Native.pasteToFrontmostApp(JSON.stringify(latestString, null, 2))
            insig8Native.showToast('Pasted!', 'success')
          } catch (e) {
            insig8Native.pasteToFrontmostApp(latestString)
            insig8Native.showToast('Not a valid JSON', 'error')
          }
      },
    },
    {
      id: 'kill_all_apps',
      icon: '☠️',
      name: 'Kill all apps',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        try {
          insig8Native.executeAppleScript(`-- get list of open apps
          tell application "System Events"
            set allApps to displayed name of (every process whose background only is false) as list
          end tell

          -- leave some apps open
          set exclusions to {"AppleScript Editor", "Automator", "Finder", "LaunchBar"}

          -- quit each app
          repeat with thisApp in allApps
            set thisApp to thisApp as text
            if thisApp is not in exclusions then
              tell application thisApp to quit
            end if
          end repeat
          `)
        } catch (e) {
          insig8Native.showToast(
            `Could not kill all apps: ${e}. Be sure to give accessibility access`,
            'error',
          )
        }
      },
    },
    ...systemPreferenceItems,
    {
      id: 'copy_wifi_password',
      icon: '🔑',
      name: 'Copy Wi-Fi Password to Clipboard',
      type: ItemType.CONFIGURATION,
      alias: 'wifi',
      callback: () => {
        try {
          const res = insig8Native.getWifiPassword()
          if (!res) {
            insig8Native.showToast(`No password found`, 'error')
            return
          }
          Clipboard.setString(res.password)
          insig8Native.showToast('Password copied to clipboard', 'success')
        } catch (e) {
          insig8Native.showToast(`Could not retrieve password: ${e}`, 'error')
        }
      },
    },
    {
      id: 'reveal_wifi_password',
      icon: '📶',
      name: 'Reveal Wi-Fi Password',
      type: ItemType.CONFIGURATION,
      alias: 'wifi',
      callback: () => {
        try {
          const res = insig8Native.getWifiPassword()
          if (!res) {
            insig8Native.showToast(`Could not retrieve password`, 'success')
            return
          }

          Clipboard.setString(res.password)
          insig8Native.showWifiQR(res.ssid, res.password)
        } catch (e) {
          insig8Native.showToast(`Could not retrieve password: ${e}`, 'error')
        }
      },
    },
    {
      id: 'empty_trash',
      icon: '🗑️',
      name: 'Empty Trash',
      type: ItemType.CONFIGURATION,
      preventClose: true,
      alias: 'trash',
      callback: async () => {
        store.ui.confirm('Clear Trash', async () => {
          try {
            await insig8Native.executeAppleScript(
              `tell application "Finder" to empty trash`,
            )
            insig8Native.showToast('Trash emptied', 'success')
          } catch (e) {
            insig8Native.showToast(`Could not empty trash: ${e}`, 'error')
          }
        })
      },
    },
    {
      id: 'hide_notch',
      icon: '🕶️',
      name: 'Hide Notch',
      type: ItemType.CONFIGURATION,
      callback: async () => {
        try {
          await insig8Native.hideNotch()
          insig8Native.showToast('Notch hidden', 'success')
        } catch (e) {
          insig8Native.showToast(`Could not hide notch: ${e}`, 'error')
        }
      },
    },
    // {
    //   icon: '⌨️',
    //   name: 'Add VSCode bindings to Xcode',
    //   type: ItemType.CONFIGURATION,
    //   callback: async () => {
    //     await insig8Native.executeBashScript(
    //       `touch ~/Library/Developer/Xcode/UserData/KeyBindings/VSCodeKeyBindings.idekeybindings`,
    //     )

    //     insig8Native.showToast('✅ Added bindings. Select them from the Xcode preferences')
    //   },
    // }
  ]

  if (__DEV__) {
    items.push({
      id: 'restart_onboarding',
      icon: '🐣',
      name: '[DEV] Restart onboarding',
      type: ItemType.CONFIGURATION,
      callback: () => {
        store.ui.onboardingStep = 'v1_start'
        store.ui.focusWidget(Widget.ONBOARDING)
        store.ui.setHasDismissedGettingStarted(false)
      },
      preventClose: true,
    })

    items.push({
      id: 'sucess_toast',
      icon: '🍞',
      name: 'Success toast',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.showToast(
          'This is a Toast test with a long test to make sure everything fits! 🍞',
          'success',
        )
      },
    })
    items.push({
      id: 'error_toast',
      icon: '🍞',
      name: 'error toast',
      type: ItemType.CONFIGURATION,
      callback: () => {
        insig8Native.showToast(
          'This is a Toast test with a long test to make sure everything fits! 🍞',
          'error',
        )
      },
    })
  }

  return items
}
