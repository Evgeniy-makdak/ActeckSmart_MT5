//+------------------------------------------------------------------+
//|                                       ActeckSmart_Trader.mq5     |
//|                       Советник исполнения для MT5                |
//+------------------------------------------------------------------+
#property copyright "Евгений Ацтек"
#property link      "https://github.com/Evgeniy-makdak/ActeckSmart_MT5"
#property version   "1.43"
#property description "Советник Safe и мульти-сделки ActeckSmart; автоторговля выключена по умолчанию"

#include <Trade/Trade.mqh>

input bool   InpAutoTrading            = false;
input double InpRiskPercent            = 2.0;
input int    InpMaximumLeverage        = 33;
input double InpExecutionCostReservePct = 10.0;
input ulong  InpMagicNumber            = 181001;
input int    InpMaxSlippagePoints      = 20;
input double InpFreeMarginReservePct  = 10.0;
input int    InpMultiOrderCount        = 2;
input double InpMultiLot               = 0.01;
input double InpMultiStopLossPoints    = 10.0;

enum ENUM_SIGNAL_MODEL
  {
   SIGNAL_MODEL_BASE = 1,
   SIGNAL_MODEL_CASCADE = 2
  };

CTrade g_trade;
int g_signal_handle = INVALID_HANDLE;
datetime g_last_processed_bar = 0;
datetime g_last_trade_signal = 0;
double g_last_trade_volume = 0.0;
double g_netting_tp1 = 0.0;
double g_netting_tp2 = 0.0;
double g_netting_leg_volume = 0.0;
bool g_netting_tp1_done = false;
bool g_netting_state_available = false;
bool g_signal_lookup_warned = false;
bool g_signal_buffer_read_warned = false;
string g_netting_state_prefix;

string g_multi_panel_prefix = "ACTECK_MULTI_";
string g_multi_buy_button = "ACTECK_MULTI_BUY";
string g_multi_sell_button = "ACTECK_MULTI_SELL";
string g_multi_lot_edit = "ACTECK_MULTI_LOT";
string g_multi_stop_edit = "ACTECK_MULTI_STOP";
string g_multi_lot_decrease = "ACTECK_MULTI_LOT_MINUS";
string g_multi_lot_increase = "ACTECK_MULTI_LOT_PLUS";
string g_multi_stop_decrease = "ACTECK_MULTI_STOP_MINUS";
string g_multi_stop_increase = "ACTECK_MULTI_STOP_PLUS";
string g_multi_toggle_button = "ACTECK_MULTI_TOGGLE";
double g_multi_last_valid_lot = 0.01;
double g_multi_last_valid_stop = 10.0;
bool g_multi_panel_expanded = true;
int g_multi_panel_hidden_offset = 10000;

int VolumeDigits(const double step)
  {
   for(int digits = 0; digits <= 8; digits++)
      if(MathAbs(step - NormalizeDouble(step, digits)) < 1e-10)
         return digits;
   return 8;
  }

double NormalizeVolumeDown(const double volume)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(step <= 0.0 || minimum <= 0.0 || volume < minimum)
      return 0.0;
   double normalized = MathFloor((volume + 1e-10) / step) * step;
   if(normalized < minimum)
      return 0.0;
   return NormalizeDouble(normalized, VolumeDigits(step));
  }

double NormalizePriceToTick(const double price, const bool round_up)
  {
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = _Point;
   double ticks = price / tick_size;
   double rounded_ticks = round_up ? MathCeil(ticks - 1e-10)
                                   : MathFloor(ticks + 1e-10);
   return NormalizeDouble(rounded_ticks * tick_size, _Digits);
  }

bool IsTradeRetcodeSuccessful(void)
  {
   uint code = g_trade.ResultRetcode();
   return (code == TRADE_RETCODE_DONE || code == TRADE_RETCODE_DONE_PARTIAL);
  }

bool EnsureSignalHandle(void)
  {
   if(g_signal_handle != INVALID_HANDLE)
      return true;
   ResetLastError();
   g_signal_handle = ChartIndicatorGet(ChartID(), 0, "ActeckSmart v1.28");
   if(g_signal_handle != INVALID_HANDLE)
     {
      g_signal_lookup_warned = false;
      Print("ActeckSmart Trader: подключён индикатор ActeckSmart v1.28");
      return true;
     }
   if(!g_signal_lookup_warned)
     {
      Print("ActeckSmart Trader: индикатор ActeckSmart v1.28 не найден на графике; панель MULTI доступна, автосигналы ожидают индикатор, err=",
            GetLastError());
      g_signal_lookup_warned = true;
     }
   return false;
  }

bool ReadSignal(const datetime signal_bar, double &direction, double &entry,
                double &stop, double &tp1, double &tp2, double &model,
                double &spec_spread, double &spread_percent, bool &ready)
  {
   ready = false;
   double dir_value[1], stop_value[1], tp1_value[1], tp2_value[1], model_value[1];
   double processed_time[1], spread_value[1], spread_percent_value[1];
   ResetLastError();
   if(CopyBuffer(g_signal_handle, 1, 1, 1, dir_value) != 1 ||
      CopyBuffer(g_signal_handle, 2, 1, 1, stop_value) != 1 ||
      CopyBuffer(g_signal_handle, 3, 1, 1, tp1_value) != 1 ||
      CopyBuffer(g_signal_handle, 4, 1, 1, tp2_value) != 1 ||
      CopyBuffer(g_signal_handle, 5, 1, 1, model_value) != 1 ||
      CopyBuffer(g_signal_handle, 6, 1, 1, processed_time) != 1 ||
      CopyBuffer(g_signal_handle, 7, 1, 1, spread_value) != 1 ||
      CopyBuffer(g_signal_handle, 8, 1, 1, spread_percent_value) != 1)
     {
      if(!g_signal_buffer_read_warned)
        {
         Print("ActeckSmart Trader: буферы сигнала пока недоступны, err=",
               GetLastError(),
               "; советник продолжит проверку без повторного вывода ошибки на каждом тике");
         g_signal_buffer_read_warned = true;
        }
      return false;
     }
   if(g_signal_buffer_read_warned)
     {
      Print("ActeckSmart Trader: чтение буферов сигнала восстановлено");
      g_signal_buffer_read_warned = false;
     }
   if(processed_time[0] != (double)signal_bar)
      return false;
   ready = true;
   if(dir_value[0] == EMPTY_VALUE || dir_value[0] == 0.0 ||
      stop_value[0] == EMPTY_VALUE || tp1_value[0] == EMPTY_VALUE ||
      tp2_value[0] == EMPTY_VALUE || model_value[0] == EMPTY_VALUE ||
      spread_value[0] == EMPTY_VALUE ||
      spread_percent_value[0] == EMPTY_VALUE)
      return false;

   int shift = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, signal_bar, true);
   if(shift < 1)
      return false;
   entry = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   if(entry <= 0.0)
      return false;
   direction = dir_value[0];
   stop = stop_value[0];
   tp1 = tp1_value[0];
   tp2 = tp2_value[0];
   model = model_value[0];
   spec_spread = spread_value[0];
   spread_percent = spread_percent_value[0];
   if(signal_bar <= 0 || (direction != 1.0 && direction != -1.0))
      return false;
   return true;
  }

