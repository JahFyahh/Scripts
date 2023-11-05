Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir   = "$PSScriptRoot"
$csvFile      = "$($workingDir)\bitvavoCryptoSheet.csv"
$skippedCsv   = "$($workingDir)\bitvavoSkippedLines.csv"
$exportCsv    = "$($workingDir)\bitvavoCrypto2Ghost.csv"
$exportJson   = "$($workingDir)\bitvavoCrypto2Ghost.json"

$accountId    = "d4faf223-7472-41e8-bb24-0ee72549d007"
$writeLine    = $false
$skipped      = 0

$import = Import-Csv $csvFile -Delimiter "," -Encoding UTF8 

# Arraylist to hold the activities
$arraylist  = New-Object System.Collections.ArrayList

# Get relevant lines
for($idx = 0; $idx -lt $import.Length; $idx++){
    try{
        $line         = $import[$idx]
        $fee          = 0
        $unitPrice    = 0.00001
        $dataSource   = "YAHOO"
        $baseCurrency = 'EUR'

        if($line.Type.ToLower() -ne "affiliate"){
            $symbol     = $line.Currency + 'USD'
            $comment    = "Bitvavo Transaction ID: " + $line.'Transaction ID'
            $quantity   = [math]::Abs([float]($line.Amount -replace ',', '.'))
            $date       = Get-Date -Year ($line.date -as [datetime]).Year -Month ($line.date -as [datetime]).Month `
                            -Day ($line.date -as [datetime]).Day -Hour ($line.time -as [datetime]).Hour `
                            -Minute ($line.time -as [datetime]).Minute -Second 0 -Format "yyyy-MM-ddTHH:mm:ss.000Z"

            if($line.Type.ToLower() -match "buy|sell|withdrawal"){
                $type = $line.Type.ToUpper()
                $fee  = [float]($line.'Fee amount' -replace ',', '.')
                $unitPrice = [float]($line.'Price (EUR)' -replace ',', '.')
                $currency = $line.'Fee currency'

                if($line.Type.ToLower() -eq "withdrawal"){
                    $type = 'SELL'
                    $unitPrice = 0.00001
                }
                
                $writeLine = $true
            }

            # Add crypto deposits and exclude cash deposits
            elseif($line.Type.ToLower() -match "deposit|staking" -and $line.Currency.ToLower() -ne "eur"){
                $type = 'BUY'
                $currency = $baseCurrency
                $comment  = $line.Type + ": " + $comment

                $writeLine = $true
            }
        }

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
