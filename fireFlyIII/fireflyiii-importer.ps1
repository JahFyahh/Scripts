Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir      = "$PSScriptRoot"
$csvFile         = "$($workingDir)\Ings_Alle_rekeningen.csv"
$skippedCsv      = "$($workingDir)\fireFlySkippedLines.csv"

$apiToken     = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIxOCIsImp0aSI6IjMzNThkMjM4MGEyYjJiMjVlNDQ5MGRlZGM1ZTYwZjA0NGU3MWU4OTNhMTYyOGYwNGYxYTg4ZTY4MDU2MzMwNjhhMTdmNjE5YTBjMjYyZTE5IiwiaWF0IjoxNzAyODQ4ODAzLjQ5MzgyLCJuYmYiOjE3MDI4NDg4MDMuNDkzODM0LCJleHAiOjE3MzQ0NzEyMDMuMzk3NTc2LCJzdWIiOiIxIiwic2NvcGVzIjpbXX0.ilPD09gFmszChrJ2c9bfCm9GDYju5FaxquWsBhAYqT131yZ5lUnHKfkXOm2r2ID4_XCxeQX6brzLS7T3zLRSarsqXj1HoKK255MOUd2R9AV3P4JEh6WAnl1PIMu6fBRa84qQ2LAuvYSR4Azlthqw1SZ6mrXw32zgSn1-Sowfcr9Htvblyexvv113rgOiMnuDBC-0emr1wKmIDNsPXLLWBenqHCAnEFSmnz1D6RFCG1ENz4TVbAX3dMpy_klh0J5OUkfEsjX_T2Zxiruigl0dmM_cco3YWh8Eof4vTgujHBRiGtdJMIONO21kYLz4rmrpzohDm6woyWS1oE4Yj8I76xFpdrqJVKi33RzwroY3v3qpeA8geokvN7HwjvZREF-gKG6vOBbPyWJy1BXExKJcB3w27y7Zqt321zeyingFYfzOpF-R1BdQ821ezJob3DBSYM1RwRSYNcIfKGj7wKdsizlLCUqti1bECAz-HDJjEeuZsqSeeSAqWY64RC6K0Tl7Z2rJAgRTec3K_Q7aeZ5uRDUPffk-8SurYWGx_b3_ZWPC2qGuSXIb5_d54jRiTMduaDKfGpN9cDHhBSJa5rfL1FDlRYmyU6FvmVRlT2F2yNLYc9-jSN2mn7Cb-_xh-IwlOCfNs6pEtLmxHw5JyjSUrVoQC1Jd92UY9g7JFaSsvaQ"
$accountId     = "d4faf223-7472-41e8-bb24-0ee72549d007"
$writeLine     = $true
$skipped       = 0
$retryAttempts = 3
$retryDelaySec = 5

# Specify the URL
$url = "http://192.168.1.11:3334/api/v1/"

# Specify the headers
$headers = @{
    'Authorization' = "Bearer $apiToken"
    'accept'         = 'application/vnd.api+json'
    'Content-Type'   = 'application/json'
}

function get-accountId(){
    param(
        [string]$account,
        [string]$name
    )

    # Switch statement based on account ID
    switch ($account) {
        "NL35INGB0002956047" { 
            return @(677, "Hr IRD Luciano")
        }
        "NL42INGB0628505914" { 
            return @(680, "Hr IRD Luciano,Mw N Boom")
        }
        Default {
            # Handle other account IDs or provide a default value if needed
            return @("", $name)
        }
    }
}

