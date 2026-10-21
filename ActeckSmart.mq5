//+------------------------------------------------------------------+
//|                                                  ActeckSmart.mq5 |
//|                                          Copyright Евгений Ацтек |
//|                                      https://github.com/Evgeniy-makdak/ActeckSmart_MT5 |
//+------------------------------------------------------------------+
#property copyright "Евгений Ацтек"
#property link      "https://github.com/Evgeniy-makdak/ActeckSmart_MT5"
#property version   "1.12"
#property description "ActeckSmart v1.12 — КЗ, модели расширения и сигналы входа"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   1
#property indicator_type1   DRAW_NONE
#property indicator_label1  "ActeckSmart"

// Версия индикатора
#define AS_VERSION   "1.12"
#define AS_SHORTNAME "ActeckSmart v" AS_VERSION
#define AS_RSI_CANVAS "RSI_CV" // единая панель RSI (spark + число)

#include <Canvas/Canvas.mqh>

//+------------------------------------------------------------------+
//| Входные параметры                                                |
//+------------------------------------------------------------------+
input string InpSep0                 = "======== ОБЩИЕ ========"; // —
input int    InpHistoryBars          = 1500;      // Глубина истории M15 (баров)
input int    InpBrokerGMTOffset      = 3;         // Сдвиг времени брокера относительно GMT (часы)
input bool   InpKeepHistory          = false;     // KeepHistory: не затухать и не удалять разметку
input int    InpFadeDays1            = 1;         // Через N дней объекты тускнеют
input int    InpFadeDays2            = 2;         // Через N дней объекты удаляются
input int    InpFadeAlpha1           = 90;        // Прозрачность (0-255) на 1-й день затухания
input int    InpFadeAlpha2           = 40;        // Прозрачность перед удалением

input string InpSep1                 = "======== ЗИГЗАГ 1-го УРОВНЯ ========"; // —
input bool   InpShowZigZag1          = false;     // Показывать зигзаг 1-го уровня
input color  InpZigZag1Color         = clrRed;    // Цвет зигзага 1-го уровня
input int    InpZigZag1Width         = 1;         // Толщина зигзага 1-го уровня
input ENUM_LINE_STYLE InpZigZag1Style = STYLE_SOLID; // Стиль зигзага 1-го уровня

input string InpSep2                 = "======== ЗИГЗАГ / ТЕНДЕНЦИИ 2-го УРОВНЯ ========"; // —
input bool   InpShowZigZag2          = false;     // Показывать зигзаг 2-го уровня
input color  InpZigZag2Color         = clrGold;   // Цвет зигзага 2-го уровня
input int    InpZigZag2Width         = 2;         // Толщина зигзага 2-го уровня
input ENUM_LINE_STYLE InpZigZag2Style = STYLE_SOLID; // Стиль зигзага 2-го уровня

input string InpSep3                 = "======== КОРРЕКЦИОННЫЕ ЗОНЫ (КЗ) ========"; // —
input bool   InpShowKZ               = true;      // Показывать КЗ
input int    InpKZWidth              = 1;         // Толщина пунктирной КЗ
input int    InpKZBrokenWidth        = 3;         // Толщина пробитой КЗ (начало ПД)
input ENUM_LINE_STYLE InpKZStyle     = STYLE_DASH; // Стиль обычной КЗ
input string InpKZFont               = "Arial";   // Шрифт подписи КЗ
input int    InpKZFontSize           = 8;         // Размер шрифта подписи КЗ
input int    InpKZLabelOffsetPoints  = 20;        // Смещение подписи КЗ (пункты)

input string InpSep4                 = "======== ЦВЕТА КЗ ПО СЕССИЯМ ========"; // —
input color  InpColorNY              = clrRed;         // New York
input color  InpColorLondon          = clrOrange;      // London
input color  InpColorEurope          = C'245,222,179'; // Europe (Beige)
input color  InpColorAsia            = clrDarkGreen;   // Asia
input color  InpColorAustralia       = clrDodgerBlue;  // Australia

input string InpSep5                 = "======== ВРЕМЯ СЕССИЙ (GMT) ========"; // —
input string InpSesAustraliaStart    = "21:00";   // Australia начало GMT
input string InpSesAustraliaEnd      = "07:00";   // Australia конец GMT
input string InpSesAsiaStart         = "21:00";   // Asia начало GMT (без дыры 21–23)
input string InpSesAsiaEnd           = "08:00";   // Asia конец GMT
input string InpSesEuropeStart       = "07:00";   // Europe начало GMT
input string InpSesEuropeEnd         = "16:00";   // Europe конец GMT
input string InpSesLondonStart       = "07:00";   // London начало GMT
input string InpSesLondonEnd         = "16:00";   // London конец GMT
input string InpSesNYStart           = "12:00";   // New York начало GMT
input string InpSesNYEnd             = "21:00";   // New York конец GMT

input string InpSep6                 = "======== ПРОДОЛЖЕННОЕ ДВИЖЕНИЕ ========"; // —
input bool   InpShowContinued        = true;      // Отображать продолженное движение
input color  InpContUpColor          = clrDodgerBlue; // Цвет ПД вверх (синий курсор)
input color  InpContDownColor        = clrRed;    // Цвет ПД вниз (красный курсор)
input ENUM_LINE_STYLE InpContStyle   = STYLE_DASH; // Стиль линий ПД
input int    InpContWidth            = 1;         // Толщина линий ПД
input int    InpContFontSize         = 10;        // Размер шрифта курсора/подписи ПД
input bool   InpShowContCursor       = true;      // Показывать курсор на конце ПД
input bool   InpSniperStyleHistory   = true;      // Стиль Sniper: хранить старые ПД/зоны (false = откат к v1.1)
input bool   InpHideObsoleteCM       = true;      // [v1.1] Скрывать линии старого ПД (если SniperStyle=false)
input bool   InpKeepObsoleteZones    = true;      // [Sniper] Оставлять зоны Fib у старых ПД
input int    InpMaxVisibleCM         = 2;         // [v1.1] Макс. видимых ПД (0=все; при SniperStyle игнор.)
input bool   InpContAlert            = false;     // Алерт появления ПД

input string InpSep7                 = "======== ЗОНЫ ИНТЕРЕСОВ (Fib 38.2%) ========"; // —
input bool   InpShowInterestZones    = true;      // Показывать зоны покупателей/продавцов
input color  InpBuyZoneColor         = C'173,216,230'; // Зона покупателей (нежно-голубой)
input color  InpSellZoneColor        = C'255,182,193'; // Зона продавцов (нежно-розовый)
input int    InpZoneAlpha            = 70;        // Непрозрачность НЕДОСТИГНУТОЙ зоны (0-255)
input int    InpZoneTouchedAlpha     = 45;        // Непрозрачность ЗАТРОНУТОЙ (не пробитой) зоны
input bool   InpZoneHideBroken       = true;      // Не рисовать зоны, пробитые ценой (ликвидность снята)
input bool   InpZoneShowStateLabel   = true;      // Показывать метку состояния зоны
input double InpFibLevel             = 0.382;     // Уровень Фибоначчи зоны интересов

input string InpSepBB                = "======== ПОЛОСЫ БОЛЛИНДЖЕРА (M15) ========"; // —
input bool   InpShowBollingerLevels  = true;      // Показывать уровни полос Боллинджера
input int    InpBBPeriod             = 100;       // Период Bollinger Bands
input double InpBBDeviation          = 2.0;       // Стандартное отклонение
input int    InpBBLineBars           = 8;         // Длина коротких линий (баров M15)
input int    InpBBLineWidth          = 2;         // Толщина линий (1-5)
input color  InpBBUpperColor         = clrRed;    // Верхняя полоса
input color  InpBBMiddleColor        = clrLimeGreen; // Центральная полоса
input color  InpBBLowerColor         = clrBlue;   // Нижняя полоса

input string InpSepSignals           = "======== СИГНАЛЫ РАСШИРЕНИЯ ========"; // —
input bool   InpEnableBaseSignals    = true;      // Сигналы базового расширения
input bool   InpEnableCascadeSignals = true;      // Сигналы каскадного расширения
input double InpBaseEntryFib         = 0.382;     // Глубина зоны входа базовой модели
input double InpCascadeEntryFib      = 0.236;     // Глубина зоны входа каскада
input int    InpSignalHistoryBars    = 3000;      // История сигналов на текущем ТФ
input int    InpSignalStopBuffer     = 2;         // Буфер SL за экстремумом (пункты)
input int    InpSignalLevelBars      = 24;        // Длина линий SL/TP (баров текущего ТФ)
input bool   InpSignalAlerts         = true;      // Алерт нового сигнала
input bool   InpShowSignalLevels     = true;      // Показывать уровни SL/TP на графике

input string InpSepRSI               = "======== RSI HUD (как Sniper) ========"; // —
input bool   InpShowRSI              = true;      // Показывать RSI в правом верхнем углу
input int    InpRSIPeriod            = 14;        // Период RSI
input bool   InpRSIUseM15            = false;     // RSI на M15 (false = ТФ графика)
input int    InpRSISparkBars         = 56;        // Баров в мини-графике RSI
input int    InpRSIPanelWidth        = 168;       // Ширина панели RSI (px)
input int    InpRSIPanelHeight       = 48;        // Высота панели RSI (px)
input int    InpRSISparkWidth        = 108;       // Ширина мини-графика внутри панели (px)
input int    InpRSIFontSize          = 26;        // Размер шрифта числа RSI
input color  InpRSIColorMid          = C'34,139,34';   // Зелёный (35..65)
input color  InpRSIColorWarn         = C'184,134,11';  // Тёмно-золотой (читаем на белом)
input color  InpRSIColorExt          = C'178,34,34';   // Красный (<30, >70)
input color  InpRSIPanelBg           = clrWhite;       // Фон панели RSI

input string InpSep8                 = "======== ПРЕФИКС ОБЪЕКТОВ ========"; // —
input string InpPrefix               = "AS_";     // Префикс графических объектов

//+------------------------------------------------------------------+
//| Константы и перечисления                                         |
//+------------------------------------------------------------------+
#define WORK_TF PERIOD_M15

enum ENUM_SIGNAL_MODEL
  {
   SIGNAL_MODEL_BASE = 1,
   SIGNAL_MODEL_CASCADE = 2
  };

