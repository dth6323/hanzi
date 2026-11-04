import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    let darkBg = UIColor(red: 0x12 / 255.0, green: 0x10 / 255.0, blue: 0x0F / 255.0, alpha: 1.0)
    window?.backgroundColor = darkBg
    window?.rootViewController?.view.backgroundColor = darkBg
  }
}
