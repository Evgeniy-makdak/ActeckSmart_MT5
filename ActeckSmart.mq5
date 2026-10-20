//+------------------------------------------------------------------+
//|                                                  ActeckSmart.mq5 |
//|                                          Copyright Евгений Ацтек |
//|                                      https://github.com/Evgeniy-makdak/ActeckSmart_MT5 |
//+------------------------------------------------------------------+
#property copyright "Евгений Ацтек"
#property link      "https://github.com/Evgeniy-makdak/ActeckSmart_MT5"
#property version   "1.1"
#property description "ActeckSmart v1.1 — КЗ, зигзаг M15, продолженное движение"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_NONE
#property indicator_label1  "ActeckSmart"

// Версия индикатора: повышать при каждом коммите (сейчас 1.1 — минор)
#define AS_VERSION   "1.1"
#define AS_SHORTNAME "ActeckSmart v" AS_VERSION
#define AS_TITLE_OBJ "TITLE"   // суффикс к InpPrefix — подпись в правом углу

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
input string InpSesAustraliaStart    = "22:00";   // Australia начало GMT
input string InpSesAustraliaEnd      = "07:00";   // Australia конец GMT
input string InpSesAsiaStart         = "23:00";   // Asia начало GMT
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
input bool   InpHideObsoleteCM       = true;      // Скрывать линии старого ПД при появлении нового
input int    InpMaxVisibleCM         = 2;         // Макс. видимых структур ПД (0 = все)
input bool   InpContAlert            = false;     // Алерт появления ПД

input string InpSep7                 = "======== ЗОНЫ ИНТЕРЕСОВ (Fib 38.2%) ========"; // —
input bool   InpShowInterestZones    = true;      // Показывать зоны покупателей/продавцов
input color  InpBuyZoneColor         = C'173,216,230'; // Зона покупателей (нежно-голубой)
input color  InpSellZoneColor        = C'255,182,193'; // Зона продавцов (нежно-розовый)
input int    InpZoneAlpha            = 60;        // Прозрачность заливки зоны (0-255)
input double InpFibLevel             = 0.382;     // Уровень Фибоначчи зоны интересов

input string InpSep8                 = "======== ПРЕФИКС ОБЪЕКТОВ ========"; // —
input string InpPrefix               = "AS_";     // Префикс графических объектов

//+------------------------------------------------------------------+
//| Константы и перечисления                                         |
//+------------------------------------------------------------------+
#define WORK_TF PERIOD_M15

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
   datetime time_end;     // обрыв при пересечении (0 = ещё актуален вправо)
   double   price;
   ENUM_SESSION session;
   bool     broken;       // пробита (для толстой линии ПД)
   bool     is_high;      // true = верхняя КЗ (на максимуме)
   int      zz_index;     // индекс точки зигзага 1
   bool     active;       // входит в актуальный диапазон баланса
   ENUM_DIR origin_l2;    // направление тенденции 2-го уровня, породившей КЗ
   int      balance_id;   // номер диапазона баланса (поколение)
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
   bool     closed;           // завершена встречным ИКИ/КЗ
   bool     obsolete;         // вытеснена более новым ПД (линии скрыть)
   int      start_bar;
   int      end_bar;
   int      balance_id;       // диапазон, из которого стартовало ПД
   int      idx_broken;       // индекс пробитой КЗ
   int      idx_unbroken;     // индекс непробитой КЗ
   double   size_points;      // размер движения в пунктах (подпись курсора)
  };

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

