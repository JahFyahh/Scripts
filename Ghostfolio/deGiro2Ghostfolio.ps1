Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir   = "$PSScriptRoot"
$csvFile      = "$($workingDir)\deGiroAccount.csv"
$skippedCsv   = "$($workingDir)\deGiroSkippedLines.csv"
$exportCsv    = "$($workingDir)\deGiroAccount_psExp.csv"
$exportJson   = "$($workingDir)\deGiroAccount_psExp.json"

$accountId    = "037d6f03-7607-4dab-8550-1bdc3030c95e"
$writeLine    = $false
$skipped      = 0

$import = Import-Csv $csvFile -Delimiter "," -Encoding UTF8 `
    -Header "date","time","currencyDate","product","isin","description","fx","currency","amount","col1","col2","orderId"

# Arraylist to hold the activities
$arraylist  = New-Object System.Collections.ArrayList

# Get relevant lines
for($idx = 0; $idx -lt $import.Length; $idx++){
    try{
        $line = $import[$idx]
        $dataSource   = "YAHOO"

        if((-not[string]::IsNullOrEmpty($line.date.ToLower())) -and $line.description -notmatch "ideal|flatex|cash sweep|withdrawal|pass-through"){
            #$line.description

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
            $date     = Get-Date -Year ($line.date -as [datetime]).Year -Month ($line.date -as [datetime]).Month -Day ($line.date -as [datetime]).Day `
                -Hour ($line.time -as [datetime]).Hour -Minute ($line.time -as [datetime]).Minute -Second 0 -Format "yyyy-MM-ddTHH:mm:ss.000Z"

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

                $writeLine = $false
            }
        }
        Clear-Variable dataSource, comment, fee, quantity, type, unitPrice, currency, date, symbol -ErrorAction SilentlyContinue
    }
    catch{
        $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"
        $Error[0]
        $line
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
