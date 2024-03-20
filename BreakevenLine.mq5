//+------------------------------------------------------------------+
//|                                                   Breakeven Line |
//|                                      Copyright © 2024, EarnForex |
//|                                        https://www.earnforex.com |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2024"
#property link      "https://www.earnforex.com/metatrader-indicators/Breakeven-Line/"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

#property description "Displays a breakeven line for the current symbol."
#property description "You can hide/show the line by pressing Shift+B."

input bool IgnoreLong = false;
input bool IgnoreShort = false;
input color line_color_buy = clrTeal;
input color line_color_sell = clrPink;
input color line_color_neutral = clrSlateGray;
input ENUM_LINE_STYLE line_style = STYLE_SOLID;
input int line_width = 1;
input color font_color = clrSlateGray;
input int font_size = 12;
input string font_face = "Courier";
input string ObjectPrefix = "BEL_"; // ObjectPrefix: To prevent confusion with other indicators/EAs.

// Global variables:
int PositionsLong, PositionsShort, PositionsTotal;
double VolumeLong, PriceLong, ProfitLong, VolumeShort, PriceShort, ProfitShort, VolumeTotal, ProfitTotal, PriceAverage, DistancePoints;
double Pip_Value = 0;
double Pip_Size = 0;
double LotStep = 0;
int LotStep_digits = 0;
string object_line, object_label;

