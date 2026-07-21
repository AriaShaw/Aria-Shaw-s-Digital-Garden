---
layout: post
title: "How Long Does an Odoo Database Migration Actually Take?"
description: "Realistic Odoo migration timelines: server moves in 1-4 hours, version upgrades in 2-6 weeks of calendar time. Duration tables by database size and what makes it slow."
date: 2026-07-21
author: Aria Shaw
---

**Short answer: the cutover itself usually takes 1-4 hours, but that's the wrong number to plan around.** A same-version server move for a typical database (under 5 GB) completes in an evening. A version upgrade is a different animal: the production run may finish in 20 minutes to a few hours, but reaching a safe production run takes 2-6 weeks of calendar time for test migrations, custom module adaptation (2-8 hours per module), and validation. People who budget for the cutover and not the runway are the ones who end up restoring backups at 3 a.m.

"Migration" means three different projects in Odoo, with three different clocks. Identify yours first.

## The three things people mean by "Odoo migration"

| Type | What it is | Technical work | Realistic calendar time |
|---|---|---|---|
| Server move | Same Odoo version, new host | Dump, transfer, restore, reconfigure | Half a day to 2 days |
| Version upgrade | e.g. Odoo 16 to 18, same data | Upgrade scripts + module adaptation + testing | 2-6 weeks (small/standard) to 3+ months (heavy custom) |
| Platform migration | From QuickBooks, NetSuite, spreadsheets, etc. | Data mapping, cleaning, import, reconciliation | 1-6 months, dominated by data quality |

The rest of this article gives duration detail for the first two, since they're what "how long does it take" usually means. Platform migrations deserve their own treatment — the timeline lives and dies on source data quality, not on Odoo.

## Server move: hours, dictated by size and bandwidth

A same-version move is mechanical: `pg_dump`, copy the filestore, restore, point DNS. The duration is almost entirely data transfer plus restore time.

| Database size | Dump + restore | Filestore copy | Total downtime window to plan |
|---|---|---|---|
| Under 1 GB | 10-30 min | 10-30 min | 1-2 hours |
| 1-5 GB | 30-90 min | 30 min - 2 h | 2-4 hours |
| 5-20 GB | 1-4 h | 1-4 h | Half a day |
| Over 20 GB | 3-8 h | Often the bottleneck | Staged migration; consider rsync pre-sync |

Three notes from how these plans actually fail:

- **The filestore is routinely forgotten and routinely the slow part.** It's thousands of small files, which transfer far slower per gigabyte than one dump file. Pre-sync it with `rsync` while the old server is still live, then do a final delta sync during the downtime window. (If you don't know whether your backups even include the filestore, [read this first](/odoo-backup-without-filestore) — it's the most common restore disaster.)
- **`pg_restore -j 4`** (parallel jobs) cuts restore time substantially on multi-core servers for custom-format dumps.
- **Always time a rehearsal.** Restore yesterday's backup onto the new server and measure. Your numbers, not a blog table, set the maintenance window. The table above is for budgeting before you can rehearse.

## Version upgrade: minutes of runtime, weeks of runway

This is where estimates go wrong by an order of magnitude, because the production upgrade run is the *end* of the project, not the project.

### If you're on Odoo Enterprise (official upgrade service)

