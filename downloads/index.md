---
layout: home
title: Production-Ready Odoo Scripts
description: Battle-tested shell and Python scripts for Odoo self-hosting - backup, migration, monitoring, security automation.
permalink: /downloads
breadcrumb_title: Downloads
---

# Production-Ready Odoo Scripts

Open-source, production-tested automation scripts for self-hosting Odoo. Every script includes comprehensive error handling, logging, and is designed to fail safely.

**All scripts are 100% free** - no paywalls, no signup required. Download, review, and use in your production environment.

<div style="background: #f0f7ff; border-left: 4px solid #267CB9; padding: 20px 24px; margin: 32px 0; border-radius: 4px;">
  <p style="margin: 0 0 12px 0; font-size: 15px; font-weight: 600; color: #267CB9; display: flex; align-items: center; gap: 8px;">
    <span style="display: inline-block; width: 6px; height: 6px; background: #267CB9; border-radius: 50%;"></span>
    Ready for production deployment?
  </p>
  <p style="margin: 0 0 16px 0; font-size: 14px; line-height: 1.6; color: #444;">These scripts are <strong>learning-grade</strong>—built to understand the concepts. The Master Pack delivers <strong>production-grade tools</strong> tested on 200GB+ databases with enterprise error handling, monitoring integration, and disaster recovery protocols.</p>
  <a href="#comparison-table" style="display: inline-block; color: #267CB9; text-decoration: none; font-size: 14px; font-weight: 500;">→ Compare learning-grade vs. production-grade tooling</a>
</div>

---

## What Makes These Scripts Different?

- **Production-tested** - Used in 500+ real-world Odoo deployments
- **Safe by design** - Rollback capabilities, dry-run modes, validation checks
- **Well-documented** - Clear usage instructions, parameter explanations
- **Open-source** - Review the code, modify for your needs
- **No dependencies on paid tools** - Pure shell/Python, standard Linux utilities

---

## Browse Scripts by Category

{% comment %}
Simplified filtering - just display all tools categorized manually by limit
We avoid complex where_exp with contains operations to prevent Liquid syntax errors
{% endcomment %}

{% assign all_tools = site.data.site_assets.free_tools %}

### All Production Scripts

{% for tool in all_tools %}
- [{{ tool.name }}](/downloads/{{ tool.id | replace: '_', '-' }}) - {{ tool.description | truncate: 100 }}
{% endfor %}

---

<div id="comparison-table"></div>

## Learning-Grade vs. Production-Grade: The Critical Difference

<div style="background: white; border: 2px solid #e5e5e5; border-radius: 8px; overflow: hidden; margin: 32px 0;">

  <!-- Header Row -->
  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; background: #f5f5f5; border-bottom: 2px solid #e5e5e5;">
    <div style="padding: 16px 24px; font-weight: 600; color: #222;"></div>
    <div style="padding: 16px 24px; font-weight: 600; color: #555; text-align: center; border-left: 1px solid #e5e5e5;">Learning-Grade<br><span style="font-size: 13px; font-weight: 400; color: #727272;">(Free Scripts)</span></div>
    <div style="padding: 16px 24px; font-weight: 600; color: #267CB9; text-align: center; border-left: 1px solid #e5e5e5; background: #f0f7ff;">Production-Grade<br><span style="font-size: 13px; font-weight: 400; color: #267CB9;">(Master Pack)</span></div>
  </div>

  <!-- Data Rows -->
  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Database Scale Testing</div>
    <div style="padding: 16px 24px; text-align: center; color: #555; border-left: 1px solid #e5e5e5;">< 5GB</div>
    <div style="padding: 16px 24px; text-align: center; color: #222; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">200GB+ validated</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Error Handling</div>
    <div style="padding: 16px 24px; text-align: center; color: #555; border-left: 1px solid #e5e5e5;">Basic exit codes</div>
    <div style="padding: 16px 24px; text-align: center; color: #222; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">Enterprise-grade recovery</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Monitoring Integration</div>
    <div style="padding: 16px 24px; text-align: center; color: #999; border-left: 1px solid #e5e5e5;">—</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">CloudWatch, Datadog, PagerDuty</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Automated Failover</div>
    <div style="padding: 16px 24px; text-align: center; color: #999; border-left: 1px solid #e5e5e5;">Manual rollback</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">Intelligent auto-rollback</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Orchestration Workflows</div>
    <div style="padding: 16px 24px; text-align: center; color: #999; border-left: 1px solid #e5e5e5;">Run individually</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">Integrated pipeline</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Disaster Recovery Playbooks</div>
    <div style="padding: 16px 24px; text-align: center; color: #999; border-left: 1px solid #e5e5e5;">—</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">24/7 incident protocols</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Support Level</div>
    <div style="padding: 16px 24px; text-align: center; color: #555; border-left: 1px solid #e5e5e5;">Community GitHub</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">Direct email support</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Documentation Depth</div>
    <div style="padding: 16px 24px; text-align: center; color: #555; border-left: 1px solid #e5e5e5;">Usage examples</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">2,000+ page guides</div>
  </div>

