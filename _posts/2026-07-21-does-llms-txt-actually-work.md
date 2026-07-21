---
layout: post
title: "Does llms.txt Actually Work? What the Evidence Shows in 2026"
description: "Server logs from 137,000+ domains show 97% of llms.txt files never get fetched by AI crawlers. Here's what the data says, and when the file is still worth having."
date: 2026-07-21
author: Aria Shaw
hide_product_cta: true
---

**Short answer: no, not for AI search visibility.** As of mid-2026, no major AI company has committed to reading llms.txt, large-scale log analysis shows 97% of published llms.txt files receive zero requests, and correlation studies across hundreds of thousands of domains find no citation lift from having one. The file does have one legitimate, narrower use case: documentation sites consumed by coding assistants.

That's the summary. The rest of this article walks through the actual evidence, because most of what's written about llms.txt is either vendor marketing or wishful thinking, and the data deserves to be looked at directly.

## What llms.txt is supposed to be

The llms.txt proposal was published in September 2024 by Jeremy Howard of Answer.AI. The idea is simple: place a Markdown file at your site root (`/llms.txt`) that gives language models a curated, token-efficient map of your most important content, instead of forcing them to parse your HTML, navigation, and cookie banners. A companion convention, `llms-full.txt`, inlines the full content of those pages into one large file.

It is worth being precise about what the proposal is *not*:

- It is **not** an access-control standard. That's `robots.txt`. llms.txt doesn't block or allow anything.
- It is **not** part of any search engine's or AI engine's documented ingestion pipeline.
- It is **not** a ranking signal anyone has confirmed.

It's an invitation: "here's a cleaner version of my site, if you want it." The question is whether anyone accepts the invitation.

## The evidence, piece by piece

### 1. Almost nobody fetches the file

