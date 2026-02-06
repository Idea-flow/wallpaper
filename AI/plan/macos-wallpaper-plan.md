# macOS 原生壁纸系统 - 功能模块规划（支持图片与视频）

## 目标与技术边界
- 目标：构建原生 macOS 壁纸系统，支持图片与视频壁纸，多屏幕与规则化切换，原生 UI 体验。
- 技术：SwiftUI + SwiftData；系统集成使用 AppKit/AVFoundation；UI 采用 Liquid Glass（macOS 26+）并提供回退。
- 运行形态：主 App + 菜单栏控制（可选常驻）+ 登录项。

## 功能模块规划（详细）

### 1) 壁纸引擎与系统集成（核心）
- 图片壁纸设置：
  - 调用 `NSWorkspace.shared.setDesktopImageURL(_:for:options:)`，支持指定屏幕。
  - 支持适配模式：填充、适应、拉伸、居中、平铺。
- 视频壁纸渲染：
  - 使用 `AVPlayer` + `AVPlayerLayer`/`NSViewRepresentable` 进行桌面背景渲染。
  - 低功耗策略：后台/锁屏时暂停；屏幕休眠时停止。
  - 音频策略：默认静音，按规则可启用音频（含音量限制）。
- 多屏幕支持：
  - 逐屏设置、统一设置、主屏优先。
  - 监测屏幕变化（插拔/分辨率变化）并自动重设。
- 安全权限：
  - 通过 `NSOpenPanel` 导入素材并保存安全作用域书签。
  - 处理资源失效、移动文件、权限丢失的恢复流程。

### 2) 素材库与媒体管理（SwiftData）
- 素材类型：
  - 图片（jpg/png/heic/gif），视频（mp4/mov/hevc）。
  - 自动提取：分辨率、时长、帧率、色调、文件大小。
- 组织方式：
  - 专辑/集合、标签、评分、收藏。
  - 智能集合：按分辨率、色调、时间、屏幕比例自动分组。
- 媒体预览：
  - 图片缩略图缓存与懒加载。
  - 视频首帧预览与短预览循环。
- 资产完整性：
  - 文件丢失检测与重新定位。
  - 重复文件检测与合并建议。

### 3) 规则与自动切换
- 时间规则：按小时/天/工作日/周末轮换。
- 事件规则：开机/登录、唤醒、屏幕变化、连接外接屏。
- 优先级与冲突处理：规则优先级、覆盖策略、最近有效规则。
- 随机策略：
  - 均匀随机、权重随机、避免最近重复。
  - 图片/视频混排比例控制。
- 视频规则扩展：
  - 视频最长时长限制。
  - 在电量/温度较高时自动降级为图片壁纸。

### 4) UI 与交互（SwiftUI + AppKit Bridge）
- 主界面布局：三栏（库/预览/详情与规则），兼容 macOS 视觉范式。
- 预览与裁剪：
  - 图片裁剪框、视频裁剪区域预览。
  - 适配方式实时预览。
- 快捷交互：拖放导入、右键菜单、批量操作。
- Liquid Glass：
  - macOS 26+ 使用 `glassEffect`，组件统一容器；低版本 `material` 回退。
  - 玻璃层级：顶部控制条、素材卡片、详情面板。
- 状态与反馈：错误提示、权限引导、后台运行提示。

### 5) 菜单栏与系统控制
- 菜单栏按钮：快速切换、暂停/继续、下一张、清理缓存。
- 快捷键：上一张/下一张、锁定当前壁纸。
- 登录项：`SMAppService` 管理开机自启。
- 后台运行管理：低能耗模式与资源占用提示。

### 6) 视频播放与性能策略
- 解码策略：
  - 优先硬件解码（H.264/HEVC）。
  - 高分辨率视频在低性能设备上自动降级。
- 帧率控制：
  - 高帧率自动限制为 30fps。
- 缓存与内存：
  - 视频预览缓存独立管理，防止 UI 卡顿。
- 安全阈值：
  - 温度/电池状态监测（如可用），必要时降级。

### 7) 设置与数据管理
- 账户与同步（可选）：
  - iCloud 同步素材元数据（不强制）。
- 导入/导出：规则与集合配置备份。
- 统计与历史：
  - 最近使用记录。
  - 失败日志与自动恢复建议。

### 8) 扩展能力（可选）
- 在线图库 Provider（可插拔，后期）。
- 主题配色自动匹配系统外观（浅色/深色）。

## 数据模型建议（SwiftData）
- `MediaItem`：
  - `id`、`type(image/video)`、`fileURL`、`thumbnailURL`、`width`、`height`、`duration`、`frameRate`、`size`、`tags`、`rating`、`isFavorite`、`createdAt`、`lastUsedAt`。
- `Album`：
  - `id`、`name`、`items`（关系）、`rules`（关系）。
- `Rule`：
  - `id`、`scope(global/screen)`、`timeWindow`、`weekdays`、`randomStrategy`、`priority`、`enabled`、`mediaMixRatio`。
- `ScreenProfile`：
  - `id`、`screenID`、`preferredFitMode`、`preferredAlbum`。
- `History`：
  - `id`、`mediaID`、`screenID`、`appliedAt`、`result`、`error`。

## 关键实现细节与注意点
- 使用安全作用域书签持久访问用户素材。
- 多显示器切换频繁，需去抖处理。
- 视频壁纸渲染需避免占用桌面窗口焦点，确保不影响用户操作。
- Liquid Glass 必须 `#available` 保护并提供回退。

