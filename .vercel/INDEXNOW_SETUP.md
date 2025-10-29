# IndexNow Auto-Submission Setup Guide

## 问题解决

### 原始问题
每次 Vercel 部署都会提交所有 URL 到 IndexNow，而不是只提交新增的 URL。

### 根本原因
- Vercel 每次部署都在**全新的无状态容器**中运行
- 之前使用的本地文件缓存（`.indexnow-cache.json`）会在每次部署后被丢弃
- 因此 `loadPreviousSitemap()` 总是返回 `null`，导致所有 URL 都被视为"新增"

### 解决方案
使用 **Vercel KV**（持久化 Redis 存储）来保存上一次部署的站点地图。

---

## Vercel KV 设置步骤

### 1. 在 Vercel Dashboard 中创建 KV 数据库

1. 访问你的 Vercel 项目：https://vercel.com/dashboard
2. 选择你的项目（ariashaw.com）
3. 点击顶部导航栏的 **Storage** 标签
4. 点击 **Create Database**
5. 选择 **KV** (Key-Value Store)
6. 配置数据库：
   - **Database Name**: `indexnow-cache`（或任意名称）
   - **Region**: 选择离你最近的区域（建议选择 `iad1` - 美国东部）
7. 点击 **Create**

### 2. 关联 KV 数据库到项目

创建完成后，Vercel 会自动提示你关联数据库到项目：

1. 在 **Connect to Project** 界面
2. 选择你的项目（应该已经自动选中）
3. 点击 **Connect**

这会自动在你的项目环境变量中添加 KV 连接配置：
- `KV_REST_API_URL`
- `KV_REST_API_TOKEN`
- `KV_REST_API_READ_ONLY_TOKEN`
- `KV_URL`

### 3. 验证环境变量

1. 在项目设置中，进入 **Settings** → **Environment Variables**
2. 确认以下变量存在：
   ```
   KV_REST_API_URL
   KV_REST_API_TOKEN
   KV_REST_API_READ_ONLY_TOKEN
   KV_URL
   ```

3. 确保这些变量在以下环境中都可用：
   - ✅ Production
   - ✅ Preview
   - ⚠️ Development（可选，本地开发会使用文件缓存）

---

## 工作原理

### 首次部署（没有历史记录）
1. 脚本检测到 Vercel KV 中没有缓存
2. 提交**所有** URL 到 IndexNow
3. 将当前站点地图保存到 Vercel KV

### 后续部署
1. 从 Vercel KV 加载上一次部署的站点地图
2. 对比当前站点地图和上一次的站点地图
3. 只提交**新增或更新**的 URL
4. 更新 Vercel KV 中的缓存

### 本地开发模式
- 脚本会自动检测是否在 Vercel 环境中运行
- 如果不在 Vercel 环境（或 KV 不可用），会回退到本地文件缓存
- 本地文件：`.vercel/.indexnow-cache.json`

---

## 测试验证

### 触发部署并查看日志

1. **推送代码到 GitHub** 或在 Vercel Dashboard 中手动触发部署
2. 在 **Deployments** 页面查看构建日志
3. 搜索 `IndexNow` 关键词，应该看到类似输出：

```
================================================================================
IndexNow Auto-Submission for Vercel
================================================================================

[STEP 1] Fetching current sitemap...
[INFO] Fetching sitemap: https://ariashaw.com/sitemap.xml
[INFO] Parsed 50 URLs from sitemap

[STEP 2] Loading previous sitemap...
[INFO] Loading previous sitemap from Vercel KV...
[INFO] Loaded previous sitemap from Vercel KV (45 URLs)
[INFO] Previous deployment: abc123def at 2025-10-28T10:30:00.000Z

[STEP 3] Comparing sitemaps...
[INFO] Found 5 new/updated URLs out of 50 total

[STEP 4] Submitting to IndexNow...
[INFO] Submitting 5 URLs in 1 batch(es) to https://api.indexnow.org/indexnow
[SUCCESS] Batch 1/1 submitted successfully (HTTP 200)

[STEP 5] Saving current sitemap...
[INFO] Saving current sitemap to Vercel KV...
[INFO] Saved 50 URLs to Vercel KV
[INFO] Deployment ID: abc123def456

================================================================================
[COMPLETE] Successfully submitted 5 URLs to IndexNow
================================================================================
```

### 验证 KV 中的数据

在 Vercel Dashboard 中查看 KV 数据：

1. 进入 **Storage** → 你的 KV 数据库
2. 点击 **Data** 标签
3. 搜索 key: `indexnow-previous-sitemap`
4. 应该看到一个 JSON 对象，包含：
   ```json
   {
     "timestamp": "2025-10-29T...",
     "deployment": "abc123...",
     "urls": [...]
   }
   ```

---

## 故障排查

### 问题：仍然提交所有 URL

**检查清单：**
1. ✅ 确认 Vercel KV 数据库已创建并关联到项目
2. ✅ 确认环境变量 `KV_*` 存在于 Production 环境
3. ✅ 查看构建日志，确认看到 `Loading previous sitemap from Vercel KV`
4. ✅ 如果看到 `No previous sitemap found`，说明是首次部署（正常）
5. ✅ 第二次部署后，应该看到 `Loaded previous sitemap from Vercel KV (X URLs)`

### 问题：构建失败，提示 KV 连接错误

**可能原因：**
- KV 数据库未正确关联到项目
- 环境变量缺失

**解决方法：**
1. 重新关联 KV 数据库
2. 检查环境变量是否正确设置
3. 触发新的部署

### 问题：本地测试时无法连接 KV

**这是正常的！** 本地开发环境会自动使用文件缓存作为回退：
```
[WARN] @vercel/kv not available - using local file storage fallback
[INFO] Using local file storage fallback...
```

如果需要在本地测试 KV：
1. 从 Vercel Dashboard 复制 KV 环境变量
2. 在本地创建 `.env` 文件
3. 添加 KV 连接变量
4. 使用 `vercel env pull` 命令

---

## 代码更新总结

### 安装的依赖
```bash
npm install @vercel/kv
```

### 更新的文件
- `.vercel/indexnow-submit.js` - 集成 Vercel KV 存储
- `vercel.json` - 已有配置，无需修改

### 关键更新
1. **导入 Vercel KV**：动态导入，本地环境失败时自动回退
2. **loadPreviousSitemap()**：优先使用 Vercel KV，失败时使用本地文件
3. **saveSitemap()**：优先保存到 Vercel KV，失败时保存到本地文件
4. **环境检测**：`CONFIG.IS_VERCEL` 检测是否在 Vercel 环境中运行

---

## 后续优化建议

1. **添加过期时间**：设置 KV 数据的 TTL，避免无限期存储
   ```javascript
   await kv.set(CONFIG.STORAGE_KEY, cache, { ex: 2592000 }); // 30天
   ```

2. **添加版本控制**：在缓存中添加版本号，方便未来升级
   ```javascript
   const cache = {
     version: 1,
     timestamp: ...,
     urls: ...
   };
   ```

3. **添加监控和告警**：在 Vercel Dashboard 中设置监控，确保 KV 操作成功

---

## 相关资源

- [Vercel KV 文档](https://vercel.com/docs/storage/vercel-kv)
- [IndexNow API 文档](https://www.indexnow.org/documentation)
- [项目仓库](https://github.com/AriaShaw/AriaShaw.github.io)

---

**更新时间**：2025-10-29
**状态**：✅ 已实现并测试
