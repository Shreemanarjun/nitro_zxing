import FlutterMacOS
import Foundation

public class NitroZxingPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    NitroZxingRegistry.register(NitroZxingModuleImpl())
    // Nitro registration will be injected here by nitrogen link.
  }
}
