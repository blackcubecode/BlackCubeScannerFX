"""
Black Cube Code ScannerFX - line protocol.
Sinkron dengan EA MT5 v1.11.
"""
from __future__ import annotations
import time
from dataclasses import dataclass
from typing import Optional


@dataclass
class Bar:
    ts_ms: int
    open: float
    high: float
    low: float
    close: float
    spread: float = 0.0

    @property
    def ts(self) -> float:
        return self.ts_ms / 1000.0


@dataclass
class Tick:
    ts_ms: int
    bid: float
    ask: float


@dataclass
class Account:
    balance: float
    equity: float
    margin: float
    free_margin: float
    profit: float


@dataclass
class OrderReply:
    order_id: str
    status: str
    detail: str
    ts: float = 0.0

    def __post_init__(self):
        if not self.ts:
            self.ts = time.time()


def parse_line(line: str):
    line = line.strip()
    if not line:
        return ("?", None)
    parts = line.split("|")
    kind = parts[0]

    if kind == "I" and len(parts) >= 6:
        try:
            return ("I", {
                "symbol": parts[1],
                "digits": int(parts[2]),
                "point": float(parts[3]),
                "magic": int(parts[4]),
                "account_login": int(parts[5]),
            })
        except (ValueError, IndexError):
            return ("?", line)

    if kind == "B" and len(parts) >= 2:
        bars = []
        bad = 0
        for chunk in parts[1].split(";"):
            chunk = chunk.strip()
            if not chunk:
                continue
            try:
                f = chunk.split(",")
                if len(f) < 5:
                    bad += 1
                    continue
                bars.append(Bar(
                    ts_ms=int(f[0]),
                    open=float(f[1]),
                    high=float(f[2]),
                    low=float(f[3]),
                    close=float(f[4]),
                    spread=float(f[5]) if len(f) > 5 else 0.0,
                ))
            except (ValueError, IndexError):
                bad += 1
                continue
        if bad:
            return ("B", bars)  # tetap kirim bar yang valid; bad diabaikan
        return ("B", bars)

    if kind == "T" and len(parts) >= 2:
        try:
            f = parts[1].split(",")
            if len(f) >= 3:
                return ("T", Tick(ts_ms=int(f[0]), bid=float(f[1]), ask=float(f[2])))
        except (ValueError, IndexError):
            return ("?", line)

    if kind == "A" and len(parts) >= 2:
        try:
            f = parts[1].split(",")
            if len(f) >= 5:
                return ("A", Account(
                    balance=float(f[0]), equity=float(f[1]),
                    margin=float(f[2]), free_margin=float(f[3]), profit=float(f[4]),
                ))
        except (ValueError, IndexError):
            return ("?", line)

    if kind == "R" and len(parts) >= 4:
        return ("R", OrderReply(order_id=parts[1], status=parts[2], detail=parts[3]))

    if kind == "P" and len(parts) >= 2:
        return ("P", parts[1])  # heartbeat

    return ("?", line)


def encode_order(order_id: str, side: str, lot: float,
                 sl: float, tp: float, digits: int) -> bytes:
    side = side.upper()
    assert side in ("BUY", "SELL")
    fmt = f"%.{digits}f"
    line = f"O|{order_id}|{side}|{lot:.2f}|{fmt % sl}|{fmt % tp}\n"
    return line.encode("utf-8")