// Приоритет при наложении: NY > London > Europe > Asia > Australia
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
   return SES_NONE;
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

   void DeleteAll(void)
     {
      ObjectsDeleteAll(m_chart, m_prefix);
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
               // i считается внутренним, ориентируемся на i+1 относительно ref... 
               // по ТЗ: n+9 игнорируется, сравниваем n+11 с n+10
               // Здесь: пропускаем i, ref остаётся, берём i+1 как кандидата
               i++;
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

   void AddKZ(const SZigPoint &p, const ENUM_DIR origin_l2, const int balance_id)
     {
      // Не дублируем КЗ на той же цене/баре
      int n = ArraySize(m_kz);
      for(int j = 0; j < n; j++)
        {
         if(m_kz[j].zz_index == p.bar && MathAbs(m_kz[j].price - p.price) < _Point)
            return;
         // Не ставим почти ту же цену повторно в том же направлении L2
         if(m_kz[j].origin_l2 == origin_l2 &&
            m_kz[j].is_high == (p.type == EXT_HIGH) &&
            MathAbs(m_kz[j].price - p.price) < 5 * _Point)
            return;
        }

      ArrayResize(m_kz, n + 1);
      m_kz[n].time_start = p.time;
      m_kz[n].time_end   = 0;
      m_kz[n].price      = p.price;
      m_kz[n].session    = DetectSession(p.time);
      m_kz[n].broken     = false;
      m_kz[n].is_high    = (p.type == EXT_HIGH);
      m_kz[n].zz_index   = p.bar;
      m_kz[n].active     = true;
      m_kz[n].origin_l2  = origin_l2;
      m_kz[n].balance_id = balance_id;
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

   // Построение тенденций 2-го уровня и КЗ по правилам ИКИ (из PDF):
   // — действительное ИКИ только если второй импульс обновляет первый;
   // — если зона есть и цена идёт по тренду, новая КЗ — только при ИКИ
   //   в ОБРАТНОМ направлении (не плодим вложенные КЗ на импульсе);
   // — альтернатива: пробитие ближайшей КЗ → крайняя точка действительного отката.
   void Build(const MqlRates &rates[], const int total)
     {
      Clear();
      if(m_zz1 == NULL || m_zz1.Size() < 4)
         return;

      int n = m_zz1.Size();
      ENUM_DIR l2_dir = DIR_NONE;
      int balance_id = 0;

      for(int i = 3; i < n; i++)
        {
         SZigPoint p0 = m_zz1.At(i - 3);
         SZigPoint p1 = m_zz1.At(i - 2);
         SZigPoint p2 = m_zz1.At(i - 1);
         SZigPoint p3 = m_zz1.At(i);

         // === ИКИ ВВЕРХ: Low → High → Low(выше) → High(выше первого High) ===
         // Второй импульс ОБЯЗАН обновить первый (PDF: действительное ИКИ)
         if(p0.type == EXT_LOW && p1.type == EXT_HIGH &&
            p2.type == EXT_LOW && p3.type == EXT_HIGH &&
            p2.price > p0.price && p3.price > p1.price)
           {
            AddZZ2(p1);
            AddZZ2(p3);

            if(l2_dir != DIR_UP)
              {
               // Новая КЗ только при старте / смене направления ИКИ
               if(l2_dir == DIR_DOWN)
                  balance_id++;
               AddKZ(p0, DIR_UP, balance_id);
               l2_dir = DIR_UP;
              }
           }

         // === ИКИ ВНИЗ: High → Low → High(ниже) → Low(ниже первого Low) ===
         if(p0.type == EXT_HIGH && p1.type == EXT_LOW &&
            p2.type == EXT_HIGH && p3.type == EXT_LOW &&
            p2.price < p0.price && p3.price < p1.price)
           {
            AddZZ2(p1);
            AddZZ2(p3);

            if(l2_dir != DIR_DOWN)
              {
               if(l2_dir == DIR_UP)
                  balance_id++;
               AddKZ(p0, DIR_DOWN, balance_id);
               l2_dir = DIR_DOWN;
              }
           }
        }

      // Обрыв КЗ при пересечении свечой M15
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

   // Актуальный диапазон баланса к моменту времени t (или последний, если t=0)
   // Берём пару high/low с максимальным общим balance_id, time_start <= t
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

      // Находим максимальный balance_id среди КЗ, уже сформированных к моменту t
      int max_bal = -1;
      for(int i = 0; i < n; i++)
        {
         if(t != 0 && m_kz[i].time_start > t)
            continue;
         if(m_kz[i].balance_id > max_bal)
            max_bal = m_kz[i].balance_id;
        }
      if(max_bal < 0)
         return false;

      // Внутри этого поколения ищем последнюю high и последнюю low КЗ
      // Также допускаем соседнее поколение, если в max_bal только один тип
      for(int i = n - 1; i >= 0; i--)
        {
         if(t != 0 && m_kz[i].time_start > t)
            continue;
         if(m_kz[i].balance_id != max_bal && m_kz[i].balance_id != max_bal - 1)
            continue;
         if(m_kz[i].is_high && idx_high < 0)
           {
            idx_high = i;
            high_kz  = m_kz[i].price;
           }
         if(!m_kz[i].is_high && idx_low < 0)
           {
            idx_low = i;
            low_kz  = m_kz[i].price;
           }
         if(idx_high >= 0 && idx_low >= 0)
            break;
        }

      // Fallback: любые две последние разных типов
      if(idx_high < 0 || idx_low < 0)
        {
         idx_high = -1;
         idx_low  = -1;
         for(int i = n - 1; i >= 0; i--)
           {
            if(t != 0 && m_kz[i].time_start > t)
               continue;
            if(m_kz[i].is_high && idx_high < 0)
              {
               idx_high = i;
               high_kz  = m_kz[i].price;
              }
            if(!m_kz[i].is_high && idx_low < 0)
              {
               idx_low = i;
               low_kz  = m_kz[i].price;
              }
            if(idx_high >= 0 && idx_low >= 0)
               break;
           }
        }

      if(idx_high < 0 || idx_low < 0 || high_kz <= low_kz)
         return false;
      balance_id = max_bal;
      return true;
     }

   bool GetBalanceRange(double &high_kz, double &low_kz, int &idx_high, int &idx_low)
     {
      int bal = -1;
      return GetBalanceRangeAt(0, high_kz, low_kz, idx_high, idx_low, bal);
     }

   // Есть ли КЗ встречного L2 после момента t_from (для закрытия ПД)
   bool FindOpposingKZ(const datetime t_from, const datetime t_to,
                       const ENUM_DIR cm_dir, int &idx_out)
     {
      idx_out = -1;
      // Для ПД вниз нужна КЗ от восходящей L2; для ПД вверх — от нисходящей L2
      ENUM_DIR need = (cm_dir == DIR_DOWN) ? DIR_UP : DIR_DOWN;
      int n = ArraySize(m_kz);
      for(int k = 0; k < n; k++)
        {
         if(m_kz[k].time_start <= t_from)
            continue;
         if(t_to != 0 && m_kz[k].time_start > t_to)
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
      for(int k = 0; k < kz_n; k++)
        {
         if(ShouldDeleteByAge(m_kz[k].time_start, now_broker))
            continue;

         datetime t2 = (m_kz[k].time_end != 0) ? m_kz[k].time_end : last_time;
         color base = SessionColor(m_kz[k].session);
         color clr  = ApplyFade(base, m_kz[k].time_start, now_broker);
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

   void Build(const MqlRates &rates[], const int total)
     {
      Clear();
      if(m_kz == NULL || total < 5)
         return;

      // Правила (PDF ИКИ + образец Sniper):
      // 1) ПД стартует ТОЛЬКО от пробоя актуального диапазона баланса.
      // 2) Пока ПД активно — одна структура; чужие/старые КЗ игнорируются.
      // 3) Закрытие — только КЗ от ИКИ ВСТРЕЧНОГО направления.
      // 4) Новое ПД вытесняет линии предыдущего (obsolete), курсор остаётся по настройкам.

      bool in_move = false;
      SContinued cur;
      ZeroMemory(cur);

      double high_kz = 0, low_kz = 0;
      int idx_h = -1, idx_l = -1, bal_id = -1;
      datetime armed_after = 0;
      int locked_bal = -1; // баланс, из которого идёт текущее ПД

      for(int i = 0; i < total; i++)
        {
         if(!in_move)
           {
            if(!m_kz.GetBalanceRangeAt(rates[i].time, high_kz, low_kz, idx_h, idx_l, bal_id))
               continue;

            SKZ kz_h = m_kz.KZAt(idx_h);
            SKZ kz_l = m_kz.KZAt(idx_l);
            datetime range_start = (kz_h.time_start > kz_l.time_start) ? kz_h.time_start : kz_l.time_start;

            if(rates[i].time <= range_start)
               continue;
            if(armed_after != 0 && rates[i].time <= armed_after)
               continue;
            // Не перезапускаем ПД из того же уже отработанного баланса
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
               if(InpContAlert)
                  Alert("ActeckSmart: продолженное движение ВВЕРХ на ", _Symbol);
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
               if(InpContAlert)
                  Alert("ActeckSmart: продолженное движение ВНИЗ на ", _Symbol);
              }
           }
         else
           {
            // Продление одной наклонной на новые экстремумы
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

            // Закрытие только встречным ИКИ (origin_l2 противоположный)
            int opp = -1;
            if(m_kz.FindOpposingKZ(cur.time_start, rates[i].time, cur.direction, opp))
              {
               SKZ z = m_kz.KZAt(opp);
               cur.closed   = true;
               cur.time_end = z.time_start;
               FinalizeItem(cur, rates, total);
               in_move = false;
               armed_after = z.time_start;
               locked_bal = -1; // новый диапазон сможет стартовать новое ПД
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

   void Draw(CChartObjects &gfx, const MqlRates &rates[], const int total, const datetime now_broker)
     {
      if(!InpShowContinued)
         return;

      int n = ArraySize(m_items);
      // Сколько последних структур показывать линиями
      int first_lines = 0;
      if(InpMaxVisibleCM > 0)
         first_lines = MathMax(0, n - InpMaxVisibleCM);

      for(int i = 0; i < n; i++)
        {
         SContinued c = m_items[i];
         if(ShouldDeleteByAge(c.time_start, now_broker))
            continue;

         const bool hide_lines = (InpHideObsoleteCM && c.obsolete) || (i < first_lines);
         color base = (c.direction == DIR_UP) ? InpContUpColor : InpContDownColor;
         color clr  = ApplyFade(base, c.time_start, now_broker);

         datetime t_end_pt = (c.end_bar >= 0 && c.end_bar < total) ? rates[c.end_bar].time
                            : ((c.time_end != 0) ? c.time_end : rates[total - 1].time);
         datetime t_h_end  = t_end_pt + PeriodSeconds(WORK_TF);

         if(!hide_lines)
           {
            // Горизонтальная опора пробоя
            gfx.HLineSegment("CM_H0_" + IntegerToString(i),
                             c.time_start, t_h_end, c.price_break,
                             clr, InpContWidth, InpContStyle);

            // Наклонная: от экстремума бара пробоя до текущего экстремума ПД
            double p_start_ext = c.price_break;
            if(c.start_bar >= 0 && c.start_bar < total)
               p_start_ext = (c.direction == DIR_UP) ? rates[c.start_bar].high
                                                     : rates[c.start_bar].low;

            gfx.Trend("CM_D_" + IntegerToString(i),
                      c.time_start, p_start_ext,
                      t_end_pt, c.price_end,
                      clr, InpContWidth, InpContStyle);

            if(c.closed)
              {
               gfx.HLineSegment("CM_H1_" + IntegerToString(i),
                                c.time_end, t_h_end + PeriodSeconds(WORK_TF) * 4, c.price_end,
                                clr, InpContWidth, InpContStyle);
              }

            // Зона интересов Fib 38.2% — только у актуального (не obsolete) ПД
            if(InpShowInterestZones && !c.obsolete)
              {
               double span = c.price_break - c.unbroken_kz;
               double fib  = c.unbroken_kz + span * InpFibLevel;
               color zclr = (c.direction == DIR_UP) ? InpBuyZoneColor : InpSellZoneColor;
               zclr = ApplyFade(zclr, c.time_start, now_broker);
               gfx.Rectangle("CM_Z_" + IntegerToString(i),
                             c.time_start, c.unbroken_kz,
                             t_h_end, fib,
                             zclr, InpZoneAlpha);
              }
           }

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

//+------------------------------------------------------------------+
//| Подпись названия+версии в правом верхнем углу графика            |
//+------------------------------------------------------------------+
void UpdateTitleLabel(void)
  {
   string name = InpPrefix + AS_TITLE_OBJ;
   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return;
     }
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 18);
   ObjectSetString(0, name, OBJPROP_TEXT, AS_SHORTNAME);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
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

   g_gfx.DeleteAll();

   g_zz1.Build(g_rates, total);
   g_kz.SetZigZag(GetPointer(g_zz1));
   g_kz.Build(g_rates, total);

   g_cont.SetKZ(GetPointer(g_kz));
   g_cont.Build(g_rates, total);

   datetime now_broker = TimeCurrent();
   g_zz1.Draw(g_gfx, now_broker);
   g_kz.Draw(g_gfx, g_rates, total, now_broker);
   g_cont.Draw(g_gfx, g_rates, total, now_broker);

   // DeleteAll снимает и TITLE — восстанавливаем подпись с версией
   UpdateTitleLabel();
   ChartRedraw(0);
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
   // DRAW_NONE plot нужен, иначе MT5 не показывает имя индикатора на графике
   SetIndexBuffer(0, g_dummy_buf, INDICATOR_DATA);
   ArraySetAsSeries(g_dummy_buf, true);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(0, PLOT_LABEL, AS_SHORTNAME);
   IndicatorSetString(INDICATOR_SHORTNAME, AS_SHORTNAME);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   g_gfx.Init(0, InpPrefix);
   g_kz.SetZigZag(GetPointer(g_zz1));
   g_cont.SetKZ(GetPointer(g_kz));

   g_last_m15_bar = 0;
   RecalculateAll();
   UpdateTitleLabel();
   // Сбрасываем флаг, чтобы первый тик после init не пропускал логику зря
   g_last_m15_bar = iTime(_Symbol, WORK_TF, 0);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_gfx.DeleteAll();
   ObjectDelete(0, InpPrefix + AS_TITLE_OBJ);
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
   // Обновление строго по закрытию свечи M15
   if(prev_calculated == 0)
     {
      RecalculateAll();
      g_last_m15_bar = iTime(_Symbol, WORK_TF, 0);
      return rates_total;
     }

   // Новый бар M15 = предыдущий закрылся
   datetime t0 = iTime(_Symbol, WORK_TF, 0);
   if(t0 != 0 && t0 != g_last_m15_bar)
     {
      g_last_m15_bar = t0;
      RecalculateAll();
     }
   return rates_total;
  }

//+------------------------------------------------------------------+
//| Обработка событий графика (смена ТФ — перерисовка тех же объектов)|
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      // Объекты привязаны ко времени M15 — просто перерисуем
      ChartRedraw(0);
     }
  }
//+------------------------------------------------------------------+
