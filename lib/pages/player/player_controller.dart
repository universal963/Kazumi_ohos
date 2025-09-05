import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:video_player/video_player.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:mobx/mobx.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/syncplay.dart';
import 'package:kazumi/utils/external_player.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();

  // 弹幕控制
  late DanmakuController danmakuController;
  @observable
  Map<int, List<Danmaku>> danDanmakus = {};
  @observable
  bool danmakuOn = false;

  // 一起看控制器
  SyncplayClient? syncplayController;
  @observable
  String syncplayRoom = '';
  @observable
  int syncplayClientRtt = 0;

  /// 视频比例类型
  /// 1. AUTO
  /// 2. COVER
  /// 3. FILL
  @observable
  int aspectRatioType = 1;

  /// 视频超分
  /// 1. OFF
  /// 2. Anime4K
  @observable
  int superResolutionType = 1;

  // 视频音量/亮度
  @observable
  double volume = -1;
  @observable
  double brightness = 0;

  // 播放器界面控制
  @observable
  bool lockPanel = false;
  @observable
  bool showVideoController = true;
  @observable
  bool showSeekTime = false;
  @observable
  bool showBrightness = false;
  @observable
  bool showVolume = false;
  @observable
  bool showPlaySpeed = false;
  @observable
  bool brightnessSeeking = false;
  @observable
  bool volumeSeeking = false;
  @observable
  bool canHidePlayerPanel = true;

  // 视频地址
  String videoUrl = '';

  // DanDanPlay 弹幕ID
  int bangumiID = 0;

  // 播放器实体
  late VideoPlayerController mediaPlayer;

  // 播放器面板状态
  @observable
  bool loading = true;
  @observable
  bool playing = false;
  @observable
  bool isBuffering = true;
  @observable
  bool completed = false;
  @observable
  Duration currentPosition = Duration.zero;
  @observable
  Duration buffer = Duration.zero;
  @observable
  Duration duration = Duration.zero;
  @observable
  double playerSpeed = 1.0;

  Box setting = GStorage.setting;
  bool hAenable = true;
  late String hardwareDecoder;
  bool lowMemoryMode = false;
  bool autoPlay = true;
  bool playerDebugMode = false;
  int forwardTime = 80;

  // 播放器实时状态
  bool get playerPlaying => mediaPlayer.value.isPlaying;

  bool get playerBuffering => mediaPlayer.value.isBuffering;

  bool get playerCompleted =>
      mediaPlayer.value.position >= mediaPlayer.value.duration;

  double get playerVolume => mediaPlayer.value.volume;

  Duration get playerPosition => mediaPlayer.value.position;

  Duration get playerBuffer => mediaPlayer.value.buffered.isEmpty
      ? Duration.zero
      : mediaPlayer.value.buffered[0].end;

  Duration get playerDuration => mediaPlayer.value.duration;

  int? get playerWidth => mediaPlayer.value.size.width.toInt();

  int? get playerHeight => mediaPlayer.value.size.height.toInt();

  /// 播放器内部日志
  List<String> playerLog = ['暂不支持'];

  Future<void> init(String url, {int offset = 0}) async {
    videoUrl = url;
    playing = false;
    loading = true;
    isBuffering = true;
    currentPosition = Duration.zero;
    buffer = Duration.zero;
    duration = Duration.zero;
    completed = false;
    try {
      await dispose(disposeSyncPlayController: false);
    } catch (_) {}
    int episodeFromTitle = 0;
    try {
      episodeFromTitle = Utils.extractEpisodeNumber(videoPageController
          .roadList[videoPageController.currentRoad]
          .identifier[videoPageController.currentEpisode - 1]);
    } catch (e) {
      KazumiLogger().log(Level.error, '从标题解析集数错误 ${e.toString()}');
    }
    if (episodeFromTitle == 0) {
      episodeFromTitle = videoPageController.currentEpisode;
    }
    getDanDanmakuByBgmBangumiID(videoPageController.bangumiItem.id, episodeFromTitle);
    mediaPlayer = await createVideoController();
    bool autoPlay = setting.get(SettingBoxKey.autoPlay, defaultValue: true);
    playerSpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    if (offset != 0) {
      await mediaPlayer.seekTo(Duration(seconds: offset));
    }
    if (autoPlay) {
      await mediaPlayer.play();
    }
    if (Utils.isDesktop()) {
      volume = volume != -1 ? volume : 100;
    } else {
      volume = volume != -1 ? volume : 100;
    }
    await setVolume(volume);
    setPlaybackSpeed(playerSpeed);
    KazumiLogger().log(Level.info, 'VideoURL初始化完成');
    loading = false;
    if (syncplayController?.isConnected ?? false) {
      if (syncplayController!.currentFileName !=
          "${videoPageController.bangumiItem.id}[${videoPageController.currentEpisode}]") {
        setSyncPlayPlayingBangumi(
            forceSyncPlaying: true, forceSyncPosition: 0.0);
      }
    }
  }

  Future<VideoPlayerController> createVideoController({int offset = 0}) async {
    String userAgent = '';
    playerDebugMode =
        setting.get(SettingBoxKey.playerDebugMode, defaultValue: false);
    if (videoPageController.currentPlugin.userAgent == '') {
      userAgent = Utils.getRandomUA();
    } else {
      userAgent = videoPageController.currentPlugin.userAgent;
    }
    String referer = videoPageController.currentPlugin.referer;
    var httpHeaders = {
      'user-agent': userAgent,
      if (referer.isNotEmpty) 'referer': referer,
    };
    mediaPlayer = VideoPlayerController.networkUrl(Uri.parse(videoUrl),
        httpHeaders: httpHeaders);
    // error handle
    bool showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: true);
    mediaPlayer.addListener(() {
      if (mediaPlayer.value.hasError &&
          mediaPlayer.value.position < mediaPlayer.value.duration) {
        if (showPlayerError) {
          KazumiDialog.showToast(
              message:
                  '播放器内部错误 ${mediaPlayer.value.errorDescription} $videoUrl',
              duration: const Duration(seconds: 5),
              showActionButton: true);
        }
        KazumiLogger().log(Level.error,
            'Player inent error. ${mediaPlayer.value.errorDescription} $videoUrl');
      }
    });
    await mediaPlayer.initialize();
    return mediaPlayer;
  }

  Future<void> setPlaybackSpeed(double playerSpeed) async {
    this.playerSpeed = playerSpeed;
    try {
      mediaPlayer.setPlaybackSpeed(playerSpeed);
    } catch (e) {
      KazumiLogger().log(Level.error, '设置播放速度失败 ${e.toString()}');
    }
  }

  Future<void> setVolume(double value) async {
    value = value.clamp(0.0, 100.0);
    volume = value;
    try {
      if (Utils.isDesktop()) {
        await mediaPlayer.setVolume(value);
      } else {
        await mediaPlayer.setVolume(volume / 100);
      }
    } catch (_) {}
  }

  Future<void> playOrPause() async {
    if (mediaPlayer.value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration duration, {bool enableSync = true}) async {
    currentPosition = duration;
    danmakuController.clear();
    await mediaPlayer.seekTo(duration);
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync(doSeek: true);
      }
    }
  }

  Future<void> pause({bool enableSync = true}) async {
    danmakuController.pause();
    await mediaPlayer.pause();
    playing = false;
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> play({bool enableSync = true}) async {
    danmakuController.resume();
    await mediaPlayer.play();
    playing = true;
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> dispose({bool disposeSyncPlayController = true}) async {
    if (disposeSyncPlayController) {
      try {
        syncplayRoom = '';
        syncplayClientRtt = 0;
        await syncplayController?.disconnect();
        syncplayController = null;
      } catch (_) {}
    }
    try {
      await mediaPlayer.dispose();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await mediaPlayer.pause();
      loading = true;
    } catch (_) {}
  }

  // Future<Uint8List?> screenshot({String format = 'image/jpeg'}) async {
  //   return await mediaPlayer.screenshot(format: format);
  // }

  void setForwardTime(int time) {
    forwardTime = time;
  }

  Future<void> getDanDanmakuByBgmBangumiID(
      int bgmBangumiID, int episode) async {
    KazumiLogger().log(Level.info, '尝试获取弹幕 [BgmBangumiID] $bgmBangumiID');
    try {
      danDanmakus.clear();
      bangumiID = await DanmakuRequest.getDanDanBangumiIDByBgmBangumiID(bgmBangumiID);
      var res = await DanmakuRequest.getDanDanmaku(bangumiID, episode);
      addDanmakus(res);
    } catch (e) {
      KazumiLogger().log(Level.warning, '获取弹幕错误 ${e.toString()}');
    }
  }

  Future<void> getDanDanmakuByEpisodeID(int episodeID) async {
    KazumiLogger().log(Level.info, '尝试获取弹幕 $episodeID');
    try {
      danDanmakus.clear();
      var res = await DanmakuRequest.getDanDanmakuByEpisodeID(episodeID);
      addDanmakus(res);
    } catch (e) {
      KazumiLogger().log(Level.warning, '获取弹幕错误 ${e.toString()}');
    }
  }

  void addDanmakus(List<Danmaku> danmakus) {
    for (var element in danmakus) {
      var danmakuList =
          danDanmakus[element.time.toInt()] ?? List.empty(growable: true);
      danmakuList.add(element);
      danDanmakus[element.time.toInt()] = danmakuList;
    }
  }

  void lanunchExternalPlayer() async {
    String referer = videoPageController.currentPlugin.referer;
    if ((Platform.isAndroid || Platform.isWindows || Platform.isOhos) &&
        referer.isEmpty) {
      if (await ExternalPlayer.launchURLWithMIME(videoUrl, 'video/mp4')) {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(
          message: '尝试唤起外部播放器',
        );
      } else {
        KazumiDialog.showToast(
          message: '唤起外部播放器失败',
        );
      }
    } else if (Platform.isMacOS || Platform.isIOS) {
      if (await ExternalPlayer.launchURLWithReferer(videoUrl, referer)) {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(
          message: '尝试唤起外部播放器',
        );
      } else {
        KazumiDialog.showToast(
          message: '唤起外部播放器失败',
        );
      }
    } else if (Platform.isLinux && referer.isEmpty) {
      KazumiDialog.dismiss();
      if (await canLaunchUrlString(videoUrl)) {
        launchUrlString(videoUrl);
        KazumiDialog.showToast(
          message: '尝试唤起外部播放器',
        );
      } else {
        KazumiDialog.showToast(
          message: '无法使用外部播放器',
        );
      }
    } else {
      if (referer.isEmpty) {
        KazumiDialog.showToast(
          message: '暂不支持该设备',
        );
      } else {
        KazumiDialog.showToast(
          message: '暂不支持该规则',
        );
      }
    }
  }

  Future<void> createSyncPlayRoom(
      String room,
      String username,
      Future<void> Function(int episode, {int currentRoad, int offset})
          changeEpisode,
      {bool enableTLS = false}) async {
    await syncplayController?.disconnect();
    final String syncPlayEndPoint = setting.get(SettingBoxKey.syncPlayEndPoint,
        defaultValue: defaultSyncPlayEndPoint);
    String syncPlayEndPointHost = '';
    int syncPlayEndPointPort = 0;
    debugPrint('SyncPlay: 连接到服务器 $syncPlayEndPoint');
    try {
      final parts = syncPlayEndPoint.split(':');
      if (parts.length == 2) {
        syncPlayEndPointHost = parts[0];
        syncPlayEndPointPort = int.parse(parts[1]);
      }
    } catch (_) {}
    if (syncPlayEndPointHost == '' || syncPlayEndPointPort == 0) {
      KazumiDialog.showToast(
        message: 'SyncPlay: 服务器地址不合法 $syncPlayEndPoint',
      );
      KazumiLogger().log(Level.error, 'SyncPlay: 服务器地址不合法 $syncPlayEndPoint');
      return;
    }
    syncplayController =
        SyncplayClient(host: syncPlayEndPointHost, port: syncPlayEndPointPort);
    try {
      await syncplayController!.connect(enableTLS: enableTLS);
      syncplayController!.onGeneralMessage.listen(
        (message) {
          // print('SyncPlay: general message: ${message.toString()}');
        },
        onError: (error) {
          print('SyncPlay: error: ${error.message}');
          if (error is SyncplayConnectionException) {
            exitSyncPlayRoom();
            KazumiDialog.showToast(
              message: 'SyncPlay: 同步中断 ${error.message}',
              duration: const Duration(seconds: 5),
              showActionButton: true,
              actionLabel: '重新连接',
              onActionPressed: () =>
                  createSyncPlayRoom(room, username, changeEpisode),
            );
          }
        },
      );
      syncplayController!.onRoomMessage.listen(
        (message) {
          if (message['type'] == 'init') {
            if (message['username'] == '') {
              KazumiDialog.showToast(
                  message: 'SyncPlay: 您是当前房间中的唯一用户',
                  duration: const Duration(seconds: 5));
              setSyncPlayPlayingBangumi();
            } else {
              KazumiDialog.showToast(
                  message:
                      'SyncPlay: 您不是当前房间中的唯一用户, 当前以用户 ${message['username']} 进度为准');
            }
          }
          if (message['type'] == 'left') {
            KazumiDialog.showToast(
                message: 'SyncPlay: ${message['username']} 离开了房间',
                duration: const Duration(seconds: 5));
          }
          if (message['type'] == 'joined') {
            KazumiDialog.showToast(
                message: 'SyncPlay: ${message['username']} 加入了房间',
                duration: const Duration(seconds: 5));
          }
        },
      );
      syncplayController!.onFileChangedMessage.listen(
        (message) {
          print(
              'SyncPlay: file changed by ${message['setBy']}: ${message['name']}');
          RegExp regExp = RegExp(r'(\d+)\[(\d+)\]');
          Match? match = regExp.firstMatch(message['name']);
          if (match != null) {
            int bangumiID = int.tryParse(match.group(1) ?? '0') ?? 0;
            int episode = int.tryParse(match.group(2) ?? '0') ?? 0;
            if (bangumiID != 0 &&
                episode != 0 &&
                episode != videoPageController.currentEpisode) {
              KazumiDialog.showToast(
                  message:
                      'SyncPlay: ${message['setBy'] ?? 'unknown'} 切换到第 $episode 话',
                  duration: const Duration(seconds: 3));
              changeEpisode(episode,
                  currentRoad: videoPageController.currentRoad);
            }
          }
        },
      );
      syncplayController!.onChatMessage.listen(
        (message) {
          if (message['username'] != username) {
            KazumiDialog.showToast(
                message:
                    'SyncPlay: ${message['username']} 说: ${message['message']}',
                duration: const Duration(seconds: 5));
          }
        },
      );
      syncplayController!.onPositionChangedMessage.listen(
        (message) {
          syncplayClientRtt = (message['clientRtt'].toDouble() * 1000).toInt();
          print(
              'SyncPlay: position changed by ${message['setBy']}: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] calculatedPosition ${message['calculatedPositon']} position: ${message['position']} doSeek: ${message['doSeek']} paused: ${message['paused']} clientRtt: ${message['clientRtt']} serverRtt: ${message['serverRtt']} fd: ${message['fd']}');
          if (message['paused'] != !playing) {
            if (message['paused']) {
              if (message['position'] != 0) {
                KazumiDialog.showToast(
                    message: 'SyncPlay: ${message['setBy'] ?? 'unknown'} 暂停了播放',
                    duration: const Duration(seconds: 3));
                pause(enableSync: false);
              }
            } else {
              if (message['position'] != 0) {
                KazumiDialog.showToast(
                    message: 'SyncPlay: ${message['setBy'] ?? 'unknown'} 开始了播放',
                    duration: const Duration(seconds: 3));
                play(enableSync: false);
              }
            }
          }
          if ((((playerPosition.inMilliseconds -
                              (message['calculatedPositon'].toDouble() * 1000)
                                  .toInt())
                          .abs() >
                      1000) ||
                  message['doSeek']) &&
              duration.inMilliseconds > 0) {
            seek(
                Duration(
                    milliseconds:
                        (message['calculatedPositon'].toDouble() * 1000)
                            .toInt()),
                enableSync: false);
          }
        },
      );
      await syncplayController!.joinRoom(room, username);
      syncplayRoom = room;
    } catch (e) {
      print('SyncPlay: error: $e');
    }
  }

  void setSyncPlayCurrentPosition(
      {bool? forceSyncPlaying, double? forceSyncPosition}) {
    if (syncplayController == null) {
      return;
    }
    forceSyncPlaying ??= playing;
    syncplayController!.setPaused(!forceSyncPlaying);
    syncplayController!.setPosition((forceSyncPosition ??
        (((currentPosition.inMilliseconds - playerPosition.inMilliseconds)
                    .abs() >
                2000)
            ? currentPosition.inMilliseconds.toDouble() / 1000
            : playerPosition.inMilliseconds.toDouble() / 1000)));
  }

  Future<void> setSyncPlayPlayingBangumi(
      {bool? forceSyncPlaying, double? forceSyncPosition}) async {
    await syncplayController!.setSyncPlayPlaying(
        "${videoPageController.bangumiItem.id}[${videoPageController.currentEpisode}]",
        10800,
        220514438);
    setSyncPlayCurrentPosition(
        forceSyncPlaying: forceSyncPlaying,
        forceSyncPosition: forceSyncPosition);
    await requestSyncPlaySync();
  }

  Future<void> requestSyncPlaySync({bool? doSeek}) async {
    await syncplayController!.sendSyncPlaySyncRequest(doSeek: doSeek);
  }

  Future<void> sendSyncPlayChatMessage(String message) async {
    if (syncplayController == null) {
      return;
    }
    await syncplayController!.sendChatMessage(message);
  }

  Future<void> exitSyncPlayRoom() async {
    if (syncplayController == null) {
      return;
    }
    await syncplayController!.disconnect();
    syncplayController = null;
    syncplayRoom = '';
    syncplayClientRtt = 0;
  }
}
