//+------------------------------------------------------------------+
//| Black Cube Code ScannerFX Breakout Bridge v1.12 (XAUUSD)         |
//| Bugfix + hardening + debug logging.                              |
//| v1.12: Dashboard panel profesional (chart objects, x=10 y=100).  |
//| Python scanner remains signal provider.                          |
//+------------------------------------------------------------------+
#property description "EA bridge TCP Black Cube Code Scanner signals (XAUUSD hardened)"
#property description "------------------------------------------------------------------"
#property description "Not Financial Advice. Past performance does not guarantee profit future."
#property description "------------------------------------------------------------------"
#property description "Free Signal Trading XAUUSD : t.me/blackcubecode"
#property description "Free Bot Trading AI XAUUSD : t.me/blackcubecodeAI_bot"
#property icon "bcc.ico"
#property version   "1.12"
#property strict


#include <Trade/Trade.mqh>
CTrade trade;

//--- Input ---------------------------------------------------------
input string InpScannerHost        = "127.0.0.1";
input int    InpScannerPort        = 5555;
input long   InpMagic              = 555501;
input int    InpHistoryM1Bars      = 1000;
input int    InpMaxSpreadPoints    = 60;       // XAUUSD: 60 poin = $0.60
input int    InpDeviationPoints    = 30;
input bool   InpAllowBuy           = true;
input bool   InpAllowSell          = true;
input bool   InpOnePositionOnly    = true;
input bool   InpUseScannerLot      = false;    // uji pakai fixed lot
input double InpFixedLot           = 0.01;
input bool   InpUseScannerSLTP     = true;
input int    InpFallbackSLPoints   = 2000;     // $20 di 2 digit
input int    InpFallbackTPPoints   = 4000;     // $40 di 2 digit
input int    InpTimerSeconds       = 1;
input bool   InpShowChartComment   = true;     // Tampilkan dashboard panel
input int    InpDashX              = 10;       // Posisi X dashboard (px)
input int    InpDashY              = 100;      // Posisi Y dashboard (px)
input int    InpReconnectMs        = 2000;
input int    InpTickThrottleMs     = 100;
input int    InpMaxRxBuffer        = 65536;
input int    InpHeartbeatSec       = 10;       // NEW: ping scanner
input bool   InpVerboseLog         = true;

//--- State ---------------------------------------------------------
int      g_socket = INVALID_HANDLE;
bool     g_connected = false;
datetime g_last_bar = 0;
datetime g_last_connect_attempt = 0;
ulong    g_last_tick_sent_msc = 0;
datetime g_last_heartbeat = 0;
string   g_rx_buffer = "";

//--- Helpers -------------------------------------------------------
string Num(double v, int digits=8) { return DoubleToString(v,digits); }

string Sanitize(const string s)
{
   string r = s;
   StringReplace(r,"|","/");
   StringReplace(r,"\n"," ");
   StringReplace(r,"\r"," ");
   return r;
}

void Log(const string s) { Print("[Bridge] ", s); }

//--- Socket I/O ----------------------------------------------------
void CloseSocket()
{
   if(g_socket != INVALID_HANDLE) SocketClose(g_socket);
   g_socket = INVALID_HANDLE;
   g_connected = false;
}

bool SendLine(const string line)
{
   if(!g_connected || g_socket==INVALID_HANDLE) return false;

   uchar data[];
   string s = line + "\n";
   int copied = StringToCharArray(s, data, 0, -1, CP_UTF8);
   if(copied <= 1) return false;
   int n = copied - 1;

   int sent = SocketSend(g_socket, data, n);
   if(sent != n)
   {
      Log("SendLine FAILED sent=" + IntegerToString(sent) +
          " want=" + IntegerToString(n) +
          " err=" + IntegerToString(GetLastError()));
      CloseSocket();
      return false;
   }
   return true;
}

