# LeafReader 详细任务拆解（v0.1–v0.5）

## 文档目的
- 作为与 `.devDocmunt/dev-plan.md` 配套的执行清单，细化到“可分配、可验收”的任务粒度
- 明确每个里程碑的工作流、交付物、前置依赖与测试关注点，降低跨功能沟通成本
- 为排期、人员分配与进度跟踪提供最小工作项（Minimum Work Item, MWI）视图

## 里程碑全景
| 里程碑 | 范围焦点 | 完成标准 | 关键依赖 |
| --- | --- | --- | --- |
| v0.1 基础导入与直读 | 导入 → 解析入库 → 阅读器首版 | 能导入多本 EPUB，并在退出后恢复阅读进度 | Readium 依赖、最小本地存储层 |
| v0.2 自定义渲染 | 全屏章头识别 + CSS 注入管线 | 进入多看全屏章节时渲染正确，CSS 管线可按章节开关 | v0.1 数据结构包含 spine properties |
| v0.3 脚注弹窗 | 兼容标准、多看、掌阅脚注 | 点击任意脚注均弹出浮层显示内容 | v0.2 JS 注入基础、Footnote UI 容器 |
| v0.4 阅读体验 | 字体映射 + 基础阅读设置 | 字体别名全部映射，字号/主题保持持久化 | v0.2 CSS 管线、Readium 设置封装 |
| v0.5 LCP 支持 | DRM 最小闭环 | LCP 样书可解密阅读，异常有提示 | ReadiumLCP 集成、凭证输入流程 |

## Ownership 与排期假设
- 当前为**独立开发者**执行，目标 3 周内完成 v0.1 可用版本（含导入、解析、阅读器最小功能）。
- v0.2 及之后的里程碑暂列为待规划，待 v0.1 验收后再细化排期。

| 里程碑 | Owner | 目标 | 预估结束日 | 备注 |
| --- | --- | --- | --- | --- |
| v0.1 基础导入与直读 | Solo Dev | 独立交付导入→阅读闭环 | 2024-07-19 | 样书验证通过；无持久化数据库 |
| v0.2 自定义渲染 | Solo Dev | 待排期 | TBD | 依赖 v0.1 产物 |
| v0.3+ | Solo Dev/待定 | 待排期 | TBD | 视资源及优先级调整 |

> 注：如新成员加入或优先级变更，请更新目标日期并补充协作角色。

## 详细拆分说明

### v0.1 基础导入与直读

#### 工作流 A：文件导入入口
- **Owner/批次**：Solo Dev · v0.1
- **关键依赖**：Info.plist 权限确认、导入样书（标准 EPUB）
- **A1 Info.plist / Capabilities 配置**
  - Expo: 补充 `CFBundleDocumentTypes`、`LSSupportsOpeningDocumentsInPlace`（如需要），确保导入源于“文件”App、AirDrop
  - 验收：Document Picker 打开时只显示 EPUB；导入 App 前无崩溃
- **A2 Document Picker UI & 状态管理**
  - SwiftUI `fileImporter` 或 UIKit 包装；处理 `isPresented`、多选禁用
  - 错误处理：取消、权限拒绝、读取失败分别弹 Toast
  - 验收：导入流畅，重复点击不崩溃
- **A3 文件拷贝与存储结构**
  - 生成 `bookId`（`UUID`），创建 `/Documents/Library/<bookId>/source.epub`
  - 重复导入时策略：相同 hash → 复用 ID，否则新增
  - 验收：本地文件夹结构符合规范（含原档）
- **A4 导入后流程编排**
  - 使用 Combine/async-await 保证拷贝成功后触发解析
  - 失败回滚：删除半成品目录
  - 验收：任意导入失败不会遗留脏目录

#### 工作流 B：解析与本地书库
- **Owner/批次**：Solo Dev · v0.1
- **关键依赖**：工作流 A 拷贝路径稳定、Readium 解析可用
- **B1 Readium Streamer 集成验证**
  - 封装 `EPUBParser`，注入 `Streamer`，统一 error handling
  - 验收：解析至少 3 本不同结构 EPUB 成功
