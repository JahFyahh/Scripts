Remove-Variable * -ErrorAction SilentlyContinue

$counter     = 0 
$ghostToken  = "4ca6941ff18a89812dffc2e4f56a08f1927750b07c2716028b0be343460c0ad44f3c363b13a28cc6a0f65d04e795a697279b2b86306e088c61d1de93525f51e0"
$ghostApiUri = "http://192.168.1.11:3333/api/v1"

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

$ghostMarketData = Invoke-RestMethod -Uri ($ghostApiUri + "/admin/market-data") -Method Get -Headers $ghostHeader
Write-Output "Found $($ghostMarketData.marketData.Count) profiles in marketData"

Foreach ($item in $ghostMarketData.marketData){
    try {
        $null = Invoke-RestMethod -Uri ($ghostApiUri + "/admin/profile-data/$($item.dataSource)/$($item.symbol)") -Method Delete -Headers $ghostHeader
        
        $counter++
    }
    catch {
        if($Error[0].Exception -match "Internal Server Error") { 
            Write-Output "Could not delete $($item.symbol.ToUpper()) with datasource $($item.dataSource). Check if all connected activities are deleted" 
        }
        else {
            $Error[0]
        }
    }
}

Write-Output "Processed $($counter) items"

