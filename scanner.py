"""Black Cube Code ScannerFX - TCP server untuk EA MT5."""
from __future__ import annotations
import argparse, configparser, json, logging, os, socket, sys
import threading, time, traceback, uuid
from collections import deque
from pathlib import Path
from typing import Dict, Optional

from protocol import (Bar, Tick, Account, OrderReply, parse_line, encode_order)
from strategy import breakout_signal

LOG = logging.getLogger("scanner")
APP_NAME = "BlackCubeScannerFX"
APP_VER  = "1.11"

DEFAULT_CFG = {
    "host":"0.0.0.0","port":"5555","magic":"555501",
    "symbol":"XAUUSD","digits":"2","point":"0.01",
    "account_login":"0","history_bars":"1000",
    "breakout_lookback":"30","atr_period":"14",
    "atr_mult_sl":"1.8","atr_mult_tp":"3.6",
    "risk_lot":"0.01","min_spread_points":"0",
    "max_spread_points":"60","cooldown_bars":"3",
    "allow_buy":"true","allow_sell":"true","log_level":"INFO",
}

def _exe_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).parent
    return Path(__file__).resolve().parent

def load_config(path_arg: Optional[str]) -> dict:
    cfg_path = Path(path_arg) if path_arg else (_exe_dir() / "config.ini")
    if not cfg_path.exists():
        cp = configparser.ConfigParser()
        cp["scanner"] = DEFAULT_CFG
        with open(cfg_path, "w", encoding="utf-8") as f:
            f.write("# Black Cube ScannerFX configuration\n")
            f.write("# Edit nilai di bawah lalu restart aplikasi.\n\n")
            cp.write(f)
        LOG.info("Created default config: %s", cfg_path)
    cp = configparser.ConfigParser()
    cp.read(cfg_path, encoding="utf-8")
    if "scanner" not in cp:
        raise SystemExit(f"config.ini tidak punya section [scanner]: {cfg_path}")
    s = cp["scanner"]
    out = {}
    ints   = {"port","magic","digits","account_login","history_bars",
              "breakout_lookback","atr_period","max_spread_points",
              "min_spread_points","cooldown_bars"}
    floats = {"point","atr_mult_sl","atr_mult_tp","risk_lot"}
    bools  = {"allow_buy","allow_sell"}
    for k, v in s.items():
        v = v.strip()
        if k in ints:   out[k] = int(v)
        elif k in floats: out[k] = float(v)
        elif k in bools:  out[k] = v.lower() in ("1","true","yes","on","y")
        else:             out[k] = v
    return out

