Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir      = "$PSScriptRoot"
$csvFile         = "$($workingDir)\bitvavoCryptoSheet.csv"
$skippedCsv      = "$($workingDir)\bitvavoSkippedLines.csv"
$exportCsv       = "$($workingDir)\bitvavoCrypto2Ghost.csv"
$exportJson      = "$($workingDir)\bitvavoCrypto2Ghost.json"
$optionsFilePath = "$($workingDir)\cryptoSelectedOptions.xml"

$ghostToken    = "4ca6941ff18a89812dffc2e4f56a08f1927750b07c2716028b0be343460c0ad44f3c363b13a28cc6a0f65d04e795a697279b2b86306e088c61d1de93525f51e0"
$accountId     = "d4faf223-7472-41e8-bb24-0ee72549d007"
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

    $import = Import-Csv $csvFile -Delimiter "," -Encoding UTF8 

    if(Test-Path -Path $skippedCsv) { Remove-Item -Path $skippedCsv -Force }

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

    function Get-CoinPrice(){
        param (
            [string]$cryptoSymbol,
            [string]$currency,
            [string]$date
        )

        # CoinGecko API endpoint for historical price
        $apiUrl = "https://api.coingecko.com/api/v3/coins/$cryptoSymbol/history?date=$date"

        # Set up headers
        $headers = @{
            accept = 'application/json'
        }

        # Make the GET request to CoinGecko
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers

        # Output the result
        return $response.market_data.current_price.$currency
    }

    # Initialize the progress bar
    Write-Progress -Activity "Processing Items" -Status "0% Complete" -PercentComplete 0

    # Get relevant lines
    Write-Output "Found $($import.Length) items to process"
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
                
                # Convert date and time strings to [datetime] objects
                $dateObject = [datetime]::ParseExact($line.date, 'dd-MM-yyyy', $null)
                $timeObject = [datetime]::ParseExact($line.time, 'HH:mm', $null)
                $date       = Get-Date -Year ($dateObject).Year -Month ($dateObject).Month -Day ($dateObject).Day `
                                -Hour ($timeObject).Hour -Minute ($timeObject).Minute -Second 0 -Format "yyyy-MM-ddTHH:mm:ss.000Z"

                if($line.Type.ToLower() -match "buy|sell|withdrawal" -and $line.Currency.ToLower() -notmatch "eur"){
                    $type = $line.Type.ToUpper()

                    if($line.'Price (EUR)'){ $unitPrice = [float]($line.'Price (EUR)' -replace ',', '.') }

                    if($line.'Fee currency'.ToLower() -ne $baseCurrency.ToLower()){
                        # Calcutale fee back to baseCurrency
                        $fee  = [float]($line.'Fee amount' -replace ',', '.') * [float]((Get-CoinPrice -cryptoSymbol $symbol -currency $baseCurrency -date (Get-Date $date -format "dd-MM-yyyy")) -replace ',', '.')
                    }
                    else { $fee  = [float]($line.'Fee amount' -replace ',', '.') }

                    if($line.Type.ToLower() -eq "withdrawal"){
                        $type = 'SELL'
                    }
                    
                    $writeLine = $true
                }

                # Add crypto deposits and exclude cash deposits
                elseif($line.Type.ToLower() -match "deposit|staking" -and $line.Currency.ToLower() -ne "eur"){
                    $type = 'BUY'
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
        finally{
            # Update the progress bar
            $percentComplete = [math]::Round(($idx / $import.Count) * 100, 2)
            Write-Progress -Activity "Processing Items" -Status "$percentComplete% Complete" -PercentComplete $percentComplete -CurrentOperation "Processing Item $item"
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
}
catch{
    $Error[0]
}
finally {
    # Complete the progress bar
    Write-Progress -Activity "Processing Items" -Status "100% Complete" -PercentComplete 100 -Completed
}