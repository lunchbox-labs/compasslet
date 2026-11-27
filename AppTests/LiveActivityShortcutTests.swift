import CompassCore
import Foundation
import Testing
@testable import Compass

@MainActor
private final class FakeDrive: ShortcutDrive {
  enum Call: Equatable { case start, end, wait(Duration), continueInForeground }

  var isDriving = false
  var compactStatus: DriveSessionController.CompactStatus = .inactive
  var setupStatus: DriveSessionController.SetupStatus = .ready
  /// Whether the drive waits for the car, as one started away from it does.
  var isAwaitingTheCar = true
  /// How long the drive waits for the car while it awaits it.
  var carWaitDelay: TimeInterval? = DriveSessionController.shortcutCarWait
  /// The Shortcut Wait Time the drive gives a start from the shortcut.
  var shortcutStartWait = DriveSessionController.shortcutCarWait
  /// The wait each start asked for.
  private(set) var startWaits: [TimeInterval] = []
  var hasLiveActivity = false
  /// What a start leaves the Live Activity as; nil leaves no drive running.
  var startResult: DriveSessionController.CompactStatus? = .active
  /// Whether a start finds the drive ended under it, as when a limit ends it meanwhile.
  var startEndsDrive = false
  var needsForeground = false
  private(set) var calls: [Call] = []

  func startLiveActivity(carWait: TimeInterval) async {
    calls.append(.start)
    startWaits.append(carWait)
    if startEndsDrive {
      isDriving = false
      compactStatus = .inactive
      return
    }
    guard let startResult else { return }
    isDriving = true
    compactStatus = startResult
    hasLiveActivity = startResult != .unavailable
  }

  func endLiveActivity() async {
    calls.append(.end)
    isDriving = false
    compactStatus = .inactive
    hasLiveActivity = false
  }

  func needsForegroundStart(waitingUpTo timeout: Duration) async -> Bool {
    calls.append(.wait(timeout))
    return needsForeground
  }

  func continueInForeground() { calls.append(.continueInForeground) }
}

private struct Declined: Error {}

@MainActor
struct LiveActivityShortcutTests {
  private let shortcutWait = DriveSessionController.shortcutCarWait
  private func start(
    _ drive: FakeDrive, canContinueInForeground: Bool = true, foregroundFails: Bool = false
  ) async -> LiveActivityShortcut.StartOutcome {
    await LiveActivityShortcut.start(
      drive, canContinueInForeground: canContinueInForeground, waitingUpTo: .seconds(5)
    ) {
      drive.continueInForeground()
      if foregroundFails { throw Declined() }
    }
  }

  @Test(arguments: [DriveSessionController.CompactStatus.active, .starting])
  func runningDriveIsLeftAsItIs(status: DriveSessionController.CompactStatus) async {
    let drive = FakeDrive()
    drive.isDriving = true
    drive.compactStatus = status
    drive.startResult = status
    #expect(await start(drive) == .alreadyRunning)
    // Asking again doesn't wait for location or end the drive.
    #expect(drive.calls == [.start])
  }

  @Test func driveThatEndsDuringTheStartIsNotReportedAsRunning() async {
    let drive = FakeDrive()
    drive.isDriving = true
    drive.compactStatus = .active
    drive.startEndsDrive = true
    #expect(await start(drive) == .couldNotStart)
    #expect(drive.calls == [.start, .wait(.seconds(5))])
  }

  @Test func driveWhoseLiveActivityWasDismissedStartsAgain() async {
    let drive = FakeDrive()
    drive.isDriving = true
    drive.compactStatus = .dismissed
    drive.isAwaitingTheCar = false
    #expect(await start(drive) == .started)
    #expect(drive.calls == [.start, .wait(.seconds(5))])
  }

  @Test func startAsksForTheShortcutWaitEachTime() async {
    let drive = FakeDrive()
    drive.needsForeground = true
    _ = await start(drive)
    #expect(drive.startWaits == [shortcutWait, shortcutWait])
  }

