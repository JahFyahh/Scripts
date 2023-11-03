# Sources
# https://steemit.com/python/@marketstack/how-to-download-historical-price-data-from-binance-with-python
# https://pythonhosted.org/telegram-send/
# https://www.macroption.com/rsi-calculation/
#

'''
#### TO-DO ####
- Advice for the opposite CCI?
-- tel telegram in which trade and give get out signal
- Get variables from (json/xml) file on every run
- Skip sending everything on the first run.

? Link to TradingView

sql_user = 'scalpy'
sql_pass = 'Sc@lp3r!nG'
'''

import os
import sys
import json
import math
import logging
import requests
import warnings
import linecache
import numpy as np
import pandas as pd
import telegram_send
import datetime as dt
from time import sleep
import matplotlib.pyplot as plt

warnings.filterwarnings('ignore')

# variables
live = "Debug"
screenprint = True
trade_pair = 'BTCUSDT'  # ,ETHUSDT,ADAUSDT,HOTUSDT,WINUSDT,PUNDIXUSDT,BNBUSDT,DOGEUSDT,XRPUSDT,SOLUSDT,FTMUSDT,'
# trade_pair += 'OMGUSDT,LTCUSDT,SLPUSDT,PIVXBTC,XMRUSDT,DOTUSDT,MATICUSDT,XLMUSDT,TRXUSDT,ETCUSDT,KNCUSDT,EOSUSDT'
# trade_pair += 'TRXUSDT,LINKUSDT,MKRUSDT,CRVUSDT,UNIUSDT,ZENUSDT,DASHUSDT'
# frequency = input("Please enter the frequency (1m/5m/30m/.../1h/6h/1d/ :  ")
frequency = '15m'
moving_avg = 'EMA'
short_avg = 20
long_avg = 50
RSI_length = 21
tradingPairPath = '/home/Ingz/scalper/tradingpars_crypto.txt'
log_filepath = 'log_' + os.path.basename(__file__).replace('.py', '') + '.txt'

# region startup
# Calulate interval in seconds
if frequency.endswith("m"):
    run_timer = 60 * int(frequency.replace('m', ''))
elif frequency.endswith("h"):
    run_timer = 3600 * int(frequency.replace('h', ''))
elif frequency.endswith("d"):
    run_timer = 86400 * int(frequency.replace('d', ''))

# column names for long and short moving average columns
short_window_col = str(short_avg) + '_' + moving_avg
long_window_col = str(long_avg) + '_' + moving_avg

# clear screen
if os.name == 'nt':
    os.system('cls')
else:
    os.system('clear')

# set logging to screen and/or to file
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

# Debug to file
fh = logging.FileHandler(log_filepath)
fh.setLevel(logging.DEBUG)
fh.setFormatter(formatter)
logger.addHandler(fh)

# Debug to screen if true
if screenprint == True:
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    ch.setFormatter(formatter)
    logger.addHandler(ch)


# endregion

# Send telegram based on live
def SendTelegram(Message, telegram_config, live):
    try:
        if live == "True":
            telegram_send.send(messages=[Message], conf=telegram_config)
        elif live == "Test":
            telegram_send.send(messages=[Message])
        elif live == "Debug":
            null = ""

    except:
        PrintException()


# Custom exception to log error and send telegram
def PrintException():
    exc_type, exc_obj, tb = sys.exc_info()
    f = tb.tb_frame
    lineno = tb.tb_lineno
    filename = f.f_code.co_filename
    linecache.checkcache(filename)
    line = linecache.getline(filename, lineno, f.f_globals)
    logger.error('EXCEPTION ON LINE {} ("{}"): {}'.format(
        lineno, line.strip(), exc_obj))

    if live == "True" or live == "Test":
        telegram_send.send(messages=['EXCEPTION ON LINE {} ("{}"): {}'.format(
            lineno, line.strip(), exc_obj)])


# Timer to run every 15min on the 0-15-30-45-min
def run(condition):
    logger.info("Pending next quarter hour")
    # Wait 1 second until we are synced up with the 'every 15 minutes' clock
    while dt.datetime.now().minute not in {0, 15, 30, 45}:
        sleep(1)

    def task():
        # Your task goes here
        # Functionised because we need to call it twice
        logger.info("Run started")
        # telegram_send.send(messages=['Run started'], conf="~/telegram/channel_EMAnnouncer.conf")
        # SendTelegram('Run started', "~/telegram/channel_EMAnnouncer.conf", live)

        check_pairs()

        logger.info("Run ended")
        # SendTelegram('Run ended', "~/telegram/channel_EMAnnouncer.conf", live)
        # telegram_send.send(messages=['Run ended'], conf="~/telegram/channel_EMAnnouncer.conf")

    task()

    # Run task on every inverval moment
    while condition == True:
        sleep(run_timer)
        task()


