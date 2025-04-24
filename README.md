# Kazumi

该分支为使用 [OpenHarmony-SIG / flutter_flutter](https://gitcode.com/openharmony-sig/flutter_flutter) 进行适配的 Kazumi
ohos (HarmonyOS NEXT) 版本。

> [!IMPORTANT]
>
> 该分支仅考虑 ohos 平台的适配，若使用该分支构建其他平台会导致各种问题。

## 支持情况

- API 版本：16
- Flutter 版本：3.22.0-ohos

## 功能适配情况

- [x] 视频解析器
- [x] 原生视频播放器
- [x] 手势亮度调节
- [x] 智慧多窗
- [x] ~~外部播放器~~(目前没有软件支持外部网络视频链接拉起)
- [ ] 基于 mpv 的视频播放器：
    - [ ] 支持更多视频规格
    - [ ] 硬件加速
    - [ ] 视频比例切换
    - [ ] 视频调试信息
    - [ ] 超分辨率
- [ ] ~~手势系统音量调节~~(架构不支持)

## 下载与安装

通过本页面 [releases](https://github.com/ErBWs/Kazumi/releases) 选项卡下载：

<a href="https://github.com/ErBWs/Kazumi/releases">
  <img src="static/svg/get_it_on_github.svg" alt="Get it on Github" width="200"/>
</a>

使用[小白调试助手](https://github.com/likuai2010/auto-installer)进行安装

## 开源协议

GNU 通用公共许可证第 3 版 (GPL-3.0)