bool ConnectScanner()
{
   // throttle reconnect
   datetime now = TimeLocal();
   if(g_last_connect_attempt > 0 &&
      (now - g_last_connect_attempt) * 1000 < InpReconnectMs) return false;
   g_last_connect_attempt = now;

   CloseSocket();

   g_socket = SocketCreate(SOCKET_DEFAULT);
   if(g_socket == INVALID_HANDLE)
   {
      Log("SocketCreate FAILED err=" + IntegerToString(GetLastError()) +
          " (Algo Trading mati?)");
      return false;
   }
   Log("SocketCreate OK. Connecting to " + InpScannerHost + ":" +
       IntegerToString(InpScannerPort) + " ...");

   if(!SocketConnect(g_socket, InpScannerHost, InpScannerPort, 3000))
   {
      int err = GetLastError();
      Log("SocketConnect FAILED err=" + IntegerToString(err) +
          " host=" + InpScannerHost + " port=" + IntegerToString(InpScannerPort));
      CloseSocket();
      return false;
   }
   g_connected = true;
   Log("CONNECTED to " + InpScannerHost + ":" + IntegerToString(InpScannerPort));

   // HELLO
   string info = "I|" + _Symbol + "|" + IntegerToString(_Digits) + "|" +
                 Num(_Point,10) + "|" + IntegerToString(InpMagic) + "|" +
                 IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   Log("HELLO: " + info);
   if(!SendLine(info)) { Log("HELLO send failed"); CloseSocket(); return false; }

   SendHistory();
   Log("CONNECTED + HELLO + history sent OK");
   return true;
}

//--- History -------------------------------------------------------
void SendHistory()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int want = (int)MathMax(50, MathMin(InpHistoryM1Bars, 5000));
   int copied = CopyRates(_Symbol, PERIOD_M1, 1, want, rates);
   if(copied <= 0)
   {
      Log("CopyRates failed err=" + IntegerToString(GetLastError()));
      g_last_bar = 0;
      return;
   }
   string msg = "B|";
   for(int i = copied-1; i >= 0; i--)
   {
      long t = (long)rates[i].time * 1000;
      double sp = (rates[i].spread > 0 ? rates[i].spread : 0);
      msg += IntegerToString(t) + "," +
             Num(rates[i].open,_Digits)  + "," +
             Num(rates[i].high,_Digits)  + "," +
             Num(rates[i].low,_Digits)   + "," +
             Num(rates[i].close,_Digits) + "," +
             Num(sp,1) + ";";
   }
   if(!SendLine(msg)) { CloseSocket(); return; }
   g_last_bar = rates[0].time;
   Log("History sent: " + IntegerToString(copied) + " bars, last=" +
       TimeToString(g_last_bar, TIME_DATE|TIME_MINUTES));
}

//--- Periodic updates ----------------------------------------------
void SendNewBarIfNeeded()
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 1, 2, r) != 2) return;
   if(ArraySize(r) < 2) return;
   if(r[0].time == g_last_bar) return;
   g_last_bar = r[0].time;
   string msg = "B|" + IntegerToString((long)r[0].time*1000) + "," +
                Num(r[0].open,_Digits)  + "," +
                Num(r[0].high,_Digits)  + "," +
                Num(r[0].low,_Digits)   + "," +
                Num(r[0].close,_Digits) + "," +
                Num((r[0].spread>0?r[0].spread:0),1) + ";";
   if(!SendLine(msg)) CloseSocket();
}

void SendTick()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;

   ulong now_msc = (ulong)t.time_msc;
   if(g_last_tick_sent_msc > 0 &&
      (long)(now_msc - g_last_tick_sent_msc) < (long)InpTickThrottleMs) return;
   g_last_tick_sent_msc = now_msc;

   string msg = "T|" + IntegerToString((long)t.time_msc) + "," +
                Num(t.bid,_Digits) + "," + Num(t.ask,_Digits) + ";";
   if(!SendLine(msg)) CloseSocket();
}