void OnInit()
{
    object_line = ObjectPrefix + "Line" + Symbol();
    object_label = ObjectPrefix + "Label" + Symbol();
    EventSetMillisecondTimer(200); // Five times per second.
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, ObjectPrefix);
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
    if (iBars(Symbol(), Period()) <= 0) return 0; // Data not loaded yet.

    if (CalculateData()) DrawData();

    return rates_total;
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_CHART_CHANGE) DrawData();
    else if (id == CHARTEVENT_KEYDOWN)
    {
        // Trade direction:
        if ((lparam == 'B') && (TerminalInfoInteger(TERMINAL_KEYSTATE_SHIFT) < 0))
        {
            if (ObjectGetInteger(0, object_line, OBJPROP_TIMEFRAMES) == OBJ_NO_PERIODS) // Was hidden.
            {
                ObjectSetInteger(0, object_line, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                ObjectSetInteger(0, object_label, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            }
            else // Was visible.
            {
                ObjectSetInteger(0, object_line, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                ObjectSetInteger(0, object_label, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            }
            ChartRedraw();
        }
    }
}

//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTrade()
{
    if (CalculateData()) DrawData();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
    /*if (CalculateData())*/ DrawData();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Calculates BE distance and other values.                         |
//+------------------------------------------------------------------+
bool CalculateData()
{
    PositionsLong = 0;
    VolumeLong = 0;
    PriceLong = 0;
    ProfitLong = 0;
    
    PositionsShort = 0;
    VolumeShort = 0;
    PriceShort = 0;
    ProfitShort = 0;
    
    PositionsTotal = 0;
    VolumeTotal = 0;
    ProfitTotal = 0;
    
    PriceAverage = 0;
    DistancePoints = 0;

    Pip_Value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    Pip_Size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    
    if ((Pip_Value == 0) || (Pip_Size == 0)) return false; // No symbol information yet.

    int total = PositionsTotal();

    for (int i = 0; i < total; i++)
    {
        string pos_symbol = PositionGetSymbol(i);
        if (pos_symbol != "")
        {
            if (pos_symbol != Symbol()) continue; // Should only consider trades on the current symbol.
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                if (IgnoreLong) continue;
                PositionsLong++;
                PriceLong += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
                VolumeLong += PositionGetDouble(POSITION_VOLUME);
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                ProfitLong += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                if (IgnoreShort) continue;
                PositionsShort++;
                PriceShort += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
                VolumeShort += PositionGetDouble(POSITION_VOLUME);
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                ProfitShort += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
        }
        else Print("Error selecting position #", i, ": ", GetLastError());
    }

    if (PriceLong > 0)
    {
        PriceLong /= VolumeLong; // Average buy price.
    }
    if (PriceShort > 0)
    {
        PriceShort /= VolumeShort; // Average sell price.
    }
    
    PositionsTotal = PositionsLong + PositionsShort;
    VolumeTotal = VolumeLong - VolumeShort;
    ProfitTotal = ProfitLong + ProfitShort;

    if (PositionsTotal > 0)
    {
        double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        if (VolumeTotal != 0)
        {
            DistancePoints = ProfitTotal / MathAbs(VolumeTotal * Pip_Value) * Pip_Size;
            if (VolumeTotal > 0)
            {
                PriceAverage = Bid - DistancePoints;
            }
            else //  VolumeTotal < 0
            {
                PriceAverage = Ask + DistancePoints;
            }
        }
        else // VolumeTotal == 0
        {
            DistancePoints = ProfitTotal / Pip_Value * Pip_Size;
            PriceAverage = (Ask + Bid) / 2 - DistancePoints;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Creates or moves chart objects.                                  |
//+------------------------------------------------------------------+
void DrawData()
{
    // Line:
    if (ObjectFind(0, object_line) < 0)
    {
        ObjectCreate(0, object_line, OBJ_HLINE, 0, 0, PriceAverage);
        ObjectSetInteger(0, object_line, OBJPROP_WIDTH, 0, line_width);
        ObjectSetInteger(0, object_line, OBJPROP_STYLE, 0, line_style);
        ObjectSetInteger(0, object_line, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, object_line, OBJPROP_HIDDEN, true);
    }
    else
    {
        ObjectMove(0, object_line, 0, 0, PriceAverage);
    }
    color colour = line_color_buy;
    if (VolumeTotal < 0) colour = line_color_sell;
    else if (VolumeTotal == 0) colour = line_color_neutral;
    ObjectSetInteger(0, object_line, OBJPROP_COLOR, colour);
    
    // Label:
    if (ObjectFind(0, object_label) < 0)
    {
        ObjectCreate(0, object_label, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, object_label, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, object_label, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, object_label, OBJPROP_FONTSIZE, font_size);
        ObjectSetString(0, object_label, OBJPROP_FONT, font_face);
        ObjectSetInteger(0, object_label, OBJPROP_COLOR, font_color);
        // This needs to run only once:
        LotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP); 
        LotStep_digits = CountDecimalPlaces(LotStep);
    }

    int x, y;
    long real_x;
    uint w, h;

    string text = IntegerToString((int)MathRound(DistancePoints / _Point)) + " (" + DoubleToString(ProfitTotal, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ") " + DoubleToString(VolumeTotal, LotStep_digits) + " lots, N = " + IntegerToString(PositionsTotal);
    ObjectSetString(0, object_label, OBJPROP_TEXT, text);

    real_x = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 2;
    // Needed only for y, x is derived from the chart width.
    ChartTimePriceToXY(0, 0, iTime(Symbol(), Period(), 0), PriceAverage, x, y);
    // Get the width of the text based on font and its size. Negative because OS-dependent, *10 because set in 1/10 of pt.
    TextSetFont(font_face, font_size * -10);
    TextGetSize(text, w, h);
    ObjectSetInteger(0, object_label, OBJPROP_XDISTANCE, real_x - w);
    y -= int(h + 1); // Above the line.
    ObjectSetInteger(0, object_label, OBJPROP_YDISTANCE, y);
}

//+------------------------------------------------------------------+
//| Counts decimal places.                                           |
//+------------------------------------------------------------------+
int CountDecimalPlaces(double number)
{
    // 100 as maximum length of number.
    for (int i = 0; i < 100; i++)
    {
        double pwr = MathPow(10, i);
        if (MathRound(number * pwr) / pwr == number) return(i);
    }
    return(-1);
}
//+------------------------------------------------------------------+