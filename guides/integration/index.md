---
layout: home
title: Integration Guides (100+)
description: Complete collection of production-tested Odoo integration guides covering 100+ services including Gmail, Slack, Stripe, PayPal, and enterprise SaaS platforms.
permalink: /guides/integration/
breadcrumb_title: Integration
---

# Integration Guides (100+)

Odoo's true power lies in its connectivity. This collection features 100+ battle-tested integration guides covering the most critical business services—from email systems (Gmail, Outlook) to payment gateways (Stripe, PayPal), CRM platforms (Salesforce, HubSpot), and enterprise SaaS tools.

Each guide is structured for practitioners: 2-4 hour implementation timeframes, production-ready API patterns, comprehensive error handling, and real-world troubleshooting scenarios. Whether you're connecting a single third-party service or building a complex integration ecosystem, these guides provide the complete technical blueprint.

All integrations follow the same proven architecture: OAuth2/API key authentication, field mapping configuration, scheduled sync tasks, and webhook-based real-time updates where supported.

---

## Quick Search

<div id="search-container">
  <input type="text" id="integration-search" placeholder="Search integrations (e.g., Gmail, Slack, Shopify)..." aria-label="Search integration guides">
</div>

---

## All Integration Guides

<div class="guides-grid" id="integration-grid">
{% assign integration_guides = site.implementations | where_exp: "item", "item.slug contains 'integrate'" | sort: "title" %}

{% for guide in integration_guides %}
  <article class="guide-card" data-title="{{ guide.title | downcase }}">
    <h3><a href="{{ guide.url }}">{{ guide.title }}</a></h3>
    <p>{{ guide.description | truncate: 120 }}</p>
  </article>
{% endfor %}
</div>

<script>
// Progressive enhancement: client-side search filter
(function() {
  const searchBox = document.getElementById('integration-search');
  if (!searchBox) return;

  searchBox.addEventListener('input', function(e) {
    const query = e.target.value.toLowerCase();
    const cards = document.querySelectorAll('.guide-card');

    cards.forEach(card => {
      const title = card.dataset.title;
      card.style.display = title.includes(query) ? 'block' : 'none';
    });
  });
})();
</script>
