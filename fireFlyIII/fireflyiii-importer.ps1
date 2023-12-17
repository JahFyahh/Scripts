Remove-Variable * -ErrorAction SilentlyContinue

#Home
$workingDir      = "$PSScriptRoot"
$csvFile         = "$($workingDir)\Ings_Alle_rekeningen.csv"
$skippedCsv      = "$($workingDir)\SkippedLines.csv"

$fireToken     = "mK1irzqWYUdWm85q2ISN5d2pykt3sEN3zwzzmcHd"
$accountId     = "d4faf223-7472-41e8-bb24-0ee72549d007"
$writeLine     = $false
$skipped       = 0
$retryAttempts = 3
$retryDelaySec = 5

# Specify the URL
$url = "http://http://192.168.1.11:3334/api/v1/transactions"

# Specify the headers
$headers = @{
    'accept'       = 'application/vnd.api+json'
    'Content-Type' = 'application/json'
}

try {
    #import file
    $import = Import-Csv $csvFile -Delimiter ";" -Encoding UTF8 

    # Initialize the progress bar
    Write-Progress -Activity "Processing Items" -Status "0% Complete" -PercentComplete 0

    Write-Output "Found $($import.Length) items to process"
    for($idx = 0; $idx -lt $import.Length; $idx++){
        try{
            $line         = $import[$idx]
            $date         = Get-Date ([datetime]::ParseExact($line.date, 'yyyyMMdd', $null)) `
                                -Format "yyyy-MM-ddTHH:mm"
            $description  = $line.Notifications
            $amount       = $line.'Amount (EUR)'.Replace(",",".")
            $tag          = @($line.Tag, $line.Code, $line.'Transaction type')
            $accountId    =

            # Switch statement based on account ID
            switch ($accountId) {
                "NL35INGB0002956047" { 
                    $accountNumber = 677
                }
                "NL42INGB0628505914" { 
                    $accountNumber = 680
                }
                Default {
                    # Handle other account IDs or provide a default value if needed
                    $accountNumber = -1
                }
            }

            if($line.'Debit/credit'.ToLower() -eq "credit") { 
                $type = "deposit"
            }
            elseif($line.'Debit/credit'.ToLower() -eq "debit") {  
                $type = "withdrawal" 
            }

            
            
            
            $destination_id = "680"
            $destination_name = "Hr IRD Luciano,Mw N Boom"
            $source_id = "1870"
            $source_name = "Nayrobiz"
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
}
catch {
    <#Do this if a terminating exception happens#>
}
finally {
    # Complete the progress bar
    Write-Progress -Activity "Processing Items" -Status "100% Complete" -PercentComplete 100 -Completed
}
    

# Specify the JSON payload
$jsonPayload = @{
    "error_if_duplicate_hash" = $true
    "apply_rules"             = $true
    "fire_webhooks"           = $true
    "group_title"             = "Split transaction title."
    "transactions"            = @(
        @{
            "type"                   = $type
            "date"                   = $date
            "amount"                 = $amount
            "description"            = $description
            "order"                  = 0
            "currency_id"            = "12"
            "currency_code"          = "EUR"
            "foreign_amount"         = "123.45"
            "foreign_currency_id"    = "17"
            "foreign_currency_code"  = "USD"
            "budget_id"              = "4"
            "category_id"            = "43"
            "category_name"          = "Groceries"
            "source_id"              = "2"
            "source_name"            = "Checking account"
            "destination_id"         = "2"
            "destination_name"       = "Buy and Large"
            "reconciled"             = $false
            "piggy_bank_id"          = 0
            "piggy_bank_name"        = "string"
            "bill_id"                = "112"
            "bill_name"              = "Monthly rent"
            "tags"                   = $null
            "notes"                  = "Some example notes"
            "internal_reference"     = "string"
            "external_id"            = "string"
            "external_url"           = "string"
            "bunq_payment_id"        = "string"
            "sepa_cc"                = "string"
            "sepa_ct_op"             = "string"
            "sepa_ct_id"             = "string"
            "sepa_db"                = "string"
            "sepa_country"           = "string"
            "sepa_ep"                = "string"
            "sepa_ci"                = "string"
            "sepa_batch_id"          = "string"
            "interest_date"          = "2023-12-17T14:29:17.067Z"
            "book_date"              = "2023-12-17T14:29:17.067Z"
            "process_date"           = "2023-12-17T14:29:17.067Z"
            "due_date"               = "2023-12-17T14:29:17.067Z"
            "payment_date"           = "2023-12-17T14:29:17.067Z"
            "invoice_date"           = "2023-12-17T14:29:17.067Z"
        }
    )
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