enum ENUM_SESSION
  {
   SES_NONE = 0,
   SES_AUSTRALIA,
   SES_ASIA,
   SES_EUROPE,
   SES_LONDON,
   SES_NEWYORK
  };

enum ENUM_EXTREMUM
  {
   EXT_NONE = 0,
   EXT_HIGH,
   EXT_LOW
  };

enum ENUM_DIR
  {
   DIR_NONE = 0,
   DIR_UP,
   DIR_DOWN
  };

enum ENUM_ZONE_STATE
  {
   ZONE_FRESH = 0,   // цена ещё не заходила — ликвидность цела
   ZONE_TOUCHED,     // зашла, но не пробила — частично снята
   ZONE_BROKEN       // тень прошла дальнюю границу — ликвидность собрана
  };

//+------------------------------------------------------------------+
//| Структуры данных                                                 |
//+------------------------------------------------------------------+
struct SZigPoint
  {
   datetime time;
   double   price;
   int      bar;       // индекс в массиве rates (0 = самый старый)
   ENUM_EXTREMUM type;
  };

struct SKZ
  {
   datetime time_start;
   datetime time_confirm; // Бар, на котором КЗ стала известна алгоритму
   datetime time_end;     // обрыв при пересечении (0 = ещё актуален вправо)
   double   price;
   ENUM_SESSION session;
   bool     broken;       // пробита (для толстой линии ПД)
   bool     is_high;      // true = верхняя КЗ (на максимуме)
   int      zz_index;     // индекс точки зигзага 1
   bool     active;       // входит в актуальный диапазон баланса
   ENUM_DIR origin_l2;    // направление тенденции 2-го уровня, породившей КЗ
   int      balance_id;   // возрастающий ID зоны
  };

struct SContinued
  {
   datetime time_start;
   datetime time_end;
   double   price_break;      // горизонтальная опора (уровень пробоя)
   double   price_end;        // конечная горизонталь / последний экстремум
   double   unbroken_kz;      // непробитая КЗ (для Fib)
   double   broken_kz;        // пробитая КЗ
   ENUM_DIR direction;        // UP = пробой вверх
   bool     closed;           // завершена встречной КЗ
   bool     obsolete;         // вытеснена более новым ПД (линии скрыть)
   int      start_bar;
   int      end_bar;
   int      balance_id;       // диапазон, из которого стартовало ПД
   int      idx_broken;       // индекс пробитой КЗ
   int      idx_unbroken;     // индекс непробитой КЗ
   double   size_points;      // размер движения в пунктах (подпись курсора)
  };

struct STradeSignal
  {
   datetime time;
   datetime setup_time;
   ENUM_DIR direction;
   ENUM_SIGNAL_MODEL model;
   double entry;
   double stop_loss;
   double take_profit_1;
   double take_profit_2;
  };

bool     g_allow_cont_alerts = false;
datetime g_last_cont_alert_time = 0;
datetime g_last_signal_chart_bar = 0;
datetime g_last_trade_signal_time = 0;
double   g_signal_direction[];
double   g_signal_stop[];
double   g_signal_tp1[];
double   g_signal_tp2[];
double   g_signal_model[];
double   g_signal_processed_time[];
MqlRates g_signal_rates[];

//+------------------------------------------------------------------+
//| Вспомогательные функции времени и сессий                         |
//+------------------------------------------------------------------+
int TimeStringToMinutes(const string hhmm)
  {
   string parts[];
   int n = StringSplit(hhmm, ':', parts);
   if(n < 2)
      return 0;
   return (int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]);
  }

datetime BrokerToGMT(const datetime broker_time)
  {
   return broker_time - InpBrokerGMTOffset * 3600;
  }

int MinutesOfDayGMT(const datetime broker_time)
  {
   datetime gmt = BrokerToGMT(broker_time);
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   return dt.hour * 60 + dt.min;
  }

bool IsInSessionRange(const int minutes, const string start_s, const string end_s)
  {
   int start_m = TimeStringToMinutes(start_s);
   int end_m   = TimeStringToMinutes(end_s);
   if(start_m == end_m)
      return true;
   // Сессия через полночь
   if(start_m > end_m)
      return (minutes >= start_m || minutes < end_m);
   return (minutes >= start_m && minutes < end_m);
  }

// Расстояние в минутах до ближайшего края интервала [start,end) (через полночь учтён)
int MinutesToSession(const int minutes, const string start_s, const string end_s)
  {
   if(IsInSessionRange(minutes, start_s, end_s))
      return 0;
   int start_m = TimeStringToMinutes(start_s);
   int end_m   = TimeStringToMinutes(end_s);
   int d_start = MathMin(MathAbs(minutes - start_m), 1440 - MathAbs(minutes - start_m));
   int d_end   = MathMin(MathAbs(minutes - end_m),   1440 - MathAbs(minutes - end_m));
   return MathMin(d_start, d_end);
  }

// Приоритет при наложении: NY > London > Europe > Asia > Australia
// Asia перекрывает Australia в 21–08 GMT — как у Sniper (ночные КЗ = Asia, не N/A)
ENUM_SESSION DetectSession(const datetime broker_time)
  {
   int m = MinutesOfDayGMT(broker_time);
   if(IsInSessionRange(m, InpSesNYStart, InpSesNYEnd))
      return SES_NEWYORK;
   if(IsInSessionRange(m, InpSesLondonStart, InpSesLondonEnd))
      return SES_LONDON;
   if(IsInSessionRange(m, InpSesEuropeStart, InpSesEuropeEnd))
      return SES_EUROPE;
   if(IsInSessionRange(m, InpSesAsiaStart, InpSesAsiaEnd))
      return SES_ASIA;
   if(IsInSessionRange(m, InpSesAustraliaStart, InpSesAustraliaEnd))
      return SES_AUSTRALIA;

   // Fallback: ближайшая сессия (не оставляем «КЗ N/A»)
   ENUM_SESSION best = SES_ASIA;
   int best_d = MinutesToSession(m, InpSesAsiaStart, InpSesAsiaEnd);
   int d;
   d = MinutesToSession(m, InpSesAustraliaStart, InpSesAustraliaEnd);
   if(d < best_d) { best_d = d; best = SES_AUSTRALIA; }
   d = MinutesToSession(m, InpSesEuropeStart, InpSesEuropeEnd);
   if(d < best_d) { best_d = d; best = SES_EUROPE; }
   d = MinutesToSession(m, InpSesLondonStart, InpSesLondonEnd);
   if(d < best_d) { best_d = d; best = SES_LONDON; }
   d = MinutesToSession(m, InpSesNYStart, InpSesNYEnd);
   if(d < best_d) { best = SES_NEWYORK; }
   return best;
  }

string SessionName(const ENUM_SESSION s)
  {
   switch(s)
     {
      case SES_NEWYORK:   return "New-York";
      case SES_LONDON:    return "London";
      case SES_EUROPE:    return "Europe";
      case SES_ASIA:      return "Asia";
      case SES_AUSTRALIA: return "Australia";
      default:            return "N/A";
     }
  }

color SessionColor(const ENUM_SESSION s)
  {
   switch(s)
     {
      case SES_NEWYORK:   return InpColorNY;
      case SES_LONDON:    return InpColorLondon;
      case SES_EUROPE:    return InpColorEurope;
      case SES_ASIA:      return InpColorAsia;
      case SES_AUSTRALIA: return InpColorAustralia;
      default:            return clrGray;
     }
  }

color ApplyFade(const color base, const datetime object_day, const datetime now_broker)
  {
   if(InpKeepHistory)
      return base;
   datetime gmt_obj = BrokerToGMT(object_day);
   datetime gmt_now = BrokerToGMT(now_broker);
   MqlDateTime d1, d2;
   TimeToStruct(gmt_obj, d1);
   TimeToStruct(gmt_now, d2);
   datetime day_obj = StringToTime(StringFormat("%04d.%02d.%02d", d1.year, d1.mon, d1.day));
   datetime day_now = StringToTime(StringFormat("%04d.%02d.%02d", d2.year, d2.mon, d2.day));
   int days = (int)((day_now - day_obj) / 86400);
   if(days < InpFadeDays1)
      return base;
   uchar a = (uchar)((days < InpFadeDays2) ? InpFadeAlpha1 : InpFadeAlpha2);
   // Смешиваем с белым фоном для «тусклости»
   int r = (int)((base & 0xFF) * a / 255 + 255 * (255 - a) / 255);
   int g = (int)(((base >> 8) & 0xFF) * a / 255 + 255 * (255 - a) / 255);
   int b = (int)(((base >> 16) & 0xFF) * a / 255 + 255 * (255 - a) / 255);
   return (color)(r | (g << 8) | (b << 16));
  }

bool ShouldDeleteByAge(const datetime object_day, const datetime now_broker)
  {
   if(InpKeepHistory)
      return false;
   datetime gmt_obj = BrokerToGMT(object_day);
   datetime gmt_now = BrokerToGMT(now_broker);
   MqlDateTime d1, d2;
   TimeToStruct(gmt_obj, d1);
   TimeToStruct(gmt_now, d2);
   datetime day_obj = StringToTime(StringFormat("%04d.%02d.%02d", d1.year, d1.mon, d1.day));
   datetime day_now = StringToTime(StringFormat("%04d.%02d.%02d", d2.year, d2.mon, d2.day));
   int days = (int)((day_now - day_obj) / 86400);
   return (days >= InpFadeDays2 + 1);
  }

int DeletePrefixedObjects(const long chart_id, const string prefix)
  {
   int deleted = ObjectsDeleteAll(chart_id, prefix, -1, -1);
   ChartRedraw(chart_id);

   // Удаляем оставшиеся объекты по именам, чтобы очистить и графику,
   // созданную до версии, использующей ObjectsDeleteAll.
   for(int i = ObjectsTotal(chart_id, -1, -1) - 1; i >= 0; i--)
     {
      string name = ObjectName(chart_id, i, -1, -1);
      if(StringFind(name, prefix) != 0)
         continue;

      ResetLastError();
      if(ObjectDelete(chart_id, name))
         deleted++;
      else
         Print("ActeckSmart: не удалось удалить объект ", name,
               ", err=", GetLastError());
     }

   ChartRedraw(chart_id);
   int remaining = 0;
   for(int i = ObjectsTotal(chart_id, -1, -1) - 1; i >= 0; i--)
     {
      string name = ObjectName(chart_id, i, -1, -1);
      if(StringFind(name, prefix) == 0)
         remaining++;
     }
   if(remaining > 0)
      Print("ActeckSmart: после удаления осталось объектов с префиксом ",
            prefix, ": ", remaining);
   return deleted;
  }