# Get data from the Binance API
def get_bars(symbol, interval):
    # Get data from Binance if not return None
    try:
        root_url = 'https://api.binance.com/api/v1/klines'
        url = root_url + '?symbol=' + symbol + '&interval=' + interval + '&limit=1000'
        data = json.loads(requests.get(url).text)
    except:
        PrintException()
        return None

    # Add data to dataframe and set expected columns
    df = pd.DataFrame(data)
    df.columns = ['open_time', 'open', 'high', 'low', 'close', 'volume',
                  'close_time', 'quote_asset_volume', 'num_trades',
                  'taker_base_vol', 'taker_quote_vol', 'ignore']

    # Convert to datetime in Amsterdam TZ from epoch time
    df['open_time'] = pd.to_datetime(df['open_time'], unit='ms')
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
        df[short_window_col] = df['close'].rolling(window=short_window, min_periods=1).mean()

        # Create a long simple moving average column
        df[long_window_col] = df['close'].rolling(window=long_window, min_periods=1).mean()

    elif moving_avg == 'EMA':
        # Create short exponential moving average column
        df[short_window_col] = df['close'].ewm(span=short_window, adjust=False).mean()

        # Create a long exponential moving average column
        df[long_window_col] = df['close'].ewm(span=long_window, adjust=False).mean()

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

    u[u.index[period - 1]] = np.mean(u[:period])  # first value is sum of avg gains
    u = u.drop(u.index[:(period - 1)])
    d[d.index[period - 1]] = np.mean(d[:period])  # first value is sum of avg losses
    d = d.drop(d.index[:(period - 1)])
    rs = pd.DataFrame.ewm(u, com=period - 1, adjust=False).mean() / \
         pd.DataFrame.ewm(d, com=period - 1, adjust=False).mean()
    RSI = (100 - 100 / (1 + rs))
    return RSI


def check_pairs():
    # Get all pairs from file
    '''
    f = open(tradingPairPath, "r")
    trade_pair = f.read().replace('\n', '').replace('\r', '')
    logger.debug("Checking pair: " + trade_pair)
    '''

    # Check all given pairs
    for pair in trade_pair.split(','):
        logger.debug("checking " + pair)

        # Get all bars from Binance
        all_bars = get_bars(pair, frequency)

        # Check if bars are returned, if not log
        try:
            if all_bars is None:
                logger.error("get_bars function did not return data")
                continue
        except:
            logger.error("get_bars function did not return data")
            PrintException()
            continue

        # Get dataFrame for pair
        globals()[pair] = get_crossing_MA(all_bars, pair, moving_avg,
                                          short_avg, long_avg)

        # Check if [pair]_last variable exists, if not create
        try:
            globals()[pair + "_last"]
        except KeyError:
            globals()[pair + "_last"] = ''

        # Check if last signal is already sent, if not, then send.
        if globals()[pair].tail(1)['open_time'].to_string(index=False) != globals()[pair + "_last"]:
            globals()[pair + "_last"] = globals()[pair].tail(1)['open_time'].to_string(index=False)

            # Get last RSI
            print(get_RSI(all_bars['close'], RSI_length).tail(1))

            # Create message to send
            sendmessages = globals()[pair]['Position'].tail(1).to_string(
                index=False) + " is adviced for " + pair + "\nSlow and Fast " + moving_avg + " crossed around price: " + \
                           globals()[
                               pair]['close'].tail(1).to_string(index=False) + "\nat: " + globals()[pair][
                               'open_time'].tail(1).to_string(index=False) + "\nRSI is giving a " + + " signal."

            # log message to debug
            logger.debug("Send telegram: " + sendmessages)

            # Send telegram message
            SendTelegram(sendmessages, "~/telegram/channel_EMAnnouncer.conf", live)

        # Remove variables for next run.
        del all_bars
        del sendmessages


# Run code.
logger.info("Code started")

try:
    if live == "True" or live == "Test":
        run(True)
    elif live == "Debug":
        check_pairs()
except KeyboardInterrupt:
    logger.debug("Keyboard Interrupt: Manually stopped")
except:
    PrintException()
    SendTelegram('Shit, Somebody fucked something up!',
                 "~/telegram/channel_EMAnnouncer.conf", live)

logger.info("Code stopped")
