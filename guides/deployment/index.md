---
layout: home
title: Deployment Guides (22)
description: Production-ready Odoo deployment guides for AWS, Azure, DigitalOcean, and 20+ cloud platforms, plus comprehensive on-premises installation guides for Ubuntu, Debian, and CentOS.
permalink: /guides/deployment/
breadcrumb_title: Deployment
---

# Deployment Guides (22)

Deploy Odoo confidently across cloud platforms and bare-metal servers with these production-validated installation guides. This collection covers the complete deployment spectrum: from managed cloud services (AWS, Azure, DigitalOcean) to self-hosted VPS environments and on-premises data centers.

Each guide follows enterprise-grade best practices: automated system configuration, security hardening from day one, PostgreSQL optimization for production workloads, and monitoring setup for proactive incident response. Deployment timeframes range from 1-2 hours for cloud platforms to 3-4 hours for complex on-premises installations.

All guides include infrastructure-as-code templates where applicable, ensuring reproducible deployments and eliminating configuration drift across environments.

---

## Cloud Platforms

<div class="platform-section">
{% assign cloud_guides = site.implementations | where_exp: "item", "item.slug contains 'deploy' or item.slug contains 'install'" | where_exp: "item", "item.slug contains 'aws' or item.slug contains 'azure' or item.slug contains 'gcp' or item.slug contains 'digitalocean' or item.slug contains 'linode' or item.slug contains 'vultr'" | sort: "title" %}

{% for guide in cloud_guides %}
  <article class="guide-card">
    <h3><a href="{{ guide.url }}">{{ guide.title }}</a></h3>
    <p>{{ guide.description | truncate: 120 }}</p>
    <span class="meta">{{ guide.date | date: "%Y-%m-%d" }}</span>
  </article>
{% endfor %}
</div>

---

## On-Premises & VPS

<div class="platform-section">
{% assign onprem_guides = site.implementations | where_exp: "item", "item.slug contains 'install'" | where_exp: "item", "item.slug contains 'ubuntu' or item.slug contains 'debian' or item.slug contains 'centos' or item.slug contains 'redhat' or item.slug contains 'rocky'" | sort: "title" %}

{% for guide in onprem_guides %}
  <article class="guide-card">
    <h3><a href="{{ guide.url }}">{{ guide.title }}</a></h3>
    <p>{{ guide.description | truncate: 120 }}</p>
  </article>
{% endfor %}
</div>
