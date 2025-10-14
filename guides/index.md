---
layout: home
title: Complete Guides Library | Aria Shaw's Digital Garden
description: Comprehensive collection of battle-tested Odoo guides covering deployment, security, migration, backup, and operations. Definitive playbooks for every stage of your Odoo journey.
breadcrumb_title: Guides
permalink: /guides/
---

# Complete Guides Library

Definitive playbooks for every stage of your Odoo journey—from strategic planning to daily operations. Each guide is meticulously crafted to be the only resource you need on the subject.

---

<div class="posts-grid-section">
<div class="posts-grid">
{% assign post_images = "code.webp,keyboard.webp,electronic.webp,earphone.webp,digital.webp,data center.webp,computer.webp,technology.webp" | split: "," %}
{% assign post_image_alts = "Python code editor showing colorful syntax highlighting with class methods and function definitions,Close-up of blue PCB circuit board with golden contacts and integrated circuits,Top view of electronic circuit board with colorful resistors capacitors and microchips,Black wireless headphones on vibrant yellow background,Digital network visualization with glowing blue connection lines and nodes on dark background,Data center network switches with blue ethernet cables connected to multiple ports,Hands typing on laptop keyboard in blurred office workspace environment,Glowing cyan circuit board chip architecture in transparent perspective view" | split: "," %}
{% assign featured_posts = "odoo-aws-deployment-guide,odoo-aws-security-hardening,odoo-database-migration-guide" | split: "," %}
{% for post in site.posts %}
  {% assign index = forloop.index0 %}
  {% assign is_featured = false %}
  {% for featured_slug in featured_posts %}
    {% if post.url contains featured_slug %}
      {% assign is_featured = true %}
    {% endif %}
  {% endfor %}
  <article class="post-card{% if is_featured %} featured{% endif %}">
    <img src="/assets/images/{{ post_images[index] }}" alt="{{ post_image_alts[index] }}" class="post-card-image" loading="lazy">
    <div class="post-card-content">
      <h3 class="post-card-title">
        <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
      </h3>
      {% if is_featured %}
        <p class="post-card-description">{{ post.description | truncate: 200 }}</p>
      {% else %}
        <p class="post-card-description">{{ post.description | truncate: 120 }}</p>
      {% endif %}
    </div>
  </article>
{% endfor %}
</div>
</div>

---

## 🧰 Production Scripts & Tools

Looking for ready-to-use automation? Browse the complete collection of production scripts.

**[→ View All Scripts](/scripts/)**

---

## 🏆 Need the Complete Toolkit?

These guides are just the beginning. The **Odoo Digital Sovereignty Master Pack** includes:

- 68+ production-ready scripts and automation tools
- 2,000+ pages of comprehensive documentation
- 5 integrated modules covering the entire Odoo lifecycle
- Zero vendor lock-in—you own everything

**[Learn More About the Master Pack](https://ariashaw.gumroad.com/l/odoo-digital-sovereignty)**
