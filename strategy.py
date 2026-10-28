"""Black Cube Breakout strategy."""
from __future__ import annotations
from dataclasses import dataclass
from typing import List, Optional

from protocol import Bar, Tick


@dataclass
class OrderRequest:
    side: str
    lot: float
    sl: float
    tp: float
    reason: str = ""


def atr(bars: List[Bar], period: int) -> float:
    if len(bars) < period + 1:
        return 0.0
    trs = []
    for i in range(1, len(bars)):
        h, l, pc = bars[i].high, bars[i].low, bars[i-1].close
        trs.append(max(h - l, abs(h - pc), abs(l - pc)))
    return sum(trs[-period:]) / period


def breakout_signal(bars: List[Bar], tick: Tick, cfg: dict) -> Optional[OrderRequest]:
    look = int(cfg["breakout_lookback"])
    if len(bars) < look + 2:
        return None

    closed = bars[:-1]
    if len(closed) < look + 1:
        return None

    window = closed[-look:]
    hh = max(b.high for b in window)
    ll = min(b.low  for b in window)

    atr_v = atr(closed, int(cfg["atr_period"]))
    if atr_v <= 0:
        return None

    point = float(cfg["point"])
    digits = int(cfg["digits"])
    spread_pts = (tick.ask - tick.bid) / point if point > 0 else 0.0
    if spread_pts > float(cfg["max_spread_points"]):
        return None

    sl_dist = atr_v * float(cfg["atr_mult_sl"])
    tp_dist = atr_v * float(cfg["atr_mult_tp"])
    lot = float(cfg["risk_lot"])

    last_close = closed[-1].close
    prev_close = closed[-2].close

    if cfg["allow_buy"] and last_close > hh and prev_close <= hh:
        sl = tick.ask - sl_dist
        tp = tick.ask + tp_dist
        return OrderRequest("BUY", lot, round(sl, digits), round(tp, digits),
                            f"breakout>{hh:.{digits}f}")

    if cfg["allow_sell"] and last_close < ll and prev_close >= ll:
        sl = tick.bid + sl_dist
        tp = tick.bid - tp_dist
        return OrderRequest("SELL", lot, round(sl, digits), round(tp, digits),
                            f"breakout<{ll:.{digits}f}")

    return None