  @Test func startAsksForTheChosenShortcutWait() async {
    let drive = FakeDrive()
    drive.shortcutStartWait = 60
    drive.needsForeground = true
    _ = await start(drive)
    #expect(drive.startWaits == [60, 60])
  }

  @Test func startSaysTheWaitThatTheDriveHas() async {
    let minute = FakeDrive()
    minute.carWaitDelay = 60
    #expect(await start(minute) == .startedWithoutCarPlay(60))
    // No wait to state: the drive isn't awaiting the car.
    let none = FakeDrive()
    none.carWaitDelay = nil
    #expect(await start(none) == .started)
  }

  @Test func startSaysTheWaitOnlyWhileTheDriveAwaitsTheCar() async {
    let parked = FakeDrive()
    #expect(await start(parked) == .startedWithoutCarPlay(shortcutWait))
    // With the car, or after it showed and left, the drive doesn't end after the wait.
    let withTheCar = FakeDrive()
    withTheCar.isAwaitingTheCar = false
    #expect(await start(withTheCar) == .started)
  }

  @Test func startThatCantContinueInTheForegroundDoesNotWaitForLocation() async {
    let drive = FakeDrive()
    drive.needsForeground = true
    #expect(
      await start(drive, canContinueInForeground: false) == .startedWithoutCarPlay(shortcutWait))
    #expect(drive.calls == [.start])
  }

  @Test func backgroundStartWithoutLocationMovesToTheForegroundAndStartsAgain() async {
    let drive = FakeDrive()
    drive.needsForeground = true
    drive.isAwaitingTheCar = false
    #expect(await start(drive) == .started)
    #expect(drive.calls == [.start, .wait(.seconds(5)), .end, .continueInForeground, .start])
    #expect(drive.isDriving)
  }

  @Test func cancelledStartDoesNotMoveToTheForeground() async {
    let drive = FakeDrive()
    drive.needsForeground = true
    let task = Task {
      await LiveActivityShortcut.start(
        drive, canContinueInForeground: true, waitingUpTo: .seconds(5)
      ) { drive.continueInForeground() }
    }
    task.cancel()
    #expect(await task.value == .startedWithoutCarPlay(shortcutWait))
    #expect(drive.calls == [.start, .wait(.seconds(5))])
    #expect(drive.isDriving)
  }

  @Test func declinedForegroundStartLeavesTheDriveEnded() async {
    let drive = FakeDrive()
    drive.needsForeground = true
    #expect(await start(drive, foregroundFails: true) == .openWhenParked)
    #expect(drive.calls == [.start, .wait(.seconds(5)), .end, .continueInForeground])
    #expect(!drive.isDriving)
    #expect(!drive.hasLiveActivity)
  }

  @Test func startThatCantRunExplainsWhy() async {
    let unavailable = FakeDrive()
    unavailable.setupStatus = .unavailable
    unavailable.startResult = nil
    #expect(await start(unavailable) == .unavailable)

    for status: DriveSessionController.SetupStatus in [
      .permissionRequired, .denied, .restricted, .servicesDisabled, .preciseLocationRequired,
    ] {
      let drive = FakeDrive()
      drive.setupStatus = status
      drive.startResult = nil
      #expect(await start(drive) == .needsPreciseLocation)
    }

    let noDrive = FakeDrive()
    noDrive.startResult = nil
    #expect(await start(noDrive) == .couldNotStart)

    let noActivity = FakeDrive()
    noActivity.startResult = .unavailable
    noActivity.isAwaitingTheCar = false
    #expect(await start(noActivity) == .couldNotStart)
  }

  @Test func endReportsWhetherAnythingWasRunningAndAlwaysEnds() async {
    let driving = FakeDrive()
    driving.isDriving = true
    #expect(await LiveActivityShortcut.end(driving) == .ended)
    #expect(driving.calls == [.end])

    // A Live Activity left from an earlier launch has no drive, but still counts.
    let leftOver = FakeDrive()
    leftOver.hasLiveActivity = true
    #expect(await LiveActivityShortcut.end(leftOver) == .ended)
    #expect(!leftOver.hasLiveActivity)

    let idle = FakeDrive()
    #expect(await LiveActivityShortcut.end(idle) == .notRunning)
    #expect(idle.calls == [.end])
  }
}

