//+------------------------------------------------------------------+
//|                                                   Breakeven Line |
//|                                 Copyright © 2024-2025, EarnForex |
//|                                        https://www.earnforex.com |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2024-2025"
#property link      "https://www.earnforex.com/indicators/Breakeven-Line/"
#property version   "1.01"
#property strict
#property indicator_chart_window

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
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
    if (CalculateData()) DrawData();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Calculates BE distance and other values.                         |
//+------------------------------------------------------------------+
bool CalculateData()
{
    AccCurrency = AccountCurrency();
    double point_value_risk = CalculatePointValue(Symbol(), Risk);
    if (point_value_risk == 0) return false; // No symbol information yet.

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

    int total = OrdersTotal();

    for (int i = 0; i < total; i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderSymbol() != Symbol()) continue; // Should only consider trades on the current symbol.
            if (OrderType() == OP_BUY)
            {
                if (IgnoreLong) continue;
                PositionsLong++;
                PriceLong += OrderOpenPrice() * OrderLots();
                VolumeLong += OrderLots();
                ProfitLong += OrderProfit() + OrderSwap() + OrderCommission();
            }
            else if (OrderType() == OP_SELL)
            {
                if (IgnoreShort) continue;
                PositionsShort++;
                PriceShort += OrderOpenPrice() * OrderLots();
                VolumeShort += OrderLots();
                ProfitShort += OrderProfit() + OrderSwap() + OrderCommission();
            }
        }
        else Print("Error selecting order #", i, ": ", GetLastError());
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

    string text = FormatDouble(IntegerToString((int)MathRound(DistancePoints / _Point)), 0) + " (" + FormatDouble(DoubleToString(ProfitTotal, 2), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ") " + DoubleToString(VolumeTotal, LotStep_digits) + " lots, N = " + IntegerToString(PositionsTotal);
    ObjectSetString(0, object_label, OBJPROP_TEXT, text);

    real_x = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 2;
    // Needed only for y, x is derived from the chart width.
    ChartTimePriceToXY(0, 0, Time[0], PriceAverage, x, y);
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
double CalculatePointValue(string cp, mode_of_operation mode)
{
    double UnitCost;

    int ProfitCalcMode = (int)MarketInfo(cp, MODE_PROFITCALCMODE);
    string ProfitCurrency = SymbolInfoString(cp, SYMBOL_CURRENCY_PROFIT);
    
    if (ProfitCurrency == "RUR") ProfitCurrency = "RUB";
    // If Symbol is CFD or futures but with different profit currency.
    if ((ProfitCalcMode == 1) || ((ProfitCalcMode == 2) && ((ProfitCurrency != AccCurrency))))
    {
        if (ProfitCalcMode == 2) UnitCost = MarketInfo(cp, MODE_TICKVALUE); // Futures, but will still have to be adjusted by CCC.
        else UnitCost = SymbolInfoDouble(cp, SYMBOL_TRADE_TICK_SIZE) * SymbolInfoDouble(cp, SYMBOL_TRADE_CONTRACT_SIZE); // Apparently, it is more accurate than taking TICKVALUE directly in some cases.
        // If profit currency is different from account currency.
        if (ProfitCurrency != AccCurrency)
        {
            double CCC = CalculateAdjustment(ProfitCurrency, mode); // Valid only for loss calculation.
            // Adjust the unit cost.
            UnitCost *= CCC;
        }
    }
    else UnitCost = MarketInfo(cp, MODE_TICKVALUE); // Futures or Forex.
    double OnePoint = MarketInfo(cp, MODE_POINT);

    if (OnePoint != 0) return(UnitCost / OnePoint);
    return UnitCost; // Only in case of an error with MODE_POINT retrieval.
}

//+-----------------------------------------------------------------------------------+
//| Calculates necessary adjustments for cases when ProfitCurrency != AccountCurrency.|
//| ReferenceSymbol changes every time because each symbol has its own RS.            |
//+-----------------------------------------------------------------------------------+
#define FOREX_SYMBOLS_ONLY 0
#define NONFOREX_SYMBOLS_ONLY 1
double CalculateAdjustment(const string profit_currency, const mode_of_operation calc_mode)
{
    string ref_symbol = NULL, add_ref_symbol = NULL;
    bool ref_mode = false, add_ref_mode = false;
    double add_coefficient = 1; // Might be necessary for correction coefficient calculation if two pairs are used for profit currency to account currency conversion. This is handled differently in MT5 version.

    if (ref_symbol == NULL) // Either first run or non-current symbol.
    {
        ref_symbol = GetSymbolByCurrencies(profit_currency, AccCurrency, FOREX_SYMBOLS_ONLY);
        if (ref_symbol == NULL) ref_symbol = GetSymbolByCurrencies(profit_currency, AccCurrency, NONFOREX_SYMBOLS_ONLY);
        ref_mode = true;
        // Failed.
        if (ref_symbol == NULL)
        {
            // Reversing currencies.
            ref_symbol = GetSymbolByCurrencies(AccCurrency, profit_currency, FOREX_SYMBOLS_ONLY);
            if (ref_symbol == NULL) ref_symbol = GetSymbolByCurrencies(AccCurrency, profit_currency, NONFOREX_SYMBOLS_ONLY);
            ref_mode = false;
        }
        if (ref_symbol == NULL)
        {
            if ((!FindDoubleReferenceSymbol("USD", profit_currency, ref_symbol, ref_mode, add_ref_symbol, add_ref_mode))  // USD should work in 99.9% of cases.
             && (!FindDoubleReferenceSymbol("EUR", profit_currency, ref_symbol, ref_mode, add_ref_symbol, add_ref_mode))  // For very rare cases.
             && (!FindDoubleReferenceSymbol("GBP", profit_currency, ref_symbol, ref_mode, add_ref_symbol, add_ref_mode))  // For extremely rare cases.
             && (!FindDoubleReferenceSymbol("JPY", profit_currency, ref_symbol, ref_mode, add_ref_symbol, add_ref_mode))) // For extremely rare cases.
            {
                Print("Adjustment calculation critical failure. Failed both simple and two-pair conversion methods.");
                return 1;
            }
        }
    }
    if (add_ref_symbol != NULL) // If two reference pairs are used.
    {
        // Calculate just the additional symbol's coefficient and then use it in final return's multiplication.
        MqlTick tick;
        SymbolInfoTick(add_ref_symbol, tick);
        add_coefficient = GetCurrencyCorrectionCoefficient(tick, calc_mode, add_ref_mode);
    }
    MqlTick tick;
    SymbolInfoTick(ref_symbol, tick);
    return GetCurrencyCorrectionCoefficient(tick, calc_mode, ref_mode) * add_coefficient;
}

//+---------------------------------------------------------------------------+
//| Returns a currency pair with specified base currency and profit currency. |
//+---------------------------------------------------------------------------+
string GetSymbolByCurrencies(const string base_currency, const string profit_currency, const uint symbol_type)
{
    // Cycle through all symbols.
    for (int s = 0; s < SymbolsTotal(false); s++)
    {
        // Get symbol name by number.
        string symbolname = SymbolName(s, false);
        string b_cur;

        // Normal case - Forex pairs:
        if (MarketInfo(symbolname, MODE_PROFITCALCMODE) == 0)
        {
            if (symbol_type == NONFOREX_SYMBOLS_ONLY) continue; // Avoid checking symbols of a wrong type.
            // Get its base currency.
            b_cur = SymbolInfoString(symbolname, SYMBOL_CURRENCY_BASE);
        }
        else // Weird case for brokers that set conversion pairs as CFDs.
        {
            if (symbol_type == FOREX_SYMBOLS_ONLY) continue; // Avoid checking symbols of a wrong type.
            // Get its base currency as the initial three letters - prone to huge errors!
            b_cur = StringSubstr(symbolname, 0, 3);
        }

        // Get its profit currency.
        string p_cur = SymbolInfoString(symbolname, SYMBOL_CURRENCY_PROFIT);

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

//+----------------------------------------------------------------------------+
//| Finds reference symbols using 2-pair method.                               |
//| Results are returned via reference parameters.                             |
//| Returns true if found the pairs, false otherwise.                          |
//+----------------------------------------------------------------------------+
bool FindDoubleReferenceSymbol(const string cross_currency, const string profit_currency, string &ref_symbol, bool &ref_mode, string &add_ref_symbol, bool &add_ref_mode)
{
    // A hypothetical example for better understanding:
    // The trader buys CAD/CHF.
    // account_currency is known = SEK.
    // cross_currency = USD.
    // profit_currency = CHF.
    // I.e., we have to buy dollars with francs (using the Ask price) and then sell those for SEKs (using the Bid price).

    ref_symbol = GetSymbolByCurrencies(cross_currency, AccCurrency, FOREX_SYMBOLS_ONLY); 
    if (ref_symbol == NULL) ref_symbol = GetSymbolByCurrencies(cross_currency, AccCurrency, NONFOREX_SYMBOLS_ONLY);
    ref_mode = true; // If found, we've got USD/SEK.

    // Failed.
    if (ref_symbol == NULL)
    {
        // Reversing currencies.
        ref_symbol = GetSymbolByCurrencies(AccCurrency, cross_currency, FOREX_SYMBOLS_ONLY);
        if (ref_symbol == NULL) ref_symbol = GetSymbolByCurrencies(AccCurrency, cross_currency, NONFOREX_SYMBOLS_ONLY);
        ref_mode = false; // If found, we've got SEK/USD.
    }
    if (ref_symbol == NULL)
    {
        Print("Error. Couldn't detect proper currency pair for 2-pair adjustment calculation. Cross currency: ", cross_currency, ". Account currency: ", AccCurrency, ".");
        return false;
    }

    add_ref_symbol = GetSymbolByCurrencies(cross_currency, profit_currency, FOREX_SYMBOLS_ONLY); 
    if (add_ref_symbol == NULL) add_ref_symbol = GetSymbolByCurrencies(cross_currency, profit_currency, NONFOREX_SYMBOLS_ONLY);
    add_ref_mode = false; // If found, we've got USD/CHF. Notice that mode is swapped for cross/profit compared to cross/acc, because it is used in the opposite way.

    // Failed.
    if (add_ref_symbol == NULL)
    {
        // Reversing currencies.
        add_ref_symbol = GetSymbolByCurrencies(profit_currency, cross_currency, FOREX_SYMBOLS_ONLY);
        if (add_ref_symbol == NULL) add_ref_symbol = GetSymbolByCurrencies(profit_currency, cross_currency, NONFOREX_SYMBOLS_ONLY);
        add_ref_mode = true; // If found, we've got CHF/USD. Notice that mode is swapped for profit/cross compared to acc/cross, because it is used in the opposite way.
    }
    if (add_ref_symbol == NULL)
    {
        Print("Error. Couldn't detect proper currency pair for 2-pair adjustment calculation. Cross currency: ", cross_currency, ". Chart's pair currency: ", profit_currency, ".");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get profit correction coefficient based on current prices.       |
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