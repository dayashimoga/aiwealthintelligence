"""Market data service using yfinance for financial metrics and historical data.

Includes stock and mutual fund info, charts, fundamentals, financial statements,
analyst estimates, and macro indicators, running synchronously blocked calls in threads.
"""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime
from typing import Any

import structlog
import yfinance as yf

logger = structlog.get_logger(__name__)


def _format_symbol(symbol: str, asset_type: str = "stock") -> str:
    """Format symbol for Yahoo Finance."""
    sym = symbol.strip().upper()
    # If mutual fund and doesn't have suffix, or if standard Indian stock without extension
    if asset_type == "mutual_fund":
        # Indian mutual funds on Yahoo Finance often end with .BO (BSE)
        if not (sym.endswith(".BO") or sym.endswith(".NS")):
            # Common suffix or try both, let's default to .BO for mutual funds
            return f"{sym}.BO"
        return sym

    # Stocks: Default to .NS (NSE) if no extension is present
    if not (sym.endswith(".NS") or sym.endswith(".BO") or sym.endswith(".BO") or "^" in sym):
        return f"{sym}.NS"
    return sym


class YFinanceMarketDataService:
    """Service to fetch market intelligence from Yahoo Finance."""

    async def get_live_price(self, symbol: str, asset_type: str = "stock") -> float:
        """Fetch real-time or near real-time price for a symbol."""
        formatted = _format_symbol(symbol, asset_type)
        try:
            # Run in threadpool as yfinance is blocking
            ticker = yf.Ticker(formatted)
            fast_info = await asyncio.to_thread(lambda: ticker.fast_info)
            price = fast_info.get("lastPrice", None)
            if price is None:
                # Fallback to history
                hist = await asyncio.to_thread(lambda: ticker.history(period="1d"))
                price = float(hist["Close"].iloc[-1]) if not hist.empty else 0.0
            return float(price)
        except Exception as e:
            logger.warning(
                "yfinance_price_fetch_failed", symbol=symbol, formatted=formatted, error=str(e)
            )
            return 0.0

    async def get_fundamental_data(self, symbol: str, asset_type: str = "stock") -> dict[str, Any]:
        """Fetch company fundamentals (PE, Market Cap, Beta, etc.)."""
        formatted = _format_symbol(symbol, asset_type)
        try:
            ticker = yf.Ticker(formatted)
            info = await asyncio.to_thread(lambda: ticker.info)

            return {
                "pe_ratio": info.get("trailingPE"),
                "forward_pe": info.get("forwardPE"),
                "peg_ratio": info.get("pegRatio"),
                "price_to_book": info.get("priceToBook"),
                "market_cap": info.get("marketCap"),
                "dividend_yield": info.get("dividendYield", 0.0) * 100
                if info.get("dividendYield")
                else 0.0,
                "beta": info.get("beta"),
                "eps": info.get("trailingEps"),
                "book_value": info.get("bookValue"),
                "fifty_two_week_high": info.get("fiftyTwoWeekHigh"),
                "fifty_two_week_low": info.get("fiftyTwoWeekLow"),
                "average_volume": info.get("averageVolume"),
                "sector": info.get("sector", ""),
                "industry": info.get("industry", ""),
                "summary": info.get("longBusinessSummary", ""),
            }
        except Exception as e:
            logger.warning("yfinance_fundamentals_fetch_failed", symbol=symbol, error=str(e))
            return {}

    async def get_historical_prices(
        self, symbol: str, period: str = "1y", interval: str = "1d"
    ) -> list[dict[str, Any]]:
        """Fetch historical prices for charts."""
        formatted = _format_symbol(symbol)
        try:
            ticker = yf.Ticker(formatted)
            hist = await asyncio.to_thread(lambda: ticker.history(period=period, interval=interval))

            prices = []
            for index, row in hist.iterrows():
                prices.append(
                    {
                        "date": index.strftime("%Y-%m-%d"),
                        "open": float(row["Open"]),
                        "high": float(row["High"]),
                        "low": float(row["Low"]),
                        "close": float(row["Close"]),
                        "volume": int(row["Volume"]),
                    }
                )
            return prices
        except Exception as e:
            logger.warning("yfinance_history_fetch_failed", symbol=symbol, error=str(e))
            return []

    async def get_financial_statements(
        self, symbol: str, asset_type: str = "stock"
    ) -> dict[str, Any]:
        """Fetch income statement, balance sheet, and cash flow statements."""
        formatted = _format_symbol(symbol, asset_type)
        try:
            ticker = yf.Ticker(formatted)

            # Helper to convert pandas dataframe to dictionary
            def df_to_dict(df):
                if df is None or df.empty:
                    return {}
                res = {}
                for col in df.columns:
                    col_str = col.strftime("%Y-%m-%d") if hasattr(col, "strftime") else str(col)
                    res[col_str] = {
                        str(k): float(v) if not isinstance(v, str) else v
                        for k, v in df[col].dropna().items()
                    }
                return res

            financials = await asyncio.to_thread(lambda: ticker.financials)
            balance_sheet = await asyncio.to_thread(lambda: ticker.balance_sheet)
            cashflow = await asyncio.to_thread(lambda: ticker.cashflow)

            return {
                "income_statement": df_to_dict(financials),
                "balance_sheet": df_to_dict(balance_sheet),
                "cashflow": df_to_dict(cashflow),
            }
        except Exception as e:
            logger.warning("yfinance_financials_fetch_failed", symbol=symbol, error=str(e))
            return {"income_statement": {}, "balance_sheet": {}, "cashflow": {}}

    async def get_corporate_actions(self, symbol: str) -> dict[str, Any]:
        """Fetch dividends, splits, and earnings dates."""
        formatted = _format_symbol(symbol)
        try:
            ticker = yf.Ticker(formatted)
            dividends = await asyncio.to_thread(lambda: ticker.dividends)
            splits = await asyncio.to_thread(lambda: ticker.splits)

            div_list = []
            if not dividends.empty:
                for idx, val in dividends.items():
                    div_list.append({"date": idx.strftime("%Y-%m-%d"), "value": float(val)})

            split_list = []
            if not splits.empty:
                for idx, val in splits.items():
                    split_list.append({"date": idx.strftime("%Y-%m-%d"), "ratio": str(val)})

            return {
                "dividends": div_list[-10:],  # last 10
                "splits": split_list,
            }
        except Exception as e:
            logger.warning("yfinance_actions_fetch_failed", symbol=symbol, error=str(e))
            return {"dividends": [], "splits": []}

    async def get_analyst_estimates(self, symbol: str) -> dict[str, Any]:
        """Fetch analyst price targets and recommendations."""
        formatted = _format_symbol(symbol)
        try:
            ticker = yf.Ticker(formatted)
            info = await asyncio.to_thread(lambda: ticker.info)

            return {
                "target_high": info.get("targetHighPrice"),
                "target_low": info.get("targetLowPrice"),
                "target_mean": info.get("targetMeanPrice"),
                "target_median": info.get("targetMedianPrice"),
                "recommendation_key": info.get("recommendationKey"),
                "number_of_analysts": info.get("numberOfAnalystOpinions"),
            }
        except Exception as e:
            logger.warning("yfinance_estimates_fetch_failed", symbol=symbol, error=str(e))
            return {}

    async def get_ticker_news(self, symbol: str) -> list[dict[str, Any]]:
        """Fetch recent news for a specific ticker."""
        formatted = _format_symbol(symbol)
        try:
            ticker = yf.Ticker(formatted)
            news = await asyncio.to_thread(lambda: ticker.news)

            results = []
            for item in news or []:
                # Convert news structure to standardized format
                published = item.get("providerPublishTime")
                pub_dt = datetime.fromtimestamp(published, UTC) if published else datetime.now(UTC)

                results.append(
                    {
                        "id": item.get("uuid", ""),
                        "title": item.get("title", ""),
                        "summary": item.get("summary", ""),
                        "source": item.get("publisher", ""),
                        "url": item.get("link", ""),
                        "published_at": pub_dt.isoformat(),
                    }
                )
            return results
        except Exception as e:
            logger.warning("yfinance_news_fetch_failed", symbol=symbol, error=str(e))
            return []

    async def get_index_performance(self) -> dict[str, Any]:
        """Get performance metrics for major Indian indices (Nifty 50, Sensex)."""
        indices = {
            "NIFTY50": "^NSEI",
            "SENSEX": "^BSESN",
        }
        res = {}
        for name, sym in indices.items():
            try:
                ticker = yf.Ticker(sym)
                hist = await asyncio.to_thread(lambda: ticker.history(period="5d"))
                if not hist.empty and len(hist) >= 2:
                    current = float(hist["Close"].iloc[-1])
                    prev = float(hist["Close"].iloc[-2])
                    change = current - prev
                    change_pct = (change / prev) * 100
                    res[name] = {
                        "price": round(current, 2),
                        "change": round(change, 2),
                        "change_pct": round(change_pct, 2),
                        "history": [float(val) for val in hist["Close"].tolist()],
                    }
                else:
                    res[name] = {"price": 0.0, "change": 0.0, "change_pct": 0.0, "history": []}
            except Exception as e:
                logger.warning("yfinance_index_fetch_failed", index=name, error=str(e))
                res[name] = {"price": 0.0, "change": 0.0, "change_pct": 0.0, "history": []}
        return res

    async def get_macro_indicators(self) -> dict[str, Any]:
        """Fetch macro indicators (inflation, repo rate, US/India 10Y Yields) from World Bank and yfinance."""
        import httpx

        from app.infrastructure.market.price_cache import cache_repo

        cache_key = "market:macro_indicators"
        cached = await cache_repo.get(cache_key)
        if cached:
            return cached

        indicators = {
            "INDIA_10Y_BOND": "^IN10Y",
            "US_10Y_BOND": "^TNX",
        }
        res = {
            "inflation_rate": 4.8,
            "gdp_growth": 6.2,
            "repo_rate": 6.5,
            "india_10y_yield": 7.0,
            "us_10y_yield": 4.2,
        }

        # 1. Fetch bond yields from yfinance
        for key, sym in indicators.items():
            try:
                ticker = yf.Ticker(sym)
                fast_info = await asyncio.to_thread(lambda: ticker.fast_info)
                val = fast_info.get("lastPrice")
                if val:
                    if key == "INDIA_10Y_BOND":
                        res["india_10y_yield"] = round(float(val), 2)
                    elif key == "US_10Y_BOND":
                        res["us_10y_yield"] = round(float(val), 2)
            except Exception:
                pass

        # 2. Fetch Inflation and GDP growth from World Bank free APIs
        async with httpx.AsyncClient() as client:
            # India CPI Inflation
            try:
                inf_res = await client.get(
                    "http://api.worldbank.org/v2/country/IN/indicator/FP.CPI.TOTL.ZG?format=json",
                    timeout=5.0,
                )
                if inf_res.status_code == 200:
                    data = inf_res.json()
                    if len(data) > 1 and isinstance(data[1], list):
                        for obs in data[1]:
                            if obs.get("value") is not None:
                                res["inflation_rate"] = round(float(obs["value"]), 2)
                                break
            except Exception as e:
                logger.warning("worldbank_inflation_fetch_failed", error=str(e))

            # India GDP Growth
            try:
                gdp_res = await client.get(
                    "http://api.worldbank.org/v2/country/IN/indicator/NY.GDP.MKTP.KD.ZG?format=json",
                    timeout=5.0,
                )
                if gdp_res.status_code == 200:
                    data = gdp_res.json()
                    if len(data) > 1 and isinstance(data[1], list):
                        for obs in data[1]:
                            if obs.get("value") is not None:
                                res["gdp_growth"] = round(float(obs["value"]), 2)
                                break
            except Exception as e:
                logger.warning("worldbank_gdp_fetch_failed", error=str(e))

        # Cache in redis for 24 hours (86400 seconds)
        await cache_repo.set(cache_key, res, ttl=86400)
        return res


market_data_service = YFinanceMarketDataService()
