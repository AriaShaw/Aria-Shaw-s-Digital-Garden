# GitHub Workflows

自动化工作流配置。

---

## IndexNow Auto Submit

**文件：** `indexnow-auto-submit.yml`

自动检测sitemap.xml中的URL变化并提交到IndexNow搜索引擎。

### 核心逻辑

**简单而精准：**
1. Build当前commit的Jekyll站点 → 提取sitemap.xml中的URL
2. Build上一个commit的Jekyll站点 → 提取sitemap.xml中的URL
3. 对比两个sitemap，找出新增的URL
4. 提交新增URL到IndexNow

**为什么只依赖sitemap？**
- ✅ sitemap.xml是唯一真相来源（包含所有应该被索引的页面）
- ✅ Jekyll自动生成，无需手动维护
- ✅ 已正确处理permalink、排除规则等配置
- ✅ 避免复杂的文件路径判断逻辑
- ✅ .gitignore的文件不会出现在sitemap中，无需额外排除

### 触发条件

**自动触发：**
```yaml
on:
  push:
    branches:
      - main
    paths:
      - '_posts/**'   # 博客文章
      - '*.md'        # 根目录markdown（README.md, toolkit.md等）
```

**手动触发：**
GitHub Actions → IndexNow Auto Submit → Run workflow

### Baseline文件

**文件：** `previous_urls.txt`

**用途：** 首次运行时的URL基准（避免提交所有已存在的URL）

**当前内容：** 9个URL
- 主页
- 5篇博客文章
- 3个toolkit页面

**何时使用：**
- 首次运行工作流时（`HEAD~1`不存在）
- previous commit的sitemap无法生成时

**维护：**
- 通常无需手动更新
- 如果手动添加了URL到sitemap（非git提交），可以更新此文件

---

## 配置步骤

### 1. 获取IndexNow API密钥

生成UUID格式的密钥：
```bash
# Linux/Mac
uuidgen | tr '[:upper:]' '[:lower:]'

# 在线工具
https://www.uuidgenerator.net/
```

示例：`a1b2c3d4-e5f6-7890-abcd-ef1234567890`

---

### 2. 添加GitHub Secret

1. GitHub仓库 → Settings → Secrets and variables → Actions
2. New repository secret
3. Name: `INDEXNOW_KEY`
4. Value: 你的API密钥
5. Add secret

---

### 3. 创建密钥验证文件

在**网站根目录**创建文件：`<你的密钥>.txt`

**内容：** 你的API密钥

**示例：**
```bash
echo "a1b2c3d4-e5f6-7890-abcd-ef1234567890" > a1b2c3d4-e5f6-7890-abcd-ef1234567890.txt
```

**验证：**
访问 `https://ariashaw.github.io/a1b2c3d4-e5f6-7890-abcd-ef1234567890.txt` 应返回你的密钥

---

### 4. 提交并推送

```bash
git add .github/workflows/
git add <你的密钥>.txt
git commit -m "Add IndexNow auto-submit workflow"
git push origin main
```

---

## 工作流输出示例

### 检测到新URL

```
✅ Extracting URLs from sitemap.xml...
Found 10 URLs

📋 Current URLs:
https://ariashaw.github.io/
https://ariashaw.github.io/new-article/
...

✅ Extracting URLs from previous sitemap.xml...
Found 9 URLs

📋 Previous URLs:
https://ariashaw.github.io/
...

📊 URL Changes Detected:
  - New URLs: 1
  - Deleted URLs: 0
  - To submit: 1

🔗 URLs to submit:
https://ariashaw.github.io/new-article/

🚀 Submitting 1 URLs to IndexNow...
  ✅ https://ariashaw.github.io/new-article/ (HTTP 200)

📈 Submission Summary:
  - Successful: 1
  - Failed: 0
  - Total: 1
```

---

### 无变化

```
✅ Extracting URLs from sitemap.xml...
Found 9 URLs

✅ Extracting URLs from previous sitemap.xml...
Found 9 URLs

📊 URL Changes Detected:
  - New URLs: 0
  - Deleted URLs: 0
  - To submit: 0

ℹ️  No new URLs to submit
```

---

## 查看结果

### 方法1：GitHub Actions Summary

Actions → 最新运行 → Summary

显示提交的URL列表

---

### 方法2：下载Artifact

Actions → 最新运行 → Artifacts → indexnow-report-xxxxx

包含：
- `indexnow_report.md` - 完整报告
- `urls_to_submit.txt` - 提交的URL
- `new_urls.txt` - 新增URL
- `deleted_urls.txt` - 删除URL

---

## 故障排查

### 问题1：INDEXNOW_KEY secret not set

**解决：** 按"配置步骤"添加GitHub Secret

---

### 问题2：提交失败 HTTP 403

**原因：** 密钥验证文件不可访问

**解决：**
1. 确认 `<你的密钥>.txt` 文件在根目录
2. 确认文件已提交并部署
3. 访问 `https://ariashaw.github.io/<你的密钥>.txt` 验证

---

### 问题3：提交失败 HTTP 429

**原因：** 请求过快

**解决：** 工作流已包含`sleep 1`延迟，如仍失败可增加到`sleep 2`

---

### 问题4：sitemap.xml not found

**原因：** Jekyll build失败

**解决：**
1. 检查Actions日志中的build错误
2. 本地运行 `bundle exec jekyll build` 测试
3. 确认`sitemap.xml`在项目根目录存在

---

## 支持的搜索引擎

提交到IndexNow API后，这些搜索引擎会自动收到通知：

- ✅ Microsoft Bing
- ✅ Yandex
- ✅ Seznam.cz
- ✅ Naver

**注意：** Google不支持IndexNow，需使用Google Search Console

---

**版本：** 2.0
**最后更新：** 2025-10-01
**维护者：** Aria Shaw
