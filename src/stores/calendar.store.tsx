import {captureException} from '@sentry/react-native'
import {extractMeetingLink} from 'lib/calendar'
import {insig8Native} from 'lib/Insig8Native'
import {DateTime} from 'luxon'
import {makeAutoObservable, runInAction} from 'mobx'
import {EmitterSubscription, Linking} from 'react-native'
import {IRootStore} from 'store'

const DAYS_TO_PARSE = 14

let onShowListener: EmitterSubscription | undefined
let onStatusBarItemClickListener: EmitterSubscription | undefined
let pollingTimeout: NodeJS.Timeout | undefined

export type CalendarStore = ReturnType<typeof createCalendarStore>

export const createCalendarStore = (root: IRootStore) => {
  let store = makeAutoObservable({
    //    ____  _                              _     _
    //   / __ \| |                            | |   | |
    //  | |  | | |__  ___  ___ _ ____   ____ _| |__ | | ___  ___
    //  | |  | | '_ \/ __|/ _ \ '__\ \ / / _` | '_ \| |/ _ \/ __|
    //  | |__| | |_) \__ \  __/ |   \ V / (_| | |_) | |  __/\__ \
    //   \____/|_.__/|___/\___|_|    \_/ \__,_|_.__/|_|\___||___/

    calendarAuthorizationStatus: 'notDetermined' as CalendarAuthorizationStatus,
    events: [] as INativeEvent[],

    //    _____                            _           _
    //   / ____|                          | |         | |
    //  | |     ___  _ __ ___  _ __  _   _| |_ ___  __| |
    //  | |    / _ \| '_ ` _ \| '_ \| | | | __/ _ \/ _` |
    //  | |___| (_) | | | | | | |_) | |_| | ||  __/ (_| |
    //   \_____\___/|_| |_| |_| .__/ \__,_|\__\___|\__,_|
    //                        | |
    //                        |_|

    get upcomingEvent(): INativeEvent | null {
      const lNow = DateTime.now()
      let found = store.events.find(e => {
        const lStart = DateTime.fromISO(e.date)
        const lEnd = DateTime.fromISO(e.endDate || e.date)

        let isCurrentlyOngoing = +lNow >= +lStart && +lNow <= +lEnd

        if (isCurrentlyOngoing) {
          return true
        }

        let isUpcoming = +lStart >= +lNow && +lStart <= +lNow.endOf('day')

        if (isUpcoming) {
          return true
        }

        return false
      })

      if (found) {
        let eventLink: string | null | undefined = found.url

        if (!eventLink) {
          eventLink = extractMeetingLink(found.notes, found.location)
        }

        return {...found, eventLink}
      }

      return null
    },
    get groupedEvents(): Array<{
      date: DateTime
      data: Array<INativeEvent>
    }> {
      const events = store.events
      let acc: Record<string, {date: DateTime; data: Array<INativeEvent>}> = {}
      for (let i = 0; i < events.length; i++) {
        const e = events[i]
        const lEventDate = DateTime.fromISO(e.date)
        const lEventDay = lEventDate.startOf('day')
        const diffDays = lEventDay.diffNow('days').days

        if (diffDays > DAYS_TO_PARSE) {
          break
        }

        const dayISODate = lEventDay.toISODate()
        if (!acc[dayISODate]) {
          acc[dayISODate] = {
            date: lEventDay,
            data: [],
          }
        }

        acc[dayISODate].data.push(e)
      }

      return Object.values(acc)
    },
    get filteredEvents(): INativeEvent[] {
      const events = store.events
      return events.filter(e => {
        if (!!root.ui.query) {
          return e.title?.toLowerCase().includes(root.ui.query.toLowerCase())
        } else {
          let notFiltered = e.status !== 3 && !e.declined

          return notFiltered
        }
      })
    },
    //                _   _
    //      /\       | | (_)
    //     /  \   ___| |_ _  ___  _ __  ___
    //    / /\ \ / __| __| |/ _ \| '_ \/ __|
    //   / ____ \ (__| |_| | (_) | | | \__ \
    //  /_/    \_\___|\__|_|\___/|_| |_|___/
    fetchEvents: async () => {
      if (!root.ui.showUpcomingEvent) {
        insig8Native.setStatusBarItemTitle('')
        return
      }

      if (store.calendarAuthorizationStatus !== 'authorized') {
        // Cannot fetch events
        return
      }

      const events = await insig8Native.getEvents()

      runInAction(() => {
        if (root.ui.isVisible) {
          store.events = events
        }

        if (!root.ui.showUpcomingEvent) {
          return
        }

        const upcomingEvent = store.upcomingEvent

        if (!upcomingEvent) {
          insig8Native.setStatusBarItemTitle('')
          return
        }

        const lStart = DateTime.fromISO(upcomingEvent.date)
        const minutes = lStart.diffNow('minutes').minutes

        if (minutes <= 0) {
          insig8Native.setStatusBarItemTitle(upcomingEvent.title?.trim() ?? '')
          return
        }

        const relativeHours = Math.floor(minutes / 60)
        const relativeHoursStr = relativeHours > 0 ? `${relativeHours}h` : ''
        const relativeMinutesStr = `${Math.floor(
          minutes - relativeHours * 60,
        )}m`

        insig8Native.setStatusBarItemTitle(
          `${upcomingEvent.title!.trim().substring(0, 18)}${
            upcomingEvent.title!.length > 18 ? '...' : ''
          } • ${relativeHoursStr} ${relativeMinutesStr}`,
        )
      })
    },
    cleanUp: () => {
      pollingTimeout && clearTimeout(pollingTimeout)
      onShowListener?.remove()
      onStatusBarItemClickListener?.remove()
    },
    poll: () => {
      pollingTimeout = setTimeout(() => {
        if (root.ui.calendarEnabled) {
          try {
            store.fetchEvents()
          } catch (e) {
            captureException(e)
            console.error('Error fetching calendar events', e)
          } finally {
            store.poll()
          }
        }
      }, 1000 * 60)
    },
    onShow: () => {
      store.fetchEvents()
    },
    getCalendarAccess: () => {
      store.calendarAuthorizationStatus =
        insig8Native.getCalendarAuthorizationStatus()
    },
    onStatusBarItemClick: () => {
      const event = store.upcomingEvent

      if (!event) {
        Linking.openURL('ical://')
        return
      }

      let eventLink: string | null | undefined = event.url

      if (!eventLink) {
        eventLink = extractMeetingLink(event.notes, event.location)
      }

      if (eventLink) {
        try {
          Linking.openURL(eventLink)
        } catch (e) {
          insig8Native.showToast(
            `Failed to open event link: ${eventLink}`,
            'error',
          )
        }
      } else {
        Linking.openURL('ical://')
      }
    },
  })

  store.getCalendarAccess()

  store.poll()

  onShowListener = insig8Native.addListener('onShow', store.onShow)
  onStatusBarItemClickListener = insig8Native.addListener(
    'onStatusBarItemClick',
    store.onStatusBarItemClick,
  )

  return store
}