//+------------------------------------------------------------------+
//| Класс: менеджер графических объектов                             |
//+------------------------------------------------------------------+
class CChartObjects
  {
private:
   string m_prefix;
   long   m_chart;

public:
   CChartObjects(void) : m_prefix("AS_"), m_chart(0) {}

   void Init(const long chart_id, const string prefix)
     {
      m_chart  = chart_id;
      m_prefix = prefix;
     }

   // Синхронное удаление по префиксу (ObjectDelete в цикле — async и в OnDeinit
   // часто не успевает → разметка остаётся на графике).
   // include_hud оставлен для совместимости вызовов; всегда сносится весь префикс.
   void DeleteAll(const bool include_hud = false)
     {
      long cid = (m_chart != 0) ? m_chart : ChartID();
      DeletePrefixedObjects(cid, m_prefix);
     }

   bool Trend(const string name, datetime t1, double p1, datetime t2, double p2,
              const color clr, const int width, const ENUM_LINE_STYLE style,
              const bool ray_right = false)
     {
      string full = m_prefix + name;
      if(ObjectFind(m_chart, full) < 0)
        {
         if(!ObjectCreate(m_chart, full, OBJ_TREND, 0, t1, p1, t2, p2))
            return false;
        }
      ObjectSetInteger(m_chart, full, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chart, full, OBJPROP_WIDTH, width);
      ObjectSetInteger(m_chart, full, OBJPROP_STYLE, style);
      ObjectSetInteger(m_chart, full, OBJPROP_RAY_RIGHT, ray_right);
      ObjectSetInteger(m_chart, full, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(m_chart, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, full, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, full, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(m_chart, full, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(m_chart, full, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(m_chart, full, OBJPROP_PRICE, 1, p2);
      return true;
     }

   bool HLineSegment(const string name, datetime t1, datetime t2, double price,
                     const color clr, const int width, const ENUM_LINE_STYLE style)
     {
      return Trend(name, t1, price, t2, price, clr, width, style, false);
     }

   bool Rectangle(const string name, datetime t1, double p1, datetime t2, double p2,
                  const color clr, const int alpha)
     {
      string full = m_prefix + name;
      if(ObjectFind(m_chart, full) < 0)
        {
         if(!ObjectCreate(m_chart, full, OBJ_RECTANGLE, 0, t1, p1, t2, p2))
            return false;
        }
      // В MT5 заливка прямоугольника: COLOR с альфа-каналом через ColorToARGB
      uint fill = ColorToARGB(clr, (uchar)alpha);
      ObjectSetInteger(m_chart, full, OBJPROP_COLOR, fill);
      ObjectSetInteger(m_chart, full, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(m_chart, full, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chart, full, OBJPROP_FILL, true);
      ObjectSetInteger(m_chart, full, OBJPROP_BACK, true);
      ObjectSetInteger(m_chart, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, full, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(m_chart, full, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(m_chart, full, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(m_chart, full, OBJPROP_PRICE, 1, p2);
      return true;
     }

   bool TextLabel(const string name, datetime t, double price, const string text,
                  const color clr, const string font, const int fontsize,
                  const ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_LOWER)
     {
      string full = m_prefix + name;
      if(ObjectFind(m_chart, full) < 0)
        {
         if(!ObjectCreate(m_chart, full, OBJ_TEXT, 0, t, price))
            return false;
        }
      ObjectSetString(m_chart, full, OBJPROP_TEXT, text);
      ObjectSetString(m_chart, full, OBJPROP_FONT, font);
      ObjectSetInteger(m_chart, full, OBJPROP_FONTSIZE, fontsize);
      ObjectSetInteger(m_chart, full, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chart, full, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(m_chart, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, full, OBJPROP_TIME, 0, t);
      ObjectSetDouble(m_chart, full, OBJPROP_PRICE, 0, price);
      return true;
     }

   // Курсор ПД: стрелка вверх (синий) / вниз (красный)
   bool CursorArrow(const string name, datetime t, double price,
                    const ENUM_DIR dir, const color clr)
     {
      string full = m_prefix + name;
      // Wingdings: 233 вверх, 234 вниз — через OBJ_ARROW_BUY/SELL надёжнее
      ENUM_OBJECT ot = (dir == DIR_UP) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
      if(ObjectFind(m_chart, full) < 0)
        {
         if(!ObjectCreate(m_chart, full, ot, 0, t, price))
            return false;
        }
      ObjectSetInteger(m_chart, full, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chart, full, OBJPROP_WIDTH, 2);
      ObjectSetInteger(m_chart, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, full, OBJPROP_TIME, 0, t);
      ObjectSetDouble(m_chart, full, OBJPROP_PRICE, 0, price);
      return true;
     }
  };

//+------------------------------------------------------------------+
//| Класс: Зигзаг 1-го уровня (баровый алгоритм с тенями)            |
//+------------------------------------------------------------------+
class CZigZagLevel1
  {
private:
   SZigPoint m_points[];

   bool IsInternal(const MqlRates &r[], const int ref, const int i)
     {
      return (r[i].high <= r[ref].high && r[i].low >= r[ref].low);
     }

   bool IsExternal(const MqlRates &r[], const int ref, const int i)
     {
      return (r[i].high > r[ref].high && r[i].low < r[ref].low);
     }

   void AddPoint(const datetime t, const double price, const int bar, const ENUM_EXTREMUM type)
     {
      int n = ArraySize(m_points);
      // Обновление последнего экстремума того же типа (без двух HIGH/LOW подряд)
      if(n > 0 && m_points[n - 1].type == type)
        {
         if(type == EXT_HIGH)
           {
            if(price >= m_points[n - 1].price)
              {
               m_points[n - 1].time  = t;
               m_points[n - 1].price = price;
               m_points[n - 1].bar   = bar;
              }
            return;
           }
         if(type == EXT_LOW)
           {
            if(price <= m_points[n - 1].price)
              {
               m_points[n - 1].time  = t;
               m_points[n - 1].price = price;
               m_points[n - 1].bar   = bar;
              }
            return;
           }
        }
      ArrayResize(m_points, n + 1);
      m_points[n].time  = t;
      m_points[n].price = price;
      m_points[n].bar   = bar;
      m_points[n].type  = type;
     }

public:
   void Clear(void) { ArrayResize(m_points, 0); }

   int Size(void) const { return ArraySize(m_points); }

   SZigPoint At(const int i) const { return m_points[i]; }

   // Построение зигзага по массиву rates (индекс 0 = самый старый бар)
   void Build(const MqlRates &rates[], const int total)
     {
      Clear();
      if(total < 3)
         return;

      int ref = 0;
      ENUM_DIR dir = DIR_NONE;
      int i = 1;

      while(i < total)
        {
         // Внутренний бар — игнорируем
         if(IsInternal(rates, ref, i))
           {
            i++;
            continue;
           }

         // Два внешних бара подряд: n и n+1 внешние → средний (i) игнорируем
         if(IsExternal(rates, ref, i) && (i + 1) < total)
           {
            if(IsExternal(rates, i, i + 1))
              {
               // Первый внешний игнорируется; второй становится базовым.
               // по ТЗ: n+9 игнорируется, сравниваем n+11 с n+10
               // n+10 становится новой базовой свечой, n+11 сравнивается с ней.
               ref = i + 1;
               i += 2;
               continue;
              }

            // Внешний бар: смотрим следующий бар для выбора направления
            int nxt = i + 1;
            if(nxt >= total)
               break; // ждём закрытия следующей свечи

            if(rates[nxt].low < rates[i].low)
              {
               // Тянем зигзаг на High внешнего, затем на Low следующего
               AddPoint(rates[i].time, rates[i].high, i, EXT_HIGH);
               AddPoint(rates[nxt].time, rates[nxt].low, nxt, EXT_LOW);
               dir = DIR_DOWN;
               ref = nxt;
               i = nxt + 1;
               continue;
              }
            if(rates[nxt].high > rates[i].high)
              {
               AddPoint(rates[i].time, rates[i].low, i, EXT_LOW);
               AddPoint(rates[nxt].time, rates[nxt].high, nxt, EXT_HIGH);
               dir = DIR_UP;
               ref = nxt;
               i = nxt + 1;
               continue;
              }
            // Следующий не обновил экстремумы внешнего однозначно — как обновление ref
            ref = i;
            i++;
            continue;
           }

         // Обычное обновление High или Low
         bool up   = (rates[i].high > rates[ref].high);
         bool down = (rates[i].low  < rates[ref].low);

         if(up && !down)
           {
            if(dir == DIR_DOWN || dir == DIR_NONE)
              {
               // Разворот вверх: фиксируем Low референса, если ещё нет
               if(dir == DIR_DOWN || Size() == 0)
                  AddPoint(rates[ref].time, rates[ref].low, ref, EXT_LOW);
               AddPoint(rates[i].time, rates[i].high, i, EXT_HIGH);
               dir = DIR_UP;
              }
            else
              {
               // Продолжение вверх — обновляем High
               AddPoint(rates[i].time, rates[i].high, i, EXT_HIGH);
              }
            ref = i;
            i++;
            continue;
           }

         if(down && !up)
           {
            if(dir == DIR_UP || dir == DIR_NONE)
              {
               if(dir == DIR_UP || Size() == 0)
                  AddPoint(rates[ref].time, rates[ref].high, ref, EXT_HIGH);
               AddPoint(rates[i].time, rates[i].low, i, EXT_LOW);
               dir = DIR_DOWN;
              }
            else
              {
               AddPoint(rates[i].time, rates[i].low, i, EXT_LOW);
              }
            ref = i;
            i++;
            continue;
           }

         // Неожиданный кейс (не должен случаться после фильтров)
         ref = i;
         i++;
        }
     }

   void Draw(CChartObjects &gfx, const datetime now_broker)
     {
      if(!InpShowZigZag1)
         return;
      int n = Size();
      for(int i = 1; i < n; i++)
        {
         if(ShouldDeleteByAge(m_points[i - 1].time, now_broker))
            continue;
         color clr = ApplyFade(InpZigZag1Color, m_points[i - 1].time, now_broker);
         gfx.Trend("ZZ1_" + IntegerToString(i),
                   m_points[i - 1].time, m_points[i - 1].price,
                   m_points[i].time, m_points[i].price,
                   clr, InpZigZag1Width, InpZigZag1Style);
        }
     }
  };

//+------------------------------------------------------------------+
//| Класс: Тенденции 2-го уровня и Коррекционные зоны                |
//+------------------------------------------------------------------+
class CCorrectionZones
  {
private:
   SZigPoint m_zz2[];
   SKZ       m_kz[];
   CZigZagLevel1 *m_zz1;

   void AddZZ2(const SZigPoint &p)
     {
      int n = ArraySize(m_zz2);
      if(n > 0 && m_zz2[n - 1].type == p.type)
        {
         m_zz2[n - 1] = p;
         return;
        }
      ArrayResize(m_zz2, n + 1);
      m_zz2[n] = p;
     }

   void AddKZ(const SZigPoint &p, const datetime confirmed_at,
              const ENUM_DIR origin_l2)
     {
      // Не дублируем одну и ту же точку зигзага; близкие отдельные КЗ сохраняем.
      int n = ArraySize(m_kz);
      for(int j = 0; j < n; j++)
        {
         if(m_kz[j].zz_index == p.bar && m_kz[j].is_high == (p.type == EXT_HIGH))
            return;
        }

      ArrayResize(m_kz, n + 1);
      m_kz[n].time_start = p.time;
      m_kz[n].time_confirm = confirmed_at;
      m_kz[n].time_end   = 0;
      m_kz[n].price      = p.price;
      m_kz[n].session    = DetectSession(p.time);
      m_kz[n].broken     = false;
      m_kz[n].is_high    = (p.type == EXT_HIGH);
      m_kz[n].zz_index   = p.bar;
      m_kz[n].active     = true;
      m_kz[n].origin_l2  = origin_l2;
      m_kz[n].balance_id = n;
     }

public:
   CCorrectionZones(void) : m_zz1(NULL) {}

   void SetZigZag(CZigZagLevel1 *zz) { m_zz1 = zz; }

   void Clear(void)
     {
      ArrayResize(m_zz2, 0);
      ArrayResize(m_kz, 0);
     }

   int KZCount(void) const { return ArraySize(m_kz); }

   SKZ KZAt(const int i) const { return m_kz[i]; }

   void SetKZBroken(const int i, const bool v)
     {
      if(i >= 0 && i < ArraySize(m_kz))
         m_kz[i].broken = v;
     }

   void SetKZEnd(const int i, const datetime t)
     {
      if(i >= 0 && i < ArraySize(m_kz))
         m_kz[i].time_end = t;
     }

   // Построение тенденций 2-го уровня и КЗ по правилам ИКИ (из PDF)
   void Build(const MqlRates &rates[], const int total)
     {
      Clear();
      if(m_zz1 == NULL || m_zz1.Size() < 4)
         return;

      int n = m_zz1.Size();
      ENUM_DIR l2_dir = DIR_NONE;

      for(int i = 3; i < n; i++)
        {
         SZigPoint p0 = m_zz1.At(i - 3);
         SZigPoint p1 = m_zz1.At(i - 2);
         SZigPoint p2 = m_zz1.At(i - 1);
         SZigPoint p3 = m_zz1.At(i);

         if(p0.type == EXT_LOW && p1.type == EXT_HIGH &&
            p2.type == EXT_LOW && p3.type == EXT_HIGH &&
            p2.price > p0.price && p3.price > p1.price)
           {
            AddZZ2(p1);
            AddZZ2(p3);
            if(l2_dir != DIR_UP)
              {
               // КЗ создаётся по подтверждённой обратной ИКИ.
               // Не требуем повторной проверки уже пройденного уровня:
               // пробой мог произойти до подтверждения второго импульса.
               AddKZ(p0, p3.time, DIR_UP);
               l2_dir = DIR_UP;
              }
           }

         if(p0.type == EXT_HIGH && p1.type == EXT_LOW &&
            p2.type == EXT_HIGH && p3.type == EXT_LOW &&
            p2.price < p0.price && p3.price < p1.price)
           {
            AddZZ2(p1);
            AddZZ2(p3);
            if(l2_dir != DIR_DOWN)
              {
               AddKZ(p0, p3.time, DIR_DOWN);
               l2_dir = DIR_DOWN;
              }
           }
        }

      UpdateCrossings(rates, total);
     }

   void UpdateCrossings(const MqlRates &rates[], const int total)
     {
      int kz_n = ArraySize(m_kz);
      for(int k = 0; k < kz_n; k++)
        {
         if(m_kz[k].time_end != 0)
            continue;
         // Ищем бар после создания КЗ, который пересёк уровень
         for(int i = 0; i < total; i++)
           {
            if(rates[i].time <= m_kz[k].time_start)
               continue;
            if(rates[i].high >= m_kz[k].price && rates[i].low <= m_kz[k].price)
              {
               m_kz[k].time_end = rates[i].time;
               break;
              }
           }
        }
     }

   // Диапазон образуют последние подтверждённые верхняя и нижняя КЗ.
   bool GetBalanceRangeAt(const datetime t, double &high_kz, double &low_kz,
                          int &idx_high, int &idx_low, int &balance_id)
     {
      idx_high = -1;
      idx_low  = -1;
      high_kz  = -DBL_MAX;
      low_kz   = DBL_MAX;
      balance_id = -1;
      int n = ArraySize(m_kz);
      if(n < 1)
         return false;

      datetime high_confirm = 0;
      datetime low_confirm  = 0;
      for(int i = 0; i < n; i++)
        {
         if(t != 0 && m_kz[i].time_confirm > t)
            continue;
         if(m_kz[i].is_high &&
            (idx_high < 0 || m_kz[i].time_confirm >= high_confirm))
           {
            idx_high = i;
            high_kz = m_kz[i].price;
            high_confirm = m_kz[i].time_confirm;
           }
         if(!m_kz[i].is_high &&
            (idx_low < 0 || m_kz[i].time_confirm >= low_confirm))
           {
            idx_low = i;
            low_kz  = m_kz[i].price;
            low_confirm = m_kz[i].time_confirm;
           }
        }

      if(idx_high < 0 || idx_low < 0 || high_kz <= low_kz)
         return false;
      // У каждой зоны уникальный возрастающий ID; максимум пары меняется
      // при появлении новой границы диапазона.
      balance_id = (m_kz[idx_high].balance_id > m_kz[idx_low].balance_id)
                   ? m_kz[idx_high].balance_id : m_kz[idx_low].balance_id;
      return true;
     }

   bool GetBalanceRange(double &high_kz, double &low_kz, int &idx_high, int &idx_low)
     {
      int bal = -1;
      return GetBalanceRangeAt(0, high_kz, low_kz, idx_high, idx_low, bal);
     }

   bool GetNearestTarget(const ENUM_DIR direction, const datetime at_time,
                        const double entry, double &target) const
     {
      target = 0.0;
      double nearest = DBL_MAX;
      for(int i = 0; i < ArraySize(m_kz); i++)
        {
         if(m_kz[i].time_confirm > at_time ||
            (m_kz[i].time_end != 0 && m_kz[i].time_end <= at_time))
            continue;
         if(direction == DIR_UP && m_kz[i].is_high && m_kz[i].price > entry)
           {
            double distance = m_kz[i].price - entry;
            if(distance < nearest)
              {
               nearest = distance;
               target = m_kz[i].price;
              }
           }
         else if(direction == DIR_DOWN && !m_kz[i].is_high && m_kz[i].price < entry)
           {
            double distance = entry - m_kz[i].price;
            if(distance < nearest)
              {
               nearest = distance;
               target = m_kz[i].price;
              }
           }
        }
      return (nearest < DBL_MAX);
     }

   // Встречная КЗ, подтверждённая после начала ПД.
   bool FindOpposingKZ(const datetime t_from, const datetime t_to,
                       const ENUM_DIR cm_dir, int &idx_out) const
     {
      idx_out = -1;
      ENUM_DIR need = (cm_dir == DIR_DOWN) ? DIR_UP : DIR_DOWN;
      int n = ArraySize(m_kz);
      for(int k = 0; k < n; k++)
        {
         if(m_kz[k].time_confirm <= t_from)
            continue;
         if(t_to != 0 && m_kz[k].time_confirm > t_to)
            continue;
         if(m_kz[k].origin_l2 == need)
           {
            idx_out = k;
            return true;
           }
        }
      return false;
     }

   void Draw(CChartObjects &gfx, const MqlRates &rates[], const int total, const datetime now_broker)
     {
      // Зигзаг 2
      if(InpShowZigZag2)
        {
         int n = ArraySize(m_zz2);
         for(int i = 1; i < n; i++)
           {
            if(ShouldDeleteByAge(m_zz2[i - 1].time, now_broker))
               continue;
            color clr = ApplyFade(InpZigZag2Color, m_zz2[i - 1].time, now_broker);
            gfx.Trend("ZZ2_" + IntegerToString(i),
                      m_zz2[i - 1].time, m_zz2[i - 1].price,
                      m_zz2[i].time, m_zz2[i].price,
                      clr, InpZigZag2Width, InpZigZag2Style);
           }
        }

      if(!InpShowKZ)
         return;

      datetime last_time = (total > 0) ? rates[total - 1].time + PeriodSeconds(WORK_TF) : TimeCurrent();
      double point_off = InpKZLabelOffsetPoints * _Point;

      int kz_n = ArraySize(m_kz);
      int current_high = -1, current_low = -1;
      double current_high_price, current_low_price;
      bool has_balance = GetBalanceRange(current_high_price, current_low_price,
                                         current_high, current_low);
      int latest_kz = -1;
      if(!has_balance)
        {
         for(int k = 0; k < kz_n; k++)
            if(latest_kz < 0 ||
               m_kz[k].time_confirm > m_kz[latest_kz].time_confirm)
               latest_kz = k;
        }

      for(int k = 0; k < kz_n; k++)
        {
         bool current = (k == current_high || k == current_low || k == latest_kz);
         if(!current && ShouldDeleteByAge(m_kz[k].time_confirm, now_broker))
            continue;

         datetime t2 = (m_kz[k].time_end != 0) ? m_kz[k].time_end : last_time;
         color base = SessionColor(m_kz[k].session);
         color clr  = current ? base : ApplyFade(base, m_kz[k].time_confirm, now_broker);
         int width  = m_kz[k].broken ? InpKZBrokenWidth : InpKZWidth;
         ENUM_LINE_STYLE style = m_kz[k].broken ? STYLE_SOLID : InpKZStyle;

         gfx.HLineSegment("KZ_" + IntegerToString(k),
                          m_kz[k].time_start, t2, m_kz[k].price,
                          clr, width, style);

         string label = "КЗ " + SessionName(m_kz[k].session);
         double label_price = m_kz[k].is_high ? m_kz[k].price + point_off
                                              : m_kz[k].price - point_off;
         gfx.TextLabel("KZL_" + IntegerToString(k),
                       m_kz[k].time_start, label_price, label,
                       clr, InpKZFont, InpKZFontSize);
        }
     }
  };

//+------------------------------------------------------------------+
//| Класс: Структура «Продолженное движение»                         |
//+------------------------------------------------------------------+
class CContinuedMove
  {
private:
   SContinued m_items[];
   CCorrectionZones *m_kz;

   void AddItem(const SContinued &item)
     {
      int n = ArraySize(m_items);
      ArrayResize(m_items, n + 1);
      m_items[n] = item;
     }

public:
   CContinuedMove(void) : m_kz(NULL) {}
   void SetKZ(CCorrectionZones *kz) { m_kz = kz; }
   void Clear(void) { ArrayResize(m_items, 0); }
   int  Size(void) const { return ArraySize(m_items); }
   SContinued At(const int i) const { return m_items[i]; }

   void MarkObsoleteExceptLast(void)
     {
      int n = ArraySize(m_items);
      if(n <= 1)
         return;
      // При появлении нового ПД старые помечаем obsolete (как в образце — линии уходят,
      // остаётся курсор на актуальном / последних)
      for(int i = 0; i < n - 1; i++)
         m_items[i].obsolete = true;
      m_items[n - 1].obsolete = false;
     }

   void FinalizeItem(SContinued &cur, const MqlRates &rates[], const int total)
     {
      if(cur.end_bar >= 0 && cur.end_bar < total)
        {
         cur.price_end = (cur.direction == DIR_UP) ? rates[cur.end_bar].high
                                                   : rates[cur.end_bar].low;
         if(cur.time_end == 0)
            cur.time_end = rates[cur.end_bar].time;
        }
      cur.size_points = MathAbs(cur.price_end - cur.price_break) / _Point;
      AddItem(cur);
      MarkObsoleteExceptLast();
     }

   int CountNewZones(const datetime after, const datetime through) const
     {
      int count = 0;
      for(int i = 0; i < m_kz.KZCount(); i++)
        {
         SKZ zone = m_kz.KZAt(i);
         if(zone.time_confirm > after && zone.time_confirm <= through)
            count++;
        }
      return count;
     }

   void BuildSignals(const MqlRates &chart_rates[], const int total,
                     STradeSignal &signals[]) const
     {
      ArrayResize(signals, 0);
      if(m_kz == NULL || total <= 0)
         return;
      double min_stop_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double stop_buffer = MathMax((double)InpSignalStopBuffer, min_stop_points) * _Point;

      for(int i = 0; i < ArraySize(m_items); i++)
        {
         SContinued item = m_items[i];
         if(!item.closed || item.time_end == 0)
            continue;

         if(i == 0 || !m_items[i - 1].closed)
            continue;

         SContinued previous = m_items[i - 1];
         ENUM_SIGNAL_MODEL model;
         double impulse_start = item.price_break;
         double impulse_end = item.price_end;
         // Два однонаправленных движения с двумя новыми КЗ образуют каскад;
         // противоположные последовательные движения подтверждают базовую модель.
         if(previous.direction == item.direction &&
            previous.time_end < item.time_start &&
            CountNewZones(previous.time_end, item.time_end) >= 2)
           {
            model = SIGNAL_MODEL_CASCADE;
            impulse_start = previous.price_break;
            impulse_end = item.price_end;
           }
         else if(previous.direction != item.direction &&
                 previous.time_end < item.time_start)
            model = SIGNAL_MODEL_BASE;
         else
            continue;

         if((model == SIGNAL_MODEL_BASE && !InpEnableBaseSignals) ||
            (model == SIGNAL_MODEL_CASCADE && !InpEnableCascadeSignals))
            continue;

         double impulse = MathAbs(impulse_end - impulse_start);
         if(impulse <= _Point)
            continue;

         double fib = (model == SIGNAL_MODEL_CASCADE)
                      ? InpCascadeEntryFib : InpBaseEntryFib;
         if(fib <= 0.0 || fib >= 1.0)
            continue;

         double zone_low, zone_high;
         if(item.direction == DIR_UP)
           {
            zone_low = impulse_end - impulse * fib;
            zone_high = impulse_end;
           }
         else
           {
            zone_low = impulse_end;
            zone_high = impulse_end + impulse * fib;
           }

         for(int bar = 0; bar < total; bar++)
           {
            if(chart_rates[bar].time <= item.time_end)
               continue;
            if(item.direction == DIR_UP && chart_rates[bar].low <= impulse_start)
              {
               break;
              }
            if(item.direction == DIR_DOWN && chart_rates[bar].high >= impulse_start)
               break;
            if(chart_rates[bar].low > zone_high || chart_rates[bar].high < zone_low)
               continue;

            double entry = chart_rates[bar].close;
            double stop = (item.direction == DIR_UP)
                          ? chart_rates[bar].low - stop_buffer
                          : chart_rates[bar].high + stop_buffer;
            double risk_distance = MathAbs(entry - stop);
            if(risk_distance <= _Point)
               break;

            double target = 0.0;
            if(!m_kz.GetNearestTarget(item.direction, chart_rates[bar].time,
                                      entry, target))
               break;

            double tp1 = (item.direction == DIR_UP) ? entry + risk_distance
                                                    : entry - risk_distance;
            double tp2 = (item.direction == DIR_UP) ? entry + risk_distance * 2.0
                                                    : entry - risk_distance * 2.0;
            if((item.direction == DIR_UP && target < tp2) ||
               (item.direction == DIR_DOWN && target > tp2))
               break;

            STradeSignal signal;
            signal.time = chart_rates[bar].time;
            signal.setup_time = item.time_end;
            signal.direction = item.direction;
            signal.model = model;
            signal.entry = entry;
            signal.stop_loss = NormalizeDouble(stop, _Digits);
            signal.take_profit_1 = NormalizeDouble(tp1, _Digits);
            signal.take_profit_2 = NormalizeDouble(tp2, _Digits);

            int n = ArraySize(signals);
            ArrayResize(signals, n + 1);
            signals[n] = signal;
            break;
           }
        }

      for(int i = 0; i < ArraySize(signals) - 1; i++)
         for(int j = i + 1; j < ArraySize(signals); j++)
            if(signals[j].time < signals[i].time)
              {
               STradeSignal swap = signals[i];
               signals[i] = signals[j];
               signals[j] = swap;
              }

      // Не допускаем несколько входов на одном баре: берём сигнал от самой
      // поздней подтверждённой модели.
      int write = 0;
      for(int i = 0; i < ArraySize(signals);)
        {
         int best = i;
         int next = i + 1;
         while(next < ArraySize(signals) && signals[next].time == signals[i].time)
           {
            if(signals[next].setup_time > signals[best].setup_time)
               best = next;
            next++;
           }
         signals[write] = signals[best];
         write++;
         i = next;
        }
      ArrayResize(signals, write);
     }

   void Build(const MqlRates &rates[], const int total)
     {
      Clear();
      if(m_kz == NULL || total < 5)
         return;

      // Пробой закрытием диапазона → экстремумы → подтверждение встречной КЗ

      bool in_move = false;
      SContinued cur;
      ZeroMemory(cur);

      double high_kz = 0, low_kz = 0;
      int idx_h = -1, idx_l = -1, bal_id = -1;
      datetime armed_after = 0;
      int locked_bal = -1;

      for(int i = 0; i < total; i++)
        {
         if(!in_move)
           {
            if(!m_kz.GetBalanceRangeAt(rates[i].time, high_kz, low_kz, idx_h, idx_l, bal_id))
               continue;

            SKZ kz_h = m_kz.KZAt(idx_h);
            SKZ kz_l = m_kz.KZAt(idx_l);
            datetime range_start = (kz_h.time_confirm > kz_l.time_confirm)
                                   ? kz_h.time_confirm : kz_l.time_confirm;

            if(rates[i].time <= range_start)
               continue;
            if(armed_after != 0 && rates[i].time <= armed_after)
               continue;
            if(bal_id == locked_bal)
               continue;

            if(rates[i].close > high_kz)
              {
               in_move = true;
               ZeroMemory(cur);
               cur.direction    = DIR_UP;
               cur.price_break  = high_kz;
               cur.broken_kz    = high_kz;
               cur.unbroken_kz  = low_kz;
               cur.time_start   = rates[i].time;
               cur.start_bar    = i;
               cur.price_end    = rates[i].high;
               cur.end_bar      = i;
               cur.time_end     = rates[i].time;
               cur.closed       = false;
               cur.obsolete     = false;
               cur.balance_id   = bal_id;
               cur.idx_broken   = idx_h;
               cur.idx_unbroken = idx_l;
               locked_bal       = bal_id;
               m_kz.SetKZBroken(idx_h, true);
               if(InpContAlert && g_allow_cont_alerts &&
                  i == total - 1 && g_last_cont_alert_time != rates[i].time)
                 {
                  Alert("ActeckSmart: продолженное движение ВВЕРХ на ", _Symbol);
                  g_last_cont_alert_time = rates[i].time;
                 }
              }
            else if(rates[i].close < low_kz)
              {
               in_move = true;
               ZeroMemory(cur);
               cur.direction    = DIR_DOWN;
               cur.price_break  = low_kz;
               cur.broken_kz    = low_kz;
               cur.unbroken_kz  = high_kz;
               cur.time_start   = rates[i].time;
               cur.start_bar    = i;
               cur.price_end    = rates[i].low;
               cur.end_bar      = i;
               cur.time_end     = rates[i].time;
               cur.closed       = false;
               cur.obsolete     = false;
               cur.balance_id   = bal_id;
               cur.idx_broken   = idx_l;
               cur.idx_unbroken = idx_h;
               locked_bal       = bal_id;
               m_kz.SetKZBroken(idx_l, true);
               if(InpContAlert && g_allow_cont_alerts &&
                  i == total - 1 && g_last_cont_alert_time != rates[i].time)
                 {
                  Alert("ActeckSmart: продолженное движение ВНИЗ на ", _Symbol);
                  g_last_cont_alert_time = rates[i].time;
                 }
              }
           }
         else
           {
            if(cur.direction == DIR_UP)
              {
               if(rates[i].high > cur.price_end)
                 {
                  cur.price_end = rates[i].high;
                  cur.end_bar   = i;
                  cur.time_end  = rates[i].time;
                 }
              }
            else
              {
               if(rates[i].low < cur.price_end)
                 {
                  cur.price_end = rates[i].low;
                  cur.end_bar   = i;
                  cur.time_end  = rates[i].time;
                 }
              }

            int opp = -1;
            if(m_kz.FindOpposingKZ(cur.time_start, rates[i].time, cur.direction, opp))
              {
               SKZ z = m_kz.KZAt(opp);
               cur.closed   = true;
               cur.time_end = z.time_confirm;
               FinalizeItem(cur, rates, total);
               in_move = false;
               armed_after = z.time_confirm;
               locked_bal = -1;
               ZeroMemory(cur);
              }
           }
        }

      if(in_move)
        {
         if(cur.time_end == 0 && total > 0)
            cur.time_end = rates[total - 1].time;
         FinalizeItem(cur, rates, total);
        }
     }

   // Состояние зоны по ликвидности: FRESH / TOUCHED / BROKEN
   ENUM_ZONE_STATE AssessZone(const SContinued &c, const MqlRates &rates[],
                              const int total, double &z_lo, double &z_hi) const
     {
      double span = c.price_break - c.unbroken_kz;
      double fib  = c.unbroken_kz + span * InpFibLevel;
      z_lo = MathMin(c.unbroken_kz, fib);
      z_hi = MathMax(c.unbroken_kz, fib);

      bool touched = false;
      bool broken  = false;

      for(int i = 0; i < total; i++)
        {
         if(rates[i].time < c.time_start)
            continue;

         // касание: бар пересекает полосу зоны
         if(rates[i].low <= z_hi && rates[i].high >= z_lo)
            touched = true;

         // пробой: тень ушла за дальнюю границу — ликвидность за зоной снята
         if(c.direction == DIR_UP)
           {
            if(rates[i].low < z_lo)
               broken = true;
           }
         else if(c.direction == DIR_DOWN)
           {
            if(rates[i].high > z_hi)
               broken = true;
           }
        }

      if(broken)
         return ZONE_BROKEN;
      if(touched)
         return ZONE_TOUCHED;
      return ZONE_FRESH;
     }

   void DrawZone(CChartObjects &gfx, const int idx, const SContinued &c,
                 const MqlRates &rates[], const int total,
                 const datetime now_broker, const datetime zt2)
     {
      if(!InpShowInterestZones)
         return;

      double z_lo, z_hi;
      ENUM_ZONE_STATE st = AssessZone(c, rates, total, z_lo, z_hi);

      // Пробитые — не рисуем (ликвидность собрана, ориентир потерян)
      if(st == ZONE_BROKEN && InpZoneHideBroken)
         return;

      color zclr = (c.direction == DIR_UP) ? InpBuyZoneColor : InpSellZoneColor;
      zclr = ApplyFade(zclr, c.time_start, now_broker);
      int za = (st == ZONE_FRESH) ? InpZoneAlpha : InpZoneTouchedAlpha;

      string zname = "CM_Z_" + IntegerToString(idx);
      gfx.Rectangle(zname, c.time_start, z_lo, zt2, z_hi, zclr, za);

      if(InpZoneShowStateLabel)
        {
         string state = (st == ZONE_FRESH) ? "НЕ ТРОНУТА | 38.2%"
                        : ((st == ZONE_TOUCHED) ? "КАСАНИЕ | 38.2%" : "ПРОБИТА | 38.2%");
         datetime label_time = zt2 - PeriodSeconds(WORK_TF) * 4;
         double label_price = (z_lo + z_hi) * 0.5;
         color label_color = (c.direction == DIR_UP) ? C'35,90,115' : C'125,65,75';
         label_color = ApplyFade(label_color, c.time_start, now_broker);
         gfx.TextLabel("CM_ZS_" + IntegerToString(idx),
                       label_time, label_price, state,
                       label_color, InpKZFont, InpKZFontSize, ANCHOR_RIGHT);
        }
     }

   void Draw(CChartObjects &gfx, const MqlRates &rates[], const int total, const datetime now_broker)
     {
      if(!InpShowContinued)
         return;

      int n = ArraySize(m_items);
      // В режиме истории сохраняем линии СПД, как на контрольном графике Sniper.
      // Ограничение/скрытие старых линий доступно только в режиме v1.1.
      const bool sniper_hist = InpSniperStyleHistory;
      int first_lines = 0;
      if(!sniper_hist && InpMaxVisibleCM > 0)
         first_lines = MathMax(0, n - InpMaxVisibleCM);

      for(int i = 0; i < n; i++)
        {
         SContinued c = m_items[i];
         if(ShouldDeleteByAge(c.time_start, now_broker))
            continue;

         // Sniper сохраняет исторические пунктиры. В режиме v1.1 ими управляют
         // флаг скрытия устаревших СПД и ограничение числа отображаемых линий.
         const bool hide_lines = !sniper_hist &&
                                 ((InpHideObsoleteCM && c.obsolete) || (i < first_lines));
         // Зона показывается для исторических СПД согласно настройке.
         const bool show_zone = InpShowInterestZones &&
                                (sniper_hist ? (InpKeepObsoleteZones || !c.obsolete)
                                             : !c.obsolete);
         color base = (c.direction == DIR_UP) ? InpContUpColor : InpContDownColor;
         color clr  = ApplyFade(base, c.time_start, now_broker);

         datetime t_end_pt = (c.end_bar >= 0 && c.end_bar < total) ? rates[c.end_bar].time
                            : ((c.time_end != 0) ? c.time_end : rates[total - 1].time);
         datetime chart_end = rates[total - 1].time + PeriodSeconds(WORK_TF) * 8;
         datetime t_h_end  = c.closed ? c.time_end
                                      : rates[total - 1].time + PeriodSeconds(WORK_TF);
         if(t_h_end <= c.time_start)
            t_h_end = c.time_start + PeriodSeconds(WORK_TF);
         datetime zt2 = rates[total - 1].time + PeriodSeconds(WORK_TF) * 8;
         if(zt2 < t_h_end)
            zt2 = t_h_end;

         if(!hide_lines)
           {
            // Горизонтальная опора пробоя
            gfx.HLineSegment("CM_H0_" + IntegerToString(i),
                             c.time_start, t_h_end, c.price_break,
                             clr, InpContWidth, InpContStyle);

            // Наклонная начинается точно на уровне пробитой границы баланса.
            // Экстремум свечи пробоя — это уже часть движения, а не его точка старта.
            gfx.Trend("CM_D_" + IntegerToString(i),
                      c.time_start, c.price_break,
                      t_end_pt, c.price_end,
                      clr, InpContWidth, InpContStyle);

            if(c.closed)
              {
               gfx.HLineSegment("CM_H1_" + IntegerToString(i),
                                t_end_pt, chart_end, c.price_end,
                                clr, InpContWidth, InpContStyle);
              }
           }

         if(show_zone)
            DrawZone(gfx, i, c, rates, total, now_broker, zt2);

         // Курсор: синий вверх / красный вниз + размер в пунктах (как «160.64» в образце)
         if(InpShowContCursor)
           {
            gfx.CursorArrow("CM_ARR_" + IntegerToString(i),
                            t_end_pt, c.price_end, c.direction, clr);
            string sz = DoubleToString(c.size_points, 2);
            ENUM_ANCHOR_POINT anc = (c.direction == DIR_UP) ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER;
            double label_off = (c.direction == DIR_UP) ? -10 * _Point : 10 * _Point;
            gfx.TextLabel("CM_SZ_" + IntegerToString(i),
                          t_end_pt, c.price_end + label_off, sz,
                          clr, InpKZFont, InpContFontSize, anc);
           }
        }
     }
  };

//+------------------------------------------------------------------+
//| Глобальные объекты                                               |
//+------------------------------------------------------------------+
CChartObjects     g_gfx;
CZigZagLevel1     g_zz1;
CCorrectionZones  g_kz;
CContinuedMove    g_cont;
datetime          g_last_m15_bar = 0;
MqlRates          g_rates[];
double            g_dummy_buf[];   // служебный буфер — чтобы MT5 показал имя индикатора
int               g_rsi_handle = INVALID_HANDLE;
int               g_bollinger_handle = INVALID_HANDLE;
int               g_m15_closed_count = 0;
datetime          g_last_bollinger_error_bar = 0;
bool              g_bollinger_drawn = false;
CCanvas           g_rsi_canvas;
bool              g_rsi_canvas_ok = false;

bool InitBollingerLevels(void)
  {
   if(!InpShowBollingerLevels)
      return true;
   if(InpBBPeriod < 2 || InpBBDeviation <= 0.0 ||
      InpBBLineBars < 1 || InpBBLineWidth < 1 || InpBBLineWidth > 5)
     {
      Print("ActeckSmart: некорректные параметры полос Боллинджера");
      return false;
     }

   g_bollinger_handle = iBands(_Symbol, WORK_TF, InpBBPeriod, 0,
                               InpBBDeviation, PRICE_CLOSE);
   if(g_bollinger_handle == INVALID_HANDLE)
     {
      Print("ActeckSmart: не удалось создать handle полос Боллинджера, err=",
            GetLastError());
      return false;
     }
   return true;
  }

void DrawBollingerLevels(const int total)
  {
   if(!InpShowBollingerLevels || g_bollinger_handle == INVALID_HANDLE || total <= 0)
      return;
   if(g_bollinger_drawn)
      return;
   if(BarsCalculated(g_bollinger_handle) < InpBBPeriod + 1)
      return;

   double middle[1], upper[1], lower[1];
   ResetLastError();
   if(CopyBuffer(g_bollinger_handle, 0, 1, 1, middle) != 1 ||
      CopyBuffer(g_bollinger_handle, 1, 1, 1, upper) != 1 ||
      CopyBuffer(g_bollinger_handle, 2, 1, 1, lower) != 1)
     {
      datetime error_bar = g_rates[total - 1].time;
      if(g_last_bollinger_error_bar != error_bar)
        {
         Print("ActeckSmart: не удалось получить значения полос Боллинджера, err=",
               GetLastError());
         g_last_bollinger_error_bar = error_bar;
        }
      return;
     }

   datetime time_start = g_rates[total - 1].time;
   datetime time_end = time_start + PeriodSeconds(WORK_TF) * InpBBLineBars;
   bool upper_drawn = g_gfx.HLineSegment("BB_UPPER", time_start, time_end, upper[0],
                                         InpBBUpperColor, InpBBLineWidth, STYLE_SOLID);
   bool middle_drawn = g_gfx.HLineSegment("BB_MIDDLE", time_start, time_end, middle[0],
                                          InpBBMiddleColor, InpBBLineWidth, STYLE_SOLID);
   bool lower_drawn = g_gfx.HLineSegment("BB_LOWER", time_start, time_end, lower[0],
                                         InpBBLowerColor, InpBBLineWidth, STYLE_SOLID);
   if(!upper_drawn || !middle_drawn || !lower_drawn)
     {
      if(g_last_bollinger_error_bar != time_start)
        {
         Print("ActeckSmart: не удалось нарисовать все маркеры полос Боллинджера, err=",
               GetLastError());
         g_last_bollinger_error_bar = time_start;
        }
      return;
     }
   g_bollinger_drawn = true;
   g_last_bollinger_error_bar = 0;
  }

//+------------------------------------------------------------------+
//| Цвет RSI по порогам Sniper                                       |
//+------------------------------------------------------------------+
color RSIValueColor(const double rsi)
  {
   if(rsi < 30.0 || rsi > 70.0)
      return InpRSIColorExt;
   if((rsi >= 30.0 && rsi <= 35.0) || (rsi >= 65.0 && rsi <= 70.0))
      return InpRSIColorWarn;
   return InpRSIColorMid;
  }

//+------------------------------------------------------------------+
//| RSI canvas / init / deinit                                       |
//+------------------------------------------------------------------+
// Пересоздать bitmap-панель RSI (после ObjectsDeleteAll объект исчезает)
bool RecreateRSICanvas(void)
  {
   if(!InpShowRSI)
      return true;

   if(g_rsi_canvas_ok)
     {
      g_rsi_canvas.Destroy();
      g_rsi_canvas_ok = false;
     }

   string cname = InpPrefix + AS_RSI_CANVAS;
   ObjectsDeleteAll(0, cname, -1, -1);

   if(!g_rsi_canvas.CreateBitmapLabel(cname, 0, 0,
                                      InpRSIPanelWidth, InpRSIPanelHeight,
                                      COLOR_FORMAT_ARGB_NORMALIZE))
     {
      Print("ActeckSmart: Canvas RSI не создан, err=", GetLastError());
      return false;
     }
   ObjectSetInteger(0, cname, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, cname, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, cname, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, cname, OBJPROP_YDISTANCE, 22);
   ObjectSetInteger(0, cname, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, cname, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, cname, OBJPROP_BACK, false);
   g_rsi_canvas_ok = true;
   return true;
  }

bool InitRSIHud(void)
  {
   if(!InpShowRSI)
      return true;

   ENUM_TIMEFRAMES tf = InpRSIUseM15 ? WORK_TF : (ENUM_TIMEFRAMES)_Period;
   g_rsi_handle = iRSI(_Symbol, tf, InpRSIPeriod, PRICE_CLOSE);
   if(g_rsi_handle == INVALID_HANDLE)
     {
      Print("ActeckSmart: не удалось создать RSI handle, err=", GetLastError());
      return false;
     }

   return RecreateRSICanvas();
  }

void DeinitRSIHud(void)
  {
   if(g_rsi_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_rsi_handle);
      g_rsi_handle = INVALID_HANDLE;
     }
   if(g_rsi_canvas_ok)
     {
      g_rsi_canvas.Destroy();
      g_rsi_canvas_ok = false;
     }
  }

//+------------------------------------------------------------------+
//| RSI HUD: непрозрачная панель spark + число (стиль Sniper)        |
//+------------------------------------------------------------------+
void UpdateRSIHud(void)
  {
   if(!InpShowRSI || g_rsi_handle == INVALID_HANDLE || !g_rsi_canvas_ok)
      return;

   int need = MathMax(InpRSISparkBars + 5, InpRSIPeriod + 5);
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(g_rsi_handle, 0, 0, need, rsi) < InpRSISparkBars)
      return;

   double cur = rsi[0];
   color  clr = RSIValueColor(cur);

   string cname = InpPrefix + AS_RSI_CANVAS;
   ObjectSetInteger(0, cname, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, cname, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, cname, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, cname, OBJPROP_YDISTANCE, 22);

   const int pw = InpRSIPanelWidth;
   const int ph = InpRSIPanelHeight;
   const int pad = 4;
   const int gap = 6;
   const int spark_w = MathMin(InpRSISparkWidth, pw - 36);
   const int spark_h = ph - pad * 2;

   // Непрозрачный белый фон — график/сетка не просвечивают сквозь число
   g_rsi_canvas.Erase(ColorToARGB(InpRSIPanelBg, 255));
   g_rsi_canvas.Rectangle(0, 0, pw - 1, ph - 1, ColorToARGB(C'200,200,200', 255));

   int bars = MathMin(InpRSISparkBars, ArraySize(rsi));
   if(bars >= 2 && spark_w > 4 && spark_h > 4)
     {
      double rmin = rsi[0], rmax = rsi[0];
      for(int i = 1; i < bars; i++)
        {
         if(rsi[i] < rmin) rmin = rsi[i];
         if(rsi[i] > rmax) rmax = rsi[i];
        }
      if(rmax - rmin < 1.0)
        {
         rmin -= 1.0;
         rmax += 1.0;
        }

      uint line_clr = ColorToARGB(clr, 255);
      int  prev_x = 0, prev_y = 0;
      for(int i = 0; i < bars; i++)
        {
         int idx = bars - 1 - i;
         int x = pad + (int)MathRound((double)i * (spark_w - 1) / (bars - 1));
         double nrm = (rsi[idx] - rmin) / (rmax - rmin);
         int y = pad + (int)MathRound((spark_h - 1) * (1.0 - nrm));
         if(i > 0)
           {
            // Толщина ~2px: основная линия + сдвиг на 1px
            g_rsi_canvas.Line(prev_x, prev_y, x, y, line_clr);
            g_rsi_canvas.Line(prev_x, prev_y + 1, x, y + 1, line_clr);
           }
         prev_x = x;
         prev_y = y;
        }
     }

   // Число RSI справа от spark — на той же непрозрачной панели
   g_rsi_canvas.FontSet("Arial Bold", InpRSIFontSize);
   string txt = IntegerToString((int)MathRound(cur));
   int tx = pad + spark_w + gap;
   int ty = ph / 2;
   g_rsi_canvas.TextOut(tx, ty, txt, ColorToARGB(clr, 255), TA_LEFT | TA_VCENTER);

   g_rsi_canvas.Update();
  }

//+------------------------------------------------------------------+
//| Загрузка котировок M15                                           |
//+------------------------------------------------------------------+
bool LoadM15Rates(const int bars_needed)
  {
   ArraySetAsSeries(g_rates, false); // 0 = самый старый
   ResetLastError();
   int copied = CopyRates(_Symbol, WORK_TF, 0, bars_needed, g_rates);
   if(copied <= 0)
     {
      Print("ActeckSmart: ошибка CopyRates M15, код=", GetLastError(),
            " (INVALID_HANDLE=", INVALID_HANDLE, ")");
      return false;
     }
   if(copied < 10)
     {
      Print("ActeckSmart: недостаточно баров M15: ", copied);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Полный пересчёт                                                  |
//+------------------------------------------------------------------+
void RecalculateAll(void)
  {
   int need = MathMax(InpHistoryBars, 100);
   if(!LoadM15Rates(need))
      return;

   int total = ArraySize(g_rates);
   // Не используем формирующийся бар — только закрытые
   // CopyRates включает текущий бар; исключаем последний незакрытый
   datetime cur_bar = iTime(_Symbol, WORK_TF, 0);
   if(total > 0 && g_rates[total - 1].time == cur_bar)
     {
      // Текущий бар ещё формируется — для расчёта берём total-1 закрытых
      // Оставляем массив как есть, но Build обрабатывает до total-1
      total = total - 1;
      if(total < 10)
         return;
     }

   g_m15_closed_count = total;
   g_bollinger_drawn = false;
   // Синхронный wipe всех AS_* (включая старый RSI canvas)
   g_gfx.DeleteAll(true);
   RecreateRSICanvas();

   g_zz1.Build(g_rates, total);
   g_kz.SetZigZag(GetPointer(g_zz1));
   g_kz.Build(g_rates, total);

   g_cont.SetKZ(GetPointer(g_kz));
   g_cont.Build(g_rates, total);

   datetime now_broker = TimeCurrent();
   g_zz1.Draw(g_gfx, now_broker);
   g_kz.Draw(g_gfx, g_rates, total, now_broker);
   g_cont.Draw(g_gfx, g_rates, total, now_broker);
   DrawBollingerLevels(total);

   UpdateRSIHud();
   ChartRedraw(0);
  }

void DrawTradeSignal(const STradeSignal &signal)
  {
   string key = IntegerToString((long)signal.time);
   color signal_color = (signal.direction == DIR_UP) ? clrDodgerBlue : clrRed;
   g_gfx.CursorArrow("SG_A_" + key, signal.time, signal.entry,
                     signal.direction, signal_color);

   if(InpShowSignalLevels)
     {
      datetime line_end = signal.time + PeriodSeconds((ENUM_TIMEFRAMES)_Period) *
                          InpSignalLevelBars;
      bool sl_drawn = g_gfx.HLineSegment("SG_SL_" + key, signal.time, line_end,
                                         signal.stop_loss, clrRed, 2, STYLE_SOLID);
      bool tp1_drawn = g_gfx.HLineSegment("SG_TP1_" + key, signal.time, line_end,
                                          signal.take_profit_1, clrLimeGreen, 2,
                                          STYLE_SOLID);
      bool tp2_drawn = g_gfx.HLineSegment("SG_TP2_" + key, signal.time, line_end,
                                          signal.take_profit_2, clrDodgerBlue, 2,
                                          STYLE_DASH);
      if(!sl_drawn || !tp1_drawn || !tp2_drawn)
         Print("ActeckSmart: не удалось создать объект уровня сигнала ",
               key, "; SL=", sl_drawn, ", TP1=", tp1_drawn,
               ", TP2=", tp2_drawn, ", err=", GetLastError());

      datetime label_time = signal.time +
                            PeriodSeconds((ENUM_TIMEFRAMES)_Period) * 3;
      bool sl_label = g_gfx.TextLabel("SG_SL_TX_" + key, label_time,
                                      signal.stop_loss,
                                      "SL " + DoubleToString(signal.stop_loss, _Digits),
                                      clrRed, InpKZFont, InpKZFontSize);
      bool tp1_label = g_gfx.TextLabel("SG_TP1_TX_" + key, label_time,
                                       signal.take_profit_1,
                                       "TP1 " + DoubleToString(signal.take_profit_1, _Digits),
                                       clrLimeGreen, InpKZFont, InpKZFontSize);
      bool tp2_label = g_gfx.TextLabel("SG_TP2_TX_" + key, label_time,
                                       signal.take_profit_2,
                                       "TP2 " + DoubleToString(signal.take_profit_2, _Digits),
                                       clrDodgerBlue, InpKZFont, InpKZFontSize);
      if(!sl_label || !tp1_label || !tp2_label)
         Print("ActeckSmart: не удалось создать подписи уровней сигнала ",
               key, "; SL=", sl_label, ", TP1=", tp1_label,
               ", TP2=", tp2_label, ", err=", GetLastError());
     }

   string model = (signal.model == SIGNAL_MODEL_CASCADE) ? "КАСКАД" : "БАЗОВАЯ";
   string side = (signal.direction == DIR_UP) ? "BUY" : "SELL";
   double label_price = (signal.direction == DIR_UP)
                        ? signal.entry - 6.0 * _Point : signal.entry + 6.0 * _Point;
   g_gfx.TextLabel("SG_TX_" + key, signal.time, label_price,
                   model + " " + side, signal_color,
                   InpKZFont, InpKZFontSize);
  }

void ProcessTradeSignals(const bool alert_latest)
  {
   ArrayInitialize(g_signal_direction, EMPTY_VALUE);
   ArrayInitialize(g_signal_stop, EMPTY_VALUE);
   ArrayInitialize(g_signal_tp1, EMPTY_VALUE);
   ArrayInitialize(g_signal_tp2, EMPTY_VALUE);
   ArrayInitialize(g_signal_model, EMPTY_VALUE);
   ArrayInitialize(g_signal_processed_time, EMPTY_VALUE);
   ObjectsDeleteAll(ChartID(), InpPrefix + "SG_", -1, -1);

   int requested = MathMax(InpSignalHistoryBars, 100);
   ArraySetAsSeries(g_signal_rates, false);
   ResetLastError();
   int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0,
                          requested, g_signal_rates);
   if(copied < 3)
     {
      Print("ActeckSmart: недостаточно баров текущего ТФ для сигналов, err=",
            GetLastError());
      return;
     }

   int closed_count = copied - 1;
   datetime latest_closed_time = g_signal_rates[closed_count - 1].time;
   for(int i = 0; i < closed_count; i++)
     {
      int shift = closed_count - i;
      if(shift < ArraySize(g_signal_processed_time))
         g_signal_processed_time[shift] = (double)g_signal_rates[i].time;
     }
   STradeSignal signals[];
   g_cont.BuildSignals(g_signal_rates, closed_count, signals);
   for(int i = 0; i < ArraySize(signals); i++)
     {
      STradeSignal signal = signals[i];

      int shift = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, signal.time, true);
      if(shift < 1 || shift >= ArraySize(g_signal_direction))
         continue;

      g_signal_direction[shift] = (signal.direction == DIR_UP) ? 1.0 : -1.0;
      g_signal_stop[shift] = signal.stop_loss;
      g_signal_tp1[shift] = signal.take_profit_1;
      g_signal_tp2[shift] = signal.take_profit_2;
      g_signal_model[shift] = (double)signal.model;
      DrawTradeSignal(signal);

      if(alert_latest && InpSignalAlerts && signal.time == latest_closed_time &&
         signal.time != g_last_trade_signal_time)
        {
         string direction = (signal.direction == DIR_UP) ? "ПОКУПКА" : "ПРОДАЖА";
         string model = (signal.model == SIGNAL_MODEL_CASCADE) ? "каскадное" : "базовое";
         Alert("ActeckSmart: ", direction, " / ", model, " расширение / ",
               _Symbol, " / ", EnumToString((ENUM_TIMEFRAMES)_Period),
               " / SL ", DoubleToString(signal.stop_loss, _Digits),
               " / TP1 ", DoubleToString(signal.take_profit_1, _Digits),
               " / TP2 ", DoubleToString(signal.take_profit_2, _Digits));
         g_last_trade_signal_time = signal.time;
        }
     }
   ChartRedraw(ChartID());
  }

//+------------------------------------------------------------------+
//| Проверка нового бара M15                                         |
//+------------------------------------------------------------------+
bool IsNewM15Bar(void)
  {
   datetime t = iTime(_Symbol, WORK_TF, 0);
   if(t == 0)
      return false;
   if(t != g_last_m15_bar)
     {
      g_last_m15_bar = t;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Init / Deinit / OnCalculate                                      |
//+------------------------------------------------------------------+
int OnInit()
  {
   // DRAW_NONE + SHORTNAME → системное кликабельное имя (свойства / список / удалить)
   SetIndexBuffer(0, g_dummy_buf, INDICATOR_DATA);
   SetIndexBuffer(1, g_signal_direction, INDICATOR_DATA);
   SetIndexBuffer(2, g_signal_stop, INDICATOR_DATA);
   SetIndexBuffer(3, g_signal_tp1, INDICATOR_DATA);
   SetIndexBuffer(4, g_signal_tp2, INDICATOR_DATA);
   SetIndexBuffer(5, g_signal_model, INDICATOR_DATA);
   SetIndexBuffer(6, g_signal_processed_time, INDICATOR_DATA);
   ArraySetAsSeries(g_dummy_buf, true);
   ArraySetAsSeries(g_signal_direction, true);
   ArraySetAsSeries(g_signal_stop, true);
   ArraySetAsSeries(g_signal_tp1, true);
   ArraySetAsSeries(g_signal_tp2, true);
   ArraySetAsSeries(g_signal_model, true);
   ArraySetAsSeries(g_signal_processed_time, true);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(0, PLOT_SHOW_DATA, false);
   PlotIndexSetString(0, PLOT_LABEL, AS_SHORTNAME);
   IndicatorSetString(INDICATOR_SHORTNAME, AS_SHORTNAME);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   if(InpBaseEntryFib <= 0.0 || InpBaseEntryFib >= 1.0 ||
      InpCascadeEntryFib <= 0.0 || InpCascadeEntryFib >= 1.0 ||
      InpSignalHistoryBars < 10 || InpSignalStopBuffer < 0 ||
      InpSignalLevelBars < 1)
     {
      Print("ActeckSmart: некорректные параметры сигналов");
      return INIT_PARAMETERS_INCORRECT;
     }

   g_gfx.Init(ChartID(), InpPrefix);
   // Удалить артефакты прошлой сессии / старых версий на текущем графике.
   DeletePrefixedObjects(ChartID(), InpPrefix);

   g_kz.SetZigZag(GetPointer(g_zz1));
   g_cont.SetKZ(GetPointer(g_kz));

   if(!InitBollingerLevels())
      return INIT_FAILED;
   if(!InitRSIHud())
      Print("ActeckSmart: RSI HUD отключён из-за ошибки инициализации");

   g_last_m15_bar = 0;
   RecalculateAll();
   ProcessTradeSignals(false);
   UpdateRSIHud();
   g_last_m15_bar = iTime(_Symbol, WORK_TF, 0);
   g_last_signal_chart_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   g_allow_cont_alerts = true;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   // 1) Освободить CCanvas (иначе bitmap может «залипнуть»)
   if(g_rsi_canvas_ok)
     {
      g_rsi_canvas.Destroy();
      g_rsi_canvas_ok = false;
     }
   if(g_rsi_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_rsi_handle);
      g_rsi_handle = INVALID_HANDLE;
     }
   if(g_bollinger_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_bollinger_handle);
      g_bollinger_handle = INVALID_HANDLE;
     }

   // 2) Удалить все объекты индикатора, включая остатки предыдущих версий.
   long cid = ChartID();
   int deleted = DeletePrefixedObjects(cid, InpPrefix);

   PrintFormat("ActeckSmart: OnDeinit reason=%d, deleted_objects=%d, prefix=%s",
               reason, deleted, InpPrefix);
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   // Пустой буфер — plot невидим, но SHORTNAME остаётся кликабельным
   if(rates_total > 0)
      ArrayInitialize(g_dummy_buf, EMPTY_VALUE);

   // RSI HUD — на каждом тике (как у Sniper)
   UpdateRSIHud();

   // Разметка КЗ/ПД — строго по закрытию свечи M15
   if(prev_calculated == 0)
     {
      RecalculateAll();
      DrawBollingerLevels(g_m15_closed_count);
      ProcessTradeSignals(false);
      g_last_m15_bar = iTime(_Symbol, WORK_TF, 0);
      g_last_signal_chart_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
      g_allow_cont_alerts = true;
      return rates_total;
     }

   datetime current_m15_bar = iTime(_Symbol, WORK_TF, 0);
   bool new_m15_bar = (current_m15_bar != 0 && current_m15_bar != g_last_m15_bar);
   if(new_m15_bar)
     {
      g_last_m15_bar = current_m15_bar;
      RecalculateAll();
     }
   if(InpShowBollingerLevels && !g_bollinger_drawn)
      DrawBollingerLevels(g_m15_closed_count);
   datetime current_chart_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   bool new_chart_bar = (current_chart_bar != 0 &&
                         current_chart_bar != g_last_signal_chart_bar);
   if(new_chart_bar || new_m15_bar)
     {
      ProcessTradeSignals(new_chart_bar && g_allow_cont_alerts);
      g_last_signal_chart_bar = current_chart_bar;
     }
   return rates_total;
  }

//+------------------------------------------------------------------+
//| Обработка событий графика                                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      UpdateRSIHud();
      ChartRedraw(0);
     }
  }
//+------------------------------------------------------------------+
