---
layout: post
title: "Why Your Site Ranks on Google but ChatGPT Never Cites It"
description: "ChatGPT retrieves from Bing's index, not Google's — 87% of its citations match Bing's top results. How to diagnose why you're invisible in AI answers, and fix it."
date: 2026-07-21
author: Aria Shaw
hide_product_cta: true
---

**Short answer: ChatGPT doesn't search Google.** Its retrieval layer leans on Bing's index — research by Seer Interactive found that 87% of ChatGPT search citations match Bing's top organic results, versus a 56% match rate for Google. If Bing hasn't indexed your page, ChatGPT cannot cite it, no matter how well it ranks on Google. And even inside Bing's index, getting *retrieved* and getting *cited* are two separate filters you have to pass.

If your site earns steady Google traffic but never appears in AI answers, work through this article in order: the diagnosis is usually one of four specific failures, and three of them are fixable in an afternoon.

## How a page actually becomes a ChatGPT citation

The pipeline has four stages, and you can fail at any of them:

1. **Query rewriting.** ChatGPT reformulates the user's question into one or more search queries. These often differ from the keywords you optimized for.
2. **Retrieval.** Those queries hit a web index. For ChatGPT, that infrastructure is Bing's, supplemented by OpenAI's own crawling via OAI-SearchBot. A page absent from this layer is invisible — the model can't cite what retrieval never surfaces.
3. **Reading.** Candidate pages are fetched and read. Pages that block OpenAI's fetchers, render only via JavaScript, or bury the answer under 800 words of preamble lose here.
4. **Citation selection.** The model decides which of the retrieved pages actually support its answer. This is where rank stops mattering: [analysis of the same dataset](https://www.seerinteractive.com/insights/87-percent-of-searchgpt-citations-match-bings-top-results) found Bing's top-3 results only matched the final citation a small fraction of the time. Being in the candidate pool is gated by Bing; being chosen is gated by whether your page contains a clearly extractable answer.

Two practical corollaries. First, **Bing is a hard gate**: 87% citation overlap with Bing's top results means Bing indexing is close to a precondition. Second, **rank within Bing is a soft signal**: pages from positions 11-20 get cited over top-3 results when their content answers the question more directly.

## The four failures, in diagnostic order

### Failure 1: Bing never indexed you

This is the most common cause and the least suspected, because site owners who live in Google Search Console often haven't looked at Bing in years. Bing's crawler is more conservative than Google's, and sites that never submitted to it can have large index gaps.

**Check:** search `site:yourdomain.com` on Bing. Compare the page count against Google's. Then check whether specific money pages are indexed by searching their exact URL.

**Fix:** verify your site in [Bing Webmaster Tools](https://www.bing.com/webmasters) (you can import your Google Search Console verification in one click), submit your sitemap, and use URL submission for pages that matter. For ongoing coverage, implement [IndexNow](https://www.bing.com/indexnow) — a free ping protocol that typically gets Bing crawling new URLs within 1-3 days instead of weeks.

### Failure 2: you're blocking the AI crawlers

OpenAI runs separate crawlers for separate jobs, and many sites block them without realizing it:

| Crawler | Job | If you block it |
|---|---|---|
| GPTBot | Training data collection | Content excluded from future model training |
| OAI-SearchBot | ChatGPT search index | Pages can't appear in ChatGPT search results |
| ChatGPT-User | On-demand fetches during a chat | Live browsing of your pages fails |

The blocking is often accidental. A blanket `Disallow: /` for unknown user agents, a WAF rule, or a CDN's one-click "block AI bots" feature (Cloudflare ships this, and some plans enable it by default) will take you out of the ChatGPT search index while leaving Google untouched.

**Check:** read your robots.txt for `GPTBot`, `OAI-SearchBot`, `PerplexityBot`, and wildcard blocks. Then check your CDN/WAF dashboard for AI bot management settings. Then grep your server logs for these user agents — if OAI-SearchBot never appears, it's either blocked or not interested yet.

**Fix:** explicitly allow the retrieval bots you want. Blocking GPTBot (training) while allowing OAI-SearchBot (search) is a coherent policy [OpenAI documents](https://developers.openai.com/api/docs/bots) — you keep search visibility without contributing training data.

### Failure 3: retrieved but unquotable

If Bing indexes you and crawlers can fetch you, but citations still go to competitors, the problem is usually the content's shape, not its quality. The model cites pages it can lift an answer from. Pages that win citations share a structure:

- The question is the heading, in the words a user would actually ask.
- The answer appears in the first paragraph under that heading, complete in 40-60 words, not teased.
- Numbers come in tables, definitions come in single sentences, steps come in numbered lists.
- Claims carry sources the model can verify against its other retrieved candidates.

A 3,000-word guide that answers thirty questions diffusely will lose citations to a 900-word page that answers one question surgically. That's not a content-quality judgment — it's an extraction-cost judgment. (It's also why "just publish long-form authority content," the default SEO playbook, translates poorly to AI answers.)

### Failure 4: you're checking the wrong engine

"AI answers" is four different retrieval systems wearing one trenchcoat:

| Engine | Retrieval source | Your lever |
|---|---|---|
| ChatGPT search | Bing index + OAI-SearchBot | Bing Webmaster Tools, IndexNow, allow OAI-SearchBot |
| Perplexity | Own index (PerplexityBot) + partners | Allow PerplexityBot, same content-shape rules |
| Google AI Overviews | Google index | Ordinary Google SEO; AIO cites pages that rank |
| Gemini | Google index | Same as above |

A site can be cited constantly in AI Overviews and never in ChatGPT, purely because of the Bing gap. Diagnose per engine before concluding you have a content problem.

## The honest caveats

Two things this article should not oversell. First, AI answers are non-deterministic: the same query can cite different sources across sessions, so measure over repeated weekly checks, not single spot checks. Second, nobody outside these companies fully knows the citation-selection weights, and anyone promising "guaranteed placement in ChatGPT answers" is selling something the pipeline's randomness doesn't support. What the evidence supports is narrower and more useful: make yourself retrievable everywhere (Bing included), make your answers extractable, and the probability mass moves toward you.

Related reading: if you've been told the fix is adding an llms.txt file, [read the evidence on that first](/does-llms-txt-actually-work) — it's weaker than the marketing suggests.

## FAQ

**Does ChatGPT use Google or Bing?**
Bing. OpenAI's partnership with Microsoft gives ChatGPT search access to Bing's index, supplemented by OpenAI's own OAI-SearchBot crawling. Research found 87% of ChatGPT search citations match Bing's top organic results.

**How do I get my website indexed by ChatGPT?**
Get indexed by Bing (verify in Bing Webmaster Tools, submit a sitemap, use IndexNow), and make sure your robots.txt and CDN allow OAI-SearchBot. There is no direct submission channel to ChatGPT itself.

**Why does my competitor show up in ChatGPT answers but I don't?**
Check three things in order: whether Bing indexes your relevant pages at all, whether OAI-SearchBot is blocked by robots.txt or your CDN, and whether your page states the answer extractably near the top or buries it mid-article.

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Why does my site rank on Google but not get cited by ChatGPT?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "ChatGPT's retrieval layer uses Bing's index, not Google's — 87% of its citations match Bing's top organic results. If Bing hasn't indexed your page, or your robots.txt/CDN blocks OAI-SearchBot, ChatGPT cannot cite you regardless of your Google rankings."
      }
    },
    {
      "@type": "Question",
      "name": "Does ChatGPT use Google or Bing for search?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Bing. ChatGPT search retrieves candidates from Bing's index supplemented by OpenAI's own OAI-SearchBot crawler. Google AI Overviews and Gemini use Google's index instead, which is why visibility can differ sharply between engines."
      }
    },
    {
      "@type": "Question",
      "name": "How do I get my website cited by ChatGPT?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Verify your site in Bing Webmaster Tools, submit your sitemap, enable IndexNow for fast crawling, allow OAI-SearchBot in robots.txt and your CDN settings, and structure pages so the direct answer to a specific question appears in the first paragraph in an extractable form."
      }
    }
  ]
}
</script>

## Sources

- [Seer Interactive: 87% of SearchGPT Citations Match Bing's Top Results](https://www.seerinteractive.com/insights/87-percent-of-searchgpt-citations-match-bings-top-results)
- [OpenAI: Overview of OpenAI Crawlers](https://developers.openai.com/api/docs/bots)
- [Bing Webmaster Tools](https://www.bing.com/webmasters)
- [IndexNow protocol](https://www.bing.com/indexnow)
