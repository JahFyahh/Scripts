$accountId  = "037d6f03-7607-4dab-8550-1bdc3030c95e"
$csvFile    = "C:\Users\Ingz\Downloads\Account.csv"
$dataSource = "YAHOO"
$writeLine  = $false

$import = Import-Csv $csvFile -Delimiter "," -Encoding UTF8 `
    -Header "date","time","currencyDate","product","isin","description","fx","currency","amount","col1","col2","orderId"

# Arraylist to hold the activities
$arraylist  = New-Object System.Collections.ArrayList

# Get relevant lines
for($idx = 1; $idx -lt $import.Length; $idx++){
    try{
        $line = $import[$idx]

        if((-not[string]::IsNullOrEmpty($line.date.ToLower())) -and $line.description -notmatch "ideal|flatex|cash sweep|withdrawalpass-through"){
            #$line.description

            # default values
            $quantity = 1
            $currency = $line.currency
            $date     = Get-Date -Year ($line.date -as [datetime]).Year -Month ($line.date -as [datetime]).Month -Day ($line.date -as [datetime]).Day `
                -Hour ($line.time -as [datetime]).Hour -Minute ($line.time -as [datetime]).Minute -Second 0 -Format "yyyy-MM-ddTHH:mm:ssZ"

            if ($line.amount) {$amountRecord = [float]($line.amount -replace ',', '.')}
            if($line.product) { $comment  = "Product: " + $line.product + " - ISIN: " + $line.isin }
            if ($line.isin) {$symbol = ((Invoke-WebRequest -UseBasicParsing -Uri "https://query1.finance.yahoo.com/v1/finance/search?q=US0605051046").Content | ConvertFrom-Json).quotes.symbol }
    
            # Set dividend activity
            if ($line.description.ToLower() -match "dividend"){
                $type = 'DIVIDEND'

                # If amount is positive its not tax
                if($amountRecord -gt 0){
                    $unitPrice = $amountRecord

                    $writeLine = $true
                }
                #if amount is negative then its tax add as fee
                #TODO: check using ISIN to correctly match!?
                else {
                    $arraylist[-1].fee = $amountRecord
                    $arraylist[-1].comment = $comment + " - dividendTax: $($line.amount)"
                }
            }

            # For the lines valuta credit and debit, eg. fees for converting to foreign currency
            elseif ($line.description.ToLower() -match "valuta"){
            
            }

            # For Buy/Sell actions
            elseif ($line.description.ToLower() -match "@"){
            
            }

            # Account for spin-off shares which usually are free
            elseif ($line.description.ToLower() -match "spin-off"){
            
            }

            # Account for stock split ??
            elseif ($line.description.ToLower() -match "stock split"){
            
            }

            # Missed lines
            else{
                #Write-Host "Could not proces line $($idx): $($line.description)"
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
        Clear-Variable fee, quantity, type, currency, date, symbol, comment -ErrorAction SilentlyContinue
    }
    catch{
        $Error[0]
        $line
        break
    }
}

#$arraylist | ConvertTo-Json
#$arraylist | Export-Csv C:\Users\Ingz\Downloads\Account_psExp.csv -NoTypeInformation -Delimiter ";"