/// The car audio route as a drive reads it, which a test changes without telling the drive, as
/// when the notification is missed while the app is suspended.
@MainActor
private final class CarAudioRoute { var connected = false }

/// The Shortcut Wait Time as a drive reads it, which a test changes between starts.
@MainActor
private final class ShortcutWaitChoice { var value = LiveActivityShortcutWait.oneMinute }

/// The Start shortcut on the real drive, away from the car or as the car comes and goes, with
/// what it says checked against when the drive ends. Where it says the drive ends in 15 minutes
/// unless CarPlay connects, that wait runs from the shortcut whatever Auto-Stop is set to, and
/// where the drive ends on Auto-Stop instead, it doesn't say so
/// ([#357](https://github.com/lunchbox-labs/compasslet/issues/357)).
@Suite(.timeLimit(.minutes(1))) @MainActor
struct StartShortcutAwayFromTheCarTests {
  private let shortcutWait = DriveSessionController.shortcutCarWait
  let clock: TestDriveClock
  let sensor: TestTravelSensor
  let activity: TestActivityPresenter
  private let carAudio: CarAudioRoute

  init() {
    clock = TestDriveClock()
    sensor = TestTravelSensor()
    activity = TestActivityPresenter()
    carAudio = CarAudioRoute()
  }

  private func makeDrive(
    autoStop: LiveActivityAutoStop, shortcutWait: LiveActivityShortcutWait = .fifteenMinutes
  ) -> DriveSessionController {
    let carAudio = carAudio
    return DriveSessionController(
      sensor: sensor, activity: activity, clock: clock, carAudioRoute: { carAudio.connected },
      autoStop: { autoStop }, shortcutWait: { shortcutWait })
  }

  private func reading() -> TravelSensorEvent {
    .reading(
      TravelReading(
        courseDegrees: 90, courseAccuracyDegrees: 2, speedMetersPerSecond: 10,
        speedAccuracyMetersPerSecond: 1, horizontalAccuracyMeters: 5, timestamp: clock.now))
  }

  /// Runs the Start shortcut as a CarPlay automation does, in the background with location
  /// running, so it never needs the foreground.
  private func runStartShortcut(
    _ drive: DriveSessionController
  ) async -> LiveActivityShortcut.StartOutcome {
    await LiveActivityShortcut.start(
      drive, canContinueInForeground: true, waitingUpTo: .seconds(5)
    ) { Issue.record("The shortcut asked to continue in the foreground") }
  }

  /// A CarPlay drive whose Live Activity was dismissed, kept 50 seconds after CarPlay disconnects.
  /// Without car audio, that is 50 seconds into the minute it then has; with car audio, the car
  /// still shows.
  private func keptDrive(
    _ drive: DriveSessionController, carAudioAtTheDisconnect: Bool = false
  ) async {
    carAudio.connected = carAudioAtTheDisconnect
    await drive.carPlayActivated()
    sensor.receive?(reading())
    activity.onDismiss?()
    drive.carPlayResignedActive()
    drive.carPlayDisconnected()
    let left = clock.now
    clock.run(until: left + 50)
    sensor.receive?(reading())
    #expect(drive.isDriving)
    #expect(drive.compactStatus == .dismissed)
  }

