import {Assets} from 'assets'
import {observer} from 'mobx-react-lite'
import {Image, Linking, Text, TouchableOpacity, View} from 'react-native'
import {useStore} from 'store'
import packageInfo from '../../../package.json'

export const About = observer(() => {
  const store = useStore()

  return (
    <View className="flex-1 justify-center items-center gap-2">
      <Image
        source={Assets.logoMinimal}
        style={{
          height: 200,
          width: 200,
        }}
      />
      <View className="gap-2 items-center">
        <Text className="text-3xl">Insig8</Text>
        <Text className="darker-text text-xxs">{packageInfo.version}</Text>
        <View className="flex-row items-center gap-2">
          <Text className="">by</Text>
          <Text className="">Insig8 Team</Text>
        </View>
        <View className="flex-row gap-2 mt-8">
          <TouchableOpacity
            className="bg-accent-strong p-2 rounded justify-center items-center w-48"
            onPress={() => {
              Linking.openURL('https://github.com/njthakker/insig8')
            }}>
            <Text className="text-white">GitHub</Text>
          </TouchableOpacity>
          <TouchableOpacity
            className="bg-accent-strong p-2 rounded justify-center items-center w-48"
            onPress={() => {
              Linking.openURL('https://www.insig8.com/')
            }}>
            <Text className="text-white">Website</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  )
})
