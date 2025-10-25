---
layout: default
title: Support
permalink: /support
description: Get help with Aria Shaw's guides and products. Email support and FAQ for Odoo self-hosting.
---

# Support

## How We Help

Support is provided via **email only**: [aria@ariashaw.com](mailto:aria@ariashaw.com)

We don't offer phone support, but email ensures:
- Detailed, thoughtful responses
- Code snippets and screenshots when needed
- Asynchronous communication (no time zone hassles)

---

## Before You Email

### For Free Guides

All free guides are provided as-is. Before emailing:

1. **Read the full guide carefully** (most answers are already there)
2. **Check the troubleshooting section** (common issues covered)
3. **Search existing GitHub issues** (if the guide has a repo)

If you're still stuck, email us with:
- Which guide you're following
- What step you're on
- Error messages (full output, not just "it doesn't work")
- Your environment (OS, Odoo version, server specs)

---

## For Purchased Products

### What's Included

When you purchase the **Odoo Digital Sovereignty Master Pack** or other products, you get:

- ✅ **Email support** for clarification questions
- ✅ **Bug fixes** if scripts have errors
- ✅ **Guidance** on using the tools correctly
- ✅ **Lifetime updates** (no additional cost)

### What's NOT Included

- ❌ **Consulting services** (we provide tools, you execute)
- ❌ **Server setup** done for you
- ❌ **Emergency hotline** (we're solo, not 24/7)
- ❌ **Guaranteed response time** (usually within 48 hours)

### How to Get Help

Email [aria@ariashaw.com](mailto:aria@ariashaw.com) with:

**Subject Line**: `[Product Name] - Brief Issue`

**Email Body**:
```
Order Number: [from Gumroad]
Product: [Master Pack / specific module]
Issue: [clear description]

What I'm trying to do:
[explain your goal]

What I've tried:
[steps you've already taken]

Error or unexpected behavior:
[paste error messages, logs]

Environment:
- OS: [Ubuntu 24.04 / Debian 12 / etc.]
- Odoo Version: [17.0 / 18.0 / etc.]
- Server: [AWS EC2 t3.medium / VPS / etc.]
```

**Response Time**: Usually within 24-48 hours (longer on weekends).

---

## Frequently Asked Questions

### Product Questions

**Q: Can I get a refund?**
A: Yes. 30-day money-back guarantee, no questions asked. Email with your order number.

**Q: Do I need to know Linux to use the guides?**
A: Basic command-line skills help, but guides are written for builders, not sysadmins. We explain the "why" behind every command.

**Q: Can I share the product with my team?**
A: Yes, within your organization. Don't post publicly or resell.

**Q: Do the scripts work on Windows?**
A: Scripts are written for Linux servers (Ubuntu/Debian). Windows users need WSL or a Linux VM.

---

### Technical Questions

**Q: My Odoo migration failed. Can you fix it?**
A: We provide guidance on using the scripts correctly, but can't debug your specific environment remotely. Follow the migration guide step-by-step, use the risk assessor script, and test in staging first.

**Q: The backup script isn't working. Help!**
A: Email us with the full error output and your config file (redact sensitive info). We'll debug the script.

**Q: Can you review my Odoo architecture design?**
A: Quick questions are fine (e.g., "Is t3.medium enough for 50 users?"). Full architecture reviews are consulting work (not included).

**Q: I need this done by tomorrow. Can you do it for me?**
A: No. These are DIY toolkits. If you need consulting, hire a firm (or email us for a quote, but it won't be $699).

---

### Free Guide Questions

**Q: The guide says X, but I'm seeing Y. Why?**
A: Versions change, cloud providers update UIs, and configurations vary. Email us with specifics, and we'll update the guide if needed.

**Q: Can you add a section about [specific topic]?**
A: Maybe! We prioritize based on demand. Email your suggestion—if others ask for it too, it gets added.

**Q: Can I translate your guide?**
A: Yes, with attribution and a link back. Don't claim it as your own work.

---

## Report Issues

### Found a Bug in a Script?

Email: [aria@ariashaw.com](mailto:aria@ariashaw.com)
Subject: `[Bug Report] Script Name - Brief Description`

Include:
- Script name and version
- Expected behavior vs. actual behavior
- Full error output
- Your environment

We fix bugs fast—usually within a week.

---

### Broken Link or Typo in Guide?

Small fixes like typos or outdated screenshots:

- Email us, or
- Open a GitHub issue (if the guide has a repo)

We appreciate the help in keeping content accurate.

---

## Feature Requests

Want a new guide, script, or calculator?

Email: [aria@ariashaw.com](mailto:aria@ariashaw.com)
Subject: `[Feature Request] Brief Description`

We can't build everything, but popular requests get prioritized.

---

## Emergency? Here's What to Do

### Production Down Right Now?

1. **Check Odoo logs**: `/var/log/odoo/odoo-server.log`
2. **Check PostgreSQL**: `sudo systemctl status postgresql`
3. **Check disk space**: `df -h`
4. **Restart Odoo**: `sudo systemctl restart odoo`

If you followed our guides, check the **troubleshooting section** of the relevant guide.

Email us, but don't expect instant replies—we're solo, not a 24/7 support team.

---

## Community

We're building a quiet corner of the internet, not a bustling forum.

- **No Discord server** (too much noise)
- **No Slack channel** (too many notifications)
- **No Facebook group** (privacy nightmare)

Just solid guides, reliable scripts, and email support when you need it.

---

## Can't Find an Answer?

Email: **aria@ariashaw.com**

We're here to help. Just remember:
- We provide tools and guidance, not done-for-you services
- Detailed questions get detailed answers
- Patience appreciated (solo operation, no support team)

Let's build something robust together.