bool HasForeignOrExistingPosition(const ENUM_ACCOUNT_MARGIN_MODE account_mode)
  {
   if(account_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
        }
      return false;
     }

   if(!PositionSelect(_Symbol))
      return false;
   return ((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber ||
           PositionGetDouble(POSITION_VOLUME) > 0.0);
  }

double CalculateLegVolume(const ENUM_ORDER_TYPE order_type, const double entry,
                          const double stop, const double risk_budget,
                          double &loss_per_lot)
  {
   double reference_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(reference_volume <= 0.0)
     {
      Print("ActeckSmart Trader: не удалось получить минимальный объём символа");
      return 0.0;
     }
   double loss = 0.0;
   if(!OrderCalcProfit(order_type, _Symbol, reference_volume,
                       entry, stop, loss) ||
      !MathIsValidNumber(loss))
     {
      Print("ActeckSmart Trader: OrderCalcProfit не рассчитал риск, err=",
            GetLastError());
      return 0.0;
     }
   loss_per_lot = MathAbs(loss) / reference_volume;
   if(loss_per_lot <= 0.0)
      return 0.0;
   return NormalizeVolumeDown(risk_budget / loss_per_lot);
  }

bool FitVolumeToMargin(const ENUM_ORDER_TYPE order_type, const double entry,
                       double &leg_volume,
                       const ENUM_ACCOUNT_MARGIN_MODE account_mode)
  {
   bool is_netting = (account_mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   double volume_for_margin = is_netting ? leg_volume * 2.0 : leg_volume;
   double margin_per_leg = 0.0;
   if(!OrderCalcMargin(order_type, _Symbol, volume_for_margin, entry, margin_per_leg) ||
      margin_per_leg <= 0.0)
     {
      Print("ActeckSmart Trader: OrderCalcMargin не рассчитал маржу, err=",
            GetLastError());
      return false;
     }

   long broker_leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   double leverage_factor = 1.0;
   if(InpMaximumLeverage > 0 && broker_leverage > InpMaximumLeverage)
      leverage_factor = (double)broker_leverage / InpMaximumLeverage;

   double margin_reserve = AccountInfoDouble(ACCOUNT_MARGIN_FREE) *
                           (100.0 - InpFreeMarginReservePct) / 100.0;
   if(margin_reserve <= 0.0)
      return false;

   double effective_pair_margin = is_netting ? margin_per_leg
                                             : 2.0 * margin_per_leg;
   effective_pair_margin *= leverage_factor;
   if(effective_pair_margin > margin_reserve)
     {
      leg_volume = NormalizeVolumeDown(leg_volume *
                                       margin_reserve / effective_pair_margin);
      if(leg_volume <= 0.0)
         return false;
      double check_volume = is_netting ? leg_volume * 2.0 : leg_volume;
      if(!OrderCalcMargin(order_type, _Symbol, check_volume, entry, margin_per_leg) ||
         margin_per_leg <= 0.0)
         return false;
      effective_pair_margin = (is_netting ? margin_per_leg
                                          : 2.0 * margin_per_leg) *
                              leverage_factor;
     }

   return (effective_pair_margin <= margin_reserve);
  }

ulong FindPositionTicketByIdentifier(const ulong identifier)
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == identifier)
         return ticket;
     }
   return 0;
  }

bool GetFillPriceAndPosition(const ulong deal, double &fill_price,
                             ulong &position_ticket)
  {
   if(deal == 0 || !HistoryDealSelect(deal))
      return false;
   fill_price = HistoryDealGetDouble(deal, DEAL_PRICE);
   ulong identifier = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   position_ticket = FindPositionTicketByIdentifier(identifier);
   return (fill_price > 0.0 && position_ticket > 0);
  }

bool GetPositionRisk(const ulong ticket, const double stop, double &risk)
  {
   risk = 0.0;
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;

   ENUM_POSITION_TYPE position_type =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   ENUM_ORDER_TYPE order_type = (position_type == POSITION_TYPE_BUY)
                                ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double profit = 0.0;
   if(!OrderCalcProfit(order_type, _Symbol,
                       PositionGetDouble(POSITION_VOLUME),
                       PositionGetDouble(POSITION_PRICE_OPEN), stop, profit) ||
      !MathIsValidNumber(profit))
      return false;
   risk = MathAbs(profit);
   return true;
  }

bool CloseHedgingPositionFully(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return true;
   if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return false;
   if(!g_trade.PositionClose(ticket) ||
      g_trade.ResultRetcode() != TRADE_RETCODE_DONE)
      return false;
   return !PositionSelectByTicket(ticket);
  }

bool CloseNettingPositionFully(void)
  {
   if(!PositionSelect(_Symbol))
      return true;
   if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return false;
   if(!g_trade.PositionClose(_Symbol) ||
      g_trade.ResultRetcode() != TRADE_RETCODE_DONE)
      return false;
   return !PositionSelect(_Symbol);
  }

bool ValidateSafeLevels(const ENUM_ORDER_TYPE order_type, const double stop,
                        const double tp1, const double tp2)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0)
      return false;

   double min_distance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) *
                         _Point;
   if(order_type == ORDER_TYPE_BUY)
      return (stop < tick.bid - min_distance &&
              tp1 > tick.bid + min_distance &&
              tp2 > tick.bid + min_distance);
   return (stop > tick.ask + min_distance &&
           tp1 < tick.ask - min_distance &&
           tp2 < tick.ask - min_distance);
  }

double SafeLevelPrice(const ENUM_ORDER_TYPE order_type, const double entry,
                      const double distance, const bool is_stop)
  {
   double price = (order_type == ORDER_TYPE_BUY)
                  ? (is_stop ? entry - distance : entry + distance)
                  : (is_stop ? entry + distance : entry - distance);
   bool round_up = ((order_type == ORDER_TYPE_SELL) == is_stop);
   return NormalizePriceToTick(price, round_up);
  }

bool PersistNettingState(void)
  {
   bool saved_tp1 = GlobalVariableSet(g_netting_state_prefix + "TP1",
                                      g_netting_tp1) != 0;
   bool saved_tp2 = GlobalVariableSet(g_netting_state_prefix + "TP2",
                                      g_netting_tp2) != 0;
   bool saved_volume = GlobalVariableSet(g_netting_state_prefix + "VOL",
                                         g_netting_leg_volume) != 0;
   bool saved_done = GlobalVariableSet(g_netting_state_prefix + "DONE",
                                       g_netting_tp1_done ? 1.0 : 0.0) != 0;
   bool saved = saved_tp1 && saved_tp2 && saved_volume && saved_done;
   if(!saved)
     {
      Print("ActeckSmart Trader: не удалось сохранить цели netting Safe, err=",
            GetLastError());
      return false;
     }
   g_netting_state_available = true;
   return true;
  }

