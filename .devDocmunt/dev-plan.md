
---

# LeafReader 开发任务清单（v0.1–v0.4）

## v0.1 基础导入与直读（Import → Library → Reader）

### 0. 启动与依赖（已完成/核验）

* **目标**：确认 SPM 依赖完整可编译运行
* **依赖建议**：`ReadiumShared`, `ReadiumStreamer`, `ReadiumNavigator`, （后续）`ReadiumLCP`, `SwiftSoup`
* **验收标准**

  * 工程可编译运行，能创建基本的 `ReaderView`（先空壳）。

---

### 1. 文件导入入口页（Document Picker）

* **目标**：用户从系统“文件”App选择 `.epub` 并导入到应用沙盒，然后进入阅读
* **涉及**：`UIDocumentPickerViewController`（UIKit）或 `DocumentPicker`（SwiftUI 包装），`UniformTypeIdentifiers.UTType(filenameExtension: "epub")`
* **实施要点**

  1. **Info.plist**

     * `UISupportsDocumentBrowser = YES`（如使用 `UIDocumentBrowserViewController` 方案）
     * 或配置 `CFBundleDocumentTypes` 接受 MIME `application/epub+zip` / 扩展名 `.epub`
  2. **选择文件 → 拷贝到沙盒**（如 `/Documents/Library/<bookId>/source.epub`）

     * 生成 `bookId`（可用 `UUID` 或基于文件hash）
     * 校验文件大小/后缀
  3. **导入后立即走解析流程**（见任务2）
* **验收标准**

  * 从“文件”App选择 `.epub` 后，应用能接收并在本地创建存储目录
  * 失败（权限/空间不足/格式不符）有用户可理解的提示
* **测试**

  * 大文件/小文件/同名文件覆盖策略
  * iCloud 文件（需要下载到本地）
  * 重复导入时合并/覆盖策略

---

### 2. 解析与入库（Readium Streamer + 本地书库）

* **目标**：使用 Readium 解析 Publication，写入本地“书库”（元数据、封面、spine 索引等）
* **涉及**：`Streamer.open(asset:)`、`Publication`、`Cover`、本地存储（`CoreData`/`SQLite`/`Realm` 任一）
* **实施要点**

  1. **解析**：

     * 用 `FileAsset` 指向本地 `.epub`
     * `Streamer().open(asset:)` → `Publication`
     * 读取 `metadata.title`, `metadata.authors`, `readingOrder`（spine）
  2. **封面提取**：优先 Publication 的 cover 链接；若无，则从 manifest/资源中寻找常见封面路径
  3. **书库表结构建议**

     * `Book(id, title, authors, filePath, coverPath, createdAt, updatedAt, lastReadLocatorJSON)`
     * `SpineItem(id, bookId, href, type, properties)`（用于后续“全屏章头”识别）
  4. **入库写入**：落地 JSON/DB，缓存封面 PNG（便于书架展示）
* **验收标准**

  * 成功打开多本 EPUB 并在“书库数据源”中可见（可先做简单列表页展示）
* **测试**

  * 元数据缺失/封面缺失
  * `readingOrder` 混合 HTML/图片资源

---

### 3. 立即阅读（EPUB Navigator）

* **目标**：从导入成功 → 打开阅读器，支持基本翻页/滚动、目录跳转、进度保存
* **涉及**：`EPUBNavigatorViewController` 或 SwiftUI 包装、`NavigatorDelegate`
* **实施要点**

  1. **初始化 Navigator**：传入 `Publication` + `initialLocation`
  2. **跳转目录 TOC**：`publication.tableOfContents` → 侧边/弹出目录
  3. **阅读位置保存**：监听 `currentLocation`（`Locator`），序列化为 JSON 存入 `Book.lastReadLocatorJSON`
  4. **主题/字号等基础设置**：先保持默认（v0.2 再扩展）
* **验收标准**

  * 能从导入页直接进入阅读器，关闭后再次打开可恢复到上次位置
* **测试**

  * 目录/锚点跳转有效
  * 横竖屏、暗黑模式不崩溃

