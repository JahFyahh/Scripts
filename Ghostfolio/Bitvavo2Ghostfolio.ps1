Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir   = "D:\Dropbox\Workspaces\VSCode\Ghostfolio"
$csvFile      = "$($workingDir)\cryptoSheet.csv"
$skippedCsv   = "$($workingDir)\skippedLines_Crypto.csv"
$exportCsv    = "$($workingDir)\crypto2Ghost.csv"
$exportJson   = "$($workingDir)\crypto2Ghost.json"
#>
<#Work
$csvFile      = "D:\Workspace\vsCode\ghostFolio\Account.csv"
$skippedCsv   = "Y:\dg2gf\skippedLines.csv"
$exportCsv    = "Y:\dg2gf\Account_psExp.csv"
#>

$accountId    = "d4faf223-7472-41e8-bb24-0ee72549d007"
$writeLine    = $false
$skipped      = 0

$import = Import-Csv $csvFile -Delimiter "," -Encoding UTF8 

# Arraylist to hold the activities
$arraylist  = New-Object System.Collections.ArrayList

# Get relevant lines
for($idx = 0; $idx -lt $import.Length; $idx++){
    try{
        $line = $import[$idx]
        $dataSource   = "YAHOO"
        $date     = Get-Date -Year ($line.date -as [datetime]).Year -Month ($line.date -as [datetime]).Month -Day ($line.date -as [datetime]).Day `
                -Hour ($line.time -as [datetime]).Hour -Minute ($line.time -as [datetime]).Minute -Second 0 -Format "yyyy-MM-ddTHH:mm:ss.000Z"

        # exclude sta
        if($line.Status.ToLower() -eq "completed"){
            # Add crypto deposits and exclude cash deposits
            if($line.Type.ToLower() -eq "deposit" -and $line.Currency.ToLower() -ne "eur"){
                $line.Currency
            }
        
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

        Clear-Variable dataSource, comment, fee, quantity, type, unitPrice, currency, date, symbol -ErrorAction SilentlyContinue
    }
    catch{
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
