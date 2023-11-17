Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir   = "$PSScriptRoot"
$csvFile      = "$($workingDir)\CoinbaseCryptoSheet.csv"
$skippedCsv   = "$($workingDir)\CoinbaseSkippedLines.csv"
$exportCsv    = "$($workingDir)\CoinbaseCrypto2Ghost.csv"
$exportJson   = "$($workingDir)\CoinbaseCrypto2Ghost.json"

$accountId    = "e50298c4-43b5-41db-8f9c-fcbcbc4709fc"
$writeLine    = $false
$skipped      = 0

$import = Import-Csv $csvFile -Delimiter "," -Encoding UTF8 

# Arraylist to hold the activities
$arraylist  = New-Object System.Collections.ArrayList

# Get relevant lines
for($idx = 0; $idx -lt $import.Length; $idx++){
    try{
        $line           = $import[$idx]
        $dataSource     = "YAHOO"
        $date           = $line.Timestamp
        $symbol         = $line.Asset + 'USD'
        $comment        = "Coinbase: " + $line.Notes
        $baseCurrency   = $line.'Spot Price Currency'
        $quantity       = [math]::Abs([float]($line.'Quantity Transacted' -replace ',', '.'))
        
        if($line.'Spot Price at Transaction'){ $unitPrice = [float]($line.'Spot Price at Transaction' -replace ',', '.') }
        else { $unitPrice = 0.00001 }
        
        if($line.'Fees and/or Spread'){ $fee  = [float]($line.'Fees and/or Spread' -replace ',', '.')}
        else { $fee = 0 }

        if ($line.'Transaction Type'.ToLower() -match "buy|learning reward|rewards income|receive"){
            $type = 'BUY'
            $writeLine = $true
        }

        if($line.'Transaction Type'.ToLower() -match "sell|send"){
            $type = 'SELL'
            $writeLine = $true
        }

        if($line.'Transaction Type'.ToLower() -match "convert"){
            $fromQuantity = [float]($line.Notes.split(" ")[1] -replace ',', '.') 
            $fromSymbol   = $line.Notes.split(" ")[2] + "USD"
            $toQuantity   = [float]($line.Notes.split(" ")[4] -replace ',', '.') 
            $toSymbol     = $line.Notes.split(" ")[5] + "USD"

            $arraylist.Add(
                [PSCustomObject]@{
                    accountId = $accountId
                    comment = $comment
                    fee = 0
                    quantity = $fromQuantity
                    type = "SELL"
                    unitPrice = $unitPrice
                    currency = $baseCurrency
                    dataSource = $dataSource
                    date = $date
                    symbol = $fromSymbol
                }
            ) | Out-Null

            $arraylist.Add(
                [PSCustomObject]@{
                    accountId = $accountId
                    comment = $comment
                    fee = $fee
                    quantity = $toQuantity
                    type = "BUY"
                    unitPrice = $unitPrice
                    currency = $baseCurrency
                    dataSource = $dataSource
                    date = $date
                    symbol = $toSymbol
                }
            ) | Out-Null




            $writeLine = $false
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
                    currency = $baseCurrency
                    dataSource = $dataSource
                    date = $date
                    symbol = $symbol
                }
            ) | Out-Null

            $writeLine = $false
            #break
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
    $arraylist | select @{n="date";e={(Get-Date $_.date -Format "yyyyMMdd")}},@{Name="Code" ;Expression={$_.symbol}},dataSource,currency,@{n="Price";e={$_.unitPrice -replace ',','.'}},Quantity,@{n="Action";e={$_.type}},@{n="Fee";e={$_.fee -replace ',','.'}},@{n="Note";e={$_.comment}} | Export-Csv $exportCsv -NoTypeInformation -Delimiter "," 

    $jsonObject = @{
        meta = @{ date = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.000Z"); version = "v2.14.0" }
        activities = $arraylist
    }

    if($jsonObject) { $jsonObject | ConvertTo-Json | Set-Content -Path $exportJson }
}