---

## v0.2 自定义渲染（全屏章头 + 基础 CSS 注入）

### 4. 识别多看全屏章节（`duokan-page-fullscreen`）

* **目标**：识别 OPF spine 上 `properties="duokan-page-fullscreen"` 的章节，切换“全屏插图模式”
* **涉及**：入库阶段解析 OPF Spine 属性；阅读时按章节切换渲染策略
* **实施要点**

  1. **入库时**：抓取 spine item 的 `properties`，标记 `isFullScreen = true`
  2. **阅读时**：当进入 `isFullScreen` 章节，注入“全屏图片 CSS”（见任务5）
* **验收标准**

  * 标记章节进入时，图片可充满屏幕（保持纵横比），背景可设为黑色，隐藏多余边距
* **测试**

  * 单图/多图/有文字的异常情况处理（只对纯图章启用）

---

### 5. CSS 注入管线（User CSS 管理）

* **目标**：为不同场景注入 CSS（全局/按章节），且不修改源文件
* **涉及**：`WKUserScript` 或 Readium 暴露的 CSS 注入机制
* **实施要点**

  * **全局 CSS**：基础排版（比如隐藏多看脚注列表 `ol.duokan-footnote-content { display:none !important; }`）
  * **全屏章头 CSS**（进入特定 spine 才注入/启用）：

    ```css
    html,body { margin:0; background:#000; }
    img { display:block; width:100vw; height:100vh; object-fit:contain; }
    ```
  * 设计一个 `CSSRegistry`：

    * `registerGlobal(cssString)`
    * `registerForSpine(id: String, cssString)`
    * `enable/disable` 随章节切换调用
* **验收标准**

  * 能有选择地为章节注入/撤销样式，切章不卡顿
* **测试**

  * 连续切换全屏章头与普通章
  * 暗黑模式/横屏的兼容性

---

## v0.3 脚注弹窗兼容（多看 & 掌阅）

### 6. Navigator 脚注代理与弹窗 UI

* **目标**：统一脚注交互为“点击图标→弹出浮层”，支持 HTML 富文本
* **涉及**：`NavigatorDelegate`（脚注/导航拦截）、`SwiftSoup`、自定义 `FootnoteSheet`
* **实施要点**

  1. 实现 `shouldNavigateToNoteAt:content:referrer:`（或对应脚注回调）
  2. 将 `content(HTML)` 渲染到自定义弹层（`UIViewController` / SwiftUI `.sheet`）
  3. 支持复制/滚动/关闭；样式遵循系统外观
* **验收标准**

  * 标准 `epub:type="noteref"` 的脚注点击后弹层展示正确
* **测试**

  * 长脚注、嵌套标签、图片/链接

---

### 7. 多看脚注预处理（A 方案：导入时修正）

* **目标**：将 `<a class="duokan-footnote" href="#df-1">` 等转为标准 noteref 或可被代理识别
* **涉及**：导入后对资源进行**只读解析 + 运行时映射**（不直接改源文件）
* **实施要点**

  * **映射表**（内存或缓存）：

    * 按 spine：`anchorId -> extractedHTML`
  * **提取算法**：

    * 解析章 DOM，找到章末 `ol.duokan-footnote-content > li#df-1` 的内部 HTML
    * 写入映射
  * **运行时拦截**：

    * 对 `.duokan-footnote` 点击（见任务8 JS）返回映射中的 HTML，显示弹层
* **验收标准**

  * 不改源 EPUB 文件即可弹出多看脚注
* **测试**

  * 多个脚注、跨章锚点、缺失内容容错

---

### 8. 运行时 JS 拦截（B 方案：无需预处理）