- **B2 元数据模型与轻量存储**
  - v0.1 阶段暂不引入数据库，使用轻量文件持久化（如 `Book` JSON + 封面缓存路径）
  - 预留接口方便后续替换为数据库实现（Protocol / Repository 模式）
  - 验收：JSON 存取读写可靠，结构与后续数据库模型兼容
- **B3 封面提取与缓存**
  - 优先 Publication `cover`；fallback 到 manifest 常见命名
  - 缓存为 PNG/JPEG（尺寸约 256x256），存放 `/Library/Caches/Cover/<bookId>.png`
  - 验收：书架列表能显示封面，无封面 fallback 默认图
- **B4 Library 数据源与列表占位**
  - 暂用简单 `LazyVGrid/List` 展示书名、作者、封面
  - 提供“最近阅读”排序
  - 验收：导入后列表自动刷新，空态文案清晰

#### 工作流 C：阅读器初版
- **Owner/批次**：Solo Dev · v0.1
- **关键依赖**：工作流 B Publication 模型、Readium UI 依赖
- **C1 Navigator 容器封装**
  - 封装 `EPUBNavigatorViewController` 到 SwiftUI；处理生命周期
  - 验收：可在 iPhone/iPad 启动阅读器，无空白页
- **C2 TOC & 章节跳转**
  - 将 `publication.tableOfContents` 映射到侧边/弹出目录
  - 跳转时定位 `Locator` 并调用 `navigator.go(to:)`
  - 验收：目录项可跳转，回退正常
- **C3 阅读位置持久化**
  - 监听 `navigator.currentLocation`，序列化 JSON 存入 `Book.lastReadLocatorJSON`
  - 重新打开时传入 `initialLocation`
  - 验收：退出/重进保持定位；无定位时落到首章
- **C4 基础 UI 与错误提示**
  - 提供加载过渡、失败重试按钮
  - 全局错误上报（LogStore/Firebase 可后补）
  - 验收：网络/文件错误有提示，不出现白屏

### v0.2 自定义渲染

#### 工作流 D：全屏章头识别
- **Owner/批次**：Solo Dev · Backlog
- **关键依赖**：SpineItem.properties 已在库中；样书含全屏章节
- **D1 数据结构扩展**
  - 在 B2 定义的 `SpineItem` 增加 `isFullScreen`、`properties` 字段
  - 数据迁移策略（老数据默认 false）
  - 验收：旧数据升级不崩溃，新导入可正确标记
- **D2 导入阶段标记**
  - 解析 OPF `spine itemref.properties`，识别 `duokan-page-fullscreen`
  - 将结果落库，并缓存一个 `fullScreenChapterIds` 索引
  - 验收：样书调试日志可见标记列表
- **D3 阅读时切换策略**
  - 进入章节时检查 `isFullScreen`，触发渲染模式切换
  - 验收：全屏章节图片充满屏幕，普通章节不受影响

#### 工作流 E：CSS 注入管线
- **Owner/批次**：Solo Dev · Backlog
- **关键依赖**：工作流 D 标记数据、WKWebView 注入接口
- **E1 CSSRegistry 抽象**
  - 提供 `registerGlobal`, `register(forSpine:)`, `activate(forSpine:)`
  - 存储策略：内存缓存 + 轻量持久化（方便调试）
  - 验收：运行时切换章节不重复注入
- **E2 注入与移除机制**
  - 封装 WKWebView `userContentController` 管理脚本
  - 避免内存泄漏：切章时移除旧脚本
  - 验收：连续切换 10 次章节无脚本堆积
- **E3 全屏/全局样式实现**
  - 全局 CSS（脚注列表隐藏、基础排版）
  - 全屏 CSS（背景黑、图片居中等）
  - 验收：可通过调试开关独立启用/禁用

### v0.3 脚注弹窗兼容

#### 工作流 F：脚注基础设施
- **Owner/批次**：Solo Dev · Backlog
- **关键依赖**：CSS 注入框架、Navigator 消息通道
- **F1 FootnoteMessage 通道**
  - 定义 `WKScriptMessageHandler`，白名单 `footnote`
  - 验收：接收到 JS 事件，反序列化安全