  /// Checks that the drive ends just after the shortcut's wait for the car from `start`, and not
  /// before: a parked start keeps running well past the minute a start from the app gets.
  private func expectEndAfterTheStartWindow(
    of drive: DriveSessionController, from start: Date
  ) async {
    clock.run(until: start + DriveSessionController.carPlayAbsenceLimit + 1)
    #expect(drive.isDriving)
    clock.run(until: start + shortcutWait)
    #expect(drive.isDriving)
    clock.run(until: start + shortcutWait + 0.1)
    #expect(!drive.isDriving)
    await drive.waitForPendingOperations()
    #expect(sensor.stops == 1)
  }

  /// Checks that the drive ends just after five minutes from `left` with Auto-Stop at 5 Minutes,
  /// and keeps running with Never.
  private func expectAutoStop(
    _ autoStop: LiveActivityAutoStop, of drive: DriveSessionController, from left: Date
  ) async {
    clock.run(until: left + 5 * 60)
    #expect(drive.isDriving)
    clock.run(until: left + 5 * 60 + 0.1)
    #expect(drive.isDriving == (autoStop == .never))
    await drive.endDrive()
  }

  @Test(arguments: [LiveActivityAutoStop.oneMinute, .never])
  func keptDriveEndsTheShortcutWaitAfterIt(autoStop: LiveActivityAutoStop) async {
    let drive = makeDrive(autoStop: autoStop)
    await keptDrive(drive)
    #expect(await runStartShortcut(drive) == .startedWithoutCarPlay(shortcutWait))
    #expect(drive.compactStatus == .active)
    #expect(sensor.starts == 1)
    // Not the Auto-Stop time from when the car left: 10 seconds from now for a minute, and
    // never for Never.
    await expectEndAfterTheStartWindow(of: drive, from: clock.now)
  }

  /// A shorter Shortcut Wait Time ends a parked start sooner, and a change applies from the next
  /// start, not to the wait in progress.
  @Test func shortcutStartEndsAfterTheChosenWait() async {
    let choice = ShortcutWaitChoice()
    let carAudio = carAudio
    let drive = DriveSessionController(
      sensor: sensor, activity: activity, clock: clock, carAudioRoute: { carAudio.connected },
      autoStop: { .oneMinute }, shortcutWait: { choice.value })
    for (wait, next) in [(60.0, LiveActivityShortcutWait.fiveMinutes), (300, .oneMinute)] {
      let shortcut = Task { await runStartShortcut(drive) }
      while !drive.isDriving { await Task.yield() }
      let started = clock.now
      sensor.receive?(reading())
      #expect(await shortcut.value == .startedWithoutCarPlay(wait))
      choice.value = next
      clock.run(until: started + wait)
      #expect(drive.isDriving)
      clock.run(until: started + wait + 0.1)
      #expect(!drive.isDriving)
      await drive.waitForPendingOperations()
    }
  }

  @Test(arguments: [LiveActivityAutoStop.fiveMinutes, .never])
  func carConnectingAfterTheShortcutKeepsTheDriveUntilAutoStop(
    autoStop: LiveActivityAutoStop
  ) async {
    let drive = makeDrive(autoStop: autoStop)
    await keptDrive(drive)
    #expect(await runStartShortcut(drive) == .startedWithoutCarPlay(shortcutWait))
    clock.run(until: clock.now + 30)
    drive.carPlayConnected()
    clock.run(until: clock.now + 10 * 60)
    #expect(drive.isDriving)
    // Once the car leaves again, the drive's Live Activity runs, so Auto-Stop applies.
    drive.carPlayDisconnected()
    await expectAutoStop(autoStop, of: drive, from: clock.now)
  }

  /// Car audio that went to CarPlay before the drive's next beat read it, as when a CarPlay
  /// automation runs the shortcut before Compasslet opens on CarPlay.
  @Test(arguments: [LiveActivityAutoStop.oneMinute, .never])
  func carAudioAtTheShortcutCountsAsTheCar(autoStop: LiveActivityAutoStop) async {
    let drive = makeDrive(autoStop: autoStop)
    await keptDrive(drive)
    carAudio.connected = true
    #expect(await runStartShortcut(drive) == .started)
    clock.run(until: clock.now + 10 * 60)
    #expect(drive.isDriving)
    #expect(drive.compactStatus == .active)
    await drive.endDrive()
  }

