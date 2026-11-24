# Compasslet

See your direction on iPhone and while driving with CarPlay.

- A phone compass that works while stationary, with dial and text displays.
- A CarPlay app showing sampled travel direction.
- A compact Live Activity that shows your travel direction, and when it was recorded,
  during a drive, keeping it visible through stops.
- Support for VoiceOver, larger text and Reduce Motion.

Requires iOS 27 or later. The phone compass points relative to magnetic north;
nearby magnets and metal can affect accuracy. CarPlay shows travel relative to
true north, including reverse movement, rather than where a stationary car points.
CarPlay readings are sampled; iOS controls when the Live Activity is displayed.
Ordinary Home Screen and Lock Screen widgets are not included.

## Using CarPlay

While parked, open Compasslet on iPhone and allow While Using location access with
Precise Location. Use Settings to repair permissions if needed; Always access is
not required. Open Compasslet from the CarPlay launcher to start automatically.
Connecting a cable alone may not launch the app. If the Live Activity doesn't start on your
drives, Settings › Help › Live Activity Shortcuts opens the website's page of shortcuts that
start it when CarPlay connects and end it when CarPlay disconnects.

Switching to Maps keeps the drive running with the background location indicator. If
Compasslet can't keep reading location after you switch, the drive ends about 15 seconds later.
The drive ends when you end the Live Activity, when location access or Precise Location is
turned off, or after eight hours. It also ends a minute after CarPlay disconnects, and a minute
after you start the Live Activity from Shortcuts or Siri without CarPlay unless CarPlay
connects; change these in Settings › Live Activity › Auto-Stop and Wait for CarPlay (see
[Live Activity Settings](#live-activity-settings)). While the Live Activity runs without
CarPlay, the compass screen's stop button ends it.
Dismissing the Live Activity ends the drive unless Compasslet is connected on CarPlay.
Open Compasslet on CarPlay again to start a new drive.

### Live Activity Settings

In Compasslet's Settings › Live Activity:

- **Update Frequency** sets how often the Live Activity gets a new direction during a drive:
  Every Second (the default), Every 5 Seconds or Every 15 Seconds. iOS decides when the Lock
  Screen and CarPlay show each update. Compasslet's own CarPlay screen isn't affected.
- **Wait for CarPlay** sets how long a Live Activity started without CarPlay, from Shortcuts
  or Siri, waits for CarPlay to connect before the drive ends: 1 Minute (the default),
  5 Minutes, 15 Minutes or No Limit. The same goes for a Live Activity started again away
  from the car. Until the drive ends, Compasslet keeps using your location, which uses more
  battery. With No Limit, the drive runs until you end it, dismiss the Live Activity or eight
  hours pass, or until CarPlay connects and then disconnects, when Auto-Stop applies.
- **Auto-Stop** sets how long a drive continues after CarPlay disconnects: 1 Minute (the
  default), 5 Minutes, 15 Minutes or Never. Until the drive ends, Compasslet keeps using your
  location, which uses more battery. Drives always end after eight hours. If you
  dismissed the Live Activity, or it couldn't start, the drive ends a minute after CarPlay
  disconnects whatever Auto-Stop is set to.