- **F2 FootnoteSheet UI**
  - SwiftUI/UIViewController 弹层，支持滚动、复制
  - 模板样式适配浅/深色
  - 验收：标准 `noteref` 能正确显示

#### 工作流 G：多看脚注
- **Owner/批次**：Solo Dev · Backlog
- **关键依赖**：工作流 F 消息通道、样书脚注集合
- **G1 DOM 解析映射（可选增强）**
  - 使用 SwiftSoup 抓取 `ol.duokan-footnote-content`，构建章节内映射表
  - 缓存策略：随章节释放
  - 验收：有映射时，脚注弹层内容完整
- **G2 JS 拦截实现（必做）**
  - 注入脚注 JS（参考主计划），处理 `.duokan-footnote`、`img.zhangyue-footnote`
  - 防御：空内容、重复点击
  - 验收：多看/掌阅样书点击均弹层
- **G3 手动回归**
  - 测试用例：长文本、嵌套标签、图片脚注
  - 记录兼容性差异，准备 FAQ

### v0.4 阅读体验增强

#### 工作流 H：字体映射
- **Owner/批次**：Solo Dev · Backlog
- **关键依赖**：CSSRegistry 全局注入能力、字体许可评估
- **H1 字体别名清单**
  - 收集多看常用别名（Songti、Heiti、FangSong、KaiTi 等）
  - 建议表格：别名 → 系统字体 → 备用字体
  - 验收：表格归档在 `Resources/Fonts/README.md`
- **H2 @font-face 注入**
  - 通过 CSSRegistry 全局注入 @font-face
  - 如需内置字体：确认版权 & 体积，放入 bundle
  - 验收：样书查看字体变更前后截图
- **H3 字体降级策略**
  - 检测系统缺字时 fallback 至 Noto Sans CJK/苹方
  - 验收：使用缺少楷体的模拟器验证展示可接受

#### 工作流 I：基础阅读设置
- **Owner/批次**：Solo Dev · Backlog
- **关键依赖**：Readium UserSettings 接口、工作流 H 字体策略
- **I1 设置面板 UI**
  - SwiftUI 面板：字号 ±，行距（可选），主题切换
  - 验收：阅读页面可呼出面板，操作顺滑
- **I2 Readium UserSettings 封装**
  - 对接 `UserSettings` / `Preferences`，同步到 Navigator
  - 处理主题与自定义 CSS 优先级
  - 验收：设置立即生效，无闪烁
- **I3 持久化与同步**
  - 设置保存到 `UserDefaults` 或 `Book` 级别
  - 考虑多书籍差异：每本书独立 vs 全局
  - 验收：重启应用后保持上次配置

### v0.5 LCP DRM 最小闭环

#### 工作流 J：LCP 集成
- **Owner/批次**：Solo Dev · Backlog
- **关键依赖**：ReadiumLCP 依赖、发行侧凭证流程
- **J1 依赖与启动配置**
  - 引入 `ReadiumLCP`，配置许可证服务器 URL（如需）
  - 验收：普通 EPUB 不受影响
- **J2 凭证管理**
  - UI：输入/粘贴 passphrase，缓存成功凭证
  - 错误提示：凭证错误、过期、失效
  - 验收：官方 LCP 样书可成功解密
- **J3 异常流程与日志**
  - 无凭证：提示引导
  - DRM 不支持：明确错误文案
  - 日志：记录解密失败原因，方便支援

## 跨里程碑支撑任务
- **测试资产管理**：维护样书清单（标准 EPUB、多看、掌阅、LCP）；放置到 `Resources/Samples/`
- **调试工具**：可选制作隐形调试面板（切换 CSS 注入、查看定位器 JSON）
- **性能/内存基线**：记录导入与阅读时的内存峰值，避免后续退化
- **可观察性**：确定日志分类与上报策略，为未来 crash 分析留钩子

## 推荐执行节奏
1. 按 A → B → C 顺序完成 v0.1 工作流，使用 Checklist 保证无漏项。
2. v0.1 提交后复盘轻量存储实现，整理未来数据库替换所需接口与数据迁移计划。
3. 每个里程碑结束前预留半天回归样书，记录兼容性差异并更新 backlog 优先级。
