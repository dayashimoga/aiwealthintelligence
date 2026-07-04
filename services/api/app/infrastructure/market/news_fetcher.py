"""Market news fetcher utilizing RSS feeds and AI sentiment analysis.

Retrieves general market and symbol-specific financial news from public RSS feeds,
then uses the AI provider to analyze sentiment and generate summaries.
"""

from __future__ import annotations

import asyncio
import urllib.parse
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

import httpx
import structlog
from bs4 import BeautifulSoup

from app.domain.entities import MarketNews
from app.infrastructure.ai.ai_provider import get_ai_provider

logger = structlog.get_logger(__name__)

# Google News RSS search template for Indian market
RSS_MARKET_URL = "https://news.google.com/rss/search?q=Indian+stock+market+Nifty+Sensex&hl=en-IN&gl=IN&ceid=IN:en"
RSS_SYMBOL_TEMPLATE = "https://news.google.com/rss/search?q={symbol}+stock+finance+India&hl=en-IN&gl=IN&ceid=IN:en"


async def fetch_rss_news(symbol: str | None = None, limit: int = 10) -> list[dict[str, Any]]:
    """Fetch raw news articles from public RSS feeds."""
    url = RSS_MARKET_URL
    if symbol:
        q = urllib.parse.quote(f"{symbol} stock finance India")
        url = f"https://news.google.com/rss/search?q={q}&hl=en-IN&gl=IN&ceid=IN:en"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            text = resp.text
            
            root = ET.fromstring(text)
            items = root.findall(".//item")
            
            articles = []
            for item in items[:limit]:
                title = item.find("title")
                link = item.find("link")
                pub_date = item.find("pubDate")
                source = item.find("source")
                desc = item.find("description")
                
                # Strip HTML from description if present
                clean_desc = ""
                if desc is not None and desc.text:
                    soup = BeautifulSoup(desc.text, "html.parser")
                    clean_desc = soup.get_text()

                pub_str = pub_date.text if pub_date is not None else None
                try:
                    # Parse standard RSS date format: "Sat, 04 Jul 2026 09:12:00 GMT"
                    pub_dt = datetime.strptime(pub_str, "%a, %d %b %Y %H:%M:%S %Z").replace(tzinfo=timezone.utc)
                except Exception:
                    pub_dt = datetime.now(timezone.utc)

                articles.append({
                    "title": title.text if title is not None else "",
                    "url": link.text if link is not None else "",
                    "published_at": pub_dt,
                    "source": source.text if source is not None else "Google News",
                    "description": clean_desc,
                })
            return articles
    except Exception as e:
        logger.warning("rss_fetch_failed", symbol=symbol, error=str(e))
        return []


async def analyze_news_sentiment(title: str, description: str) -> dict[str, Any]:
    """Use AI provider to summarize and extract sentiment/relevance from news."""
    provider = get_ai_provider()
    
    prompt = f"""You are a financial analyst AI. Analyze this news article headline and description.
Title: {title}
Description: {description}

Provide your analysis in JSON format with these exact keys:
1. sentiment: One of "positive", "negative", "neutral"
2. relevance_score: Value from 0.0 to 10.0 (how relevant it is to stock prices/investments)
3. summary: A clean one-sentence summary of the news
4. sectors: A list of affected sectors (e.g. ["Technology", "Financial Services"])
5. symbols: A list of affected stock symbols (e.g. ["RELIANCE", "TCS"])

Return ONLY the JSON block. Do not include markdown code block formatting."""

    try:
        response = await provider.complete(
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"}
        )
        import json
        data = json.loads(response)
        return {
            "sentiment": data.get("sentiment", "neutral"),
            "relevance_score": float(data.get("relevance_score", 5.0)),
            "summary": data.get("summary", title),
            "sectors": data.get("sectors", []),
            "symbols": data.get("symbols", []),
        }
    except Exception as e:
        logger.debug("news_ai_analysis_failed", error=str(e))
        # Fallback if AI fails or key is missing
        return {
            "sentiment": "neutral",
            "relevance_score": 5.0,
            "summary": title,
            "sectors": [],
            "symbols": [],
        }


async def fetch_and_analyze_news(symbol: str | None = None, limit: int = 5) -> list[MarketNews]:
    """Fetch raw news articles and perform AI analysis to return MarketNews objects."""
    raw_articles = await fetch_rss_news(symbol, limit=limit)
    
    news_items = []
    for art in raw_articles:
        analysis = await analyze_news_sentiment(art["title"], art["description"])
        
        item = MarketNews(
            title=art["title"],
            summary=analysis["summary"],
            source=art["source"],
            url=art["url"],
            sentiment=analysis["sentiment"],
            relevance_score=Decimal(str(analysis["relevance_score"])),
            sectors=analysis["sectors"],
            symbols=analysis["symbols"] if symbol is None else [symbol.upper()],
            published_at=art["published_at"],
            fetched_at=datetime.now(timezone.utc),
        )
        news_items.append(item)
    return news_items
