#property strict

//mklink /D Files R:\Files

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

string ver = "ver.2014.09.24  05:30";

double spreadLock_EURUSD = 0.5;
double spreadLock_USDJPY = 0.5;
double spreadLock_GBPUSD = 1.3;

double spreadLock;
int slip = 5;

double stopMargin = 10.0;

double pip;

MqlTick tick;

double bid;
double ask;
double spread;
double spreadAvg;

int a = 10;
double spreadA[10];

double bid0 = 0;
double ask0 = 0;

bool pending;

int holdCount;

int holdVal = 10;

int OnInit()
{
  EventSetTimer(1);

  ObjectsDeleteAll(0, 0, -1);
   
  ObjectCreate(0, "pair", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "pair", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "pair", OBJPROP_YDISTANCE, 20);
  //--- set the text
  ObjectSetString(0, "pair", OBJPROP_TEXT, Symbol());
  //--- set text font
  ObjectSetInteger(0, "pair", OBJPROP_FONTSIZE, 12);
  //--- set color
  ObjectSetInteger(0, "pair", OBJPROP_COLOR, clrWhite);

  ObjectCreate(0, "ver", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "ver", OBJPROP_XDISTANCE, 150);
  ObjectSetInteger(0, "ver", OBJPROP_YDISTANCE, 15);
  //--- set the text
  ObjectSetString(0, "ver", OBJPROP_TEXT, ver);
  //--- set text font
  ObjectSetInteger(0, "ver", OBJPROP_FONTSIZE, 8);
  //--- set color
  ObjectSetInteger(0, "ver", OBJPROP_COLOR, clrWhite);

  ObjectCreate(0, "ea", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "ea", OBJPROP_XDISTANCE, 350);
  ObjectSetInteger(0, "ea", OBJPROP_YDISTANCE, 10);

  //--- set text font
  ObjectSetInteger(0, "ea", OBJPROP_FONTSIZE, 15);



  if (IsTradeAllowed())
  {
    //--- set the text
    ObjectSetString(0, "ea", OBJPROP_TEXT, "Trade Enabled");
    //--- set color
    ObjectSetInteger(0, "ea", OBJPROP_COLOR, clrGreen);
  }
  else
  {
    //--- set the text
    ObjectSetString(0, "ea", OBJPROP_TEXT, "Trade Disabled");
    //--- set color
    ObjectSetInteger(0, "ea", OBJPROP_COLOR, clrDeepPink);
  }





  if (Symbol() == "USDJPY")
  {
    pip = 0.01;
  }
  else
  {
    pip = 0.0001;
  }
  
    
  if (Symbol() == "EURUSD")
  {
    spreadLock = spreadLock_EURUSD;
  } 
  
  
  if (Symbol() == "USDJPY")
  {
    spreadLock = spreadLock_USDJPY;
  } 
  
    
  if (Symbol() == "GBPUSD")
  {
    spreadLock = spreadLock_GBPUSD;
  } 
  

  holdCount = 0;

  compute();

  //---
  return (INIT_SUCCEEDED);
}


void OnTick()
{
  compute();

}


void OnTimer()
{
  compute(); // buggy in the loop if with tick event
  // Print("test");
}


void OnDeinit(const int reason)
{
  EventKillTimer();
  ObjectsDeleteAll(0, 0, -1);
}



//+------------------------------------------------------------------+
struct Protocol
{
  //from file
  string dt;
  string posString; //long short flat
  double losscut;
  double size;
  int LC;

  //calc here
  int d;
  double pos;
};

struct Asset
{
  int d;
  double pos;
  double losscut;
  double size;
  int ticket;


};

Protocol protocol; //keep value in the loop