void SendAccount()
{
   string msg = "A|" + Num(AccountInfoDouble(ACCOUNT_BALANCE),2) + "," +
                Num(AccountInfoDouble(ACCOUNT_EQUITY),2) + "," +
                Num(AccountInfoDouble(ACCOUNT_MARGIN),2) + "," +
                Num(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2) + "," +
                Num(AccountInfoDouble(ACCOUNT_PROFIT),2);
   if(!SendLine(msg)) CloseSocket();
}

void SendHeartbeat()
{
   datetime now = TimeLocal();
   if(g_last_heartbeat > 0 && (now - g_last_heartbeat) < InpHeartbeatSec) return;
   g_last_heartbeat = now;
   // Scanner v1.10+ ignores unknown lines safely.
   SendLine("P|" + IntegerToString((long)now));
}

//--- Order execution ----------------------------------------------
int CountOurPositions()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagic) count++;
   }
   return count;
}

bool SpreadOK()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return false;
   double spread = (t.ask - t.bid) / _Point;
   return (InpMaxSpreadPoints <= 0) || (spread <= InpMaxSpreadPoints);
}

double NormalizeVolume(double lot)
{
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;
   lot = MathMax(minv, MathMin(maxv, lot));
   lot = MathFloor(lot / step) * step;
   if(lot < minv) lot = minv;
   return NormalizeDouble(lot, 2);
}

double ClampStop(double price, double ref, int stop_points, bool is_sl, bool is_buy)
{
   double stops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops <= 0) stops = stop_points;
   double min_dist = stops * _Point;
   if(is_buy)
   {
      if(is_sl && (ref - price) < min_dist) price = ref - min_dist;
      if(!is_sl && (price - ref) < min_dist) price = ref + min_dist;
   }
   else
   {
      if(is_sl && (price - ref) < min_dist) price = ref + min_dist;
      if(!is_sl && (ref - price) < min_dist) price = ref - min_dist;
   }
   return NormalizeDouble(price, _Digits);
}

void SendOrderReply(const string id, const string status, const string detail)
{
   SendLine("R|" + Sanitize(id) + "|" + Sanitize(status) + "|" + Sanitize(detail));
}

void ExecuteScannerOrder(const string line)
{
   string p[];
   int n = StringSplit(line, '|', p);
   if(n < 6 || p[0] != "O")
   {
      Log("Bad order line: " + line);
      if(n >= 2) SendOrderReply(p[1], "ERR", "MALFORMED");
      return;
   }
   string id   = p[1];
   string side = p[2];
   double lot  = StringToDouble(p[3]);
   double sl   = StringToDouble(p[4]);
   double tp   = StringToDouble(p[5]);

   Log("Order received: id=" + id + " side=" + side +
       " lot=" + DoubleToString(lot,2) +
       " sl=" + DoubleToString(sl,_Digits) +
       " tp=" + DoubleToString(tp,_Digits));

   if(side == "BUY"  && !InpAllowBuy)  { SendOrderReply(id,"ERR","BUY_DISABLED");  return; }
   if(side == "SELL" && !InpAllowSell) { SendOrderReply(id,"ERR","SELL_DISABLED"); return; }
   if(side != "BUY" && side != "SELL") { SendOrderReply(id,"ERR","BAD_SIDE");      return; }
   if(!SpreadOK())                     { SendOrderReply(id,"ERR","SPREAD");        return; }
   if(InpOnePositionOnly && CountOurPositions() > 0)
                                       { SendOrderReply(id,"ERR","POSITION_EXISTS"); return; }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))  { SendOrderReply(id,"ERR","NO_TICK"); return; }

   if(!InpUseScannerLot) lot = InpFixedLot;
   lot = NormalizeVolume(lot);
   if(lot <= 0) { SendOrderReply(id,"ERR","BAD_LOT"); return; }

   if(!InpUseScannerSLTP)
   {
      if(side == "BUY") { sl = tick.ask - InpFallbackSLPoints*_Point;
                          tp = tick.ask + InpFallbackTPPoints*_Point; }
      else              { sl = tick.bid + InpFallbackSLPoints*_Point;
                          tp = tick.bid - InpFallbackTPPoints*_Point; }
   }
   else
   {
      if(side == "BUY"  && sl > 0 && sl >= tick.ask) { SendOrderReply(id,"ERR","BAD_SL"); return; }
      if(side == "BUY"  && tp > 0 && tp <= tick.ask) { SendOrderReply(id,"ERR","BAD_TP"); return; }
      if(side == "SELL" && sl > 0 && sl <= tick.bid) { SendOrderReply(id,"ERR","BAD_SL"); return; }
      if(side == "SELL" && tp > 0 && tp >= tick.bid) { SendOrderReply(id,"ERR","BAD_TP"); return; }
   }

   double ref = (side == "BUY" ? tick.ask : tick.bid);
   if(sl > 0) sl = ClampStop(sl, ref, InpFallbackSLPoints, true,  side=="BUY");
   if(tp > 0) tp = ClampStop(tp, ref, InpFallbackTPPoints, false, side=="BUY");

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   bool ok = false;
   if(side == "BUY") ok = trade.Buy(lot,_Symbol,0.0,sl,tp,"ScannerFX Breakout");
   else              ok = trade.Sell(lot,_Symbol,0.0,sl,tp,"ScannerFX Breakout");

   if(ok)
   {
      Log("Order OK ticket=" + IntegerToString((long)trade.ResultOrder()));
      SendOrderReply(id,"OK",IntegerToString((long)trade.ResultOrder()));
   }
   else
   {
      Log("Order FAILED retcode=" + IntegerToString((int)trade.ResultRetcode()) +
          " " + trade.ResultRetcodeDescription());
      SendOrderReply(id,"ERR",
             IntegerToString((int)trade.ResultRetcode()) + "_" +
             trade.ResultRetcodeDescription());
   }
}

