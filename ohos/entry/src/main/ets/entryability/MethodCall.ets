import { FlutterPlugin, FlutterPluginBinding, MethodCall, MethodChannel, MethodResult } from "@ohos/flutter_ohos";
import { common, Want } from "@kit.AbilityKit";
import { BusinessError } from "@kit.BasicServicesKit";
import uri from "@ohos.uri";

export default class MethodCallPlugin implements FlutterPlugin {
  private channel?: MethodChannel;

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "com.predidit.kazumi/intent");
    this.channel.setMethodCallHandler({
      onMethodCall : (call: MethodCall, result: MethodResult) => {
        switch (call.method) {
          case "openWithMime":
            let url = String(call.argument("url"));
            let mimeType = String(call.argument("mimeType"));
            this.openWithMime(url, mimeType);
            result.success("");
            break;
          default:
            result.notImplemented();
            break;
        }
      }
    })
  }

  private openWithMime(url: string, mimeType: string): void {
    let context = getContext(this) as common.UIAbilityContext;
    let want: Want = {
      uri: url,
      type: mimeType
    };

    context.startAbility(want, (err: BusinessError) => {
      if (err.code) {
        console.error(`Failed to startAbility. Code: ${err.code}, message: ${err.message}`);
      }
    });
  }

  getUniqueClassName(): string {
    return "MethodCallPlugin"
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
  }
}