void compute()
{
  if (SymbolInfoTick(Symbol(), tick))
  {
    bid = tick.bid;
    ask = tick.ask;
    spread = NormalizeDouble((ask - bid) / pip, 1);

    if (bid0 == 0)
    {
      for (int i = 0; i < a; i++)
      {
        spreadA[i] = spread;
      }
    }

    bid0 = bid;
    ask0 = ask;

    for (int i = 0; i < a - 1; i++)
    {
      spreadA[i + 1] = spreadA[i];
    }

    spreadA[0] = spread;

    double sumA = 0;
    //Print("------");
    for (int i = 0; i < a; i++)
    {
      sumA += spreadA[i];
      // Print(spreadA[i]);
    }

    spreadAvg = sumA / a;

    showTick(bid, ask, spread, spreadAvg); 
  }
  else Print("SymbolInfoTick() failed, error = ", GetLastError());


//=============================================================


  if (holdCount > 0)
    holdCount--;

  //--- open the file
  ResetLastError();

  datetime current = TimeCurrent();
  string dt0 = TimeToString(current, TIME_DATE) + "   " + TimeToString(current, TIME_SECONDS);

  obtainProtocol(protocol);
  showProtocol(protocol, dt0);


  Asset asset; //reset value in the loop
  obtainAsset(asset);
  showAsset(asset);

  pending = false;

  //order stream ===========================================
  if (holdCount == 0)
  {

    if (asset.pos != protocol.pos)
    {
      Print(Symbol() + " " + asset.pos + " -> " + protocol.pos);

      if (spread > spreadLock) //exclude the border val from trades
      {
        Print("spread > spreadLock, pending " + spread);

        pending = true;
      }
      else
      {
        bool orderCloseError = false;
        // the exsiting position to close===============
        if (asset.pos > 0)
        {
          Print(Symbol() + " close " + asset.size);
          if (OrderClose(asset.ticket, asset.size, Ask, slip))
          {
            Print("OrderClose placed successfully");
            Print(Symbol() + " ClOSED " + asset.pos + " (spread)" + spread);
            holdCount = 10;

            pending = false;
          }
          else
          {
            Print("OrderClose failed with error #", GetLastError());
            pending = true;

            orderCloseError = true;
          }
        }
        if (asset.pos < 0)
        {
          Print(Symbol() + " close " + asset.size);
          if (OrderClose(asset.ticket, asset.size, Bid, slip))
          {
            Print("OrderClose placed successfully");
            Print(Symbol() + " CLOSED " + asset.pos + " (spread)" + spread);
            holdCount = 10;

            pending = false;
          }
          else
          {
            Print("OrderClose failed with error #", GetLastError());
            pending = true;

            orderCloseError = true;
          }
        }
        //===============================================================

        if (orderCloseError == false)
        {

          //new Position double check ============================================
          int ticket;

          if (protocol.pos > 0)
          {
            //protocol.losscut +- margin for bracket stop
            double lc = NormalizeDouble(protocol.losscut - stopMargin * pip, 5);

            Print(Symbol() + " buy " + protocol.size + " (LC)" + protocol.losscut + "(LC-margin)" + lc);

            if (protocol.losscut >= Ask) //something wrong
            {
              Print("protocol.losscut >= Ask    something wrong, so no order");
              pending = true;
            }
            else //fine
            {
              ticket = OrderSend(Symbol(), OP_BUY, protocol.size, Ask, slip, lc, 0);
              if (ticket < 0)
              {
                Print("OrderSend failed with error #", GetLastError());
                pending = true;
              }
              else
              {
                Print("OrderSend placed successfully");
                Print(Symbol() + " BUY " + protocol.pos + " (spread)" + spread);
                holdCount = 10;

                pending = false;
              }
            }
          }

          if (protocol.pos < 0)
          {

            //protocol.losscut +- margin for bracket stop
            double lc = NormalizeDouble(protocol.losscut + stopMargin * pip, 5);

            Print(Symbol() + " sell " + protocol.size + " (LC)" + protocol.losscut + "(LC+margin)" + lc);

            if (protocol.losscut <= Bid) //something wrong
            {
              Print("protocol.losscut <= Bid    something wrong, so no order");
              pending = true;
            }
            else //fine
            {
              ticket = OrderSend(Symbol(), OP_SELL, protocol.size, Bid, slip, lc, 0);
              if (ticket < 0)
              {
                Print("OrderSend failed with error #", GetLastError());
                pending = true;
              }
              else
              {
                Print("OrderSend placed successfully");
                Print(Symbol() + " SELL " + protocol.pos + " (spread)" + spread);
                holdCount = 10;

                pending = false;
              }
            }
          }

        }

      }
    }
    else
    {

      if (asset.pos != 0) //same asset position, but in case of different lc+-margin
      {
        double lc;

        if (asset.pos > 0)
          lc = NormalizeDouble(protocol.losscut - stopMargin * pip, 5);

        if (asset.pos < 0)
          lc = NormalizeDouble(protocol.losscut + stopMargin * pip, 5);

        if (asset.losscut != lc)
        {
          Print(Symbol() + " trailing-stop " + protocol.losscut + " Margin-> " + lc);
          Print(asset.losscut + " " + lc);
          if (OrderModify(asset.ticket, lc, lc, 0, 0))
          {
            Print("OrderModify placed successfully");
            holdCount = 10;
          }
          else
            Print("OrderModify failed with error #", GetLastError());
        }

      }
    }

  }

  //finally again for the new Asset
  obtainAsset(asset);
  showAsset(asset);


  //=======================================================================
  //========================================================================


}

