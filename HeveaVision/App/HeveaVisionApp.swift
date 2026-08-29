import SwiftUI

@main
struct HeveaVisionApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup(id: AppModel.mainWindowID) {
      MissionControlView()
        .environment(model)
    }
    .defaultSize(width: 1_180, height: 880)

    ImmersiveSpace(id: AppModel.immersiveSpaceID) {
      ImmersiveLabView()
        .environment(model)
    }
    .immersionStyle(selection: .constant(.full), in: .full)
  }
}