Odoo's hosted upgrade service processes a copy of your database and returns the upgraded version. [Odoo's own documentation](https://www.odoo.com/documentation/19.0/administration/upgrade.html) notes that if a test upgrade completes in under 20 minutes, you can trigger the production upgrade directly — which tells you the runtime for a standard small database is minutes, not hours. Large databases with heavy transactional tables (`account.move.line`, `stock.move.line` with millions of rows) can run for hours, particularly when upgrade scripts add computed fields that must backfill every row.

The realistic timeline for a standard implementation:

| Phase | Duration |
|---|---|
| Request and receive first test upgrade | Hours to 1-2 days |
| Fix what the test reveals, per custom module | 2-8 hours each |
| Second and third test rounds (plan at least 2-3) | 1-2 weeks elapsed |
| User acceptance testing on the upgraded copy | 3-10 days |
| Production upgrade run (the actual downtime) | 20 min - a few hours |

### If you're on Community (OpenUpgrade)

[OpenUpgrade](https://www.odoo-community.org/blog/news-updates-1/openupgrade-187) migrates one version per hop — Odoo 14 to 18 means running the 15, 16, 17, and 18 migrations in sequence. Each hop takes roughly 10 minutes to several hours depending on database size, so a multi-version jump multiplies both runtime and the number of places things can break. Budget each hop as its own mini-project with its own verification pass, and expect the total elapsed time for a 3-4 version jump on a customized database to be measured in weeks.

### What actually consumes the time

Across both routes, the big four time sinks, in order:

1. **Custom modules.** Every module touching changed core models needs adaptation — the 2-8 hours per module estimate is the community consensus range, and a database with 15 custom modules can carry 1-3 weeks of developer time on this line alone.
2. **Large transactional tables.** Upgrade scripts that rewrite or compute fields across millions of rows dominate runtime. This is why runtime scales with data volume more than with module count.
3. **Repeated testing.** The 2-3 test migration cycles aren't padding; the first test exists to produce the error list, the second to verify the fixes, the third to rehearse the cutover.
4. **Data cleanup deferred until now.** Duplicate partners, orphaned attachments, and unposted entries from 2019 all surface during upgrade validation. Cleaning before you start is faster than debugging during.

## Cutting the downtime window

If the business can't absorb hours of downtime, the standard technique is incremental sync: restore a copy to the new environment days ahead, then replay only the delta during a short cutover window. Done well, this reduces user-facing downtime to under an hour even for large databases. The mechanics — along with the full step-by-step for both migration types — are covered in my complete [Odoo database migration guide](/odoo-database-migration-guide).

## FAQ

**How long does it take to upgrade Odoo to a new version?**
The production run typically takes 20 minutes to a few hours. The full project — test upgrades, custom module adaptation at 2-8 hours per module, and 2-3 validation rounds — realistically takes 2-6 weeks for a standard implementation, and longer with heavy customization.

**How long does it take to move Odoo to a new server?**
For databases under 5 GB, plan a 2-4 hour maintenance window including dump, filestore transfer, restore, and verification. Above 20 GB, pre-sync the filestore with rsync and consider a staged approach.

**Can I skip versions when upgrading Odoo?**
The official upgrade service handles multi-version jumps in one request. OpenUpgrade (Community) cannot skip: it migrates one version per hop, and each hop adds its own runtime and risk.

**What makes an Odoo migration slow?**
In practice: custom module adaptation, upgrade scripts backfilling computed fields across million-row tables, filestore transfer for large attachment volumes, and repeated test cycles. Raw database size matters less than these four.

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "How long does an Odoo database migration take?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "A same-version server move takes 1-4 hours of downtime for typical databases under 5 GB. A version upgrade's production run takes 20 minutes to a few hours, but the full project including test migrations and custom module adaptation (2-8 hours per module) realistically spans 2-6 weeks of calendar time."
      }
    },
    {
      "@type": "Question",
      "name": "Can I skip versions when upgrading Odoo?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Odoo's official upgrade service handles multi-version jumps in one request. OpenUpgrade for Community edition migrates one version per hop, so Odoo 14 to 18 means running four sequential migrations, each taking 10 minutes to several hours depending on database size."
      }
    },
    {
      "@type": "Question",
      "name": "What makes an Odoo migration slow?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "The four dominant time sinks are custom module adaptation, upgrade scripts computing fields across large transactional tables like account.move.line, filestore transfer of thousands of small files, and the 2-3 test migration cycles needed before a safe production cutover."
      }
    }
  ]
}
</script>

## Sources

- [Odoo official documentation: Upgrade](https://www.odoo.com/documentation/19.0/administration/upgrade.html)
- [OCA: OpenUpgrade project](https://www.odoo-community.org/blog/news-updates-1/openupgrade-187)
- [Complete Odoo Database Migration Guide (this site)](/odoo-database-migration-guide)
