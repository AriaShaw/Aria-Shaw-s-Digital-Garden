# IndexNow Auto-Submission for Vercel Deployments

## 概述

这个系统在每次 Vercel 部署成功后自动向 IndexNow API 提交新增或更新的 URL，通知搜索引擎（Bing、Yandex等）索引你的内容。

**关键特性**：
- ✅ **智能比对**：只提交新增或更新的 URL
- ✅ **初次全量提交**：首次部署时提交全站 URL
- ✅ **错误恢复**：部署失败时使用上次成功的 sitemap
- ✅ **零成本**：不依赖第三方服务，纯 Node.js 脚本
- ✅ **批量提交**：支持最多 10,000 URLs/批次

## 架构设计

```
Vercel Deployment (Success)
         ↓
   Build完成后自动运行
         ↓
   indexnow-submit.js
         ↓
1. 获取当前 sitemap.xml
2. 与上次 sitemap 比对
3. 提取新增/更新 URL
4. 批量提交到 IndexNow
5. 保存当前 sitemap 作为基线
```

## 文件说明

### 1. `indexnow-submit.js`
主脚本，负责：
- 获取和解析 sitemap.xml
- 比对新旧 sitemap
- 提交到 IndexNow API
- 缓存 sitemap 基线

### 2. `deploy-succeeded.sh`
Vercel 部署钩子，在构建成功后自动触发 IndexNow 提交。

### 3. `.indexnow-cache.json`（自动生成）
存储上次成功部署的 sitemap 数据，用于下次比对。

**格式**：
```json
{
  "timestamp": "2025-10-28T10:30:00.000Z",
  "deployment": "abc123def456",
  "urls": [
    {
      "loc": "https://ariashaw.com/",
      "lastmod": "2025-10-28"
    }
  ]
}
```

## 部署步骤

### 步骤 1：配置 Vercel 环境变量

在 Vercel 项目设置中添加环境变量：

1. 进入 Vercel Dashboard → 你的项目 → Settings → Environment Variables
2. 添加以下变量：

| 变量名 | 值 | 作用域 |
|--------|-----|--------|
| `INDEXNOW_KEY` | `537e80460b3a4aa898514c845316796e` | Production, Preview, Development |
| `SITE_URL` | `https://ariashaw.com` | Production |
| `VERBOSE` | `true` （可选，用于调试） | Development |

### 步骤 2：验证 IndexNow Key 文件

确保根目录存在 IndexNow 验证文件：
```
537e80460b3a4aa898514c845316796e.txt
```

文件内容应为：
```
537e80460b3a4aa898514c845316796e
```

**验证方法**：
访问 `https://ariashaw.com/537e80460b3a4aa898514c845316796e.txt`，应返回你的 key。

### 步骤 3：配置 Vercel Build Command

`vercel.json` 已配置好，包括：
- 安装依赖：`npm install xml2js`
- 环境变量注入
- Sitemap 缓存头设置

### 步骤 4：部署后自动运行

**方案 A：使用 Vercel Deploy Hooks（推荐）**

在 `vercel.json` 中添加：
```json
{
  "build": {
    "env": {
      "INDEXNOW_KEY": "537e80460b3a4aa898514c845316796e"
    }
  }
}
```

然后在项目根目录创建 `package.json`：
```json
{
  "name": "ariashaw-site",
  "version": "1.0.0",
  "scripts": {
    "postbuild": "node .vercel/indexnow-submit.js"
  },
  "dependencies": {
    "xml2js": "^0.6.0"
  }
}
```

Vercel 会在 Jekyll 构建完成后自动运行 `postbuild` 脚本。

**方案 B：使用 Vercel CLI 手动触发**

部署后手动运行：
```bash
vercel env pull
node .vercel/indexnow-submit.js
```

**方案 C：使用 Vercel Cron Jobs（定时任务）**

