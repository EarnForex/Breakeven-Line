//+------------------------------------------------------------------+
//|                                                   Breakeven Line |
//|                                 Copyright © 2024-2025, EarnForex |
//|                                        https://www.earnforex.com |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2024-2025"
#property link      "https://www.earnforex.com/indicators/Breakeven-Line/"
#property version   "1.01"
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
int PositionsLong, PositionsShort, PosTotal;
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
    DrawData();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Calculates BE distance and other values.                         |
//+------------------------------------------------------------------+
bool CalculateData()
{
    AccCurrency = AccountInfoString(ACCOUNT_CURRENCY);
    
    double point_value_risk = CalculatePointValue(Risk);
    if (point_value_risk == 0) return false; // No symbol information yet.

    PositionsLong = 0;
    VolumeLong = 0;
    PriceLong = 0;
    ProfitLong = 0;
    
    PositionsShort = 0;
    VolumeShort = 0;
    PriceShort = 0;
    ProfitShort = 0;
    
    PosTotal = 0;
    VolumeTotal = 0;
    ProfitTotal = 0;
    
    PriceAverage = 0;
    DistancePoints = 0;

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
                ProfitLong += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + CalculateCommission();
            }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                if (IgnoreShort) continue;
                PositionsShort++;
                PriceShort += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
                VolumeShort += PositionGetDouble(POSITION_VOLUME);
                ProfitShort += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + CalculateCommission();
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
    
    PosTotal = PositionsLong + PositionsShort;
    VolumeTotal = VolumeLong - VolumeShort;
    ProfitTotal = ProfitLong + ProfitShort;

    if (PosTotal > 0)
    {
        double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        if (VolumeTotal != 0)
        {
            DistancePoints = ProfitTotal / MathAbs(VolumeTotal * point_value_risk);
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
            DistancePoints = ProfitTotal / point_value_risk;
            PriceAverage = (Ask + Bid) / 2 - DistancePoints;
        }
    }

    return true;
}