bool LoadNettingState(void)
  {
   string key1 = g_netting_state_prefix + "TP1";
   string key2 = g_netting_state_prefix + "TP2";
   string keyv = g_netting_state_prefix + "VOL";
   string keyd = g_netting_state_prefix + "DONE";
   if(!GlobalVariableCheck(key1) || !GlobalVariableCheck(key2) ||
      !GlobalVariableCheck(keyv) || !GlobalVariableCheck(keyd))
      return false;
   g_netting_tp1 = GlobalVariableGet(key1);
   g_netting_tp2 = GlobalVariableGet(key2);
   g_netting_leg_volume = GlobalVariableGet(keyv);
   g_netting_tp1_done = (GlobalVariableGet(keyd) > 0.5);
   if(g_netting_tp1 <= 0.0 || g_netting_tp2 <= 0.0 ||
      g_netting_leg_volume <= 0.0)
     {
      Print("ActeckSmart Trader: сохранённое состояние netting Safe повреждено");
      g_netting_state_available = false;
      return false;
     }
   g_netting_state_available = true;
   return true;
  }

void ClearNettingState(void)
  {
   GlobalVariableDel(g_netting_state_prefix + "TP1");
   GlobalVariableDel(g_netting_state_prefix + "TP2");
   GlobalVariableDel(g_netting_state_prefix + "VOL");
   GlobalVariableDel(g_netting_state_prefix + "DONE");
   g_netting_state_available = false;
  }

bool CloseNettingVolume(const ENUM_ORDER_TYPE close_type, const double volume)
  {
   if(!PositionSelect(_Symbol))
      return false;
   double current_volume = PositionGetDouble(POSITION_VOLUME);
   double close_volume = NormalizeVolumeDown(MathMin(volume, current_volume));
   if(close_volume <= 0.0 || close_volume >= current_volume)
      return false;
   bool sent = (close_type == ORDER_TYPE_BUY)
               ? g_trade.Buy(close_volume, _Symbol, 0.0, 0.0, 0.0, "Acteck Safe TP1")
               : g_trade.Sell(close_volume, _Symbol, 0.0, 0.0, 0.0, "Acteck Safe TP1");
   if(!sent || !IsTradeRetcodeSuccessful())
     {
      Print("ActeckSmart Trader: не удалось частично закрыть netting-позицию: ",
            g_trade.ResultRetcodeDescription());
      return false;
     }
   if(g_trade.ResultRetcode() == TRADE_RETCODE_DONE_PARTIAL)
     {
      Alert("ActeckSmart Trader: КРИТИЧНО — частичное исполнение TP1 в netting; закрывается остаток позиции");
      if(PositionSelect(_Symbol))
        {
         if(CloseNettingPositionFully())
            ClearNettingState();
         else
            Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть позицию после частичного TP1");
        }
      return false;
     }
   return true;
  }

void ManageNettingPosition(void)
  {
   if(!PositionSelect(_Symbol))
     {
      if(g_netting_state_available)
         ClearNettingState();
      return;
     }
   if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return;
   if(!g_netting_state_available && !LoadNettingState())
     {
      Print("ActeckSmart Trader: нет сохранённых целей netting-позиции; действует серверный SL/TP2");
      return;
     }

   ENUM_POSITION_TYPE position_type =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool tp2_hit = (position_type == POSITION_TYPE_BUY)
                  ? (bid >= g_netting_tp2) : (ask <= g_netting_tp2);
   if(tp2_hit)
     {
      if(!CloseNettingPositionFully())
         Print("ActeckSmart Trader: не удалось закрыть остаток netting-позиции: ",
               g_trade.ResultRetcodeDescription());
      else
         ClearNettingState();
      return;
     }

   bool tp1_hit = (position_type == POSITION_TYPE_BUY)
                  ? (bid >= g_netting_tp1) : (ask <= g_netting_tp1);
   if(tp1_hit && !g_netting_tp1_done)
     {
      ENUM_ORDER_TYPE close_type = (position_type == POSITION_TYPE_BUY)
                                   ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      if(CloseNettingVolume(close_type, g_netting_leg_volume))
        {
         g_netting_tp1_done = true;
         if(!PersistNettingState())
            Alert("ActeckSmart Trader: КРИТИЧНО — TP1 закрыт, но его состояние не сохранено; проверьте позицию и серверный TP2");
        }
     }
  }

bool OpenHedgingLeg(const ENUM_ORDER_TYPE order_type, const double volume,
                    const double stop_price, const double target_distance,
                    const double other_target_distance,
                    ulong &position_ticket)
  {
   double quote_entry = (order_type == ORDER_TYPE_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double provisional_tp1 = SafeLevelPrice(order_type, quote_entry,
                                           target_distance, false);
   double provisional_tp2 = SafeLevelPrice(order_type, quote_entry,
                                           other_target_distance, false);
   if(!ValidateSafeLevels(order_type, stop_price,
                          provisional_tp1, provisional_tp2))
     {
      Print("ActeckSmart Trader: уровни Safe слишком близки к рынку для ограничений брокера");
      return false;
     }
   bool sent = (order_type == ORDER_TYPE_BUY)
               ? g_trade.Buy(volume, _Symbol, 0.0, stop_price, 0.0, "Acteck Safe")
               : g_trade.Sell(volume, _Symbol, 0.0, stop_price, 0.0, "Acteck Safe");
   if(!sent || !IsTradeRetcodeSuccessful())
     {
      Print("ActeckSmart Trader: не удалось открыть часть Safe: ",
            g_trade.ResultRetcodeDescription());
      return false;
     }

   if(g_trade.ResultRetcode() == TRADE_RETCODE_DONE_PARTIAL)
     {
      double partial_fill = 0.0;
      ulong partial_ticket = 0;
      if(GetFillPriceAndPosition(g_trade.ResultDeal(), partial_fill, partial_ticket))
        {
         if(!CloseHedgingPositionFully(partial_ticket))
            Alert("ActeckSmart Trader: КРИТИЧНО — частичное исполнение Safe не удалось закрыть, ticket ",
                  partial_ticket);
        }
      else
         Alert("ActeckSmart Trader: КРИТИЧНО — частичное исполнение Safe, ticket не найден; проверьте позиции");
      return false;
     }

   double fill = 0.0;
   if(!GetFillPriceAndPosition(g_trade.ResultDeal(), fill, position_ticket))
     {
      Alert("ActeckSmart Trader: ордер исполнен, но не удалось определить ticket позиции; проверьте позицию вручную");
      return false;
     }

   double final_tp = SafeLevelPrice(order_type, fill, target_distance, false);
   double final_tp2 = SafeLevelPrice(order_type, fill,
                                     other_target_distance, false);
   if(!ValidateSafeLevels(order_type, stop_price, final_tp, final_tp2))
     {
      Print("ActeckSmart Trader: fill пересёк рассчитанные уровни либо нарушает min stop distance");
      if(!CloseHedgingPositionFully(position_ticket))
         Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть позицию с недопустимыми уровнями Safe");
      return false;
     }
   if(!g_trade.PositionModify(position_ticket, stop_price, final_tp) ||
      !IsTradeRetcodeSuccessful())
     {
      Print("ActeckSmart Trader: не удалось скорректировать TP по цене исполнения: ",
            g_trade.ResultRetcodeDescription());
      if(!CloseHedgingPositionFully(position_ticket))
         Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть позицию после ошибки установки TP, ticket ",
               position_ticket);
      return false;
     }
   return true;
  }

