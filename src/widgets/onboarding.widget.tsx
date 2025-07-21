import {Assets} from 'assets'
import clsx from 'clsx'
import {Fade} from 'components/Fade'
import {GradientView} from 'components/GradientView'
import {Key} from 'components/Key'
import {useFullSize} from 'hooks/useFullSize'
import {observer} from 'mobx-react-lite'
import React, {FC, useEffect, useState} from 'react'
import {Appearance, Image, Text, View, ViewStyle, useColorScheme} from 'react-native'
import {useStore} from 'store'
import {Widget} from 'stores/ui.store'
import customColors from '../colors'

interface Props {
  style?: ViewStyle
  className?: string
}

const SHORTCUTS = [
  {
    label: ({style}: {style?: any; className: string}) => (
      <Text style={style}>
        <Text className="font-bold text-base" style={style}>
          ⌥
        </Text>{' '}
        then{' '}
        <Text className="font-bold" style={style}>
          Space
        </Text>
      </Text>
    ),
  },
  {
    label: ({style}: {style?: any; className: string}) => (
      <Text style={style}>
        <Text className="font-bold text-base" style={style}>
          ⌃
        </Text>{' '}
        then{' '}
        <Text className="font-bold" style={style}>
          Space
        </Text>
      </Text>
    ),
  },
  {
    label: ({style}: {style?: any; className: string}) => (
      <Text style={style}>
        <Text className="font-bold text-base" style={style}>
          ⌘
        </Text>{' '}
        then{' '}
        <Text className="font-bold" style={style}>
          Space
        </Text>
      </Text>
    ),
    subLabel: () => {
      return (
        <View className="w-96 absolute bottom-[-90]">
          <Text className="text-xs text-neutral-500 dark:text-neutral-400 mt-8 text-center">
            Unbind the Spotlight shortcut via
          </Text>
          <Text className="text-xs text-neutral-500 dark:text-neutral-200 mt-2 text-center">
            System Settings → Keyboard Shortcuts → Spotlight
          </Text>
          <Text className="text-xs text-neutral-500 dark:text-neutral-400 mt-2 text-center">
            Open this panel again with ⌘ then Space
          </Text>
        </View>
      )
    },
  },
]

