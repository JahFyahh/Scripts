Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir      = "$PSScriptRoot"
$csvFile         = "$($workingDir)\bitvavoCryptoSheet.csv"
$skippedCsv      = "$($workingDir)\bitvavoSkippedLines.csv"
$exportCsv       = "$($workingDir)\bitvavoCrypto2Ghost.csv"
$exportJson      = "$($workingDir)\bitvavoCrypto2Ghost.json"
$optionsFilePath = "$($workingDir)\cryptoSelectedOptions.xml"

$accountId    = "d4faf223-7472-41e8-bb24-0ee72549d007"
$writeLine    = $false
$skipped      = 0

$import = Import-Csv $csvFile -Delimiter "," -Encoding UTF8 

# Arraylist to hold the activities
$arraylist  = New-Object System.Collections.ArrayList

# Get list of all symbols from coingecko
$apiUrl = "https://api.coingecko.com/api/v3/coins/list"
$response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop

# Reload previously selected options
$global:selectedOptions = @{}

if (Test-Path $optionsFilePath) {
    $global:selectedOptions = Import-Clixml -Path $optionsFilePath
}

function Get-CoinGeckoSymbol(){
    param (
        [string]$ticker
    )

    # Exceptions on the CoinGecko rule
    #$global:selectedOptions["AVAX"] = "avalanche"

    $coin = $response | Where-Object {$_.symbol -eq $ticker}

    if($coin.Count -gt 1){
        do {
            # If there are multiple matching coins, check if a selection has been made before
            if ($global:selectedOptions.ContainsKey($ticker)) {
                $previouslySelected = $global:selectedOptions[$ticker]
                $symbol = $previouslySelected

                break
            }

            # Display the menu
            Write-Host "Choose a coin for " $ticker ":"
        
            for ($i = 0; $i -lt $coin.Count; $i++) {
                Write-Host "$($i + 1). $($coin[$i].id)"
            }
        
            # Get user input
            $choice = Read-Host "Enter the number of your choice"
        
            # Validate user input
            if ($choice -ge 1 -and $choice -le $coin.Count) {
                # Subtract 1 to get the correct index
                $selectedCoin = $coin[$choice - 1]
                $symbol = $selectedCoin.id
                
                # Save the selection for future occurrences
                $global:selectedOptions[$ticker] = $symbol

                break  # Exit the loop if a valid choice is made
            } else {
                Write-Warning "Invalid choice. Please enter a valid number."
            }
        } while ($true)  # Loop until a valid choice is made
    }
    else { $symbol = $coin.id }

    if($symbol) { return $symbol.ToLower() }
}

# Get relevant lines
for($idx = 0; $idx -lt $import.Length; $idx++){
    try{
        $line         = $import[$idx]
        $fee          = 0
        $unitPrice    = 0.00001
        $dataSource   = "COINGECKO"
        $baseCurrency = 'EUR'

        if($line.Type.ToLower() -ne "affiliate"){
            $symbol     = Get-CoinGeckoSymbol -ticker $line.Currency
            $comment    = "Bitvavo Transaction ID: " + $line.'Transaction ID'
            $quantity   = [math]::Abs([float]($line.Amount -replace ',', '.'))
            $date       = Get-Date -Year ($line.date -as [datetime]).Year -Month ($line.date -as [datetime]).Month `
                            -Day ($line.date -as [datetime]).Day -Hour ($line.time -as [datetime]).Hour `
                            -Minute ($line.time -as [datetime]).Minute -Second 0 -Format "yyyy-MM-ddTHH:mm:ss.000Z"

            if($line.Type.ToLower() -match "buy|sell|withdrawal" -and $line.Currency.ToLower() -notmatch "eur"){
                $type = $line.Type.ToUpper()
                $currency = $line.'Fee currency'
                $fee  = [float]($line.'Fee amount' -replace ',', '.')
                if($line.'Price (EUR)'){ $unitPrice = [float]($line.'Price (EUR)' -replace ',', '.') }

                if($line.Type.ToLower() -eq "withdrawal"){
                    $type = 'SELL'
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

    # Export the updated selected options to the file
    $global:selectedOptions | Export-Clixml -Path $optionsFilePath
}