bool ExecuteHedgingSafe(const ENUM_ORDER_TYPE order_type, const double volume,
                        const double stop_distance, const double tp1_distance,
                        const double tp2_distance)
  {
   double reference_entry = (order_type == ORDER_TYPE_BUY)
                            ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double common_stop = SafeLevelPrice(order_type, reference_entry,
                                       stop_distance, true);
   ulong first_ticket = 0;
   if(!OpenHedgingLeg(order_type, volume, common_stop, tp1_distance,
                      tp2_distance,
                      first_ticket))
      return false;

   ulong second_ticket = 0;
   if(!OpenHedgingLeg(order_type, volume, common_stop, tp2_distance,
                      tp1_distance,
                      second_ticket))
     {
      if(!CloseHedgingPositionFully(first_ticket))
         Alert("ActeckSmart Trader: КРИТИЧНО — вторая часть Safe не открыта, первую закрыть не удалось. Ticket ",
               first_ticket);
      return false;
     }

   double first_risk = 0.0, second_risk = 0.0;
   double maximum_risk = AccountInfoDouble(ACCOUNT_BALANCE) *
                         InpRiskPercent / 100.0;
   if(!PositionSelectByTicket(first_ticket))
     {
      CloseHedgingPositionFully(first_ticket);
      CloseHedgingPositionFully(second_ticket);
      return false;
     }
   if(!GetPositionRisk(first_ticket, common_stop, first_risk) ||
      !PositionSelectByTicket(second_ticket))
     {
      bool first_closed = CloseHedgingPositionFully(first_ticket);
      bool second_closed = CloseHedgingPositionFully(second_ticket);
      if(!first_closed || !second_closed)
         Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть Safe после ошибки проверки риска");
      return false;
     }
   if(!GetPositionRisk(second_ticket, common_stop, second_risk) ||
      first_risk + second_risk > maximum_risk + 0.01)
     {
      Alert("ActeckSmart Trader: фактический риск Safe после исполнения превысил лимит или не вычислен; закрываются обе части");
      bool first_closed = CloseHedgingPositionFully(first_ticket);
      bool second_closed = CloseHedgingPositionFully(second_ticket);
      if(!first_closed || !second_closed)
         Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть обе части Safe после превышения риска");
      return false;
     }
   return true;
  }

bool ExecuteNettingSafe(const ENUM_ORDER_TYPE order_type, const double volume,
                        const double stop_distance, const double tp1_distance,
                        const double tp2_distance)
  {
   double total_volume = NormalizeVolumeDown(volume * 2.0);
   if(total_volume <= 0.0)
      return false;
   double quote_entry = (order_type == ORDER_TYPE_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double provisional_stop = SafeLevelPrice(order_type, quote_entry,
                                            stop_distance, true);
   double provisional_tp1 = SafeLevelPrice(order_type, quote_entry,
                                           tp1_distance, false);
   double provisional_tp2 = SafeLevelPrice(order_type, quote_entry,
                                           tp2_distance, false);
   if(!ValidateSafeLevels(order_type, provisional_stop,
                          provisional_tp1, provisional_tp2))
     {
      Print("ActeckSmart Trader: уровни Safe слишком близки к рынку для ограничений брокера");
      return false;
     }
   bool sent = (order_type == ORDER_TYPE_BUY)
               ? g_trade.Buy(total_volume, _Symbol, 0.0, provisional_stop, 0.0, "Acteck Safe")
               : g_trade.Sell(total_volume, _Symbol, 0.0, provisional_stop, 0.0, "Acteck Safe");
   if(!sent || !IsTradeRetcodeSuccessful())
     {
      Print("ActeckSmart Trader: не удалось открыть netting Safe: ",
            g_trade.ResultRetcodeDescription());
      return false;
     }
   if(g_trade.ResultRetcode() == TRADE_RETCODE_DONE_PARTIAL)
     {
      if(PositionSelect(_Symbol) &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
         if(!CloseNettingPositionFully())
            Alert("ActeckSmart Trader: КРИТИЧНО — частичное netting-исполнение не удалось закрыть");
        }
      else
         Alert("ActeckSmart Trader: КРИТИЧНО — частичное netting-исполнение; проверьте позицию вручную");
      return false;
     }
   if(!PositionSelect(_Symbol) ||
      (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
     {
      Alert("ActeckSmart Trader: ордер исполнен, но позицию netting не удалось проверить");
      return false;
     }

   double fill = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double final_stop = SafeLevelPrice(order_type, fill, stop_distance, true);
   g_netting_tp1 = SafeLevelPrice(order_type, fill, tp1_distance, false);
   g_netting_tp2 = SafeLevelPrice(order_type, fill, tp2_distance, false);
   g_netting_leg_volume = volume;
   g_netting_tp1_done = false;
   if(!ValidateSafeLevels(order_type, final_stop, g_netting_tp1,
                          g_netting_tp2))
     {
      Alert("ActeckSmart Trader: fill пересёк рассчитанные уровни либо нарушает min stop distance; позиция закрывается");
      if(CloseNettingPositionFully())
         ClearNettingState();
      else
         Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть netting-позицию с недопустимыми уровнями");
      return false;
     }
   if(!g_trade.PositionModify(_Symbol, final_stop, g_netting_tp2) ||
      !IsTradeRetcodeSuccessful())
     {
      Print("ActeckSmart Trader: TP2 серверной защиты не установлен: ",
            g_trade.ResultRetcodeDescription());
      if(CloseNettingPositionFully())
         ClearNettingState();
      else
         Alert("ActeckSmart Trader: КРИТИЧНО — TP2 не установлен и netting-позицию не удалось закрыть");
      return false;
     }
   if(!PersistNettingState())
     {
      Alert("ActeckSmart Trader: не удалось сохранить цели netting Safe; позиция закрывается для предотвращения потери состояния");
      if(CloseNettingPositionFully())
         ClearNettingState();
      else
         Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть позицию после ошибки сохранения состояния");
      return false;
     }

   double position_risk = 0.0;
   double maximum_risk = AccountInfoDouble(ACCOUNT_BALANCE) *
                         InpRiskPercent / 100.0;
   if(!GetPositionRisk((ulong)PositionGetInteger(POSITION_TICKET), final_stop,
                       position_risk) ||
      position_risk > maximum_risk + 0.01)
     {
      Alert("ActeckSmart Trader: фактический риск netting Safe превысил лимит или не вычислен; позиция закрывается");
      if(CloseNettingPositionFully())
         ClearNettingState();
      else
         Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть netting-позицию после превышения риска");
      return false;
     }

   return true;
  }

bool ExecuteSignal(const double direction, const double signal_entry,
                   const double signal_stop, const double signal_tp1,
                   const double signal_tp2, const double signal_spec_spread,
                   const double spread_percent)
  {
   ENUM_ACCOUNT_MARGIN_MODE account_mode =
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     {
      Print("ActeckSmart Trader: торговля запрещена настройками терминала, эксперта или счёта");
      return false;
     }
   if(HasForeignOrExistingPosition(account_mode))
     {
      Print("ActeckSmart Trader: новая сделка пропущена — на символе уже есть позиция этого EA или чужая netting-позиция");
      return false;
     }

   ENUM_ORDER_TYPE order_type = (direction > 0.0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;
   double entry = (order_type == ORDER_TYPE_BUY) ? ask : bid;
   double current_spec_spread = (spread_percent > 0.0)
                                ? entry * spread_percent : signal_spec_spread;
   double effective_spread = MathMax(current_spec_spread, ask - bid);
   double stop_points_distance = MathAbs(signal_entry - signal_stop) -
                                 signal_spec_spread;
   double tp1_points_distance = MathAbs(signal_tp1 - signal_entry) -
                                signal_spec_spread;
   double tp2_points_distance = MathAbs(signal_tp2 - signal_entry) -
                                signal_spec_spread;
   if(effective_spread <= 0.0 || stop_points_distance <= 0.0 ||
      tp1_points_distance <= 0.0 || tp2_points_distance <= 0.0)
     {
      Print("ActeckSmart Trader: нельзя восстановить фиксированные дистанции SL/TP из сигнала");
      return false;
     }
   double stop_distance = stop_points_distance + effective_spread;
   double tp1_distance = tp1_points_distance + effective_spread;
   double tp2_distance = tp2_points_distance + effective_spread;
   double sizing_entry = entry + ((order_type == ORDER_TYPE_BUY) ? 1.0 : -1.0) *
                         InpMaxSlippagePoints * _Point;
   double sizing_stop = SafeLevelPrice(order_type, sizing_entry,
                                       stop_distance, true);
   double estimated_stop = SafeLevelPrice(order_type, entry, stop_distance, true);
   double estimated_tp1 = SafeLevelPrice(order_type, entry, tp1_distance, false);
   double estimated_tp2 = SafeLevelPrice(order_type, entry, tp2_distance, false);
   if(!ValidateSafeLevels(order_type, estimated_stop, estimated_tp1,
                          estimated_tp2))
     {
      Print("ActeckSmart Trader: фиксированные уровни Safe слишком близки к рынку или уже пройдены; сделка пропущена");
      return false;
     }

   double risk_per_lot = 0.0;
   double risk_budget = AccountInfoDouble(ACCOUNT_BALANCE) *
                        InpRiskPercent / 100.0 *
                        (100.0 - InpExecutionCostReservePct) / 100.0 / 2.0;
   double leg_volume = CalculateLegVolume(order_type, sizing_entry, sizing_stop,
                                           risk_budget, risk_per_lot);
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(max_volume <= 0.0)
     {
      Print("ActeckSmart Trader: не удалось получить максимальный объём символа");
      return false;
     }
   if(account_mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      max_volume *= 0.5;
   if(leg_volume > max_volume)
      leg_volume = NormalizeVolumeDown(max_volume);
   if(leg_volume <= 0.0)
     {
      Print("ActeckSmart Trader: минимальный объём превышает риск-бюджет сделки");
      return false;
     }
   if(!FitVolumeToMargin(order_type, entry, leg_volume, account_mode))
     {
      Print("ActeckSmart Trader: объём Safe не помещается в маржу с заданным ограничением плеча");
      return false;
     }

   double total_loss = 0.0;
   if(!OrderCalcProfit(order_type, _Symbol, leg_volume, sizing_entry,
                       sizing_stop, total_loss) ||
      MathAbs(total_loss) * 2.0 > AccountInfoDouble(ACCOUNT_BALANCE) *
                                  InpRiskPercent / 100.0 + 0.01)
     {
      Print("ActeckSmart Trader: фактический расчёт риска пары превышает лимит");
      return false;
     }
   if(risk_per_lot <= 0.0)
      return false;

   if(account_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      if(!ExecuteHedgingSafe(order_type, leg_volume, stop_distance,
                             tp1_distance, tp2_distance))
         return false;
     }
   else
     {
      if(!ExecuteNettingSafe(order_type, leg_volume, stop_distance,
                             tp1_distance, tp2_distance))
         return false;
     }

   g_last_trade_volume = leg_volume * 2.0;
   Print("ActeckSmart Trader: Safe открыт, symbol=", _Symbol,
         ", volume=", DoubleToString(g_last_trade_volume, VolumeDigits(
            SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))),
         ", SL distance=", DoubleToString(stop_distance, _Digits),
         ", TP1 distance=", DoubleToString(tp1_distance, _Digits),
         ", TP2 distance=", DoubleToString(tp2_distance, _Digits),
         ", spec spread=", DoubleToString(effective_spread, _Digits),
         ", risk%=", DoubleToString(InpRiskPercent, 2),
         ", max leverage 1:", InpMaximumLeverage);
   return true;
  }

bool CreateMultiPanelButton(const string name, const string caption,
                            const int x_distance, const int y_distance,
                            const int width, const int height,
                            const color background)
  {
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
      return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, background);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
   ObjectSetString(0, name, OBJPROP_TEXT, caption);
   return true;
  }

bool CreateMultiPanelEdit(const string name, const string initial_text,
                          const int x_distance, const int y_distance,
                          const int width)
  {
   if(!ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0))
      return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 30);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C'35,48,62');
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'190,201,213');
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 11);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 30);
   ObjectSetString(0, name, OBJPROP_TEXT, initial_text);
   return true;
  }