void obtainProtocol(Protocol & protocol)
{
  int file_handle = FileOpen(Symbol() + ".txt", FILE_READ | FILE_TXT);

  if (file_handle != INVALID_HANDLE)
  {

    protocol.dt = FileReadString(file_handle);
    protocol.posString = FileReadString(file_handle);
    protocol.losscut = NormalizeDouble(StringToDouble(FileReadString(file_handle)), 5);
    protocol.size = NormalizeDouble(StringToDouble(FileReadString(file_handle)), 2);
    protocol.LC = StringToInteger(FileReadString(file_handle));
    //--- close the file
    FileClose(file_handle);

    // little calc

    if (protocol.posString == "long")
      protocol.d = 1;
    if (protocol.posString == "short")
      protocol.d = -1;
    if (protocol.posString == "flat")
      protocol.d = 0;

    protocol.pos = NormalizeDouble(protocol.d * StringToDouble(protocol.size), 2);
  }
  else
    Print("Failed to open the file");


}

void obtainAsset(Asset & asset)
{
  asset.d = 0;
  asset.pos = 0;
  asset.losscut = 0;

  for (int i = 0; i < OrdersTotal(); i++)
  {
    if (OrderSelect(i, SELECT_BY_POS) == false) break;

    if (OrderSymbol() == Symbol())
    {
      if (OrderType() == OP_BUY)
      {
        asset.d = 1;
        asset.ticket = OrderTicket();
        asset.size = OrderLots();

        asset.losscut = NormalizeDouble(OrderStopLoss(), 5);
      }
      if (OrderType() == OP_SELL)
      {
        asset.d = -1;
        asset.ticket = OrderTicket();
        asset.size = OrderLots();

        asset.losscut = NormalizeDouble(OrderStopLoss(), 5);
      }
    }
  }
  //
  if (asset.d != 0)
    asset.pos = NormalizeDouble(asset.size * asset.d, 2);
}

void showTick(double bid, double ask, double spread, double spreadAvg)
{

  ObjectCreate(0, "ask", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "ask", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "ask", OBJPROP_YDISTANCE, 38);
  //--- set the text
  ObjectSetString(0, "ask", OBJPROP_TEXT, DoubleToStr(ask, 5));
  //--- set text font
  ObjectSetInteger(0, "ask", OBJPROP_FONTSIZE, 13);
  //--- set color
  ObjectSetInteger(0, "ask", OBJPROP_COLOR, clrWhite);


  ObjectCreate(0, "bid", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "bid", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "bid", OBJPROP_YDISTANCE, 50);
  //--- set the text
  ObjectSetString(0, "bid", OBJPROP_TEXT, DoubleToStr(bid, 5));
  //--- set text font
  ObjectSetInteger(0, "bid", OBJPROP_FONTSIZE, 13);
  //--- set color
  ObjectSetInteger(0, "bid", OBJPROP_COLOR, clrWhite);


  ObjectCreate(0, "spread", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "spread", OBJPROP_XDISTANCE, 120);
  ObjectSetInteger(0, "spread", OBJPROP_YDISTANCE, 42);
  //--- set the text
  ObjectSetString(0, "spread", OBJPROP_TEXT, DoubleToStr(spread, 1));
  //--- set text font
  ObjectSetInteger(0, "spread", OBJPROP_FONTSIZE, 15);
  //--- set color
  ObjectSetInteger(0, "spread", OBJPROP_COLOR, clrWhite);


  ObjectCreate(0, "spreadAvg", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "spreadAvg", OBJPROP_XDISTANCE, 180);
  ObjectSetInteger(0, "spreadAvg", OBJPROP_YDISTANCE, 42);
  //--- set the text
  ObjectSetString(0, "spreadAvg", OBJPROP_TEXT, DoubleToStr(spreadAvg, 1) + " (recent " + a + " avg)");
  //--- set text font
  ObjectSetInteger(0, "spreadAvg", OBJPROP_FONTSIZE, 12);
  //--- set color
  ObjectSetInteger(0, "spreadAvg", OBJPROP_COLOR, clrWhite);
}