在 `vercel.json` 中添加：
```json
{
  "crons": [
    {
      "path": "/api/indexnow",
      "schedule": "0 2 * * *"
    }
  ]
}
```

然后创建 `/api/indexnow.js` Serverless Function（见下文）。

## 自动化方案选择

### 方案对比

| 方案 | 触发时机 | 延迟 | 复杂度 | 推荐度 |
|------|---------|------|--------|--------|
| **postbuild 脚本** | 每次部署后 | 0秒 | 低 | ⭐⭐⭐⭐⭐ |
| Deploy Hook Webhook | 部署成功后 | 1-5秒 | 中 | ⭐⭐⭐⭐ |
| Cron Job | 定时（如每天2AM） | 最多24小时 | 中 | ⭐⭐⭐ |
| 手动触发 | 手动运行 | 按需 | 低 | ⭐⭐ |

**推荐：方案 A（postbuild 脚本）**

原因：
- ✅ 零延迟，部署完立即提交
- ✅ 无需额外配置 webhook 或 cron
- ✅ 在 Vercel 构建环境中运行，访问所有环境变量
- ✅ 支持初次全量提交逻辑

## 实现方案 A：postbuild 自动触发

### 1. 创建 `package.json`

在项目根目录创建：
```json
{
  "name": "ariashaw-digital-garden",
  "version": "1.0.0",
  "description": "Aria Shaw's Digital Garden - Odoo Implementation Guides",
  "private": true,
  "scripts": {
    "postbuild": "node .vercel/indexnow-submit.js"
  },
  "dependencies": {
    "xml2js": "^0.6.2"
  },
  "engines": {
    "node": ">=18"
  }
}
```

### 2. 更新 `vercel.json`

已完成！当前配置：
```json
{
  "buildCommand": "JEKYLL_ENV=production bundle exec jekyll build",
  "installCommand": "gem install bundler:2.3.26 && bundle install && npm install xml2js"
}
```

### 3. 测试部署

提交代码并推送到 GitHub：
```bash
git add .vercel/ package.json vercel.json
git commit -m "feat: Add IndexNow auto-submission on Vercel deployment"
git push origin main
```

**预期行为**：
1. Vercel 开始构建
2. Jekyll 构建 `_site/`
3. 运行 `npm run postbuild`（自动触发 `indexnow-submit.js`）
4. 脚本输出日志，显示提交的 URL 数量

### 4. 查看日志

在 Vercel Dashboard → Deployments → 你的部署 → Build Logs 中查看：
```
[INFO] Fetching sitemap: https://ariashaw.com/sitemap.xml
[INFO] Parsed 150 URLs from sitemap
[INFO] No previous sitemap found - treating as initial submission
[STEP 4] Submitting to IndexNow...
[SUCCESS] Batch 1/1 submitted successfully (HTTP 200)
[COMPLETE] Successfully submitted 150 URLs to IndexNow
```

## 手动测试（本地）

### 1. 设置环境变量

```bash
export SITE_URL="https://ariashaw.com"
export INDEXNOW_KEY="537e80460b3a4aa898514c845316796e"
```

Windows (PowerShell):
```powershell
$env:SITE_URL = "https://ariashaw.com"
$env:INDEXNOW_KEY = "537e80460b3a4aa898514c845316796e"
```

### 2. 安装依赖

```bash
npm install xml2js
```

### 3. 运行脚本

```bash
node .vercel/indexnow-submit.js
```

**预期输出**：
```
================================================================================
IndexNow Auto-Submission for Vercel
================================================================================

[STEP 1] Fetching current sitemap...
[INFO] Fetching sitemap: https://ariashaw.com/sitemap.xml
[INFO] Parsed 150 URLs from sitemap

[STEP 2] Loading previous sitemap...
[INFO] No previous sitemap found

[STEP 3] Comparing sitemaps...
[INFO] No previous sitemap found - treating as initial submission

[STEP 4] Submitting to IndexNow...
[INFO] Submitting 150 URLs in 1 batch(es) to https://api.indexnow.org/indexnow
[SUCCESS] Batch 1/1 submitted successfully (HTTP 200)

[STEP 5] Saving current sitemap...
[INFO] Saved 150 URLs to cache

================================================================================
[COMPLETE] Successfully submitted 150 URLs to IndexNow
================================================================================
```