bool CreateMultiPanelLabel(const string name, const string caption,
                           const int x_distance, const int y_distance,
                           const color text_color, const int font_size)
  {
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
   ObjectSetString(0, name, OBJPROP_TEXT, caption);
   return true;
  }

void DeleteMultiPanel(void)
  {
   ObjectDelete(0, g_multi_buy_button);
   ObjectDelete(0, g_multi_sell_button);
   ObjectDelete(0, g_multi_lot_decrease);
   ObjectDelete(0, g_multi_lot_increase);
   ObjectDelete(0, g_multi_stop_decrease);
   ObjectDelete(0, g_multi_stop_increase);
   ObjectDelete(0, g_multi_toggle_button);
   ObjectDelete(0, g_multi_lot_edit);
   ObjectDelete(0, g_multi_stop_edit);
   ObjectDelete(0, g_multi_panel_prefix + "BG");
   ObjectDelete(0, g_multi_panel_prefix + "HEADER");
   ObjectDelete(0, g_multi_panel_prefix + "LOT_LABEL");
   ObjectDelete(0, g_multi_panel_prefix + "SL_LABEL");
   ObjectDelete(0, g_multi_panel_prefix + "ACCENT");
   ChartRedraw(0);
  }

void DeleteLegacyMultiPanel(void)
  {
   ObjectDelete(0, "AS_MULTI_BUY");
   ObjectDelete(0, "AS_MULTI_SELL");
   ObjectDelete(0, "AS_MULTI_LOT");
   ObjectDelete(0, "AS_MULTI_STOP");
   ObjectDelete(0, "AS_MULTI_LOT_MINUS");
   ObjectDelete(0, "AS_MULTI_LOT_PLUS");
   ObjectDelete(0, "AS_MULTI_STOP_MINUS");
   ObjectDelete(0, "AS_MULTI_STOP_PLUS");
   ObjectDelete(0, "AS_MULTI_TOGGLE");
   ObjectDelete(0, "AS_MULTI_BG");
   ObjectDelete(0, "AS_MULTI_HEADER");
   ObjectDelete(0, "AS_MULTI_LOT_LABEL");
   ObjectDelete(0, "AS_MULTI_SL_LABEL");
   ObjectDelete(0, "AS_MULTI_ACCENT");
  }

