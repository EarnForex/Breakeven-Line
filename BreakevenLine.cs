// -------------------------------------------------------------------------------
//   Displays a breakeven line for the current symbol.
//   You can hide/show the line by pressing Shift+B.
//   
//   Version 1.01
//   Copyright 2025, EarnForex.com
//   https://www.earnforex.com/indicators/Breakeven-Line/
// -------------------------------------------------------------------------------

using System;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Indicators
{
    [Indicator(IsOverlay = true, TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class BreakevenLine : Indicator
    {
        [Parameter("Ignore Long", DefaultValue = false)]
        public bool IgnoreLong { get; set; }

        [Parameter("Ignore Short", DefaultValue = false)]
        public bool IgnoreShort { get; set; }

        [Parameter("Line Color Buy", DefaultValue = "Teal")]
        public Color LineColorBuy { get; set; }

        [Parameter("Line Color Sell", DefaultValue = "Pink")]
        public Color LineColorSell { get; set; }

        [Parameter("Line Color Neutral", DefaultValue = "SlateGray")]
        public Color LineColorNeutral { get; set; }

        [Parameter("Line Style", DefaultValue = LineStyle.Solid)]
        public LineStyle LineStyle { get; set; }

        [Parameter("Line Width", DefaultValue = 1, MinValue = 1, MaxValue = 5)]
        public int LineWidth { get; set; }

        [Parameter("Font Color", DefaultValue = "SlateGray")]
        public Color FontColor { get; set; }

        [Parameter("Font Size", DefaultValue = 12, MinValue = 8, MaxValue = 24)]
        public int FontSize { get; set; }

        [Parameter("Object Prefix", DefaultValue = "BEL_")]
        public string ObjectPrefix { get; set; }

        // Global variables:
        private int PositionsLong, PositionsShort, PosTotal;
        private double VolumeLong, PriceLong, ProfitLong, VolumeShort, PriceShort, ProfitShort;
        private double VolumeTotal, ProfitTotal, PriceAverage, DistancePoints;
        private ChartHorizontalLine breakEvenLine;
        private ChartText breakEvenLabel;
        private string objectLine, objectLabel;
        private int lotStepDigits;
        private double lotStep;
        private bool isVisible = true;

        protected override void Initialize()
        {
            objectLine = ObjectPrefix + "Line" + Symbol.Name;
            objectLabel = ObjectPrefix + "Label" + Symbol.Name;
            
            // Calculate lot step digits.
            lotStep = Symbol.VolumeInUnitsStep;
            lotStepDigits = CountDecimalPlaces(lotStep);
            
            // Create initial objects.
            CreateObjects();
            
            // Subscribe to events.
            Positions.Opened += OnPositionOpenedEvent;
            Positions.Closed += OnPositionClosedEvent;
            Positions.Modified += OnPositionModifiedEvent;
            Chart.KeyDown += OnChartKeyDown;
            
            // Set timer for updates (5 times per second).
            Timer.Start(TimeSpan.FromMilliseconds(200));
        }

        public override void Calculate(int index)
        {
            // Main calculation is done in timer and position events.
            if (IsLastBar)
            {
                if (CalculateData())
                    DrawData();
            }
        }

        protected override void OnTimer()
        {
            // Update display on timer tick.
            if (CalculateData())
                DrawData();
        }

        private void OnPositionOpenedEvent(PositionOpenedEventArgs args)
        {
            // Recalculate on any position change.
            if (CalculateData())
                DrawData();
        }

        private void OnPositionClosedEvent(PositionClosedEventArgs args)
        {
            // Recalculate on any position change.
            if (CalculateData())
                DrawData();
        }

        private void OnPositionModifiedEvent(PositionModifiedEventArgs args)
        {
            // Recalculate on any position change.
            if (CalculateData())
                DrawData();
        }

        private void OnChartKeyDown(ChartKeyboardEventArgs args)
        {
            // Toggle visibility with Shift+B.
            if (args.Key == Key.B && args.ShiftKey)
            {
                isVisible = !isVisible;
                
                if (breakEvenLine != null)
                    breakEvenLine.IsHidden = !isVisible;
                    
                if (breakEvenLabel != null)
                    breakEvenLabel.IsHidden = !isVisible;
            }
        }

        //+------------------------------------------------------------------+
        //| Calculates BE distance and other values.                        |
        //+------------------------------------------------------------------+
        private bool CalculateData()
        {
            // Reset all values.
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

            // Process all positions for current symbol.
            foreach (var position in Positions.Where(p => p.SymbolName == Symbol.Name))
            {
                if (position.TradeType == TradeType.Buy)
                {
                    if (IgnoreLong) continue;
                    PositionsLong++;
                    PriceLong += position.EntryPrice * position.VolumeInUnits;
                    VolumeLong += position.VolumeInUnits;
                    ProfitLong += position.NetProfit;
                }
                else if (position.TradeType == TradeType.Sell)
                {
                    if (IgnoreShort) continue;
                    PositionsShort++;
                    PriceShort += position.EntryPrice * position.VolumeInUnits;
                    VolumeShort += position.VolumeInUnits;
                    ProfitShort += position.NetProfit;
                }
            }

            // Calculate average prices.
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
                double pointValue = Symbol.PipValue;
                
                if (VolumeTotal != 0)
                {
                    DistancePoints = ProfitTotal * Symbol.PipSize / Math.Abs(VolumeTotal * pointValue);
                    if (VolumeTotal > 0)
                    {
                        PriceAverage = Symbol.Bid - DistancePoints;
                    }
                    else // VolumeTotal < 0
                    {
                        PriceAverage = Symbol.Ask + DistancePoints;
                    }
                }
                else // VolumeTotal == 0
                {
                    DistancePoints = ProfitTotal * Symbol.PipSize / pointValue;
                    PriceAverage = (Symbol.Ask + Symbol.Bid) / 2 - DistancePoints;
                }
            }

            return true;
        }

        //+------------------------------------------------------------------+
        //| Creates or moves chart objects.                                 |
        //+------------------------------------------------------------------+
        private void DrawData()
        {
            if (PosTotal == 0)
            {
                // Hide objects when no positions.
                if (breakEvenLine != null)
                    breakEvenLine.IsHidden = true;
                if (breakEvenLabel != null)
                    breakEvenLabel.IsHidden = true;
                return;
            }

            // Update line.
            if (breakEvenLine != null)
            {
                breakEvenLine.Y = PriceAverage;
                breakEvenLine.IsHidden = !isVisible;
                
                // Set color based on volume.
                Color lineColor;
                if (VolumeTotal > 0)
                    lineColor = LineColorBuy;
                else if (VolumeTotal < 0)
                    lineColor = LineColorSell;
                else
                    lineColor = LineColorNeutral;
                    
                breakEvenLine.Color = lineColor;
            }

            // Update label.
            if (breakEvenLabel != null)
            {
                // Calculate distance in points.
                int distanceInPoints = (int)Math.Round(DistancePoints / Symbol.TickSize);
                
                // Format volume with appropriate decimal places.
                double volumeInLots = VolumeTotal / Symbol.LotSize;
                string volumeText = volumeInLots.ToString($"F{lotStepDigits}");
                
                // Create label text.
                string text = $"{distanceInPoints:N0} pips ({ProfitTotal:N2} {Account.Asset.Name}) {volumeText} lots, N = {PosTotal}";
                breakEvenLabel.Text = text;
                
                // Position label above the line.
                breakEvenLabel.Y = PriceAverage;
                
                // Right align the label.
                breakEvenLabel.HorizontalAlignment = HorizontalAlignment.Right;
                breakEvenLabel.VerticalAlignment = VerticalAlignment.Top;
                
                breakEvenLabel.IsHidden = !isVisible;
            }
        }

        //+------------------------------------------------------------------+
        //| Creates initial chart objects.                                   |
        //+------------------------------------------------------------------+
        private void CreateObjects()
        {
            // Create horizontal line.
            breakEvenLine = Chart.DrawHorizontalLine(objectLine, 0, LineColorNeutral, LineWidth, LineStyle);
            breakEvenLine.IsInteractive = false;
            breakEvenLine.IsHidden = true;

            // Create text label.
            breakEvenLabel = Chart.DrawText(objectLabel, "", Bars.Count - 1, 0, FontColor);
            breakEvenLabel.FontSize = FontSize;
            breakEvenLabel.IsHidden = true;
        }

        //+------------------------------------------------------------------+
        //| Counts decimal places.                                           |
        //+------------------------------------------------------------------+
        private int CountDecimalPlaces(double number)
        {
            // 100 as maximum length of number.
            for (int i = 0; i < 100; i++)
            {
                double pwr = Math.Pow(10, i);
                if (Math.Round(number * pwr) / pwr == number) 
                    return i;
            }
            return -1;
        }
    }
}