The largest public dataset comes from [Ahrefs' study of 137,210 domains](https://ahrefs.com/blog/llmstxt-study/) with measurable traffic in May 2026:

| Finding | Number |
|---|---|
| Domains publishing a valid llms.txt | 38,360 (28%) |
| Of those, files receiving **zero requests** in the month | 97% |
| Files receiving any traffic at all | ~1,100 domains (3%) |
| Share of llms.txt requests coming from bots | 96% |
| Bot requests from **non-AI** tools (SEO auditors, crawlers, profilers) | 77% |
| Requests from retrieval bots (OAI-SearchBot, PerplexityBot) | ~1% |

Read that last row again. The bots that actually feed AI search answers — the retrieval crawlers — barely register in llms.txt request logs. Most of the traffic to these files comes from SEO audit tools checking whether you have one, which is a nearly perfect illustration of the whole phenomenon: the industry studying itself.

The study also noted that AI bots never requested llms.txt on domains where the file didn't exist. Crawlers aren't probing for it. If they wanted the file, cheap probing is exactly what you'd expect to see.

### 2. No platform has committed to using it

As of this writing, none of OpenAI, Google, Anthropic, Meta, Perplexity, or Mistral has publicly stated that their production systems read or act on llms.txt. Individual crawlers have been observed fetching the file occasionally (GPTBot appears in logs more than others), but occasional fetching is not the same as the file influencing answers.

Google has been unusually direct. John Mueller [compared llms.txt to the keywords meta tag](https://www.searchenginejournal.com/97-of-llms-txt-files-got-no-requests-ahrefs-data-shows/579478/) — a self-declared description of what a site claims to be about, which is precisely why search engines stopped trusting that class of signal fifteen years ago.

### 3. No measurable citation lift

SE Ranking analyzed roughly 300,000 domains and found no statistically significant correlation between having an llms.txt file and how often a domain gets cited in AI answers. More telling: removing llms.txt as a variable from their predictive model *improved* its accuracy — the file was noise, not signal.

I have not found a single controlled study showing a citation lift from adding llms.txt. If you find one, check who funded it and whether llms.txt was the only variable that changed. In every case I've reviewed, the file shipped alongside content restructuring, technical fixes, or link acquisition — any of which explains the result on its own.

## Where llms.txt genuinely works

The honest picture isn't "llms.txt is useless." It's "llms.txt is useful for a different, smaller job than the one it's marketed for."

The real adopters are **documentation sites serving coding assistants**. Tools like Cursor, Continue, and Cline, and various MCP-based integrations, can be pointed at an `llms.txt` or `llms-full.txt` to pull clean, current documentation into a coding session. For a developer-tools company, that's a real use case: your users' AI assistants get accurate API docs instead of hallucinated ones. Framework documentation (FastHTML, Svelte, and others) is where the standard actually lives today.

Note what makes this case different: the file is fetched *on demand by a tool the user configured*, not discovered by a crawler deciding what to cite. The demand side exists. For general AI search visibility, it doesn't.

## So should you add one?

A decision rule that matches the evidence:

- **You run developer documentation:** yes, add both `llms.txt` and `llms-full.txt`. Your users' tools will actually consume them.
- **You run a content or commerce site and hope it improves AI citations:** the evidence says it won't. Adding it costs ten minutes and does no harm, but treat it as a lottery ticket on future adoption, not a tactic. Don't let anyone sell it to you as one.
- **You're paying an agency that lists "llms.txt implementation" as a deliverable:** ask them for their evidence that it moves citations. This article is a reasonable summary of the public data; theirs should be better than vendor blog posts.

What *does* have evidence behind it for AI answer visibility is boring: being indexed where the answer engines retrieve from (ChatGPT's retrieval layer leans on Bing's index — [87% of its citations match Bing's top results](https://www.seerinteractive.com/insights/87-percent-of-searchgpt-citations-match-bings-top-results)), serving clean crawlable HTML, and publishing content that answers a specific question directly enough to be quoted. I've written a separate breakdown of that pipeline: [Why Your Site Ranks on Google but ChatGPT Never Cites It](/why-chatgpt-never-cites-your-site).

## FAQ

**Does llms.txt help SEO?**
No. Google has stated it does not use llms.txt for Search, and it has no effect on rankings. It's also not a substitute for robots.txt, sitemaps, or structured data.

**Does ChatGPT read llms.txt?**
GPTBot (OpenAI's training crawler) fetches the file occasionally on some sites, but OpenAI has not stated that llms.txt influences ChatGPT answers, and OAI-SearchBot — the crawler that feeds ChatGPT search — barely requests it at all in large-scale log data.

**Is llms.txt harmful to have?**
No known harm, with one caveat: an `llms-full.txt` hands your entire content to anyone who wants a clean scrape, which matters if your business model depends on people visiting your pages.

**What's the difference between llms.txt and robots.txt?**
robots.txt tells crawlers what they may not access, and major AI crawlers document their compliance with it. llms.txt suggests what crawlers might want to read. One is an enforced-by-convention gate; the other is an unread brochure.

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Does llms.txt actually work for AI search visibility?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "No. As of mid-2026, no major AI company has committed to reading llms.txt, Ahrefs' analysis of 137,210 domains found 97% of published llms.txt files received zero requests, and SE Ranking's analysis of ~300,000 domains found no correlation between having the file and AI citation frequency. Its one proven use case is documentation sites consumed by coding assistants like Cursor."
      }
    },
    {
      "@type": "Question",
      "name": "Does llms.txt help SEO?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "No. Google's John Mueller compared it to the keywords meta tag, and Google has stated it is not used for Search. It has no effect on rankings and is not a substitute for robots.txt, sitemaps, or structured data."
      }
    },
    {
      "@type": "Question",
      "name": "Does ChatGPT read llms.txt?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "OpenAI's GPTBot occasionally fetches the file on some sites, but OpenAI has not stated that llms.txt influences answers, and OAI-SearchBot, which feeds ChatGPT search, accounts for around 1% of llms.txt requests in large-scale server log data."
      }
    }
  ]
}
</script>

## Sources

- [Ahrefs: We Analyzed 137K Sites — 97% of llms.txt Files Never Get Read](https://ahrefs.com/blog/llmstxt-study/)
- [Search Engine Journal: 97% Of llms.txt Files Got No Requests, Ahrefs Data Shows](https://www.searchenginejournal.com/97-of-llms-txt-files-got-no-requests-ahrefs-data-shows/579478/)
- [Seer Interactive: 87% of SearchGPT Citations Match Bing's Top Results](https://www.seerinteractive.com/insights/87-percent-of-searchgpt-citations-match-bings-top-results)
- [llms.txt proposal (Answer.AI)](https://llmstxt.org/)
- [OpenAI: Overview of OpenAI Crawlers](https://developers.openai.com/api/docs/bots)