  /// Car audio that kept the car showing after CarPlay disconnected, gone by the shortcut before
  /// the drive read it, so the drive goes from present to left to awaiting the car.
  @Test(arguments: [LiveActivityAutoStop.oneMinute, .never])
  func carAudioGoneAtTheShortcutStartsTheWindow(autoStop: LiveActivityAutoStop) async {
    let drive = makeDrive(autoStop: autoStop)
    await keptDrive(drive, carAudioAtTheDisconnect: true)
    carAudio.connected = false
    #expect(await runStartShortcut(drive) == .startedWithoutCarPlay(shortcutWait))
    await expectEndAfterTheStartWindow(of: drive, from: clock.now)
  }

  /// CarPlay disconnecting while the Live Activity starts again leaves the drive on Auto-Stop, so
  /// the shortcut doesn't announce the wait.
  @Test(arguments: [LiveActivityAutoStop.fiveMinutes, .never])
  func carPlayDisconnectingDuringTheRestartKeepsAutoStop(autoStop: LiveActivityAutoStop) async {
    let drive = makeDrive(autoStop: autoStop)
    await drive.carPlayActivated()
    sensor.receive?(reading())
    activity.onDismiss?()
    drive.carPlayResignedActive()
    #expect(drive.compactStatus == .dismissed)
    activity.pauseStart = true
    let shortcut = Task { await runStartShortcut(drive) }
    while activity.startContinuation == nil { await Task.yield() }
    drive.carPlayDisconnected()
    activity.pauseStart = false
    activity.startContinuation?.resume()
    #expect(await shortcut.value == .started)
    #expect(drive.compactStatus == .active)
    await expectAutoStop(autoStop, of: drive, from: clock.now)
  }

  /// Car audio dropping while the shortcut waits for location leaves a new drive on Auto-Stop, so
  /// the shortcut doesn't announce the wait.
  @Test(arguments: [LiveActivityAutoStop.fiveMinutes, .never])
  func carAudioDroppingDuringTheWaitKeepsAutoStop(autoStop: LiveActivityAutoStop) async {
    let drive = makeDrive(autoStop: autoStop)
    carAudio.connected = true
    let shortcut = Task { await runStartShortcut(drive) }
    while drive.compactStatus != .active { await Task.yield() }
    sensor.receive?(reading())
    carAudio.connected = false
    drive.carAudioChanged(connected: false)
    #expect(await shortcut.value == .started)
    await expectAutoStop(autoStop, of: drive, from: clock.now)
  }

  @Test func keptDriveDismissedAgainAwayFromTheCarEnds() async {
    let drive = makeDrive(autoStop: .never)
    await keptDrive(drive)
    #expect(await runStartShortcut(drive) == .startedWithoutCarPlay(shortcutWait))
    activity.onDismiss?()
    #expect(!drive.isDriving)
    await drive.waitForPendingOperations()
    #expect(sensor.stops == 1)
  }

  @Test(arguments: [LiveActivityAutoStop.oneMinute, .never])
  func freshStartEndsTheShortcutWaitAfterIt(autoStop: LiveActivityAutoStop) async {
    let drive = makeDrive(autoStop: autoStop)
    let shortcut = Task { await runStartShortcut(drive) }
    while !drive.isDriving { await Task.yield() }
    let started = clock.now
    sensor.receive?(reading())
    #expect(await shortcut.value == .startedWithoutCarPlay(shortcutWait))
    #expect(drive.compactStatus == .active)
    #expect(sensor.starts == 1)
    await expectEndAfterTheStartWindow(of: drive, from: started)
  }
}