//--- RX ------------------------------------------------------------
void ReadScanner()
{
   if(!g_connected) return;
   int guard = 0;
   while(SocketIsReadable(g_socket) > 0 && guard++ < 64)
   {
      uchar data[4096];
      int got = SocketRead(g_socket, data, ArraySize(data), 10);
      if(got <= 0) break;

      g_rx_buffer += CharArrayToString(data, 0, got, CP_UTF8);

      if(StringLen(g_rx_buffer) > InpMaxRxBuffer)
      {
         Log("RX buffer overflow, resetting");
         g_rx_buffer = "";
         CloseSocket();
         return;
      }

      int at = 0;
      while((at = StringFind(g_rx_buffer, "\n")) >= 0)
      {
         string line = StringSubstr(g_rx_buffer, 0, at);
         StringTrimLeft(line);
         StringTrimRight(line);
         g_rx_buffer = StringSubstr(g_rx_buffer, at+1);
         if(StringLen(line) > 0) ExecuteScannerOrder(line);
      }
   }
}

//--- Dashboard panel (profesional) ---------------------------------
// Panel digambar dengan chart objects: latar gelap, aksen emas,
// status berwarna, 11 baris data. Posisi = InpDashX / InpDashY.
#define DASH_PFX   "BCBG_"          // prefix nama objek dashboard
#define DASH_W     330              // lebar panel (px)
#define DASH_ROW_H 20               // tinggi 1 baris data (px)
#define DASH_TOP   84               // offset y baris data pertama (px)

#define COL_BG     C'15,19,28'      // latar panel (dark navy)
#define COL_BORDER C'196,158,62'    // bingkai emas
#define COL_LINE   C'52,60,76'      // garis pemisah header
#define COL_TITLE  C'232,196,92'    // judul (emas terang)
#define COL_SUB    C'132,142,158'   // sub-judul
#define COL_LABEL  C'138,148,164'   // label kolom kiri
#define COL_VALUE  C'232,238,248'   // nilai kolom kanan
#define COL_OK     C'0,204,128'     // hijau (OK / profit / connected)
#define COL_BAD    C'240,84,62'     // merah (error / loss / disconnected)

