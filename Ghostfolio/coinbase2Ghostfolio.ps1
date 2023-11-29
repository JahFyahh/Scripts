Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir      = "$PSScriptRoot"
$csvFile         = "$($workingDir)\CoinbaseCryptoSheet.csv"
$skippedCsv      = "$($workingDir)\CoinbaseSkippedLines.csv"
$exportCsv       = "$($workingDir)\CoinbaseCrypto2Ghost.csv"
$exportJson      = "$($workingDir)\CoinbaseCrypto2Ghost.json"
$optionsFilePath = "$($workingDir)\cryptoSelectedOptions.xml"

$ghostToken    = "4ca6941ff18a89812dffc2e4f56a08f1927750b07c2716028b0be343460c0ad44f3c363b13a28cc6a0f65d04e795a697279b2b86306e088c61d1de93525f51e0"
$accountId     = "e50298c4-43b5-41db-8f9c-fcbcbc4709fc"
$writeLine     = $false
$skipped       = 0
$retryAttempts = 3
$retryDelaySec = 5

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

$import = Import-Csv $csvFile -Delimiter "," -Encoding UTF8 

if(Test-Path -Path $skippedCsv) { Remove-Item -Path $skippedCsv -Force }

# Arraylist to hold the activities
$arraylist  = New-Object System.Collections.ArrayList

# Get list of all symbols from coingecko
$apiUrl = "https://api.coingecko.com/api/v3/coins/list"
$CoinList = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop

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

    $coin = $CoinList | Where-Object {$_.symbol -eq $ticker}

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

    return $symbol.ToLower()
}

# Get relevant lines
Write-Output "Found $($import.Length) items to process"
for($idx = 0; $idx -lt $import.Length; $idx++){
    try{
        $line           = $import[$idx]
        $dataSource     = "COINGECKO"
        $date           = $line.Timestamp
        $comment        = "Coinbase: " + $line.Notes
        $baseCurrency   = $line.'Spot Price Currency'
        $symbol         = Get-CoinGeckoSymbol -ticker $line.Asset
        $quantity       = [math]::Abs([float]($line.'Quantity Transacted' -replace ',', '.'))

        if($line.'Spot Price at Transaction'){ $unitPrice = [float]($line.'Spot Price at Transaction' -replace ',', '.') }
        else { $unitPrice = 0.00001 }
        
        if($line.'Fees and/or Spread'){ $fee  = [float]($line.'Fees and/or Spread' -replace ',', '.')}
        else { $fee = 0.00001 }

        if ($line.'Transaction Type'.ToLower() -match "buy|learning reward|rewards income|receive"){
            $type = 'BUY'
            $writeLine = $true
        }

        elseif($line.'Transaction Type'.ToLower() -match "sell|send"){
            $type = 'SELL'
            $writeLine = $true
        }

        elseif($line.'Transaction Type'.ToLower() -match "convert"){
            $fromQuantity = [float]($line.Notes.split(" ")[1] -replace ',', '.') 
            $fromSymbol   = Get-CoinGeckoSymbol -ticker $line.Notes.split(" ")[2]
            $toQuantity   = [float]($line.Notes.split(" ")[4] -replace ',', '.') 
            $toSymbol     = Get-CoinGeckoSymbol -ticker $line.Notes.split(" ")[5]

            $ghostBody = @{
                activities = @(
                    @{
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
                    },
                    @{
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
                Write-Output "All retries failed. Exporting to CSV."
                $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"
                $skipped++
            }
            else {
                Write-Output "Request $idx successful after $attempt attempts."
            }

            $writeLine = $false
        }

        else{
            $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"
            $skipped++
            continue
        }

        if($writeLine){
            # Add object to Arraylist
            $ghostBody = @{
                activities = @(
                    @{
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
                Write-Output "All retries failed. Exporting to CSV."
                $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"
                $skipped++
            }
            else {
                Write-Output "Request $idx successful after $attempt attempts."
            }

            $writeLine = $false
            #break
        }

        Clear-Variable dataSource, comment, fee, quantity, type, unitPrice, currency, date, symbol -ErrorAction SilentlyContinue
    }
    catch{
        $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"
        $Error[0]
        $idx
        $line

        if($Error[0] -match "Bad Request") { $idx-- }
    }
}

Write-Host -ForegroundColor Yellow "Skipped $($skipped) lines"

if($arraylist) {
    Write-Host "Exporting to file" -ForegroundColor Yellow
    $arraylist | Select-Object @{n="date";e={(Get-Date $_.date -Format "yyyyMMdd")}},@{Name="Code" ;Expression={$_.symbol}},dataSource,currency,@{n="Price";e={$_.unitPrice -replace ',','.'}},Quantity,@{n="Action";e={$_.type}},@{n="Fee";e={$_.fee -replace ',','.'}},@{n="Note";e={$_.comment}} | Export-Csv $exportCsv -NoTypeInformation -Delimiter "," 

    $jsonObject = @{
        meta = @{ date = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.000Z"); version = "v2.14.0" }
        activities = $arraylist
    }

    if($jsonObject) { $jsonObject | ConvertTo-Json | Set-Content -Path $exportJson }

    # Export the updated selected options to the file
    $global:selectedOptions | Export-Clixml -Path $optionsFilePath
}