* **目标**：对 `.duokan-footnote` 与 `img.zhangyue-footnote` 绑定点击→通过 `WKScriptMessageHandler` 将文本传回原生
* **涉及**：`WKUserScript`、`window.webkit.messageHandlers["footnote"].postMessage(...)`
* **实施要点**

  * 页面 `DOMContentLoaded`：

    * 选择器 `.duokan-footnote`：解析其 `href` 取 `#id`，在 DOM 中 `getElementById(id)` 抓取 HTML
    * 选择器 `img.zhangyue-footnote`：读取 `zy-footnote` 或 `alt`
    * `postMessage({ type:"footnote", html: "<p>...</p>" })`
  * 原生侧统一弹层展示
* **验收标准**

  * 无需改 EPUB，点击即弹
* **测试**

  * 消息通道多次触发、内存释放、切章后重复绑定

> 实战建议：优先实现 **JS 拦截（任务8）**，落地快、覆盖面广；后续再补 **预处理映射（任务7）** 提升健壮性与离线渲染一致性。

---

## v0.4 字体映射与基础阅读设置

### 9. 字体映射（多看别名 → 系统/内置字体）

* **目标**：兼容多看 CSS 中如 `"DK-SONGTI"`, `"DK-KAITI"` 等别名
* **涉及**：全局注入 `@font-face`
* **实施要点**

  * 在全局 CSS 注入：

    ```css
    @font-face { font-family: "DK-SONGTI"; src: local("Songti SC"), local("STSong"); }
    @font-face { font-family: "DK-KAITI";  src: local("Kaiti SC"), local("STKaiti"); }
    /* …其他别名… */
    ```
  * 如需内置字库：将 `.ttf/.otf` 放入 bundle，并用相对 URL 作为 `src: url("...")`
  * 不支持用户切换（本期），仅保证“看起来对”
* **验收标准**

  * 常见样章能以接近多看的字形显示
* **测试**

  * 系统缺字回退、粗斜体合成效果

---

### 10. 基础阅读设置（ReadiumCSS 开关）

* **目标**：字号、行距、页边、主题（浅/深）设置可用；保留为下期可扩展
* **涉及**：Readium 的用户设置 API（`UserSettings` / `Preferences`）
* **实施要点**

  * 暴露一个简单设置面板：字号 ±、主题切换
  * 设置持久化到 `Book` 或全局偏好
* **验收标准**

  * 改变设置后立即生效，重启应用仍保留
* **测试**

  * 与自定义 CSS 冲突排查（优先级控制）

---

## v0.5（并行可做）：DRM（LCP）接入最小闭环

### 11. LCP 支持（可读/可报错）

* **目标**：对于 LCP 加密 EPUB，可输入/获取凭证后正常解密阅读；不支持的 DRM 清晰提示
* **涉及**：`ReadiumLCP`、许可证解析、错误提示
* **实施要点**

  * 在 `Streamer.open` 前检测/包装 LCP 资产
  * UI：需要凭证时弹窗输入/或账号获取
* **验收标准**

  * LCP 样书可读；非 LCP 私有 DRM 有明确提示
* **测试**

  * 凭证错误/过期、离线打开

---

# 代码骨架（关键片段示例）

> **Document Picker（SwiftUI）**

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var isPickerPresented = false

    var body: some View {
        VStack {
            Button("导入 EPUB") { isPickerPresented = true }
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [UTType(filenameExtension: "epub")!],
            allowsMultipleSelection: false
        ) { result in
            guard let url = try? result.get().first else { return }
            ImportCoordinator.shared.handleImportedEPUB(at: url)
        }
    }
}
```

> **解析 & 入库骨架**

```swift
final class ImportCoordinator {
    static let shared = ImportCoordinator()

    func handleImportedEPUB(at srcURL: URL) {
        let bookId = UUID().uuidString
        let dstDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Library/\(bookId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true)
        let dstURL = dstDir.appendingPathComponent("source.epub")

        try? FileManager.default.removeItem(at: dstURL)
        try? FileManager.default.copyItem(at: srcURL, to: dstURL)

        EPUBParser.shared.openPublication(from: dstURL) { result in
            switch result {
            case .success(let pub):
                LibraryStore.shared.insert(bookId: bookId, publication: pub, fileURL: dstURL)
                ReaderRouter.open(bookId: bookId, initialLocator: nil)
            case .failure(let error):
                AlertCenter.show("导入失败：\(error.localizedDescription)")
            }
        }
    }
}
```

> **CSS/JS 注入（示意）**

```swift
final class InjectionCenter {
    static let shared = InjectionCenter()

