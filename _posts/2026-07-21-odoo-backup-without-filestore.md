---
layout: post
title: "What Happens If You Back Up the Odoo Database but Not the Filestore?"
description: "A database-only Odoo backup restores cleanly, then every image, attachment, and document is broken. Why it happens, how to check your backups, and what's recoverable."
date: 2026-07-21
author: Aria Shaw
---

**Short answer: the restore succeeds, and then everything visual breaks.** Odoo stores your structured data in PostgreSQL but keeps the actual binary files — product images, PDF attachments, uploaded documents — on disk in a separate directory called the filestore. A `.dump` or `.sql` backup captures only the database, which contains *references* to those files, not the files themselves. Restore it on a new server and every reference points to a file that doesn't exist: broken product images, empty chatter attachments, documents that 404. The files cannot be regenerated from the dump, because they were never in it.

This is the single most common way Odoo restores go wrong — and the cruelest part is that nothing warns you at backup time. The backup completes, the restore completes, and the damage only shows when someone opens a quotation and the logo is a broken-image icon.

## Why Odoo splits your data in two

Odoo deliberately keeps large binaries out of PostgreSQL:

| Component | What it holds | Where it lives |
|---|---|---|
| PostgreSQL database | Records, relations, configuration — and an `ir_attachment` table of file *metadata* | Your database server |
| Filestore | The actual binary content of attachments | `~/.local/share/Odoo/filestore/<database_name>/` (default on Linux) |

Every uploaded file gets a row in `ir_attachment`. The row stores the filename, mimetype, checksum, and a `store_fname` column — a relative path like `a3/a3f2c9...`, which is the file's SHA-1 checksum used as its location inside the filestore directory. The binary itself sits at that path on disk.

So when a database-only backup is restored elsewhere, `ir_attachment` arrives intact and confidently points at `a3/a3f2c9...` — a path on a disk that has no filestore. Odoo logs `FileNotFoundError` entries, browsers get 404s or placeholder icons, and reports that embed images fail to render.

## What breaks, and what survives

**Broken after a filestore-less restore:**

- Product images (all resolutions — the resized variants are attachments too)
- Every file attached via chatter on invoices, orders, tasks, and records generally
- Documents app contents
- Employee photos, partner logos, and the company logo on printed reports
- Email attachments stored on incoming messages
- Website images uploaded through the media manager

**Survives:**

- All structured data: partners, products, invoices, inventory, accounting entries — the business ledger is intact
- Web assets (CSS/JS bundles): these look broken at first because the cached bundles were attachments, but Odoo regenerates them automatically; a forced asset regeneration or first page load fixes them
- Any attachments stored in-database: if `ir_attachment.db_datas` holds the binary (a non-default configuration some older or deliberately configured systems use), those specific files survive

That last point explains a confusing symptom: some systems restore with *some* attachments working and most broken. Check `ir_attachment` — rows with `db_datas` populated survived; rows with only `store_fname` didn't.

## Check right now whether your backups have this hole

Sixty seconds, no restore required:

1. **Backup from the database manager (`/web/database/manager`):** if your saved file is a `.zip`, open it — a complete backup contains `dump.sql`, a `manifest.json`, and a `filestore/` directory. If you've been saving the "without filestore" format or raw `.dump` files, you have the hole.
2. **Backup via `pg_dump` in a cron job:** `pg_dump` knows nothing about the filestore, full stop. Unless a separate line in the script tars or rsyncs `~/.local/share/Odoo/filestore/<dbname>`, you have the hole.
3. **Hosted platforms:** Odoo.sh backups include the filestore. Third-party hosts vary — verify by downloading one backup and looking inside, not by reading the marketing page.

Then run the real test: restore the backup to a scratch server and open a product with an image. Backup files you haven't restored are Schrödinger's backups. My [complete backup and restore guide](/odoo-database-backup-restore-guide) covers the full verification procedure and automation.

## If it already happened: your recovery options

In order of preference:

**1. The old server (or any old snapshot) still exists.** You're fine. Copy the filestore across and fix ownership:

