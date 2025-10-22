#!/usr/bin/env python3
"""
Phase 2: Keyword Validation Script (SerpApi-Powered)

This script validates seed keywords by fetching precise SERP data from Google.

Usage:
    python scripts/validate_keywords.py <seed_keywords_file>

Example:
    python scripts/validate_keywords.py .pseo-projects/odoo-implementation/seed_keywords.txt

Input:
    - Text file with one keyword per line (from Phase 1 AI expansion)

Output:
    - validated_keywords.json with structured SERP data for Phase 3 AI analysis

SerpApi Key: 3b11f8e3dcda70001516cb6fac7ede59468e1ee387ad5967421a6e22d4ab9b18
"""

import sys
import json
import time
from pathlib import Path
from typing import Dict, List, Any
import requests

SERPAPI_KEY = "3b11f8e3dcda70001516cb6fac7ede59468e1ee387ad5967421a6e22d4ab9b18"
SERPAPI_BASE_URL = "https://serpapi.com/search"

def fetch_serp_data(keyword: str) -> Dict[str, Any]:
    """Fetch SERP data for a single keyword using SerpApi."""
    params = {
        "api_key": SERPAPI_KEY,
        "q": keyword,
        "engine": "google",
        "num": 10,  # Top 10 results
        "gl": "us",  # Geographic location
        "hl": "en"   # Language
    }

    try:
        response = requests.get(SERPAPI_BASE_URL, params=params)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"  ERROR fetching SERP data for '{keyword}': {e}")
        return {}

def fetch_autocomplete(keyword: str) -> List[str]:
    """Fetch Google Autocomplete suggestions."""
    params = {
        "api_key": SERPAPI_KEY,
        "q": keyword,
        "engine": "google_autocomplete"
    }

    try:
        response = requests.get(SERPAPI_BASE_URL, params=params)
        response.raise_for_status()
        data = response.json()
        return [suggestion.get("value", "") for suggestion in data.get("suggestions", [])]
    except Exception as e:
        print(f"  WARNING: Could not fetch autocomplete for '{keyword}': {e}")
        return []

def extract_paa_questions(serp_data: Dict) -> List[str]:
    """Extract People Also Ask (PAA) questions from SERP data."""
    paa_questions = []

    if "related_questions" in serp_data:
        for question_data in serp_data["related_questions"]:
            if "question" in question_data:
                paa_questions.append(question_data["question"])

    return paa_questions

def extract_related_searches(serp_data: Dict) -> List[str]:
    """Extract Related Searches from SERP data."""
    related_searches = []

    if "related_searches" in serp_data:
        for search_data in serp_data["related_searches"]:
            if "query" in search_data:
                related_searches.append(search_data["query"])

    return related_searches

def analyze_competition(serp_data: Dict) -> Dict[str, Any]:
    """Analyze top 10 SERP competitors."""
    organic_results = serp_data.get("organic_results", [])[:10]

    analysis = {
        "total_results": len(organic_results),
        "domains": [],
        "content_types": [],
        "quality_signals": {
            "has_featured_snippet": "featured_snippet" in serp_data,
            "has_knowledge_panel": "knowledge_graph" in serp_data,
            "avg_domain_authority": None  # Would need additional API for DA
        }
    }

    for result in organic_results:
        domain = result.get("link", "").split("/")[2] if result.get("link") else "unknown"
        analysis["domains"].append({
            "position": result.get("position", 0),
            "domain": domain,
            "title": result.get("title", ""),
            "snippet": result.get("snippet", "")
        })

        # Detect content type from URL/title
        link = result.get("link", "").lower()
        title = result.get("title", "").lower()

        if any(word in link or word in title for word in ["guide", "tutorial", "how-to"]):
            analysis["content_types"].append("guide")
        elif any(word in link or word in title for word in ["blog", "article"]):
            analysis["content_types"].append("blog_post")
        elif any(word in link or word in title for word in ["forum", "reddit", "stackoverflow"]):
            analysis["content_types"].append("forum")
        else:
            analysis["content_types"].append("other")

    return analysis

def validate_keyword(keyword: str) -> Dict[str, Any]:
    """Validate a single keyword by fetching all SERP data."""
    print(f"  Validating: {keyword}")

    # Fetch main SERP data
    serp_data = fetch_serp_data(keyword)
    time.sleep(1)  # Rate limiting

    # Fetch autocomplete suggestions
    autocomplete = fetch_autocomplete(keyword)
    time.sleep(1)  # Rate limiting

    # Extract validation data
    validation_result = {
        "keyword": keyword,
        "paa_questions": extract_paa_questions(serp_data),
        "autocomplete_suggestions": autocomplete,
        "related_searches": extract_related_searches(serp_data),
        "competition_analysis": analyze_competition(serp_data),
        "raw_serp_data": serp_data  # Include for AI analysis in Phase 3
    }

    print(f"    OK - PAA: {len(validation_result['paa_questions'])} | "
          f"Autocomplete: {len(autocomplete)} | "
          f"Related: {len(validation_result['related_searches'])}")

    return validation_result

def main():
    if len(sys.argv) != 2:
        print("Usage: python scripts/validate_keywords.py <seed_keywords_file>")
        print("Example: python scripts/validate_keywords.py .pseo-projects/odoo-implementation/seed_keywords.txt")
        sys.exit(1)

    seed_file = Path(sys.argv[1])

    if not seed_file.exists():
        print(f"ERROR: File not found: {seed_file}")
        sys.exit(1)

    # Read seed keywords
    with open(seed_file, 'r', encoding='utf-8') as f:
        keywords = [line.strip() for line in f if line.strip()]

    print(f"\nPhase 2: Keyword Validation (SerpApi)")
    print(f"Input: {seed_file}")
    print(f"Keywords to validate: {len(keywords)}\n")

    # Validate each keyword
    validated_keywords = []
    for i, keyword in enumerate(keywords, 1):
        print(f"[{i}/{len(keywords)}]", end=" ")
        result = validate_keyword(keyword)
        validated_keywords.append(result)

    # Save results
    output_file = seed_file.parent / "validated_keywords.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump({
            "metadata": {
                "source_file": str(seed_file),
                "total_keywords": len(keywords),
                "validated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                "api_used": "SerpApi"
            },
            "keywords": validated_keywords
        }, f, indent=2, ensure_ascii=False)

    print(f"\nValidation Complete!")
    print(f"Output: {output_file}")
    print(f"\nNext Step: AI analysis (Phase 3)")
    print(f"   The AI agent will now read {output_file.name} and generate the final research report.\n")

if __name__ == "__main__":
    main()