double CalculateCommission()
{
    double commission_sum = 0;
    if (!HistorySelectByPosition(PositionGetInteger(POSITION_IDENTIFIER)))
    {
        Print("HistorySelectByPosition failed: ", GetLastError());
        return 0;
    }
    int deals_total = HistoryDealsTotal();
    for (int i = 0; i < deals_total; i++)
    {
        ulong deal_ticket = HistoryDealGetTicket(i);
        if (deal_ticket == 0)
        {
            Print("HistoryDealGetTicket failed: ", GetLastError());
            continue;
        }
        if ((HistoryDealGetInteger(deal_ticket, DEAL_TYPE) != DEAL_TYPE_BUY) && (HistoryDealGetInteger(deal_ticket, DEAL_TYPE) != DEAL_TYPE_SELL)) continue; // Wrong kinds of deals.
        if (HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue; // Only entry deals.
        commission_sum += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
    }
    return commission_sum;
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

    int currency_digits = (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS);
    string text = FormatDouble(IntegerToString((int)MathRound(DistancePoints / _Point)), 0) + " (" + FormatDouble(DoubleToString(ProfitTotal, currency_digits), currency_digits) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ") " + DoubleToString(VolumeTotal, LotStep_digits) + " lots, N = " + IntegerToString(PosTotal);
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

enum mode_of_operation
{
    Risk,
    Reward
};

string AccCurrency;
double CalculatePointValue(mode_of_operation mode)
{
    string cp = Symbol();
    double UnitCost = CalculateUnitCost(cp, mode);
    double OnePoint = SymbolInfoDouble(cp, SYMBOL_POINT);
    return(UnitCost / OnePoint);
}

//+----------------------------------------------------------------------+
//| Returns unit cost either for Risk or for Reward mode.                |
//+----------------------------------------------------------------------+
double CalculateUnitCost(const string cp, const mode_of_operation mode)
{
    ENUM_SYMBOL_CALC_MODE CalcMode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(cp, SYMBOL_TRADE_CALC_MODE);

    // No-Forex.
    if ((CalcMode != SYMBOL_CALC_MODE_FOREX) && (CalcMode != SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE) && (CalcMode != SYMBOL_CALC_MODE_FUTURES) && (CalcMode != SYMBOL_CALC_MODE_EXCH_FUTURES) && (CalcMode != SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS))
    {
        double TickSize = SymbolInfoDouble(cp, SYMBOL_TRADE_TICK_SIZE);
        double UnitCost = TickSize * SymbolInfoDouble(cp, SYMBOL_TRADE_CONTRACT_SIZE);
        string ProfitCurrency = SymbolInfoString(cp, SYMBOL_CURRENCY_PROFIT);
        if (ProfitCurrency == "RUR") ProfitCurrency = "RUB";

        // If profit currency is different from account currency.
        if (ProfitCurrency != AccCurrency)
        {
            return(UnitCost * CalculateAdjustment(ProfitCurrency, mode));
        }
        return UnitCost;
    }
    // With Forex instruments, tick value already equals 1 unit cost.
    else
    {
        if (mode == Risk) return SymbolInfoDouble(cp, SYMBOL_TRADE_TICK_VALUE_LOSS);
        else return SymbolInfoDouble(cp, SYMBOL_TRADE_TICK_VALUE_PROFIT);
    }
}

//+-----------------------------------------------------------------------------------+
//| Calculates necessary adjustments for cases when GivenCurrency != AccountCurrency. |
//| Used in two cases: profit adjustment and margin adjustment.                       |
//+-----------------------------------------------------------------------------------+
double CalculateAdjustment(const string ProfitCurrency, const mode_of_operation mode)
{
    string ReferenceSymbol = GetSymbolByCurrencies(ProfitCurrency, AccCurrency);
    bool ReferenceSymbolMode = true;
    // Failed.
    if (ReferenceSymbol == NULL)
    {
        // Reversing currencies.
        ReferenceSymbol = GetSymbolByCurrencies(AccCurrency, ProfitCurrency);
        ReferenceSymbolMode = false;
    }
    // Everything failed.
    if (ReferenceSymbol == NULL)
    {
        Print("Error! Cannot detect proper currency pair for adjustment calculation: ", ProfitCurrency, ", ", AccCurrency, ".");
        ReferenceSymbol = Symbol();
        return 1;
    }
    MqlTick tick;
    SymbolInfoTick(ReferenceSymbol, tick);
    return GetCurrencyCorrectionCoefficient(tick, mode, ReferenceSymbolMode);
}

//+---------------------------------------------------------------------------+
//| Returns a currency pair with specified base currency and profit currency. |
//+---------------------------------------------------------------------------+
string GetSymbolByCurrencies(string base_currency, string profit_currency)
{
    // Cycle through all symbols.
    for (int s = 0; s < SymbolsTotal(false); s++)
    {
        // Get symbol name by number.
        string symbolname = SymbolName(s, false);

        // Skip non-Forex pairs.
        if ((SymbolInfoInteger(symbolname, SYMBOL_TRADE_CALC_MODE) != SYMBOL_CALC_MODE_FOREX) && (SymbolInfoInteger(symbolname, SYMBOL_TRADE_CALC_MODE) != SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)) continue;

        // Get its base currency.
        string b_cur = SymbolInfoString(symbolname, SYMBOL_CURRENCY_BASE);
        if (b_cur == "RUR") b_cur = "RUB";

        // Get its profit currency.
        string p_cur = SymbolInfoString(symbolname, SYMBOL_CURRENCY_PROFIT);
        if (p_cur == "RUR") p_cur = "RUB";
        
        // If the currency pair matches both currencies, select it in Market Watch and return its name.
        if ((b_cur == base_currency) && (p_cur == profit_currency))
        {
            // Select if necessary.
            if (!(bool)SymbolInfoInteger(symbolname, SYMBOL_SELECT)) SymbolSelect(symbolname, true);

            return symbolname;
        }
    }
    return NULL;
}

//+------------------------------------------------------------------+
//| Get profit correction coefficient based on profit currency,      |
//| calculation mode (profit or loss), reference pair mode (reverse  |
//| or direct), and current prices.                                  |
//+------------------------------------------------------------------+
double GetCurrencyCorrectionCoefficient(MqlTick &tick, const mode_of_operation mode, const bool ReferenceSymbolMode)
{
    if ((tick.ask == 0) || (tick.bid == 0)) return -1; // Data is not yet ready.
    if (mode == Risk)
    {
        // Reverse quote.
        if (ReferenceSymbolMode)
        {
            // Using Buy price for reverse quote.
            return tick.ask;
        }
        // Direct quote.
        else
        {
            // Using Sell price for direct quote.
            return(1 / tick.bid);
        }
    }
    else if (mode == Reward)
    {
        // Reverse quote.
        if (ReferenceSymbolMode)
        {
            // Using Sell price for reverse quote.
            return tick.bid;
        }
        // Direct quote.
        else
        {
            // Using Buy price for direct quote.
            return(1 / tick.ask);
        }
    }
    return -1;
}

//+---------------------------------------------------------------------------+
//| Formats double with thousands separator for so many digits after the dot. |
//+---------------------------------------------------------------------------+
string FormatDouble(const string number, const int digits = 2)
{
    // Find "." position.
    int pos = StringFind(number, ".");
    string integer = number;
    string decimal = "";
    if (pos > -1)
    {
        integer = StringSubstr(number, 0, pos);
        decimal = StringSubstr(number, pos, digits + 1);
    }
    string formatted = "";
    string comma = "";

    while (StringLen(integer) > 3)
    {
        int length = StringLen(integer);
        string group = StringSubstr(integer, length - 3);
        formatted = group + comma + formatted;
        comma = ",";
        integer = StringSubstr(integer, 0, length - 3);
    }
    if (integer == "-") comma = "";
    if (integer != "") formatted = integer + comma + formatted;

    return(formatted + decimal);
}
//+------------------------------------------------------------------+