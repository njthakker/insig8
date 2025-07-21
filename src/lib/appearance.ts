import { Appearance } from 'react-native'
import { runInAction } from 'mobx'

/**
 * Safely get color scheme, ensuring it runs on the main thread
 * Returns 'light' as default if unable to determine
 */
export const getColorSchemeSafe = (): 'light' | 'dark' => {
  try {
    // In React Native macOS, this should already be handled properly
    // but we'll add a fallback just in case
    const scheme = Appearance.getColorScheme()
    return scheme || 'light'
  } catch (error) {
    console.warn('Failed to get color scheme:', error)
    return 'light'
  }
}

/**
 * Get color scheme async - useful for background operations
 */
export const getColorSchemeAsync = async (): Promise<'light' | 'dark'> => {
  return new Promise((resolve) => {
    // Ensure we're on the main thread by using setTimeout with 0 delay
    setTimeout(() => {
      resolve(getColorSchemeSafe())
    }, 0)
  })
}