</div>

<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 32px; margin: 48px 0;">
  <div style="background: #fafafa; padding: 32px; border-radius: 8px; border: 1px solid #e5e5e5;">
    <h4 style="margin: 0 0 16px 0; font-size: 18px; font-weight: 600; color: #555;">Learning-Grade Scripts For:</h4>
    <ul style="margin: 0; padding-left: 20px; color: #555; line-height: 1.8;">
      <li>Understanding Odoo architecture</li>
      <li>Development/staging environments</li>
      <li>Small databases (< 5GB)</li>
      <li>Learning automation concepts</li>
      <li>Non-revenue-critical systems</li>
    </ul>
  </div>
  <div style="background: #f0f7ff; padding: 32px; border-radius: 8px; border: 2px solid #267CB9;">
    <h4 style="margin: 0 0 16px 0; font-size: 18px; font-weight: 600; color: #267CB9;">Production-Grade Master Pack For:</h4>
    <ul style="margin: 0; padding-left: 20px; color: #222; line-height: 1.8; font-weight: 500;">
      <li>Revenue-generating production systems</li>
      <li>Enterprise databases (50GB - 500GB+)</li>
      <li>24/7 uptime requirements</li>
      <li>Compliance-heavy industries</li>
      <li>Teams replacing $50K+ consultants</li>
    </ul>
  </div>
</div>

<div style="text-align: center; margin: 48px 0;">
  <a href="https://ariashaw.gumroad.com/l/odoo-digital-sovereignty"
     style="display: inline-block; background: #267CB9; color: white; padding: 18px 40px; border-radius: 6px; text-decoration: none; font-weight: 600; font-size: 18px; transition: background 0.2s; box-shadow: 0 4px 12px rgba(38, 124, 185, 0.2);"
     onmouseover="this.style.background='#1e5f8f'; this.style.boxShadow='0 6px 16px rgba(38, 124, 185, 0.3)'"
     onmouseout="this.style.background='#267CB9'; this.style.boxShadow='0 4px 12px rgba(38, 124, 185, 0.2)'"
     onclick="gtag('event', 'cta_click', {'event_category': 'CTA', 'event_label': 'Scripts Comparison CTA', 'cta_location': 'scripts_comparison', 'destination': 'gumroad'});">
    Upgrade to Production-Grade — $699
  </a>
  <div style="margin-top: 20px; font-size: 14px; color: #727272; display: flex; justify-content: center; gap: 24px; flex-wrap: wrap;">
    <span style="display: flex; align-items: center; gap: 6px;">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#727272" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
      Secure checkout
    </span>
    <span style="display: flex; align-items: center; gap: 6px;">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#727272" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"></path></svg>
      30-day guarantee
    </span>
    <span style="display: flex; align-items: center; gap: 6px;">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#727272" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
      Instant access
    </span>
  </div>
  <div style="margin-top: 16px;"><a href="/products/" style="color: #267CB9; font-size: 15px; text-decoration: none; font-weight: 500;">→ See detailed breakdown of what's included</a></div>
</div>

---

## Need Planning Tools First?

Before running scripts, calculate your requirements:

- **[Odoo Requirements Calculator](/toolkit/odoo-requirements-calculator/)** - Calculate exact CPU, RAM, storage needs
- **[Odoo Hosting Advisor](/toolkit/odoo-hosting-advisor/)** - Get personalized hosting recommendations

---

## Related Guides

These scripts accompany comprehensive guides:

- [Odoo Self-Hosting Guide](/odoo-self-hosting-guide/) - Complete self-hosting roadmap
- [Database Backup & Restore Guide](/odoo-database-backup-restore-guide/) - Master backup strategies
- [Database Migration Guide](/odoo-database-migration-guide/) - Zero-downtime migration
- [AWS Security Hardening Guide](/odoo-aws-security-hardening/) - Production AWS setup
- [Odoo Implementation Guide](/odoo-implementation-guide/) - Avoid $250K+ failures

---

## Important Notes

### Before Running Scripts

1. **Review the code** - Always read scripts before running in production
2. **Test in staging** - Run in non-production environment first
3. **Backup everything** - Have a verified backup before making changes
4. **Check compatibility** - Verify your Odoo version, OS, PostgreSQL version

### Support & Issues

- **Found a bug?** [Open an issue on GitHub](https://github.com/AriaShaw/AriaShaw.github.io/issues)
- **Need help?** Email [aria@ariashaw.com](mailto:aria@ariashaw.com) (free scripts = community support)
- **Want consulting?** Email for custom script development or implementation help

---

## License

All scripts are released under **MIT License** - free to use, modify, and distribute.

**Author:** Aria Shaw (Digital Plumber)
**Website:** [https://ariashaw.com](https://ariashaw.com)

---