void showProtocol(Protocol & protocol, string dt0)
{

  ObjectCreate(0, "dt0", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "dt0", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "dt0", OBJPROP_YDISTANCE, 70);
  //--- set the text
  ObjectSetString(0, "dt0", OBJPROP_TEXT, dt0 + " (server time)");
  //--- set text font
  ObjectSetInteger(0, "dt0", OBJPROP_FONTSIZE, 12);
  //--- set color
  ObjectSetInteger(0, "dt0", OBJPROP_COLOR, clrWhite);

  ObjectCreate(0, "dt", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "dt", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "dt", OBJPROP_YDISTANCE, 100);
  //--- set the text
  ObjectSetString(0, "dt", OBJPROP_TEXT, protocol.dt + " (protocol time)");
  //--- set text font
  ObjectSetInteger(0, "dt", OBJPROP_FONTSIZE, 12);
  //--- set color
  ObjectSetInteger(0, "dt", OBJPROP_COLOR, clrWhite);



  ObjectCreate(0, "pos", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "pos", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "pos", OBJPROP_YDISTANCE, 120);
  //--- set the text
  ObjectSetString(0, "pos", OBJPROP_TEXT, protocol.pos + " (" + protocol.posString + " x " + protocol.size + ")");
  //--- set text font
  ObjectSetInteger(0, "pos", OBJPROP_FONTSIZE, 17);
  //--- set color
  if (protocol.posString == "long")
    ObjectSetInteger(0, "pos", OBJPROP_COLOR, clrAqua);
  else if (protocol.posString == "short")
    ObjectSetInteger(0, "pos", OBJPROP_COLOR, clrDeepPink);
  else
    ObjectSetInteger(0, "pos", OBJPROP_COLOR, clrGreen);

  ObjectCreate(0, "lc", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "lc", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "lc", OBJPROP_YDISTANCE, 145);
  //--- set the text
  ObjectSetString(0, "lc", OBJPROP_TEXT, protocol.losscut + " (losscut)");
  //--- set text font
  ObjectSetInteger(0, "lc", OBJPROP_FONTSIZE, 13);
  //--- set color
  ObjectSetInteger(0, "lc", OBJPROP_COLOR, clrWhite);
}

void showAsset(Asset & asset)
{

  ObjectCreate(0, "asset.pos", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "asset.pos", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "asset.pos", OBJPROP_YDISTANCE, 170);
  //--- set the text
  if (pending)
    ObjectSetString(0, "asset.pos", OBJPROP_TEXT, asset.pos + " <--- PENDING");
  else
    ObjectSetString(0, "asset.pos", OBJPROP_TEXT, asset.pos);
  //--- set text font
  ObjectSetInteger(0, "asset.pos", OBJPROP_FONTSIZE, 17);
  //--- set color
  ObjectSetInteger(0, "asset.pos", OBJPROP_COLOR, clrYellow);

  ObjectCreate(0, "lcA", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "lcA", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "lcA", OBJPROP_YDISTANCE, 190);
  //--- set the text
  ObjectSetString(0, "lcA", OBJPROP_TEXT, asset.losscut + " (losscut+-" + stopMargin + "pips)");
  //--- set text font
  ObjectSetInteger(0, "lcA", OBJPROP_FONTSIZE, 13);
  //--- set color
  ObjectSetInteger(0, "lcA", OBJPROP_COLOR, clrYellow);
  //========================================================

  //===============================
  ObjectCreate(0, "hc", OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, "hc", OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, "hc", OBJPROP_YDISTANCE, 270);
  //--- set the text
  ObjectSetString(0, "hc", OBJPROP_TEXT, holdCount + " ticks (order hold counter)");
  //--- set text font
  ObjectSetInteger(0, "hc", OBJPROP_FONTSIZE, 8);
  //--- set color
  ObjectSetInteger(0, "hc", OBJPROP_COLOR, clrYellow);
  //========================================================

}