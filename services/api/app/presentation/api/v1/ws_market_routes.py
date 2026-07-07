"""WebSocket endpoint for real-time market price streaming.

Endpoint: GET /ws/market/prices?symbols=TCS,INFY,RELIANCE
- Sends price snapshots every `interval` seconds (default 5s, min 2s, max 60s)
- Accepts JSON messages: {"action": "subscribe", "symbols": [...]} or {"action": "ping"}
- Connection is JWT-authenticated via query param `token`
- Gracefully closes on auth failure or client disconnect
"""

from __future__ import annotations

import asyncio
import json
from datetime import UTC, datetime

import structlog
import yfinance as yf
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from fastapi.websockets import WebSocketState

from app.shared.security import decode_token

logger = structlog.get_logger(__name__)
router = APIRouter()

_DEFAULT_SYMBOLS = ["^NSEI", "^BSESN"]  # NIFTY50, SENSEX


async def _fetch_prices(symbols: list[str]) -> dict[str, dict]:
    """Fetch latest price data for a list of symbols using yfinance."""
    result: dict[str, dict] = {}
    try:
        raw_symbols = " ".join(s + ".NS" if not s.startswith("^") else s for s in symbols)
        data = await asyncio.to_thread(
            lambda: yf.download(
                raw_symbols,
                period="1d",
                interval="1m",
                progress=False,
                auto_adjust=True,
            )
        )
        if data.empty:
            return result

        for sym in symbols:
            yf_sym = sym + ".NS" if not sym.startswith("^") else sym
            try:
                if "Close" in data.columns:
                    close_col = data["Close"]
                    if hasattr(close_col, "columns"):
                        # Multi-ticker download
                        if yf_sym in close_col.columns:
                            price = float(close_col[yf_sym].dropna().iloc[-1])
                        else:
                            continue
                    else:
                        price = float(close_col.dropna().iloc[-1])

                    result[sym] = {
                        "symbol": sym,
                        "price": round(price, 2),
                        "ts": datetime.now(UTC).isoformat(),
                    }
            except Exception:
                pass
    except Exception as e:
        logger.debug("ws_price_fetch_error", error=str(e))
    return result


@router.websocket("/ws/market/prices")
async def ws_market_prices(
    websocket: WebSocket,
    token: str | None = Query(default=None),
    symbols: str | None = Query(default=None),
    interval: int = Query(default=5, ge=2, le=60),
) -> None:
    """Stream real-time market prices over WebSocket.

    Query params:
    - token: JWT access token for authentication
    - symbols: comma-separated list of symbols (e.g. TCS,INFY,RELIANCE)
    - interval: push interval in seconds (2-60, default 5)

    Message format (server -> client):
    {
      "type": "prices",
      "data": {"TCS": {"symbol": "TCS", "price": 3500.0, "ts": "..."}, ...},
      "ts": "2026-07-07T..."
    }
    """
    # Validate auth
    if not token:
        await websocket.close(code=4001, reason="Missing authentication token")
        return

    try:
        claims = decode_token(token)
        user_id = claims.get("sub") if claims else None
        if not user_id:
            raise ValueError("Invalid token")
    except Exception:
        await websocket.close(code=4003, reason="Invalid or expired token")
        return

    await websocket.accept()

    # Initial symbol list from query param
    watched: list[str] = (
        [s.strip().upper() for s in symbols.split(",") if s.strip()]
        if symbols
        else list(_DEFAULT_SYMBOLS)
    )

    logger.info("ws_price_stream_connected", user_id=user_id, symbols=watched)

    try:
        while websocket.client_state == WebSocketState.CONNECTED:
            # Non-blocking check for incoming client messages
            try:
                raw = await asyncio.wait_for(websocket.receive_text(), timeout=0.1)
                msg = json.loads(raw)
                action = msg.get("action")
                if action == "subscribe" and "symbols" in msg:
                    new_syms = [s.strip().upper() for s in msg["symbols"] if s.strip()]
                    if new_syms:
                        watched = new_syms
                        logger.debug(
                            "ws_subscription_updated",
                            user_id=user_id,
                            symbols=watched,
                        )
                elif action == "ping":
                    await websocket.send_json({"type": "pong", "ts": datetime.now(UTC).isoformat()})
            except TimeoutError:
                pass  # No incoming message — continue to push prices
            except json.JSONDecodeError:
                pass  # Ignore malformed messages

            # Fetch and push prices
            prices = await _fetch_prices(watched)
            await websocket.send_json(
                {
                    "type": "prices",
                    "data": prices,
                    "symbols": watched,
                    "ts": datetime.now(UTC).isoformat(),
                }
            )

            # Wait for next interval
            await asyncio.sleep(interval)

    except WebSocketDisconnect:
        logger.info("ws_price_stream_disconnected", user_id=user_id)
    except Exception as e:
        logger.warning("ws_price_stream_error", user_id=user_id, error=str(e))
        if websocket.client_state == WebSocketState.CONNECTED:
            await websocket.close(code=1011, reason="Internal error")