class Session:
    def __init__(self, sock, addr, cfg):
        self.sock = sock; self.addr = addr; self.cfg = cfg
        self.rx = b""; self.tx_lock = threading.Lock()
        self.bars = deque(maxlen=int(cfg["history_bars"]))
        self.last_tick = None; self.last_account = None
        self.symbol = cfg["symbol"]; self.digits = int(cfg["digits"])
        self.point = float(cfg["point"]); self.magic = int(cfg["magic"])
        self.account_login = int(cfg["account_login"])
        self.pending = {}; self.last_signal_bar_ts = 0
        self.closed = False; self.rx_lines = 0; self.rx_bars = 0

    def send(self, data):
        with self.tx_lock:
            try:
                self.sock.sendall(data); return True
            except OSError as e:
                LOG.warning("send fail %s: %s", self.addr, e)
                self.closed = True; return False

    def send_order(self, req, reason):
        oid = uuid.uuid4().hex[:12]
        data = encode_order(oid, req.side, req.lot, req.sl, req.tp, self.digits)
        self.pending[oid] = {"req": req, "reason": reason, "ts": time.time()}
        LOG.info("SEND %s %s lot=%.2f sl=%.5f tp=%.5f (%s)",
                 oid, req.side, req.lot, req.sl, req.tp, reason)
        if not self.send(data): self.pending.pop(oid, None)
        return oid

    def run(self):
        try:
            while not self.closed:
                try: chunk = self.sock.recv(4096)
                except OSError: break
                if not chunk: break
                self.rx += chunk
                if len(self.rx) > 2_000_000:
                    LOG.error("RX overflow %s size=%d", self.addr, len(self.rx)); break
                self._drain()
        except Exception:
            LOG.error("session exception %s:\n%s", self.addr, traceback.format_exc())
        finally:
            self.closed = True
            try: self.sock.close()
            except OSError: pass
            LOG.info("session closed %s (rx_lines=%d, rx_bars=%d)",
                     self.addr, self.rx_lines, self.rx_bars)

    def _drain(self):
        while b"\n" in self.rx:
            raw, self.rx = self.rx.split(b"\n", 1)
            self.rx_lines += 1
            try:
                line = raw.decode("utf-8", errors="replace")
                kind, payload = parse_line(line)
                if kind == "?": continue
                self._handle(kind, payload)
            except Exception as e:
                LOG.error("drain exception: %s | line=%r", e, raw[:300])
                LOG.error(traceback.format_exc())

    def _handle(self, kind, payload):
        try:
            if kind == "I":
                self.symbol = payload["symbol"]; self.digits = payload["digits"]
                self.point = payload["point"]; self.magic = payload["magic"]
                self.account_login = payload["account_login"]
                LOG.info("HELLO %s sym=%s digits=%d magic=%d login=%d",
                         self.addr, self.symbol, self.digits,
                         self.magic, self.account_login); return
            if kind == "B":
                added = 0
                for b in payload:
                    if self.bars and b.ts_ms <= self.bars[-1].ts_ms: continue
                    self.bars.append(b); added += 1
                self.rx_bars += added
                if added: LOG.info("received %d bars (total=%d)", added, len(self.bars))
                if payload and payload[-1].ts_ms > self.last_signal_bar_ts:
                    self._maybe_signal()
                return
            if kind == "T": self.last_tick = payload; return
            if kind == "A": self.last_account = payload; return
            if kind == "R":
                rep = payload
                self.pending.pop(rep.order_id, None)
                if rep.status == "OK":
                    LOG.info("FILL %s ticket=%s", rep.order_id, rep.detail)
                else:
                    LOG.warning("REJECT %s %s", rep.order_id, rep.detail)
                return
            if kind == "P": return
        except Exception as e:
            LOG.error("handle(%s) exception: %s | payload=%r",
                      kind, e, str(payload)[:200])
            LOG.error(traceback.format_exc())

    def _maybe_signal(self):
        if not self.bars or not self.last_tick: return
        if len(self.bars) < int(self.cfg["breakout_lookback"]) + 2: return
        last_ts = self.bars[-1].ts_ms
        if last_ts <= self.last_signal_bar_ts: return
        self.last_signal_bar_ts = last_ts
        try:
            req = breakout_signal(list(self.bars), self.last_tick, self.cfg)
        except Exception as e:
            LOG.error("strategy exception: %s\n%s", e, traceback.format_exc()); return
        if req is None: return
        self.send_order(req, req.reason)

class Server:
    def __init__(self, cfg):
        self.cfg = cfg; self.sessions = []; self.sessions_lock = threading.Lock()

    def serve_forever(self):
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind((self.cfg["host"], int(self.cfg["port"])))
        srv.listen(8)
        LOG.info("%s v%s listening on %s:%d", APP_NAME, APP_VER,
                 self.cfg["host"], int(self.cfg["port"]))
        LOG.info("symbol=%s digits=%d point=%s lot=%s breakout=%d",
                 self.cfg["symbol"], int(self.cfg["digits"]),
                 self.cfg["point"], self.cfg["risk_lot"],
                 int(self.cfg["breakout_lookback"]))
        LOG.info("Tekan Ctrl+C untuk stop.")
        try:
            while True:
                client, addr = srv.accept()
                client.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                client.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
                LOG.info("accept %s", addr)
                sess = Session(client, addr, self.cfg)
                with self.sessions_lock: self.sessions.append(sess)
                threading.Thread(target=self._wrap, args=(sess,), daemon=True).start()
        except KeyboardInterrupt:
            LOG.info("shutdown by user")
        finally:
            srv.close()

    def _wrap(self, sess):
        try: sess.run()
        finally:
            with self.sessions_lock:
                if sess in self.sessions: self.sessions.remove(sess)

def main():
    ap = argparse.ArgumentParser(description="Black Cube ScannerFX")
    ap.add_argument("--config", default=None)
    ap.add_argument("--log", default=None)
    args = ap.parse_args()

    exe_dir = _exe_dir()
    log_path = Path(args.log) if args.log else (exe_dir / "scanner.log")

    handlers = [logging.StreamHandler(sys.stdout)]
    try: handlers.append(logging.FileHandler(log_path, encoding="utf-8"))
    except OSError: pass
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(levelname)s %(message)s",
                        handlers=handlers)

    LOG.info("=" * 60)
    LOG.info("%s v%s starting", APP_NAME, APP_VER)
    LOG.info("EXE dir : %s", exe_dir)
    LOG.info("Log file: %s", log_path)

    try: cfg = load_config(args.config)
    except Exception as e:
        LOG.error("Config error: %s", e); sys.exit(1)

    try: Server(cfg).serve_forever()
    except OSError as e:
        LOG.error("Port %s tidak bisa dibuka: %s", cfg.get("port"), e)
        LOG.error("Mungkin scanner lain sedang jalan. Tutup lalu coba lagi.")
        sys.exit(2)

if __name__ == "__main__":
    main()