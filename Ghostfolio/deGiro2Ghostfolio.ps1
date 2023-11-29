Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir   = "$PSScriptRoot"
$csvFile      = "$($workingDir)\deGiroAccount.csv"
$skippedCsv   = "$($workingDir)\deGiroSkippedLines.csv"
$exportCsv    = "$($workingDir)\deGiroAccount_psExp.csv"
$exportJson   = "$($workingDir)\deGiroAccount_psExp.json"

$ghostToken    = "4ca6941ff18a89812dffc2e4f56a08f1927750b07c2716028b0be343460c0ad44f3c363b13a28cc6a0f65d04e795a697279b2b86306e088c61d1de93525f51e0"
$accountId     = "0986e828-5c89-4497-8d08-445f35563bbf"
$writeLine     = $false
$skipped       = 0
$retryAttempts = 3
$retryDelaySec = 5

try{
    $ghostApiUri = "http://192.168.1.11:3333/api/v1"
    $ghostImport = $ghostApiUri + "/import"

    $ghostHeader = @{ Authorization = "Bearer " + (Invoke-RestMethod -Uri ($ghostApiUri + "/auth/anonymous") -Method Post -Body @{ accessToken = $ghostToken }).authToken 
                        ContentType = "application/json"
                        Accept = 'application/json, text/plain, */*'
                        "Accept-Language" = 'en-GB,en-US;q=0.9,en;q=0.8,de;q=0.7'
                        "Cache-Control" = 'no-cache'
                        "Content-Type" = 'application/json'
                        Origin = 'http://localhost:4200'
                        Pragma = 'no-cache'
                        Referer = 'http://localhost:4200/en/portfolio/activities'
                        "Sec-Fetch-Dest" = 'empty'
                        "Sec-Fetch-Mode" = 'cors'
                        "Sec-Fetch-Site" = 'same-origin'
                        "User-Agent" = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36'
                    }

    $import = (Get-Content $csvFile | Select-Object -Skip 1) | ConvertFrom-Csv -Delimiter "," `
        -Header "date","time","currencyDate","product","isin","description","fx","currency","amount","col1","col2","orderId"

    # Arraylist to hold the activities
    $arraylist  = New-Object System.Collections.ArrayList

    if(Test-Path -Path $skippedCsv) { Remove-Item -Path $skippedCsv -Force }

    # Initialize the progress bar
    Write-Progress -Activity "Processing Items" -Status "0% Complete" -PercentComplete 0

    # Get relevant lines
    Write-Output "Found $($import.Length) items to process"
    for($idx = 0; $idx -lt $import.Length; $idx++){
        try{
            $line = $import[$idx]
            $dataSource   = "YAHOO"

            if((-not[string]::IsNullOrEmpty($line.date.ToLower())) -and $line.description -notmatch "ideal|flatex|cash sweep|withdrawal|pass-through"){
                #$line.description

                #Exclude certain isins for now
                #if($line.isin -match "AU000000FBR4"){ continue }

                # Skip the following but add them to a list for future checks
                if ($line.description.ToLower() -match "productwijziging|geldmarktfonds"){
                    $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"
                    $skipped++
                    continue
                }

                # default values
                $fee      = 0
                $quantity = 1
                $currency = $line.currency

                # Convert date and time strings to [datetime] objects
                $dateObject = [datetime]::ParseExact($line.date, 'dd-MM-yyyy', $null)
                $timeObject = [datetime]::ParseExact($line.time, 'HH:mm', $null)
                $date     = Get-Date -Year ($dateObject).Year -Month ($dateObject).Month -Day ($dateObject).Day `
                            -Hour ($timeObject).Hour -Minute ($timeObject).Minute -Second 0 -Format "yyyy-MM-ddTHH:mm:ss.000Z"

                if ($line.amount) { $amountRecord = [float]($line.amount -replace ',', '.') }
                if ($line.isin)   { $comment  = "ISIN: " + $line.isin + " - " + $line.description }
                if ($line.isin)   { $symbol = ((Invoke-WebRequest -UseBasicParsing -Uri "https://query1.finance.yahoo.com/v1/finance/search?q=$($line.isin)").Content | ConvertFrom-Json).quotes.symbol }
        
                # Set dividend activity
                if ($line.description.ToLower() -match "dividend"){
                    $type = 'DIVIDEND'

                    # If amount is positive its not tax
                    if($amountRecord -gt 0){
                        $unitPrice = $amountRecord

                        $writeLine = $true
                    }
                    #if amount is negative then its tax add as fee
                    else {
                        if($arraylist[-1].symbol -eq $symbol){
                            $arraylist[-1].fee = [math]::Abs([float]$amountRecord)
                            $arraylist[-1].comment = "ISIN: " + $line.isin + " - Dividend: " + " - dividendTax: $($line.amount)"
                        }
                    }
                }

                # For the lines valuta credit and debit, eg. fees for converting to foreign currency
                # Adding as unit price, the negative and positive should balance out the actual cost.
                elseif ($line.description.ToLower() -match "valuta|courtesy|aansluitingskosten|verrekening"){
                    #"FEE " + $line.description

                    $type       = "FEE"
                    $unitPrice  = [math]::Abs([float]$amountRecord)
                    $symbol     = "Fee"
                    $dataSource = "MANUAL"

                    if(-NOT$line.isin) { $comment  = $line.description }

                    $writeLine = $true
                }

                # For Buy/Sell actions
                elseif ($line.description.ToLower() -match "@"){
                    #$line.description

                    # Use regular expression to match the number in the description and convert to float
                    $numberSharesFromDescription = [regex]::Match($line.description, '([\d*\.?\,?\d*]+)').Value
                    $quantity = [double]::Parse($numberSharesFromDescription)

                    # Account for spin-off shares which usually are free
                    if ($line.description.ToLower() -match "spin-off"){
                        # Set type, currently based on dutch export as there are no other traits to determine buy or sell
                        if($line.description.ToLower() -match "koop"){ $type = 'BUY' } 
                        elseif($line.description.ToLower() -match "verkoop") { $type = 'SELL' }

                        [float]$unitPrice = 0
                    }

                    # Account for stock split ??
                    elseif ($line.description.ToLower() -match "stock split"){
                        #$line.description
                    }

                    # Buy/Sell activities
                    else{
                        #$line.description

                        # Convert unitPrice by dividing total spend by number of shares
                        $unitPrice = [math]::Round(([math]::Abs($amountRecord) / $quantity), 3)

                        # Calculate fee by looking at the previous 2 entries
                        if($import[$idx-1] -match "en\/of|and\/or|und\/oder|e\/o"){
                            $fee = [math]::Abs([float]($import[$idx-1].amount -replace ',', '.')) 

                            if($import[$idx-2] -match "en\/of|and\/or|und\/oder|e\/o"){
                                $fee = $fee + [math]::Abs([float]($import[$idx-1].amount -replace ',', '.'))
                            }
                            if($fee -lt 0) { break }
                        }

                        # Set type based on amount, if negative its buy, else sell.
                        if($amountRecord -lt 0){ $type = 'BUY' } else { $type = 'SELL' }
                        
                        $writeLine = $true
                    }
                }

                # Missed lines
                else{
                    $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"
                    $skipped++
                    continue
                }

                if($writeLine){
                    # Add object to Arraylist
                    $arraylist.Add(
                        [PSCustomObject]@{
                            accountId = $accountId
                            comment = $comment
                            fee = $fee
                            quantity = $quantity
                            type = $type
                            unitPrice = $unitPrice
                            currency = $currency
                            dataSource = $dataSource
                            date = $date
                            symbol = $symbol
                        }
                    ) | Out-Null
                    
                    # Create body and upload to ghost
                    $ghostBody = @{
                        activities = @(
                            @{
                                accountId = $accountId
                                comment = $comment
                                fee = $fee
                                quantity = $quantity
                                type = $type
                                unitPrice = $unitPrice
                                currency = $currency
                                dataSource = $dataSource
                                date = $date
                                symbol = $symbol
                            }
                        )
                    } | ConvertTo-Json

                    for ($attempt = 1; $attempt -le $retryAttempts; $attempt++) {
                        try {
                            # Make the REST request
                            $ghostResponse = Invoke-RestMethod -Uri $ghostImport -Method Post -Body $ghostBody -Headers $ghostHeader
                    
                            # If the request is successful, break out of the retry loop

                            break
                        } catch {
                            # If an exception occurs, output the error and wait for a moment before retrying
                            Write-Output "Error: $_"
                            Write-Output "Attempt $attempt failed. Retrying in $retryDelaySec seconds..."
                            Start-Sleep -Seconds $retryDelaySec
                        }
                    }

                    # Check if all retries failed
                    if ($attempt -gt $retryAttempts) {
                        Write-Output "All retries failed for row $($idx). Exporting to CSV."
                        $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"
                        $skipped++
                    }
                    else {
                        Write-Output "Request $idx successful after $attempt attempts."
                    }

                    $writeLine = $false
                }
            }
            Clear-Variable dataSource, comment, fee, quantity, type, unitPrice, currency, date, symbol -ErrorAction SilentlyContinue
        }
        catch{
            $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"
            $Error[0]
            $line

            if($Error[0] -match "Bad Request") { $idx-- }
        }
        finally{
            # Update the progress bar
            $percentComplete = ($idx / $import.Count) * 100
            Write-Progress -Activity "Processing Items" -Status "$percentComplete% Complete" -PercentComplete $percentComplete -CurrentOperation "Processing Item $item"
        }
    }

    Write-Host -ForegroundColor Yellow "Skipped $($skipped) lines"

    if($arraylist) {
        Write-Host "Exporting to file" -ForegroundColor Yellow
        $arraylist | Export-Csv $exportCsv -NoTypeInformation -Delimiter ";"

        $jsonObject = @{
            meta = @{ date = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.000Z"); version = "v2.14.0" }
            activities = $arraylist
        }

        if($jsonObject) { $jsonObject | ConvertTo-Json | Set-Content -Path $exportJson }
    }
}
catch{
    $Error[0]
}
finally {
    # Complete the progress bar
    Write-Progress -Activity "Processing Items" -Status "100% Complete" -PercentComplete 100 -Completed
}