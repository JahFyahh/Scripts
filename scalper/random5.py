# Sources
# https://steemit.com/python/@marketstack/how-to-download-historical-price-data-from-binance-with-python###

#region Start
import requests 
import json 
import pandas as pd 
import numpy as np  
import datetime as dt  
import math
import telegram_send
import warnings
import matplotlib.pyplot as plt
warnings.filterwarnings('ignore')

trade_pair  = 'BTCUSDT' #,ETHUSDT,DOGEUSDT,ADAUSDT,XMRUSDT'
frequency   = '15m'                         #frequency = input("Please enter the frequency (1m/5m/30m/.../1h/6h/1d/ :  ")
moving_avg  = 'EMA'
short_avg   = 20
long_avg    = 50

RSI_period = 21

# column names for long and short moving average columns
short_window_col = str(short_avg) + '_' + moving_avg
long_window_col  = str(long_avg) + '_' + moving_avg  
#endregion

def get_bars(symbol, interval):
    root_url = 'https://api.binance.com/api/v1/klines'
    url = root_url + '?symbol=' + symbol + '&interval=' + interval
    data = json.loads(requests.get(url).text)
    df = pd.DataFrame(data)
    df.columns = ['open_time','open', 'high', 'low', 'close', 'volume',
                  'close_time', 'quote_asset_volume', 'num_trades',
                  'taker_base_vol', 'taker_quote_vol', 'ignore']
    
    # Convert to datetime in Amsterdam TZ from epoch time
    df['open_time'] = pd.to_datetime(df['open_time'],unit='ms')
    df['open_time'] = df['open_time'].dt.tz_localize('UTC').dt.tz_convert('Europe/Amsterdam')
    
    # Drop unneeded columns
    df.drop('high', axis=1, inplace=True)
    df.drop('low', axis=1, inplace=True)
    df.drop('close_time', axis=1, inplace=True)
    df.drop('quote_asset_volume', axis=1, inplace=True)
    df.drop('num_trades', axis=1, inplace=True)
    df.drop('taker_base_vol', axis=1, inplace=True)
    df.drop('taker_quote_vol', axis=1, inplace=True)
    df.drop('ignore', axis=1, inplace=True)
    
    return df

def get_crossing_MA(df, symbol, moving_avg, short_window, long_window):
    # Add Moving Avg to column
    if moving_avg == 'SMA':
        # Create a short simple moving average column
        df[short_window_col] = df['close'].rolling(window = short_window, min_periods = 1).mean()

        # Create a long simple moving average column
        df[long_window_col] = df['close'].rolling(window = long_window, min_periods = 1).mean()

    elif moving_avg == 'EMA':
        # Create short exponential moving average column
        df[short_window_col] = df['close'].ewm(span = short_window, adjust = False).mean()

        # Create a long exponential moving average column
        df[long_window_col] = df['close'].ewm(span = long_window, adjust = False).mean()

    # Add difference between both MAs
    df['ema_diff'] = df[short_window_col] - df[long_window_col]

    # create a new column 'indicator' such that if faster moving average is greater than slower moving average 
    # then set indicator as 1 else 0.
    df['indicator'] = 0.0  
    df['indicator'] = np.where(df[short_window_col] > df[long_window_col], 1.0, 0.0) 

    # create a new column 'Position' which is a day-to-day difference of the 'indicator' column. 
    df['Position'] = df['indicator'].diff()
    df['symbol'] = symbol

    df_pos = df[(df['Position'] == 1) | (df['Position'] == -1)]
    df_pos['Position'] = df_pos['Position'].apply(lambda x: 'Buy' if x == 1 else 'Sell')
    
    return df_pos

def get_RSI(delta, period):
    # Convert close bars to float
    delta = delta.astype(float)

    # Calculate and get the difference between the previous days
    delta = delta.diff().dropna()
    
    u = delta * 0
    d = u.copy()
    u[delta > 0] = delta[delta > 0]
    d[delta < 0] = -delta[delta < 0]
    
    u[u.index[period-1]] = np.mean( u[:period] ) #first value is sum of avg gains
    u = u.drop(u.index[:(period-1)])
    d[d.index[period-1]] = np.mean( d[:period] ) #first value is sum of avg losses
    d = d.drop(d.index[:(period-1)])
    rs = pd.DataFrame.ewm(u, com=period-1, adjust=False).mean() / \
         pd.DataFrame.ewm(d, com=period-1, adjust=False).mean()
    RSI = (100 - 100 / (1 + rs))
    return RSI


for pair in trade_pair.split(','):   
    # Get dataFrame for pair
    globals()[pair] = get_crossing_MA(get_bars(pair, frequency), pair, moving_avg, short_avg, long_avg)
    
    # Get all bars
    globals()[pair + '_bars'] = get_bars(pair, frequency)
    
    
    
    # Get the RSI
    print(get_RSI(globals()[pair + '_bars']['close'], RSI_period))
