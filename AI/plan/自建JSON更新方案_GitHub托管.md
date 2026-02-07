# 自建 JSON 更新方案（GitHub 托管，待评审）

本方案不使用 Sparkle，改为：
- 通过 **GitHub 上公开的 JSON** 获取版本信息与更新内容
- 客户端对比版本号
- 提示用户下载更新包（.dmg）

---

## 1. 目标
- 实现应用内“检查更新”
- 自动或手动对比版本
- 提示下载并引导升级
- 版本信息托管在 GitHub（公开 JSON）

---

## 2. 核心流程
1. App 启动/手动触发更新检查
2. 请求远端 JSON
3. 解析版本信息
4. 对比本地版本号
5. 如果有新版本：
   - 展示更新内容
   - 提供下载按钮
   - 跳转到下载链接

---

## 3. JSON 数据结构（托管在 GitHub）
建议路径：
```
https://raw.githubusercontent.com/<owner>/<repo>/main/update/update.json
```

### 示例 JSON
```json
{
  "latest": {
    "version": "1.3.0",
    "build": 10300,
    "title": "1.3.0 发布",
    "notes": "- 新增 Bing 壁纸双栏布局\n- 优化菜单栏导入\n- 新增 Dock 图标隐藏",
    "pub_date": "2026-02-07",
    "download_url": "https://github.com/<owner>/<repo>/releases/download/v1.3.0/Wallpaper-1.3.0.dmg",
    "size_bytes": 123456789,
    "sha256": "<可选哈希>"
  },
  "minimum": {
    "version": "1.2.0",
    "build": 10200
  }
}
```

字段说明：
- `latest.version`：对应 `CFBundleShortVersionString`
- `latest.build`：对应 `CFBundleVersion`
- `download_url`：直接下载链接
- `sha256`：可选，用于下载后校验
- `minimum`：强制最低版本（低于此版本提示必须更新）

---

## 4. 版本号配置
在 Xcode 中配置：
- `CFBundleShortVersionString`（用户看到的版本号）
- `CFBundleVersion`（构建号）

---

## 5. 客户端实现要点
### 5.1 更新检查入口
- 设置页增加：
  - “检查更新”按钮
  - “自动检查更新”开关（可选）

### 5.2 网络请求
- 使用 `URLSession` 拉取 JSON
- 解析为模型

### 5.3 版本比较
- 优先比较 `build`（数值更可靠）
- 如果 `build` 不存在，再比较 `version`

### 5.4 提示与交互
- 有新版本 → 弹窗展示更新内容和下载按钮
- 点击下载 → 打开浏览器/开始下载

---

## 6. 可选增强
- 下载后校验 SHA256
- 内置“下载进度”
- 支持稳定/测试双通道（两个 JSON）

---

## 7. 发布流程（版本升级）
1. 修改版本号（Xcode）
2. 构建并打包  `.dmg`
3. 上传到 GitHub Releases
4. 更新 `update.json`
5. 提交 `update.json` 到仓库
6. 客户端拉取并提示更新

---

## 8. 风险与限制
- 没有 Sparkle 的自动替换能力，用户需要手动下载安装 
- 无更新签名机制（可通过 `sha256` 缓解）
- 无差量更新（下载包较大）

---

## 9. 待确认事项
- JSON 文件路径（repo/branch/目录）
- 更新包格式（zip / dmg）
- 是否需要强制更新机制（minimum version）
- 是否需要自动下载或仅跳转下载链接
