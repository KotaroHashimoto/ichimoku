//+------------------------------------------------------------------+
//|                                             Ichimokukinkohyo.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

//--- input parameters
input int Magic_Number = 1;

input double Entry_Lot = 0.1;
input int Close_TimeOut = 10;

string thisSymbol;
datetime lastModified;

double minLot;
double maxLot;
double lotSize;
double lotStep;

double sl;

void getAverageCandle(double& low, double& high) {

  low = (iOpen(NULL, PERIOD_CURRENT, 1) + iClose(NULL, PERIOD_CURRENT, 1)) / 2.0;
  high = (iLow(NULL, PERIOD_CURRENT, 0) + iHigh(NULL, PERIOD_CURRENT, 0) + iOpen(NULL, PERIOD_CURRENT, 0) + iClose(NULL, PERIOD_CURRENT, 0)) / 4.0;
  
  if(high < low) {
    double b = low;
    low = high;
    high = b;
  }
}

void getMAs(double& yellow, double& blue, double& white, double& gray) {

  yellow = iMA(NULL, PERIOD_CURRENT, 25, 0, MODE_SMA, PRICE_WEIGHTED, 0);
  blue = iMA(NULL, PERIOD_CURRENT, 75, 0, MODE_SMA, PRICE_WEIGHTED, 0);
  white = iMA(NULL, PERIOD_CURRENT, 100, 0, MODE_SMA, PRICE_WEIGHTED, 0);
  gray = iMA(NULL, PERIOD_CURRENT, 200, 0, MODE_SMA, PRICE_WEIGHTED, 0);
}

bool upTrendBuy(double yellow, double blue, double white, double gray, double low, double high) {

  if(gray < white && white < blue && blue < yellow) {
    if((low < gray && gray < high) || (low < white && white < high) || (low < blue && blue < high) || (low < yellow && yellow < high)) {
      double i = iCustom(NULL, PERIOD_CURRENT, "HMD", 0, 0);
      if(0 < i && i < 1000) {
        return True;
      }
    }
  }
  
  return False;
}

bool downTrendSell(double yellow, double blue, double white, double gray, double low, double high) {

  if(gray > white && white > blue && blue > yellow) {
    if((low < gray && gray < high) || (low < white && white < high) || (low < blue && blue < high) || (low < yellow && yellow < high)) {
      double i = iCustom(NULL, PERIOD_CURRENT, "HMD", 1, 0);
      if(0 < i && i < 1000) {
        return True;
      }
    }
  }
  
  return False;
}


void takeProfit(double yellow, double blue, double white, double gray, double low, double high) {

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        int direction = OrderType();

        if(direction == OP_BUY) {
        
          double ic = iCustom(NULL, PERIOD_CURRENT, "HMD", 1, 0);
          bool up = (gray < white && white < blue && blue < yellow);
          
          if((up && (0 < ic && ic < 1000)) || !up || (0 < lastModified && Close_TimeOut * 60 < TimeLocal() - lastModified)) {
            bool closed = OrderClose(OrderTicket(), OrderLots(), Bid, 0);
            if(closed) {
              i = -1;
              lastModified = 0;
              continue;
            }
          }
        
          if(OrderStopLoss() < Ask - sl) {
            if(OrderModify(OrderTicket(), OrderOpenPrice(), Ask - sl, 0, 0)) {
              lastModified = TimeLocal();
            }
          }
        }
        else if(direction == OP_SELL) {
        
          double ic = iCustom(NULL, PERIOD_CURRENT, "HMD", 0, 0);        
          bool down = (gray > white && white > blue && blue > yellow);
          
          if((down && (0 < ic && ic < 1000)) || !down || (0 < lastModified && Close_TimeOut * 60 < TimeLocal() - lastModified)) {
            bool closed = OrderClose(OrderTicket(), OrderLots(), Ask, 0);
            if(closed) {
              i = -1;
              lastModified = 0;
              continue;
            }
          }
        
          if(Bid + sl < OrderStopLoss()) {
            if(OrderModify(OrderTicket(), OrderOpenPrice(), Bid + sl, 0, 0)) {
              lastModified = TimeLocal();
            }
          }
        }
      }
    }
  }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{  
  thisSymbol = Symbol();

  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
  lastModified = 0;

  //---
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---   
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  double yellow, blue, white, gray, low, high;
  
  getMAs(yellow, blue, white, gray);
  getAverageCandle(low, high);
  
  if(OrdersTotal() == 0) {
  
    if(upTrendBuy(yellow, blue, white, gray, low, high)) {
      Alert("Buy " + Symbol() + " at", Ask);    
      int ticket = OrderSend(thisSymbol, OP_BUY, Entry_Lot, NormalizeDouble(Ask, Digits), 3, NormalizeDouble(gray, Digits), 0, NULL, Magic_Number);
      sl = Ask - gray;
      lastModified = 0;
    }
    else if(downTrendSell(yellow, blue, white, gray, low, high)) {
      Alert("Sell " + Symbol() + " at", Bid);
      int ticket = OrderSend(thisSymbol, OP_SELL, Entry_Lot, NormalizeDouble(Bid, Digits), 3, NormalizeDouble(gray, Digits), 0, NULL, Magic_Number);
      sl = gray - Bid;
      lastModified = 0;
    }
  }
  else {
    takeProfit(yellow, blue, white, gray, low, high);
  }
}

