for pair in trade_pair.split(','):
    # Get dataFrame for pair
    globals()[pair] = get_bars(pair, frequency, moving_avg, short_avg, long_avg)
    
    # RSI part
    # convert to float
    globals()[pair]['close'] = globals()[pair]['close'].astype(float)

    delta = globals()[pair]['close'].diff().dropna()
    period = 14
    
    
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
    print(100 - 100 / (1 + rs))

    '''
    # Get the difference in price from previous step
    delta = globals()[pair]['close'].diff()
    
    # Get rid of the first row, which is NaN since it did not have a previous 
    # row to calculate the differences
    delta = delta[1:] 

    # Make the positive gains (up) and negative gains (down) Series
    up, down = delta.clip(lower=0), delta.clip(upper=0)

    # Calculate the EWMA
    roll_up1 = up.ewm(span=window_length).mean()
    roll_down1 = down.abs().ewm(span=window_length).mean()

    # Calculate the RSI based on EWMA
    RS1 = roll_up1 / roll_down1
    RSI1 = 100.0 - (100.0 / (1.0 + RS1))

    # Calculate the SMA
    roll_up2 = up.rolling(window_length).mean()
    roll_down2 = down.abs().rolling(window_length).mean()

    # Calculate the RSI based on SMA
    RS2 = roll_up2 / roll_down2
    RSI2 = 100.0 - (100.0 / (1.0 + RS2))

    # Compare graphically
    plt.figure(figsize=(8, 6))
    RSI1.plot()
    RSI2.plot()
    plt.legend(['RSI via EWMA', 'RSI via SMA'])
    plt.show()
    '''