bool CreateMultiPanel(void)
  {
   // Remove prior namespaces before recreating this panel.
   DeleteMultiPanel();
   DeleteLegacyMultiPanel();

   string background = g_multi_panel_prefix + "BG";
   color panel_fill = C'246,248,251';
   if(!ObjectCreate(0, background, OBJ_RECTANGLE_LABEL, 0, 0, 0))
     {
      Print("ActeckSmart Trader: не удалось создать фон панели MULTI, err=",
            GetLastError());
      DeleteMultiPanel();
      return false;
     }
   ObjectSetInteger(0, background, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, background, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, background, OBJPROP_YDISTANCE, 190);
   ObjectSetInteger(0, background, OBJPROP_XSIZE, 420);
   ObjectSetInteger(0, background, OBJPROP_YSIZE, 184);
   ObjectSetInteger(0, background, OBJPROP_BGCOLOR, panel_fill);
   ObjectSetInteger(0, background, OBJPROP_COLOR, C'204,213,223');
   ObjectSetInteger(0, background, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, background, OBJPROP_BACK, false);
   ObjectSetInteger(0, background, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, background, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, background, OBJPROP_ZORDER, 0);

   string accent = g_multi_panel_prefix + "ACCENT";
   if(!ObjectCreate(0, accent, OBJ_RECTANGLE_LABEL, 0, 0, 0))
     {
      Print("ActeckSmart Trader: не удалось создать акцент панели MULTI, err=",
            GetLastError());
      DeleteMultiPanel();
      return false;
     }
   ObjectSetInteger(0, accent, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, accent, OBJPROP_XDISTANCE, 11);
   ObjectSetInteger(0, accent, OBJPROP_YDISTANCE, 199);
   ObjectSetInteger(0, accent, OBJPROP_XSIZE, 3);
   ObjectSetInteger(0, accent, OBJPROP_YSIZE, 142);
   ObjectSetInteger(0, accent, OBJPROP_BGCOLOR, C'43,119,190');
   ObjectSetInteger(0, accent, OBJPROP_COLOR, C'43,119,190');
   ObjectSetInteger(0, accent, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, accent, OBJPROP_BACK, false);
   ObjectSetInteger(0, accent, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, accent, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, accent, OBJPROP_ZORDER, 1);

   bool created =
      CreateMultiPanelLabel(g_multi_panel_prefix + "HEADER",
                            "MULTI-TRADE  |  ACTECKSMART",
                            28, 198, C'39,58,79', 9) &&
      CreateMultiPanelButton(g_multi_toggle_button, "−", 390, 198, 24, 20,
                             C'108,124,141') &&
      CreateMultiPanelLabel(g_multi_panel_prefix + "LOT_LABEL",
                            "LOT / ORDER", 28, 234, C'91,106,122', 8) &&
      CreateMultiPanelEdit(g_multi_lot_edit, DoubleToString(InpMultiLot, 2),
                           28, 260, 102) &&
      CreateMultiPanelButton(g_multi_lot_increase, "▲", 135, 260, 24, 14,
                             C'108,124,141') &&
      CreateMultiPanelButton(g_multi_lot_decrease, "▼", 135, 276, 24, 14,
                             C'108,124,141') &&
      CreateMultiPanelLabel(g_multi_panel_prefix + "SL_LABEL",
                            "SL / POINTS", 224, 234,
                            C'91,106,122', 8) &&
      CreateMultiPanelEdit(g_multi_stop_edit,
                           DoubleToString(InpMultiStopLossPoints, 2),
                           224, 260, 102) &&
      CreateMultiPanelButton(g_multi_stop_increase, "▲", 331, 260, 24, 14,
                             C'108,124,141') &&
      CreateMultiPanelButton(g_multi_stop_decrease, "▼", 331, 276, 24, 14,
                             C'108,124,141') &&
      CreateMultiPanelButton(g_multi_buy_button,
                             StringFormat("BUY x%d",
                                          InpMultiOrderCount),
                             28, 318, 180, 30, C'35,119,190') &&
      CreateMultiPanelButton(g_multi_sell_button,
                             StringFormat("SELL x%d",
                                          InpMultiOrderCount),
                             216, 318, 180, 30, C'194,77,83');
   if(!created)
     {
      Print("ActeckSmart Trader: не удалось создать панель MULTI, err=",
            GetLastError());
      DeleteMultiPanel();
      return false;
     }
   g_multi_last_valid_lot = InpMultiLot;
   g_multi_last_valid_stop = InpMultiStopLossPoints;
   ChartRedraw(0);
   Print("ActeckSmart Trader: панель MULTI создана в левом верхнем углу, под стандартной панелью One Click");
   return true;
  }

bool ReadPositivePanelNumber(const string object_name, double &value)
  {
   string text = ObjectGetString(0, object_name, OBJPROP_TEXT);
   StringTrimLeft(text);
   StringTrimRight(text);
   StringReplace(text, ",", ".");
   int length = StringLen(text);
   bool has_digit = false;
   bool has_decimal = false;
   for(int i = 0; i < length; i++)
     {
      ushort character = StringGetCharacter(text, i);
      if(character >= '0' && character <= '9')
         has_digit = true;
      else if(character == '.' && !has_decimal)
         has_decimal = true;
      else
         return false;
     }
   if(!has_digit)
      return false;
   value = StringToDouble(text);
   return (MathIsValidNumber(value) && value > 0.0);
  }

bool IsMultiLotValid(const double lot)
  {
   double minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maximum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minimum <= 0.0 || maximum <= 0.0 || step <= 0.0 ||
      lot < minimum - 1e-9 || lot > maximum + 1e-9)
      return false;

   double broker_steps = lot / step;
   double hundredth_steps = lot / 0.01;
   return (MathAbs(broker_steps - MathRound(broker_steps)) < 1e-7 &&
           MathAbs(hundredth_steps - MathRound(hundredth_steps)) < 1e-7);
  }

void AdjustMultiLot(const int step_direction)
  {
   double current_lot = 0.0;
   if(!ReadPositivePanelNumber(g_multi_lot_edit, current_lot) ||
      !IsMultiLotValid(current_lot))
      return;

   double new_lot = NormalizeDouble(current_lot + step_direction * 0.01, 2);
   if(!IsMultiLotValid(new_lot))
      return;
   ObjectSetString(0, g_multi_lot_edit, OBJPROP_TEXT,
                   DoubleToString(new_lot, 2));
   g_multi_last_valid_lot = new_lot;
   ChartRedraw(0);
  }

void AdjustMultiStopLoss(const int step_direction)
  {
   double current_points = 0.0;
   if(!ReadPositivePanelNumber(g_multi_stop_edit, current_points) ||
      current_points > 1000000.0)
     {
      Alert("ActeckSmart Trader: сначала укажите положительную дистанцию SL");
      return;
     }

   double new_points = NormalizeDouble(current_points + step_direction, 2);
   if(new_points <= 0.0 || new_points > 1000000.0)
     {
      Alert("ActeckSmart Trader: дистанция SL должна быть больше 0 и не превышать 1000000 пунктов");
      return;
     }
   ObjectSetString(0, g_multi_stop_edit, OBJPROP_TEXT,
                   DoubleToString(new_points, 2));
   g_multi_last_valid_stop = new_points;
   ChartRedraw(0);
  }