double FloatingPL()
{
   double pl = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return pl;
}

void DashBox(const string name, const ENUM_OBJECT type, const int x, const int y,
             const int w, const int h, const color bg, const color border)
{
   string obj = DASH_PFX + name;
   if(ObjectFind(0, obj) < 0)
   {
      ObjectCreate(0, obj, type, 0, 0, 0);
      ObjectSetInteger(0, obj, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(0, obj, OBJPROP_SELECTED,    false);
      ObjectSetInteger(0, obj, OBJPROP_HIDDEN,      true);
      ObjectSetInteger(0, obj, OBJPROP_BACK,        false);
      ObjectSetInteger(0, obj, OBJPROP_ZORDER,      0);
   }
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, InpDashX + x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, InpDashY + y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE,     w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE,     h);
   ObjectSetInteger(0, obj, OBJPROP_BGCOLOR,   bg);
   ObjectSetInteger(0, obj, OBJPROP_COLOR,     border);
}

void DashText(const string name, const int x, const int y, const string text,
              const color clr, const string font, const int size)
{
   string obj = DASH_PFX + name;
   if(ObjectFind(0, obj) < 0)
   {
      ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj, OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj, OBJPROP_HIDDEN,     true);
      ObjectSetInteger(0, obj, OBJPROP_BACK,       false);
      ObjectSetInteger(0, obj, OBJPROP_ZORDER,     1);
   }
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, InpDashX + x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, InpDashY + y);
   ObjectSetString (0, obj, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, obj, OBJPROP_COLOR,     clr);
   ObjectSetString (0, obj, OBJPROP_FONT,      font);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE,  size);
}

void DashRow(const int idx, const string label, const string value, const color vclr)
{
   int y = DASH_TOP + idx * DASH_ROW_H;
   DashText("L" + IntegerToString(idx), 16,  y + 1, label, COL_LABEL, "Segoe UI", 8);
   DashText("V" + IntegerToString(idx), 110, y,     value, vclr,      "Consolas", 9);
}

