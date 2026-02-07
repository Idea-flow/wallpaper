# Bing 壁纸功能规划（素材库子模块）

> 目标：在「素材库」下新增「Bing 壁纸」菜单，使用 Bing 主页每日壁纸接口展示图片，支持预览与右键保存到素材库（下载到应用目录）。

---

## 1. 数据来源与合规

- **数据源**：使用 Bing 主页壁纸接口 `HPImageArchive.aspx`，获取每日壁纸列表。该接口返回 JSON，包含 `images` 数组、`url` / `urlbase` / `title` / `copyright` / `copyrightlink` 等字段。
- **参数**：
  - `format=js`：返回 JSON
  - `idx`：从哪一天起（0=今天，1=昨天，-1=明天预告，最多约 16 天）
  - `n`：返回数量（1~8）
  - `mkt`：地区（如 `zh-CN` / `en-US`）
- **下载限制提示**：接口响应中包含 `tooltips.walls / tooltips.walle` 说明“仅限壁纸用途”，同时 `wp` 字段可能用于标识可否作为壁纸。
- **4K 获取策略**：社区常用规则是将 `url` 中的 `_1920x1080` 替换为 `_UHD` 来请求超清版本（不保证一定存在，失败需回退到 `url`）。

> 说明：该接口是公开可访问的端点，但并非明确官方文档化 API，需做好失败回退与免责声明提示。

---

## 2. 入口与导航（左侧菜单）

- 在侧栏「素材库」下新增一级菜单：**Bing 壁纸**
- 图标建议：`globe.asia.australia` 或 `photo.on.rectangle.angled`
- 行为：点击后在中间栏显示 Bing 壁纸列表，右侧显示详情预览

---

## 3. 页面布局规划

### 3.1 中间栏：Bing 壁纸列表（网格/列表）

**顶部工具栏（横向）**
- 地区选择：`mkt` 下拉（zh-CN / en-US / ja-JP / en-GB ...）
- 时间分页：上一天 / 今天 / 下一天（或使用 `idx`）
- 数量选择：8 张 / 4 张
- 刷新按钮：重新拉取
- 4K 开关：默认开启（失败则自动回退）

**内容区（网格卡片）**
- 图片缩略图（优先 `url` 作为缩略）
- 标题 + 日期 + 版权来源
- 状态标记：已下载 / 未下载

**右键菜单**（卡片右键）
- 保存到素材库
- 复制图片链接
- 设为壁纸(实际分为两步,先下载到本地,然后再把这个图片设置壁纸)

### 3.2 右侧详情栏：Bing 壁纸预览

- 大图预览（优先 4K URL；失败回退 1080p）
- 标题 / 版权 / 日期 / 地区
- 操作按钮：
  - 设为壁纸(实际分为两步,先下载到本地,然后再把这个图片设置壁纸)
  - 保存到素材库（下载）
  - 打开版权链接

---

## 4. 下载与保存（方案 A：保存到应用目录）

- 点击「保存到素材库」时：
  1. 根据 `urlbase` 组装 4K URL（`_UHD.jpg`）
  2. 若 4K 请求失败（404/超时），自动回退 `url`
  3. 下载文件到应用目录：
     `~/Library/Containers/<bundle>/Data/Library/Application Support/wallpaper/MediaLibrary/`
  4. 创建 `MediaItem` 写入数据库（类型为图片）

**好处**：下载后不依赖外部权限，打包后稳定可用。

---

## 5. 数据模型与缓存

- 新增轻量 `BingWallpaperItem`（仅内存）：
  - `id`/`title`/`date`/`url`/`urlbase`/`copyright`/`copyrightlink`/`wp`
- 缓存策略：
  - 列表缓存到内存（或轻量磁盘缓存）
  - 缩略图缓存使用现有 ThumbnailCache（或新增 URLCache）

---

## 6. 关键交互流程

1. 进入 Bing 壁纸页面 -> 拉取 `idx=0 & n=8`
2. 列表展示 -> 点击卡片更新右侧预览
3. 右键保存 -> 下载(需要有进度条) -> 写入素材库 -> 列表标记“已下载”
4. 下载失败 -> 展示错误原因 + 记录日志

---

## 7. 日志与错误提示（已接入日志中心）

- 拉取成功 / 失败
- 4K 回退
- 下载成功 / 失败
- 保存入库失败

所有日志进入「日志」页面，方便排查。

---

## 8. 需要确认的产品决策（请你审核）

1. 是否开放“设为壁纸”按钮（直接使用在线图片设置壁纸）？ 答: 开放有这个功能,但是这个功能点击后实际分为两步,先下载到本地,然后再把这个图片设置壁纸
2. 默认地区 `mkt` 是否跟随系统语言？ 答: 跟随系统语言
3. 是否需要支持“历史 16 天翻页”？ 支持
4. 下载后是否自动切换到素材库详情？ 提示用户是否跳转,下载要有个进度条展示

---

## 参考（接口与字段来源）

- HPImageArchive 接口、参数说明、返回字段示例（`url` / `urlbase` / `mkt` / `idx` / `n`）  
  https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US  
  https://blog.atwork.at/post/2020/use-the-daily-bing-picture-in-teams-calls/  
  https://www.cnblogs.com/cinlap/p/14713302.html  
- `tooltips` 与 `wp` 字段（包含“仅限壁纸用途”的提示）  
  https://qastack.it/programming/10639914/is-there-a-way-to-get-bings-photo-of-the-day  
- 4K 规则（`urlbase` + `_UHD.jpg`）为社区常用做法，需做好失败回退  
  https://gist.github.com/y0ngb1n/c249edc8e547fb0f7d663c0dc98e79e7  