try {
    #import file
    $import = Import-Csv $csvFile -Delimiter ";" -Encoding UTF8 

    #$accountList = Invoke-RestMethod -Uri ($url + "accounts?limit=1000&page=1") -Method Get -Headers $headers

    # Initialize the progress bar
    Write-Progress -Activity "Processing Items" -Status "0% Complete" -PercentComplete 0

    Write-Output "Found $($import.Length) items to process"
    for($idx = 0; $idx -lt $import.Length; $idx++){
        try{
            $line         = $import[$idx]
            $description  = $line.Notifications
            $name         = $line.'Name / Description'
            $amount       = $line.'Amount (EUR)'.Replace(",",".")
            $tag          = @($line.Code,$line.'Transaction type',$line.Tag) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            $date         = Get-Date ([datetime]::ParseExact($line.date, 'yyyyMMdd', $null)) `
                                -Format "yyyy-MM-ddTHH:mm"

            if($line.'Debit/credit'.ToLower() -eq "credit") { 
                $type             = "deposit"
                $source_id        = (get-accountId -account $line.Counterparty -name $line.'Name / Description')[0]
                $source_name      = (get-accountId -account $line.Counterparty -name $line.'Name / Description')[1]
                $destination_id   = (get-accountId -account $line.Account -name $line.'Name / Description')[0]
                $destination_name = (get-accountId -account $line.Account -name $line.'Name / Description')[1]
            }
            elseif($line.'Debit/credit'.ToLower() -eq "debit") {  
                $type             = "withdrawal" 
                $source_id        = (get-accountId -account $line.Account -name $line.'Name / Description')[0]
                $source_name      = (get-accountId -account $line.Account -name $line.'Name / Description')[1]
                $destination_id   = (get-accountId -account $line.Counterparty -name $line.'Name / Description')[0]
                $destination_name = (get-accountId -account $line.Counterparty -name $line.'Name / Description')[1]
            }

            if($writeLine){
                # Specify the JSON payload
                $jsonPayload = @{
                    "error_if_duplicate_hash" = $true
                    "apply_rules"             = $true
                    "fire_webhooks"           = $true
                    "group_title"             = ""
                    "transactions"            = @(
                        @{
                            "type"                   = $type
                            "date"                   = $date
                            "amount"                 = $amount
                            "description"            = $description
                            "source_id"              = $source_id
                            "source_name"            = $source_name
                            "destination_id"         = $destination_id
                            "destination_name"       = $destination_name
                            "tags"                   = $tag
                        }
                    )
                } | ConvertTo-Json

                # Make the API call
                $response = Invoke-RestMethod -Uri ($url + "transactions") -Method Post -Headers $headers -Body $jsonPayload

                # Display the response
                # $response
                Write-Host "http://192.168.1.11:3334/transactions/show/$($response.data.id)"
            }

        }
        catch{
            # Handle the error
            if ($_.Exception.Response -ne $null) {
                $errorDetails = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorDetails)
                $responseContent = $reader.ReadToEnd()
                Write-Host -ForegroundColor Red "Validation Error Details: $responseContent"
            }
            $exceptDetails = $_
            Write-Host -ForegroundColor Red "Error details: $_"

            # Added skipped/failed line to file
            $line | Add-Member -MemberType NoteProperty -Name "idx" -Value $idx -Force
            $line | Add-Member -MemberType NoteProperty -Name "apiError" -Value ($responseContent | ConvertFrom-Json).message -Force
            $line | Add-Member -MemberType NoteProperty -Name "psError" -Value $exceptDetails.Exception.Message -Force
            $line | Export-Csv -Path $skippedCsv -Append -NoTypeInformation -Delimiter ";"


        }
        finally{
            Remove-Variable line, jsonPayload, destination_id, destination_name, source_id, source_name, type, exceptDetails, responseContent, `
                date, amount, description, tag, response -ErrorAction SilentlyContinue

            # Update the progress bar
            $percentComplete = [math]::Round(($idx / $import.Count) * 100, 2)
            Write-Progress -Activity "Processing Items" -Status "$percentComplete% Complete" -PercentComplete $percentComplete -CurrentOperation "Processing Item $item"
        }
    }
}
catch {
    <#Do this if a terminating exception happens#>
}
finally {
    # Complete the progress bar
    Write-Progress -Activity "Processing Items" -Status "100% Complete" -PercentComplete 100 -Completed
}
    
<#


@{
    "type"           = "withdrawal"
    "date"           = "2023-01-01T12:00:00Z"
    "amount"         = "100.00"
    "description"    = "Transaction Description"
    "currency_code"  = "USD"
    "source_name"    = "Source Account Name"
    "destination_name" = "Destination Account Name"
    # Add other transaction details as needed
}

# Convert the payload to JSON
$jsonPayloadString = $jsonPayload | ConvertTo-Json

# Make the API call
$response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $jsonPayloadString

# Display the response
$response