void UpdateDashboard()
{
   static bool shown = false;

   if(!InpShowChartComment)
   {
      if(shown) { ObjectsDeleteAll(0, DASH_PFX, -1, -1); ChartRedraw(); shown = false; }
      return;
   }
   shown = true;

   const int rows   = 11;
   const int height = DASH_TOP + rows * DASH_ROW_H + 8;   // 312 px

   //--- panel + aksen + garis header
   DashBox("BG",     OBJ_RECTANGLE_LABEL, 0, 0,  DASH_W,   height, COL_BG,     COL_BORDER);
   DashBox("ACCENT", OBJ_RECTANGLE_LABEL, 0, 0,  3,        height, COL_BORDER, COL_BORDER);
   DashBox("LINE",   OBJ_RECTANGLE_LABEL, 1, 52, DASH_W-2, 1,      COL_LINE,   COL_LINE);

   //--- header
   DashText("TITLE", 16, 10, "BLACK CUBE — SCANNER BRIDGE", COL_TITLE, "Segoe UI Semibold", 10);
   DashText("SUB",   16, 31, "Breakout " + _Symbol + " · v1.12 · Magic " + IntegerToString(InpMagic),
            COL_SUB, "Segoe UI", 8);

   //--- status koneksi
   color  sc   = g_connected ? COL_OK : COL_BAD;
   string stxt = g_connected
                 ? "CONNECTED · " + InpScannerHost + ":" + IntegerToString(InpScannerPort)
                 : "DISCONNECTED · retrying...";
   DashText("DOT",  16, 61, "l",  sc, "Wingdings", 10);
   DashText("STAT", 32, 60, stxt, sc, "Segoe UI Semibold", 9);

   //--- data pasar & akun
   MqlTick t;
   bool   have_tick = SymbolInfoTick(_Symbol, t);
   double sp_pts    = have_tick ? (t.ask - t.bid) / _Point : 0.0;
   bool   lim_on    = (InpMaxSpreadPoints > 0);
   bool   spread_ok = !lim_on || (sp_pts <= InpMaxSpreadPoints);
   string cur       = AccountInfoString(ACCOUNT_CURRENCY);
   double pl        = FloatingPL();
   bool   algo_on   = (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
                       MQLInfoInteger(MQL_TRADE_ALLOWED));

   int i = 0;
   DashRow(i++, "Symbol", _Symbol + " · " + IntegerToString(_Digits) + " dig · pt " +
            DoubleToString(_Point, _Digits), COL_VALUE);
   DashRow(i++, "Spread",
           have_tick ? DoubleToString(sp_pts, 0) + " pt (" +
                       DoubleToString(t.ask - t.bid, _Digits) + ")" +
                       (lim_on ? (spread_ok ? "  OK" : "  WIDE") : "")
                     : "-",
           have_tick ? (spread_ok ? (lim_on ? COL_OK : COL_VALUE) : COL_BAD) : COL_LABEL);
   DashRow(i++, "Posisi", IntegerToString(CountOurPositions()) +
            (InpOnePositionOnly ? " / maks 1" : ""), COL_VALUE);
   DashRow(i++, "Balance",     DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2)     + " " + cur, COL_VALUE);
   DashRow(i++, "Equity",      DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2)      + " " + cur, COL_VALUE);
   DashRow(i++, "Free Margin", DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + " " + cur, COL_VALUE);
   DashRow(i++, "Open P/L",    (pl > 0 ? "+" : "") + DoubleToString(pl, 2) + " " + cur,
           pl > 0 ? COL_OK : (pl < 0 ? COL_BAD : COL_VALUE));
   DashRow(i++, "Bar M1", g_last_bar > 0 ? TimeToString(g_last_bar, TIME_DATE|TIME_MINUTES) : "-", COL_VALUE);
   DashRow(i++, "Ping",   g_last_heartbeat > 0 ?
          IntegerToString((int)(TimeLocal() - g_last_heartbeat)) + "s lalu" : "-", COL_VALUE);
   DashRow(i++, "Waktu",  "S " + TimeToString(TimeCurrent(), TIME_SECONDS) +
                          "  L " + TimeToString(TimeLocal(), TIME_SECONDS), COL_VALUE);
   DashRow(i++, "Algo",   algo_on ? "AKTIF" : "MATI", algo_on ? COL_OK : COL_BAD);

   ChartRedraw();
}

//--- Lifecycle -----------------------------------------------------
int OnInit()
{
   Log("=== OnInit ===");
   Log("Symbol=" + _Symbol + " Digits=" + IntegerToString(_Digits) +
       " Point=" + DoubleToString(_Point,10));
   Log("TerminalAutoTrading=" + IntegerToString(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) +
       " MQLTradeAllowed=" + IntegerToString(MQLInfoInteger(MQL_TRADE_ALLOWED)));
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      Log("!! Algo Trading MATI. Aktifkan tombol Algo Trading di toolbar MT5.");
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      Log("!! EA tidak diizinkan trading. Centang Allow Algo Trading di dialog EA.");

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   EventSetTimer(MathMax(1, InpTimerSeconds));
   ConnectScanner();
   UpdateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Log("OnDeinit reason=" + IntegerToString(reason));
   EventKillTimer();
   CloseSocket();
   ObjectsDeleteAll(0, DASH_PFX, -1, -1);
   ChartRedraw();
}

void OnTick()
{
   if(!g_connected)
   {
      ConnectScanner();
      UpdateDashboard();
      return;
   }
   SendTick();
   ReadScanner();
   UpdateDashboard();
}

void OnTimer()
{
   if(!g_connected) ConnectScanner();
   if(g_connected)
   {
      SendNewBarIfNeeded();
      SendAccount();
      SendHeartbeat();
      ReadScanner();
   }
   UpdateDashboard();
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Replies are sent synchronously in ExecuteScannerOrder.
}
//+------------------------------------------------------------------+