```bash
rsync -a olduser@oldserver:~/.local/share/Odoo/filestore/proddb/ \
    ~/.local/share/Odoo/filestore/proddb/
chown -R odoo:odoo ~/.local/share/Odoo/filestore/proddb
```

The filestore doesn't have to be version-matched to the minute — an older filestore restores every attachment that existed at its snapshot date. You lose only files uploaded between that snapshot and the database dump.

**2. A partial or older filestore exists.** Copy what you have. Everything whose checksum path exists comes back; the rest stay broken and can be cleaned up afterward.

**3. Nothing exists.** The binaries are unrecoverable — no tool reconstructs them from the dump, because the data was never there. What you can do is stop the database from referencing ghosts, so users see clean empty states instead of errors. After a full backup of the current state, remove orphaned attachment records:

```sql
-- Review the damage first
SELECT COUNT(*) FROM ir_attachment
WHERE store_fname IS NOT NULL AND db_datas IS NULL;
```

Deleting those rows (filtered to exclude anything you've since re-uploaded) clears the broken references. Treat this as a last resort, run it on a copy first, and expect to re-upload critical documents manually from email trails and local copies.

## The rule that prevents all of this

A complete Odoo backup is **database dump + filestore, captured together**. Either use the database manager's zip format ("with filestore"), or make your backup script two lines instead of one:

```bash
pg_dump -Fc proddb > /backup/proddb_$(date +%F).dump
tar czf /backup/filestore_$(date +%F).tar.gz \
    -C ~/.local/share/Odoo/filestore proddb
```

And restore-test on a schedule, because the only backup that counts is one you've watched come back to life.

## FAQ

**Does an Odoo database backup include the filestore?**
Only if you choose the zip format in the database manager, which bundles `dump.sql`, `manifest.json`, and the `filestore/` directory. Raw `pg_dump` output and the "without filestore" option contain the database only — attachments are not included.

**Can I regenerate the Odoo filestore from a .dump file?**
No. The dump contains attachment metadata (names, checksums, paths) but not the binary content. Only web asset bundles regenerate automatically; images and documents are gone unless a filestore copy exists somewhere.

**Where is the Odoo filestore located?**
By default on Linux: `~/.local/share/Odoo/filestore/<database_name>/` under the user running Odoo. The path can be changed via the `data_dir` option in `odoo.conf`, so check there if the default is empty.

**Why are images broken after restoring an Odoo backup?**
The restored database references files by checksum path in a filestore directory that's missing or incomplete on the new server. Copy the filestore from the source server into place, fix ownership, and the images return immediately — no reimport needed.

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "What happens if you back up the Odoo database but not the filestore?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "The restore completes, but every product image, attachment, and document breaks. Odoo stores binaries on disk in the filestore, not in PostgreSQL — the database only holds references. Files cannot be regenerated from a dump; recovery requires a filestore copy from the original server or an older snapshot."
      }
    },
    {
      "@type": "Question",
      "name": "Does an Odoo database backup include the filestore?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Only the zip-format backup from Odoo's database manager includes the filestore. Raw pg_dump output and the 'without filestore' option capture the database only, leaving all attachments and images out of the backup."
      }
    },
    {
      "@type": "Question",
      "name": "Can I regenerate the Odoo filestore from a dump file?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "No. The dump stores attachment metadata but not binary content. Web asset bundles regenerate automatically, but images and documents are unrecoverable without a filestore copy. Orphaned ir_attachment rows can be cleaned up so users see empty states instead of errors."
      }
    }
  ]
}
</script>

## Sources

- [Odoo forum: How to recreate Odoo filestore from a .dump file](https://www.odoo.com/forum/help-1/how-to-recreate-odoo-filestore-from-a-dump-file-267841)
- [GitHub odoo/odoo #9296: restore bug when backup does not include filestore](https://github.com/odoo/odoo/issues/9296)
- [Odoo forum: No images after restoring backup](https://www.odoo.com/forum/help-1/no-images-after-restore-backup-in-odoo-12-155341)
- [Complete Odoo Backup and Restore Guide (this site)](/odoo-database-backup-restore-guide)