$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
$session.Cookies.Add((New-Object System.Net.Cookie("organizrLanguage", "en", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("organizr_user_uuid", "6cf15128-3bc5-48db-bb7d-bef3a85118a0", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("grafana_session", "e51cc0acfb70a5895c08203576115e21", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("grafana_session_expiry", "1702335785", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("remember_web_59ba36addc2b2f9401580f014c7f58ea4e30989d", "eyJpdiI6InlySzlPdkpJbHRuTVZrb0dJcnlaeVE9PSIsInZhbHVlIjoiZ3BSV2hQN0pZdFBKWUNRZXMzWDJKQ3VzY3NLSmxWMTJRd3paY0s3RVh2aGRtaDU2NHVlQ3VqcWxlNnRJZU5jYk1rR3QyeXZoY3dsQ3EvQzhPb2tSOWdQQVRjY1Z3NDRpMElWY1BZSXNLMitwWnZKa0FWckN5S2EyNmZISUIzMGpRcXU5Z0xqMkw4V3MwWTRScU41czNGNFZNU3V0TVc1cEdmT05ibHZ6MmtUcUtGRUZPWkNUaXd6Z3RTM0pRM042R1Fsdm1oVElVZWRCVTIzWVU5U3dVYlZwaHYwQTEyWFVZSlZCNjRQbG8yRT0iLCJtYWMiOiJhZjRlZjMzZjE2MDZmNWI3ZTcyYmU0NWQ1ZTM2NmFjZWZmNmM0ZWFiMjA1YTJmMTQ2OWFlN2VkNzlhNzg2MzkwIiwidGFnIjoiIn0%3D", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("flow", "eyJpdiI6IjNqV2gyMHlHZGEvSTAwbG1KY2VBTnc9PSIsInZhbHVlIjoiM256anIyZ21lTG1JWU5iSHBwNHRnSW1DVE1hbDlvZUlIczl0d2NxcGNSTjRNU2V0ZXhtbkpyMXZqZXFTTHpmSSIsIm1hYyI6IjQ0ZTU1NzVjNjgyYjU4MDY0NmM1OWEyYTExYmFlNWE1MzA0MDA3ZWI2NjA1NDRlMzE1ZGUyYjEzYzViZDhhMTYiLCJ0YWciOiIifQ%3D%3D", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("data_session", "eyJpdiI6ImF1SFU5bWZoV3VwdDFscW1JS3F3U3c9PSIsInZhbHVlIjoiN2FqWnczUVFTM0tpMmNNTW9USTZHNFJ6S0Z0RFVTa1kvWi94Y3FsWjU1ZTlTMXJBbFR4T1Y0ZG56NmF6Vm9ZVkxuT2tPTkxyaHRtZnFva1ZPWjgvYlFaOVArS3FWY2hZRVJINFN2U0tnc2o0a1RPVU4xYlM4aGdTdytVNXJHelMiLCJtYWMiOiI0Y2IxNGUxNjkyYjQwN2Q0MjliNTM2MTdiNjgxOWY3MDg5ZjRjZDgyYzUxNzQxN2ZjN2RjNDJhNjUwNDAyNWFjIiwidGFnIjoiIn0%3D", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("laravel_token", "eyJpdiI6IjdzVHgxeDlpa0txYVBrZk5LeHdLZHc9PSIsInZhbHVlIjoiY25yRUs5SjdmeUJoamErNG8zNkJJMDJoUlFBditCZkZ5b2p1d0FqRW5HRXlyQjhnR0FuY3FMcjlyRXUyOGlEclFCV2gxbWJrZVNYZkhmRTBzU2JFKzdOOFp3WnBLNERGUFhycUk4bm9IN1BQNEVIeE40QzdhY2htT2hWSmRVbFBNUTluOUd1WHBtWnRNSDZZMmZxelVHVDFMZExRdk1iejN2TmE5MHFUTnpMQkJrcjhoU3RLc29vWnZjemI4NnRPMEpmSU0yQ2VCalpOQXdtUVhjRWF2NkpTQUNiYUlKVjNCcUFFcElVQ1FMTnhoWXp0a2FyYUY0eXZpa1lPcGNyd2xqM1RqYTE4VW1KVG1pdi9CU01aWnBjQVZLYVc0S3hJRHZCV0gwLyttSjhCQURQQ3FEMEJ3MDlMb09yd1VWRkUiLCJtYWMiOiI5Nzk3YmRlYjAyNjAzMDM5NWJjNDQzZThlNjBhNmNhYTE5YjY3Yzc4ZDRmMmIxNDIyMGIwMWY1MjIzMTQ1MzMzIiwidGFnIjoiIn0%3D", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("google2fa_token", "eyJpdiI6IkJiTG1qc21LRjlTYXJ5QVZ0SlVYbEE9PSIsInZhbHVlIjoiUzkvWnpWeEN2RC9uZDZDYzdLSWJ2ZFdnQ0dvZlJjRkVVaDRNOTRyWnp2YVpUYjZUcWJ1SWtrNTBXRzdLcXE4NyIsIm1hYyI6ImRiMmM2NzFkZGJjZTBmNzdiMDMyYThlZDdhMzkxYzhiZDMwMWNhM2U4YTFlYjMxN2IxZTcxZWQwM2I5ZTZiMjgiLCJ0YWciOiIifQ%3D%3D", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("XSRF-TOKEN", "eyJpdiI6IksxSE96dUhGWStzc0QxR1c2VFA2Y0E9PSIsInZhbHVlIjoiQjBiRitQVXcrL1J0QlhIcG1LQ0lJZ1ZQTTNrRFZmRzlkR1RHbGxQTytrUG9ZcU13eDM0QWpqV0RiV0tmbnBFTmFodVJOLzFnMWc5dmhEZ1JQNVo2MWJuQ3RWY2R1ZGZ4QUp1YkNNWm9sbnY4bnFJSXVWUTBsSVcrZFAzUkdpL1kiLCJtYWMiOiJkNjJkZjY0ZmE0MjQwNWVkNTI0ZjU3YWI4ZGNkOTg4YTkxMjJiN2E3ZmMxODNmZmU2M2VlYWNjZWI2OWI4M2M4IiwidGFnIjoiIn0%3D", "/", "192.168.1.11")))
$session.Cookies.Add((New-Object System.Net.Cookie("firefly_session", "eyJpdiI6IlZHR2FCTkQyTVZPbytYR3RyM3haNnc9PSIsInZhbHVlIjoiTlNjbmhlVXR0Zm03Q3FQc3lYelZmOE5UbGhNM25YZjkxZm5PUkFJODF6blhjQlpyTG5yR0RPRDBBZ0ZYbm5JTTJ5VCtaWjlaWkpLNHVNUllOa09jMzQyYXRLTVhJNTN5QldOa09Ua0tKNHB4VWJvL01WM0hCQ3VIdVFwdEh5NWgiLCJtYWMiOiI0OWU2YWEyNDQ4YzYzZWQ3MjgwNmFiNzI5MWQ3OTI0NDI3MDhkZDkwNjE0NGQ1YzVmNThhYzJhMDYxODQ1MTE2IiwidGFnIjoiIn0%3D", "/", "192.168.1.11")))
Invoke-WebRequest -UseBasicParsing -Uri "http://192.168.1.11:3334/api/v1/transactions?_token=mK1irzqWYUdWm85q2ISN5d2pykt3sEN3zwzzmcHd" `
-Method "POST" `
-WebSession $session `
-Headers @{
"Accept"="application/json, text/plain, */*"
  "Accept-Encoding"="gzip, deflate"
  "Accept-Language"="en-US,en"
  "DNT"="1"
  "Origin"="http://192.168.1.11:3334"
  "Sec-GPC"="1"
  "X-CSRF-TOKEN"="mK1irzqWYUdWm85q2ISN5d2pykt3sEN3zwzzmcHd"
  "X-Requested-With"="XMLHttpRequest"
  "X-XSRF-TOKEN"="eyJpdiI6IksxSE96dUhGWStzc0QxR1c2VFA2Y0E9PSIsInZhbHVlIjoiQjBiRitQVXcrL1J0QlhIcG1LQ0lJZ1ZQTTNrRFZmRzlkR1RHbGxQTytrUG9ZcU13eDM0QWpqV0RiV0tmbnBFTmFodVJOLzFnMWc5dmhEZ1JQNVo2MWJuQ3RWY2R1ZGZ4QUp1YkNNWm9sbnY4bnFJSXVWUTBsSVcrZFAzUkdpL1kiLCJtYWMiOiJkNjJkZjY0ZmE0MjQwNWVkNTI0ZjU3YWI4ZGNkOTg4YTkxMjJiN2E3ZmMxODNmZmU2M2VlYWNjZWI2OWI4M2M4IiwidGFnIjoiIn0="
} `
-ContentType "application/json" `
-Body "{`"apply_rules`":true,`"fire_webhooks`":true,`"transactions`":[{`"type`":`"deposit`",`"date`":`"2023-12-17T00:00`",`"amount`":`"500`",`"description`":`"Name: Nayrobiz Description: prive onttrekking IBAN: NL62INGB0007738534 Value date: 01/12/2022`",`"source_id`":`"1870`",`"source_name`":`"Nayrobiz`",`"destination_id`":`"680`",`"destination_name`":`"Hr IRD Luciano,Mw N Boom`",`"category_name`":`"`",`"interest_date`":`"`",`"book_date`":`"`",`"process_date`":`"`",`"due_date`":`"`",`"payment_date`":`"`",`"invoice_date`":`"`",`"internal_reference`":`"`",`"notes`":`"`",`"external_url`":`"`"}]}"

#>