## 工作流示例

### 首次部署（全量提交）

1. 用户推送代码到 GitHub
2. Vercel 开始构建
3. Jekyll 生成 sitemap.xml（150个URL）
4. `indexnow-submit.js` 运行：
   - 获取当前 sitemap（150个URL）
   - 检查缓存：无（首次部署）
   - **提交全部150个URL到 IndexNow**
   - 保存当前 sitemap 到 `.indexnow-cache.json`

### 后续部署（增量提交）

1. 用户添加5篇新文章，更新3篇旧文章
2. 推送到 GitHub，Vercel 构建
3. Jekyll 生成新 sitemap（158个URL）
4. `indexnow-submit.js` 运行：
   - 获取当前 sitemap（158个URL）
   - 加载上次缓存（150个URL）
   - **比对差异：8个新增/更新URL**
   - **仅提交这8个URL到 IndexNow**
   - 更新缓存为当前 sitemap

### 部署失败恢复

1. 用户推送有错误的代码
2. Vercel 构建失败（Jekyll报错）
3. `indexnow-submit.js` **不运行**（因为构建失败）
4. 缓存保持不变（仍然是上次成功的sitemap）
5. 用户修复错误，重新部署
6. 构建成功，脚本运行，正常提交新增URL

## 监控和调试

### 查看提交历史

IndexNow 不提供查询 API，但你可以通过以下方式验证：

1. **Bing Webmaster Tools**
   - 登录：https://www.bing.com/webmasters
   - 查看 "URL Inspection" 或 "Index Status"
   - 验证最近提交的URL是否被索引

2. **查看 Vercel 日志**
   - Vercel Dashboard → Deployments → Build Logs
   - 搜索 "IndexNow" 或 "submitted"

3. **本地缓存文件**
   - 检查 `.vercel/.indexnow-cache.json`
   - 查看上次提交的时间戳和URL列表

### 调试模式

设置 `VERBOSE=true` 环境变量启用详细日志：
```bash
export VERBOSE=true
node .vercel/indexnow-submit.js
```

输出示例：
```
[DEBUG] Batch 1/1: 8 URLs
[DEBUG] Payload: {"host":"ariashaw.com","key":"537e...","urlList":[...]}
[DEBUG] Response status: 200
[DEBUG] Response body: OK
```

## 故障排查

### 问题1：脚本未运行

**症状**：部署成功但没有 IndexNow 日志

**原因**：
- `package.json` 中没有 `postbuild` 脚本
- `vercel.json` 中 `installCommand` 没有安装 `xml2js`

**解决**：
```bash
# 确保 package.json 存在且有 postbuild
cat package.json | grep postbuild

# 确保 vercel.json 安装了依赖
cat vercel.json | grep "npm install xml2js"
```

### 问题2：401 Unauthorized

**症状**：`[ERROR] Batch 1/1 failed: HTTP 401`

**原因**：IndexNow key 不匹配或验证文件不存在

**解决**：
1. 验证 key 文件可访问：
   ```bash
   curl https://ariashaw.com/537e80460b3a4aa898514c845316796e.txt
   ```
   应返回：`537e80460b3a4aa898514c845316796e`

2. 检查环境变量：
   ```bash
   echo $INDEXNOW_KEY
   ```

### 问题3：No URLs to submit

**症状**：每次部署都显示 "No new URLs"

**原因**：sitemap 的 `<lastmod>` 日期没有更新