export const OnboardingWidget: FC<Props> = observer(({style}) => {
  const store = useStore()
  useFullSize()
  const colorScheme = useColorScheme()
  const [visible, setVisible] = useState(true)
  const [onboardingStep, setOnboardingStep] = useState(store.ui.onboardingStep)

  useEffect(() => {
    if (store.ui.onboardingStep === 'v1_completed') {
      setTimeout(() => {
        store.ui.focusWidget(Widget.SEARCH)
      }, 350)
    }
    if (store.ui.onboardingStep !== 'v1_start') {
      setVisible(false)
    }
    setTimeout(() => {
      setVisible(true)
      setOnboardingStep(store.ui.onboardingStep)
    }, 500)
  }, [store.ui.onboardingStep])

  return (
    <View className="flex-1" style={style}>
      {onboardingStep === 'v1_start' && (
        <Fade visible={visible} className="items-center flex-1" duration={250}>
          <View className="flex-1" />
          <View className="flex-row items-center">
            <Image
              source={Assets.logoMinimal}
              style={{
                height: 120,
                width: 120,
              }}
            />
          </View>

          <Text className="mt-6 text">Welcome to your new launcher</Text>
          <Text className="mt-2 darker-text">Press return to continue</Text>

          <View className="flex-1" />
          <View className="w-full flex-row items-center justify-end subBg px-3 py-2 gap-1">
            <Text className="text-sm">Continue</Text>
            <Key symbol="⏎" className="mx-2" />
          </View>
        </Fade>
      )}

      {onboardingStep === 'v1_shortcut' && (
        <Fade visible={visible} className="items-center flex-1" duration={250}>
          <View className="flex-1 justify-center relative">
            <Text className="text-neutral-500 dark:text-neutral-400 mb-4 self-center">
              Pick a global shortcut
            </Text>

            {SHORTCUTS.map((item, index) => {
              const Label = item.label
              const SubLabel = item.subLabel
              let isActive = store.ui.selectedIndex === index

              return (
                <View key={index} className="items-center">
                  <GradientView
                    className={'flex-row items-center px-3 py-2'}
                    startColor={
                      isActive ? `${customColors.accent}BB` : '#00000000'
                    }
                    endColor={
                      isActive ? `${customColors.accent}77` : '#00000000'
                    }
                    cornerRadius={10}
                    angle={90}>
                    <Label
                      className={clsx({
                        'text-white': store.ui.selectedIndex === index,
                      })}
                    />
                  </GradientView>
                  {!!SubLabel && store.ui.selectedIndex === index && (
                    <SubLabel />
                  )}
                </View>
              )
            })}
          </View>

          <View className="w-full flex-row items-center justify-end subBg px-3 py-2 gap-1">
            <Text className="text-sm darker-text">Open System Settings</Text>
            <Key symbol="⇧" className="mx-2" />
            <Key symbol="⏎" className="mx-2" />
            <View className="mx-2" />
            <Text className="text-sm darker-text">Select</Text>
            <Key symbol="⏎" className="mx-2" />
          </View>
        </Fade>
      )}

      {onboardingStep === 'v1_quick_actions' && (
        <Fade visible={visible} className="items-center flex-1" duration={250}>
          <View className="flex-1" />
          <View className="flex-1 justify-center items-center">
            <Text className="darker-text">
              Here are some shortcuts to get you started
            </Text>

            <View className="flex-row gap-2 mt-10 items-center">
              <Text className="flex-1 text-right text">Clipboard Manager</Text>
              <View className="flex-1 flex-row items-center gap-1">
                <Key symbol="⌘" className="ml-2" />
                <Key symbol="⇧" className="ml-1" />
                <Key symbol="V" className="ml-1" />
              </View>
            </View>

            <View className="flex-row gap-2 mt-4 items-center">
              <Text className="flex-1 text-right text">Emoji Picker</Text>
              <View className="flex-1 flex-row items-center gap-1">
                <Key symbol="⌘" className="ml-2" />
                <Key symbol="⌃" className="ml-1" />
                <Key symbol="␣" className="ml-1" />
              </View>
            </View>

            <View className="flex-row gap-2 mt-4 items-center">
              <Text className="flex-1 text-right text">Note Scratchpad</Text>
              <View className="flex-1 flex-row items-center gap-1">
                <Key symbol="⌘" className="ml-2" />
                <Key symbol="⇧" className="ml-1" />
                <Key symbol="␣" className="ml-1" />
              </View>
            </View>

            <View className="flex-row gap-2 mt-4 items-center">
              <Text className="flex-1 text-right text">
                Fullscreen front-most window
              </Text>
              <View className="flex-1 flex-row items-center gap-1">
                <Key symbol="^" className="ml-2" />
                <Key symbol="⌥" className="ml-1" />
                <Key symbol="⏎" className="ml-1" />
              </View>
            </View>

            <View className="flex-row gap-2 mt-4 items-center">
              <Text className="flex-1 text-right text">
                Resize front-most window to the right
              </Text>
              <View className="flex-1 flex-row items-center gap-1">
                <Key symbol="^" className="ml-2" />
                <Key symbol="⌥" className="ml-1" />
                <Key symbol="→" className="ml-1" />
              </View>
            </View>

            <View className="flex-row gap-2 mt-4 items-center">
              <Text className="flex-1 text-right text">
                Resize front-most window to the left
              </Text>
              <View className="flex-1 flex-row items-center gap-1">
                <Key symbol="^" className="ml-2" />
                <Key symbol="⌥" className="ml-1" />
                <Key symbol="←" className="ml-1" />
              </View>
            </View>
          </View>
          <View className="flex-1" />

          <View className="w-full flex-row items-center justify-end subBg px-3 py-2 gap-1">
            <Text className="text-sm">Continue</Text>
            <Key symbol="⏎" className="mx-2" />
          </View>
        </Fade>
      )}
    </View>
  )
})