    // 全局 CSS（隐藏多看脚注列表、基础排版）
    let globalCSS = """
    ol.duokan-footnote-content { display:none !important; }
    """

    // 全屏章头 CSS
    let fullscreenCSS = """
    html,body { margin:0; background:#000; }
    img { display:block; width:100vw; height:100vh; object-fit:contain; }
    """

    // 脚注 JS：拦截多看/掌阅点击
    let footnoteJS = """
    document.addEventListener('DOMContentLoaded', function() {
      function postFootnote(html) {
        try { window.webkit.messageHandlers.footnote.postMessage({type:'footnote', html}); } catch(e) {}
      }
      document.querySelectorAll('a.duokan-footnote').forEach(function(a){
        a.addEventListener('click', function(e){
          e.preventDefault();
          var id = (a.getAttribute('href')||'').replace('#','');
          var li = document.getElementById(id);
          if (li) postFootnote(li.innerHTML);
        });
      });
      document.querySelectorAll('img.zhangyue-footnote').forEach(function(img){
        img.style.cursor = 'pointer';
        img.addEventListener('click', function(){
          var txt = img.getAttribute('zy-footnote') || img.getAttribute('alt') || '';
          postFootnote(txt);
        });
      });
    });
    """
}
```

> **Navigator 挂载注入（示意）**

```swift
func configure(webView: WKWebView, forSpine isFullscreen: Bool) {
    let userContent = webView.configuration.userContentController
    userContent.removeAllUserScripts()
    userContent.addUserScript(WKUserScript(source: InjectionCenter.shared.globalCSS.asStyleTag(),
                                          injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    userContent.addUserScript(WKUserScript(source: InjectionCenter.shared.footnoteJS,
                                          injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    if isFullscreen {
        userContent.addUserScript(WKUserScript(source: InjectionCenter.shared.fullscreenCSS.asStyleTag(),
                                              injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }
}
private extension String {
    func asStyleTag() -> String { "<style>\(self)</style>" }
}
```

---

# 工程结构建议

```
LeafReader/
 ├── App/ (入口、路由)
 ├── Features/
 │   ├── Import/ (DocumentPicker, ImportCoordinator)
 │   ├── Library/ (列表、封面缓存、LibraryStore)
 │   ├── Reader/
 │   │   ├── NavigatorHost (Readium 集成)
 │   │   ├── Injection (CSS/JS 管线)
 │   │   └── Footnote (弹层 UI, handler)
 │   └── Settings/ (v0.4)
 ├── Core/
 │   ├── Persistence/ (DB/文件系统)
 │   ├── Models/ (Book, SpineItem, Locator)
 │   └── DRM/ (LCP v0.5)
 └── Resources/ (内置字体、图标、全局CSS)
```

---

# 风险与注意事项

* **不同厂商私有 CSS/JS 差异**：优先覆盖“多看 + 掌阅”路径，保持注入逻辑解耦，便于将来扩展其他平台。
* **性能**：频繁切章时谨慎重复注入；为不同章节做轻量开关（启用/禁用）而非堆叠脚本。
* **可维护性**：所有注入内容（CSS/JS）集中管理（版本化、注释），加单元测试（对 HTML 片段的解析/提取）。
* **安全性**：`WKScriptMessageHandler` 只暴露白名单通道；对 HTML 内容进行最小可信渲染（富文本时防脚本）。

---

# 里程碑与验收概览

* **v0.1**：导入 → 解析入库 → 立即阅读（可恢复进度）
* **v0.2**：全屏章头识别 + CSS 注入管线
* **v0.3**：脚注弹窗（标准 + 多看/掌阅）
* **v0.4**：字体映射 + 基础阅读设置
* **v0.5**：LCP DRM 最小闭环（可后置并行）

---