void SetMultiPanelExpanded(const bool expanded)
  {
   if(g_multi_panel_expanded == expanded)
      return;

   string content_objects[] =
     {
      g_multi_buy_button,
      g_multi_sell_button,
      g_multi_lot_decrease,
      g_multi_lot_increase,
      g_multi_stop_decrease,
      g_multi_stop_increase,
      g_multi_lot_edit,
      g_multi_stop_edit,
      g_multi_panel_prefix + "LOT_LABEL",
      g_multi_panel_prefix + "SL_LABEL"
     };
   int offset = expanded ? -g_multi_panel_hidden_offset
                         : g_multi_panel_hidden_offset;
   for(int i = 0; i < ArraySize(content_objects); i++)
     {
      if(ObjectFind(0, content_objects[i]) < 0)
         continue;
      long x_distance = ObjectGetInteger(0, content_objects[i],
                                         OBJPROP_XDISTANCE);
      ObjectSetInteger(0, content_objects[i], OBJPROP_XDISTANCE,
                       x_distance + offset);
     }

   ObjectSetInteger(0, g_multi_panel_prefix + "BG", OBJPROP_YSIZE,
                    expanded ? 184 : 38);
   ObjectSetInteger(0, g_multi_panel_prefix + "ACCENT", OBJPROP_YSIZE,
                    expanded ? 142 : 22);
   ObjectSetString(0, g_multi_toggle_button, OBJPROP_TEXT,
                   expanded ? "−" : "+");
   ObjectSetInteger(0, g_multi_toggle_button, OBJPROP_STATE, false);
   g_multi_panel_expanded = expanded;
   ChartRedraw(0);
  }

double MultiSpecificationPointPrice(void)
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   long digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string base_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string profit_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   if(StringLen(base_currency) == 3 && StringLen(profit_currency) == 3 &&
      (digits == 3 || digits == 5))
      return point * 10.0;

   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return (tick_size > 0.0) ? tick_size : point;
  }

bool ValidateMultiLevels(const ENUM_ORDER_TYPE order_type,
                         const double stop, const double take_profit)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0)
      return false;
   double minimum_distance = SymbolInfoInteger(_Symbol,
                                               SYMBOL_TRADE_STOPS_LEVEL) *
                             _Point;
   if(order_type == ORDER_TYPE_BUY)
      return (stop < tick.bid - minimum_distance &&
              take_profit > tick.bid + minimum_distance);
   return (stop > tick.ask + minimum_distance &&
           take_profit < tick.ask - minimum_distance);
  }

bool OpenMultiPosition(const ENUM_ORDER_TYPE order_type, const double volume,
                       const double common_stop, const double reward_ratio,
                       const int position_number, ulong &position_ticket)
  {
   position_ticket = 0;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return false;
   double quote_entry = (order_type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
   double initial_risk = MathAbs(quote_entry - common_stop);
   double provisional_tp = SafeLevelPrice(order_type, quote_entry,
                                          initial_risk * reward_ratio, false);
   if(!ValidateMultiLevels(order_type, common_stop, provisional_tp))
     {
      Print("ActeckSmart Trader: SL/TP слишком близки к рынку для ограничений брокера");
      return false;
     }

   string comment = StringFormat("Acteck Multi %d", position_number);
   bool sent = (order_type == ORDER_TYPE_BUY)
               ? g_trade.Buy(volume, _Symbol, 0.0, common_stop,
                             provisional_tp, comment)
               : g_trade.Sell(volume, _Symbol, 0.0, common_stop,
                              provisional_tp, comment);
   if(!sent || !IsTradeRetcodeSuccessful())
     {
      Print("ActeckSmart Trader: не удалось открыть MULTI-позицию ",
            position_number, ": ", g_trade.ResultRetcodeDescription());
      return false;
     }

   if(g_trade.ResultRetcode() == TRADE_RETCODE_DONE_PARTIAL)
     {
      double partial_fill = 0.0;
      ulong partial_ticket = 0;
      if(GetFillPriceAndPosition(g_trade.ResultDeal(), partial_fill,
                                 partial_ticket))
        {
         if(!CloseHedgingPositionFully(partial_ticket))
            Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть частично исполненную MULTI-позицию, ticket ",
                  partial_ticket);
        }
      else
         Alert("ActeckSmart Trader: КРИТИЧНО — частичное исполнение MULTI; проверьте позицию вручную");
      return false;
     }

   double fill_price = 0.0;
   if(!GetFillPriceAndPosition(g_trade.ResultDeal(), fill_price,
                               position_ticket))
     {
      Alert("ActeckSmart Trader: ордер MULTI исполнен, но ticket позиции не определён; проверьте её вручную");
      return false;
     }

   double actual_risk = MathAbs(fill_price - common_stop);
   double final_tp = SafeLevelPrice(order_type, fill_price,
                                    actual_risk * reward_ratio, false);
   if(!ValidateMultiLevels(order_type, common_stop, final_tp))
     {
      Print("ActeckSmart Trader: после исполнения цены не соответствуют ограничениям SL/TP");
      if(!CloseHedgingPositionFully(position_ticket))
         Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть MULTI-позицию с недопустимым TP, ticket ",
               position_ticket);
      return false;
     }
   bool modification_sent =
      g_trade.PositionModify(position_ticket, common_stop, final_tp);
   uint modification_retcode = g_trade.ResultRetcode();
   bool modification_succeeded =
      (modification_sent && modification_retcode == TRADE_RETCODE_DONE) ||
      modification_retcode == TRADE_RETCODE_NO_CHANGES;
   if(!modification_succeeded)
     {
      Print("ActeckSmart Trader: не удалось установить TP по фактическому fill: ",
            g_trade.ResultRetcodeDescription());
      if(!CloseHedgingPositionFully(position_ticket))
         Alert("ActeckSmart Trader: КРИТИЧНО — не удалось закрыть MULTI-позицию после ошибки установки TP, ticket ",
               position_ticket);
      return false;
     }
   return true;
  }

