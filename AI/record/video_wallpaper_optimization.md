# 视频壁纸低功耗方案（2026-02-07）

## 目标
- 降低视频壁纸对 GPU/解码的占用，减小耗电。
- 在低电或壁纸不可见时自动暂停，保持静帧。
- 保持可配置：用户可在设置中关闭。

## 实施点
1) **播放参数限速**  
   - `preferredPeakBitRate = 8 Mbps`（低功耗开关启用时），上限 16 Mbps（关闭时）。  
   - `preferredMaximumResolution = screen.size` 避免超采样。  
   - `preferredForwardBufferDuration = 1` 秒，减少内存与无谓预缓冲。  
   - `AVMutableVideoComposition` 在低功耗模式下将帧率锁到 **24fps**，降低重绘频率。

2) **静帧省电模式**（默认开启，可在设置关闭）  
   - 监听 `isLowPowerModeEnabled` 及壁纸窗口可见性。  
   - 低电或不可见 → `pause()`，保留当前帧作为静态壁纸；恢复时继续 `play()`.

3) **可见性轮询**  
   - 每秒检查窗口 `occlusionState.contains(.visible)`；无可见窗口视为被遮挡。

## 相关代码
- `Services/VideoWallpaperService.swift`  
  - `configurePerformanceHints(...)`：限码率/分辨率/帧率。  
  - `updatePlaybackForPowerState()`：低电/不可见暂停静帧。  
  - `startPowerObserver()`、`startVisibilityTimer()`：监听低电与可见性。
- `Views/SettingsView.swift`  
  - 新增开关 `低电/遮挡时暂停视频，保留静帧` (`pauseVideoWhenLowPower`)，默认开启。

## 使用说明
- 在设置 > 性能优化 中可关闭“低电/遮挡时暂停”，恢复持续播放。  
- 低功耗模式开关决定是否启用 24fps + 8Mbps 的限流策略。  
- 如需进一步压缩，可在导入时额外转码到 1080p/24fps H.264（待需求确认）。 
