import {insig8Native} from 'lib/Insig8Native'
import React from 'react'
import {ViewStyle} from 'react-native'
import {FileIcon} from './FileIcon'

export const SystemPreferencesIcon = ({style}: {style?: ViewStyle} = {}) => {
  return (
    <FileIcon
      style={style}
      className="w-6 h-6"
      url={
        insig8Native.OSVersion >= 13
          ? '/System/Applications/System Settings.app'
          : '/System/Applications/System Preferences.app'
      }
    />
  )
}