bool ExecuteMultiTrade(const ENUM_ORDER_TYPE order_type)
  {
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) !=
      ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Alert("ActeckSmart Trader: MULTI BUY/SELL доступны только на Hedging-счёте");
      return false;
     }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     {
      Alert("ActeckSmart Trader: торговля запрещена настройками терминала, эксперта или счёта");
      return false;
     }

   double lot = 0.0;
   double stop_loss_points = 0.0;
   if(!ReadPositivePanelNumber(g_multi_lot_edit, lot) ||
      !IsMultiLotValid(lot))
     {
      Alert("ActeckSmart Trader: лот должен быть не меньше минимума символа и соответствовать шагу 0.01 и шагу брокера");
      return false;
     }
   if(!ReadPositivePanelNumber(g_multi_stop_edit, stop_loss_points) ||
      stop_loss_points > 1000000.0)
     {
      Alert("ActeckSmart Trader: в поле SL укажите положительную дистанцию в пунктах");
      return false;
     }

   ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED ||
      trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY ||
      (order_type == ORDER_TYPE_BUY &&
       trade_mode == SYMBOL_TRADE_MODE_SHORTONLY) ||
      (order_type == ORDER_TYPE_SELL &&
       trade_mode == SYMBOL_TRADE_MODE_LONGONLY))
     {
      Alert("ActeckSmart Trader: направление MULTI-сделки запрещено для символа");
      return false;
     }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0)
     {
      Alert("ActeckSmart Trader: не удалось получить текущие Bid/Ask");
      return false;
     }
   double specification_point = MultiSpecificationPointPrice();
   if(specification_point <= 0.0)
     {
      Alert("ActeckSmart Trader: не удалось определить размер пункта символа");
      return false;
     }

   double entry = (order_type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
   double spread = MathMax(0.0, tick.ask - tick.bid);
   double stop_distance = stop_loss_points * specification_point + spread;
   double common_stop = SafeLevelPrice(order_type, entry, stop_distance, true);
   ulong first_ticket = 0;
   if(!OpenMultiPosition(order_type, lot, common_stop, 1.0, 1,
                         first_ticket))
      return false;

   if(InpMultiOrderCount == 1)
     {
      Print("ActeckSmart Trader: MULTI позиция открыта, ticket=",
            first_ticket, ", volume=", DoubleToString(lot, 2),
            ", SL=", DoubleToString(common_stop, _Digits), ", RR=1:1");
      return true;
     }

   ulong second_ticket = 0;
   if(!OpenMultiPosition(order_type, lot, common_stop, 2.0, 2,
                         second_ticket))
     {
      if(!CloseHedgingPositionFully(first_ticket))
         Alert("ActeckSmart Trader: КРИТИЧНО — второй MULTI-ордер не открыт, первый не удалось закрыть. Ticket ",
               first_ticket);
      return false;
     }

   Print("ActeckSmart Trader: MULTI ",
         (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
         " открыт: count=", InpMultiOrderCount,
         ", volume/order=", DoubleToString(lot, 2),
         ", common SL=", DoubleToString(common_stop, _Digits),
         ", TP1=1:1, TP2=1:2, tickets=", first_ticket, "/", second_ticket);
   return true;
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_ENDEDIT &&
      (sparam == g_multi_lot_edit || sparam == g_multi_stop_edit))
     {
      double value = 0.0;
      if(!ReadPositivePanelNumber(sparam, value) ||
         (sparam == g_multi_lot_edit && !IsMultiLotValid(value)) ||
         (sparam == g_multi_stop_edit && value > 1000000.0))
        {
         double last_valid = (sparam == g_multi_lot_edit)
                             ? g_multi_last_valid_lot
                             : g_multi_last_valid_stop;
         ObjectSetString(0, sparam, OBJPROP_TEXT,
                         DoubleToString(last_valid, 2));
         ChartRedraw(0);
         return;
        }
      ObjectSetString(0, sparam, OBJPROP_TEXT,
                      DoubleToString(value, 2));
      if(sparam == g_multi_lot_edit)
         g_multi_last_valid_lot = value;
      else
         g_multi_last_valid_stop = value;
      ChartRedraw(0);
      return;
     }

   if(id != CHARTEVENT_OBJECT_CLICK)
      return;
   if(sparam == g_multi_toggle_button)
     {
      SetMultiPanelExpanded(!g_multi_panel_expanded);
     }
   else if(sparam == g_multi_lot_decrease)
     {
      ObjectSetInteger(0, g_multi_lot_decrease, OBJPROP_STATE, false);
      AdjustMultiLot(-1);
     }
   else if(sparam == g_multi_lot_increase)
     {
      ObjectSetInteger(0, g_multi_lot_increase, OBJPROP_STATE, false);
      AdjustMultiLot(1);
     }
   else if(sparam == g_multi_stop_decrease)
     {
      ObjectSetInteger(0, g_multi_stop_decrease, OBJPROP_STATE, false);
      AdjustMultiStopLoss(-1);
     }
   else if(sparam == g_multi_stop_increase)
     {
      ObjectSetInteger(0, g_multi_stop_increase, OBJPROP_STATE, false);
      AdjustMultiStopLoss(1);
     }
   else if(sparam == g_multi_buy_button)
     {
      ObjectSetInteger(0, g_multi_buy_button, OBJPROP_STATE, false);
      ExecuteMultiTrade(ORDER_TYPE_BUY);
     }
   else if(sparam == g_multi_sell_button)
     {
      ObjectSetInteger(0, g_multi_sell_button, OBJPROP_STATE, false);
      ExecuteMultiTrade(ORDER_TYPE_SELL);
     }
  }

int OnInit()
  {
   if(InpRiskPercent <= 0.0 || InpRiskPercent > 2.0 ||
      InpMaximumLeverage < 1 || InpMaxSlippagePoints < 0 ||
      InpMagicNumber == 0 ||
      InpExecutionCostReservePct < 0.0 || InpExecutionCostReservePct >= 100.0 ||
      InpFreeMarginReservePct < 0.0 || InpFreeMarginReservePct >= 100.0 ||
      InpMultiOrderCount < 1 || InpMultiOrderCount > 2 ||
      InpMultiLot <= 0.0 || InpMultiStopLossPoints <= 0.0)
     {
      Print("ActeckSmart Trader: неверные параметры риска, маржи или MULTI-панели");
      return INIT_PARAMETERS_INCORRECT;
     }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints((ulong)InpMaxSlippagePoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_netting_state_prefix = StringFormat("ASAFE.%I64d.%I64u.%s.",
                                         AccountInfoInteger(ACCOUNT_LOGIN),
                                         InpMagicNumber,
                                         StringSubstr(_Symbol, 0, 12));
   g_last_processed_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   LoadNettingState();
   if(!CreateMultiPanel())
      return INIT_FAILED;
   EnsureSignalHandle();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   DeleteMultiPanel();
   g_signal_handle = INVALID_HANDLE;
  }

void OnTick()
  {
   ENUM_ACCOUNT_MARGIN_MODE account_mode =
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(account_mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      ManageNettingPosition();
   if(!EnsureSignalHandle())
      return;

   datetime closed_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   if(closed_bar == 0 || closed_bar == g_last_processed_bar)
      return;
   double direction, entry, stop, tp1, tp2, model;
   double spec_spread, spread_percent;
   bool buffers_ready = false;
   bool has_signal = ReadSignal(closed_bar, direction, entry, stop, tp1, tp2,
                                model, spec_spread, spread_percent,
                                buffers_ready);
   if(!buffers_ready)
      return;
   g_last_processed_bar = closed_bar;
   if(!has_signal)
      return;
   if(closed_bar == g_last_trade_signal)
      return;
   g_last_trade_signal = closed_bar;

   string model_name = (model == (double)SIGNAL_MODEL_CASCADE)
                       ? "каскадная" : "базовая";
   string side = (direction > 0.0) ? "BUY" : "SELL";
   Print("ActeckSmart Trader: подтверждён сигнал ", model_name, " ", side,
         " на ", _Symbol, " / ", EnumToString((ENUM_TIMEFRAMES)_Period));

   if(InpAutoTrading &&
      !ExecuteSignal(direction, entry, stop, tp1, tp2, spec_spread,
                     spread_percent))
      Print("ActeckSmart Trader: ордера не открыты; см. предыдущие причины в журнале");
  }