**解决**：
1. 检查 Jekyll 配置，确保生成正确的 lastmod：
   ```yaml
   # _config.yml
   plugins:
     - jekyll-sitemap
   ```

2. 手动清除缓存：
   ```bash
   rm .vercel/.indexnow-cache.json
   ```

### 问题4：Too Many Requests (429)

**症状**：`[ERROR] Batch 1/1 failed: HTTP 429`

**原因**：IndexNow API 有频率限制

**解决**：
- 减少批次大小（`MAX_URLS_PER_BATCH`）
- 增加批次间延迟（`BATCH_DELAY_MS`）

## 高级配置

### 支持多个搜索引擎

默认只提交到 `api.indexnow.org`（会自动分发到 Bing、Yandex 等）。

如需直接提交到特定搜索引擎，修改 `INDEXNOW_ENDPOINTS`：
```javascript
INDEXNOW_ENDPOINTS: [
  'https://api.indexnow.org/indexnow',  // 通用（推荐）
  'https://www.bing.com/indexnow',      // Bing 直接端点
  'https://yandex.com/indexnow',        // Yandex（如果需要）
],
```

### 使用 Vercel Blob 存储

替换文件缓存为 Vercel Blob（持久化存储）：

1. 安装依赖：
   ```bash
   npm install @vercel/blob
   ```

2. 修改 `indexnow-submit.js`：
   ```javascript
   const { put, get } = require('@vercel/blob');

   async function loadPreviousSitemap() {
     const blob = await get('indexnow-cache');
     return blob ? JSON.parse(blob.toString()) : null;
   }

   async function saveSitemap(urls) {
     await put('indexnow-cache', JSON.stringify({ urls, timestamp: new Date() }));
   }
   ```

### 过滤特定 URL

排除某些 URL 不提交（如测试页面）：
```javascript
function filterUrls(urls) {
  return urls.filter(url => {
    const loc = url.loc || url;
    return !loc.includes('/test/') && !loc.includes('/draft/');
  });
}

// 在 compareSitemaps 后调用
const urlsToSubmit = filterUrls(compareSitemaps(currentUrls, previousUrls));
```

## 性能优化

### 批量提交优化

- **小站点（< 100 URLs）**：单批次提交，延迟0ms
- **中型站点（100-1000 URLs）**：无需调整
- **大型站点（> 1000 URLs）**：
  - 设置 `MAX_URLS_PER_BATCH: 500`
  - 设置 `BATCH_DELAY_MS: 2000`（2秒间隔）

### 缓存策略

- **Vercel 部署**：使用 `.vercel/.indexnow-cache.json`
- **Vercel Blob**：持久化存储，跨部署保留
- **Vercel KV**：更快速的键值存储

## 成本分析

| 项目 | 成本 |
|------|------|
| IndexNow API | **免费** |
| Vercel 部署 | 免费额度足够 |
| Node.js 依赖 | 免费（xml2js） |
| 存储（file cache） | 0 字节成本 |
| 存储（Vercel Blob）| ~$0.001/月 |

**总成本：$0 /月**

## 维护清单

- [ ] 每月检查 Bing Webmaster Tools 索引状态
- [ ] 每季度验证 IndexNow key 文件可访问
- [ ] 每次大规模内容更新后查看提交日志
- [ ] 每半年清理一次 `.indexnow-cache.json`（可选）

## 参考资料

- [IndexNow 官方文档](https://www.indexnow.org/documentation)
- [Vercel Build Hooks](https://vercel.com/docs/concepts/git/deploy-hooks)
- [Vercel Environment Variables](https://vercel.com/docs/concepts/projects/environment-variables)
- [Jekyll Sitemap Plugin](https://github.com/jekyll/jekyll-sitemap)

## 支持

如有问题，请检查：
1. Vercel Build Logs
2. `.vercel/.indexnow-cache.json` 内容
3. `https://ariashaw.com/sitemap.xml` 可访问性
4. IndexNow key 验证文件
