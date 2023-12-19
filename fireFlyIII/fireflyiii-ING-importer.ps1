Remove-Variable * -ErrorAction SilentlyContinue

#region Variables
$workingDir     = "$PSScriptRoot"
$rekeningenFile = "$($workingDir)\Ings_Alle_rekeningen_01-01-2023_16-12-2023.csv"
$savingsFile    = "$($workingDir)\X59233900_01-01-2016_17-12-2023.csv"
$skippedCsv     = "$($workingDir)\fireFlySkippedLines.csv"

$url            = "http://192.168.1.11:3334/api/v1/"
$apiToken       = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIxOCIsImp0aSI6IjMzNThkMjM4MGEyYjJiMjVlNDQ5MGRlZGM1ZTYwZjA0NGU3MWU4OTNhMTYyOGYwNGYxYTg4ZTY4MDU2MzMwNjhhMTdmNjE5YTBjMjYyZTE5IiwiaWF0IjoxNzAyODQ4ODAzLjQ5MzgyLCJuYmYiOjE3MDI4NDg4MDMuNDkzODM0LCJleHAiOjE3MzQ0NzEyMDMuMzk3NTc2LCJzdWIiOiIxIiwic2NvcGVzIjpbXX0.ilPD09gFmszChrJ2c9bfCm9GDYju5FaxquWsBhAYqT131yZ5lUnHKfkXOm2r2ID4_XCxeQX6brzLS7T3zLRSarsqXj1HoKK255MOUd2R9AV3P4JEh6WAnl1PIMu6fBRa84qQ2LAuvYSR4Azlthqw1SZ6mrXw32zgSn1-Sowfcr9Htvblyexvv113rgOiMnuDBC-0emr1wKmIDNsPXLLWBenqHCAnEFSmnz1D6RFCG1ENz4TVbAX3dMpy_klh0J5OUkfEsjX_T2Zxiruigl0dmM_cco3YWh8Eof4vTgujHBRiGtdJMIONO21kYLz4rmrpzohDm6woyWS1oE4Yj8I76xFpdrqJVKi33RzwroY3v3qpeA8geokvN7HwjvZREF-gKG6vOBbPyWJy1BXExKJcB3w27y7Zqt321zeyingFYfzOpF-R1BdQ821ezJob3DBSYM1RwRSYNcIfKGj7wKdsizlLCUqti1bECAz-HDJjEeuZsqSeeSAqWY64RC6K0Tl7Z2rJAgRTec3K_Q7aeZ5uRDUPffk-8SurYWGx_b3_ZWPC2qGuSXIb5_d54jRiTMduaDKfGpN9cDHhBSJa5rfL1FDlRYmyU6FvmVRlT2F2yNLYc9-jSN2mn7Cb-_xh-IwlOCfNs6pEtLmxHw5JyjSUrVoQC1Jd92UY9g7JFaSsvaQ"
$skippedRek     = 0
$skippedSav     = 0
$runRekening    = $true
$runSavings     = $false
$headers        = @{
    'Authorization' = "Bearer $apiToken"
    'accept'         = 'application/vnd.api+json'
    'Content-Type'   = 'application/json'
}
#endregion Variables

#region functions
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
        "X 592-33900" { 
            return @(678, "Hr IRD Luciano savings account")
        }
        Default {
            # Handle other account IDs or provide a default value if needed
            return @("", $name)
        }
    }
}

function Rename-FileWith {
    param (
        [string]$FilePath,
        [string]$Append
    )

    # Check if the file path is provided
    if (-not $FilePath) {
        throw "File path is required."
    }

    # Check if the file exists
    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        Write-Host "Creating $FilePath" -ForegroundColor Yellow
        $null = New-Item $FilePath
    }

    # Get the file's base name and extension
    $directory = [System.IO.Path]::GetDirectoryName($FilePath)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $extension = [System.IO.Path]::GetExtension($FilePath)

    # Construct the new file name by appending "done"
    $newFileName = "${baseName}_$($Append)$($extension)"

    # Construct the new file path
    $newFilePath = Join-Path -Path $directory -ChildPath $newFileName

    # Rename the file
    Rename-Item -Path $FilePath -NewName $newFileName

    Write-Host "File renamed to: $newFilePath" -ForegroundColor Yellow

    return $newFilePath
}

function New-Transaction {
    param (
        [string]$type,
        [string]$date,
        [decimal]$amount,
        [string]$description,
        [string]$source_id,
        [string]$source_name,
        [string]$destination_id,
        [string]$destination_name,
        [string]$tag
    )
    try {
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
        Write-Host "http://192.168.1.11:3334/transactions/show/$($response.data.id)" -ForegroundColor Yellow 
    }
    catch {
        # Handle the error
        if ($null -ne $_.Exception.Response) {
            $errorDetails = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorDetails)
            $responseContent = $reader.ReadToEnd()
            #Write-Host -ForegroundColor Red "Validation Error Details: $responseContent"
        }
        $exceptDetails = $_
        #Write-Host -ForegroundColor Red "Error details: $_"

        throw "$($exceptDetails.Exception.Message) - $($responseContent)"
    }
    finally {
        <#Do this after the try block regardless of whether an exception occurred or not#>
    }
}
#endregion functions

#region rekeningen
if((Test-Path -Path $rekeningenFile -PathType Leaf) -and ($runRekening)){
    try {
        # Intro
        Write-Host -ForegroundColor Yellow "Importing rekeningen file: $(Split-Path -Path $rekeningenFile -Leaf)"
        
        # import file
        $rekeningImport = Import-Csv $rekeningenFile -Delimiter ";" -Encoding UTF8 

        # Created skipped file
        $newSkippedCsv = Rename-FileWith -FilePath $skippedCsv -Append "rekeningen_$(Get-Date -Format "yyyyMMddTHHmm")"

        # Initialize the progress bar
        Write-Progress -Activity "Processing rekeningen Items" -Status "0% Complete" -PercentComplete 0

        Write-Host "Found $($rekeningImport.Length) items to process" -ForegroundColor Yellow 
        for($idx = 0; $idx -lt $rekeningImport.Length; $idx++){
            try{
                $line         = $rekeningImport[$idx]
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

                if( $source_id -and $destination_id ) { $type = "transfer" }

                $transactionParams = @{
                    "type"               = $type
                    "date"               = $date
                    "amount"             = $amount
                    "description"        = $description
                    "source_id"          = $source_id
                    "source_name"        = $source_name
                    "destination_id"     = $destination_id
                    "destination_name"   = $destination_name
                    "tags"               = $tag
                }

                New-Transaction @transactionParams

            }
            catch{
                # Handle the error
                $exceptDetails = $_
                Write-Host -ForegroundColor Red "Rekeningen sub Error details: $_"

                # Added skipped/failed line to file
                $line | Add-Member -MemberType NoteProperty -Name "idx" -Value $idx -Force
                $line | Add-Member -MemberType NoteProperty -Name "psError" -Value $exceptDetails.Exception.Message -Force
                $line | Export-Csv -Path $newSkippedCsv -Append -NoTypeInformation -Delimiter ";"

                $skippedRek++
            }
            finally{
                Remove-Variable line, jsonPayload, destination_id, destination_name, source_id, source_name, type, exceptDetails, responseContent, `
                    date, amount, description, tag, response -ErrorAction SilentlyContinue

                # Update the progress bar
                $percentComplete = [math]::Round(($idx / $rekeningImport.Count) * 100, 2)
                Write-Progress -Activity "Processing rekeningen Items" -Status "$percentComplete% Complete" -PercentComplete $percentComplete -CurrentOperation "Processing Item $item"
            }
        }   
    }
    catch {
        $exceptDetails = $_
        Write-Host -ForegroundColor Red "Rekeningen Main catch Error details: $($Error[0])"
    }
    finally {
        # Complete the progress bar
        Write-Progress -Activity "Processing rekeningen Items" -Status "100% Complete" -PercentComplete 100 -Completed
        Write-Host "Done processing rekeningen" -ForegroundColor Green
        Write-Host "Skipped $($skippedRek) lines" -ForegroundColor Yellow
        Rename-FileWith -FilePath $rekeningenFile -Append "done"
    }
}
else{
    Write-Host "Either the given rekeningen file does not exist or this run is disabled" -ForegroundColor Yellow
}
#endregion rekeningen

#region Savings Accounts
if((Test-Path -Path $savingsFile -PathType Leaf) -and ($runSavings)){
    try {
        # Intro
        Write-Host -ForegroundColor Yellow "Importing savings file: $(Split-Path -Path $savingsFile -Leaf)"
        
        # import file
        $savingsImport = Import-Csv $savingsFile -Delimiter ";" -Encoding UTF8 

        # Create skipped file
        $newSkippedCsv = Rename-FileWith -FilePath $skippedCsv -Append "savings_$(Get-Date -Format "yyyyMMddTHHmm")"

        # Initialize the progress bar
        Write-Progress -Activity "Processing Savings Items" -Status "0% Complete" -PercentComplete 0

        Write-Host "Found $($savingsImport.Length) items to process" -ForegroundColor Yellow 
        for($idy = 0; $idy -lt $savingsImport.Length; $idy++){
            try{
                $line         = $savingsImport[$idy]
                $description  = $line.Description
                $amount       = $line.Amount.Replace(",",".")
                $tag          = @($line.Code,$line.'Transaction type',$line.Tag) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                $date         = Get-Date ([datetime]::ParseExact($line.date, 'yyyy-MM-dd', $null)) `
                                    -Format "yyyy-MM-ddTHH:mm"

                if($line.'Debit/credit'.ToLower() -eq "credit") { 
                    $type             = "deposit"
                    $source_id        = (get-accountId -account $line.Counterparty -name "ING BANK N.V.")[0]
                    $source_name      = (get-accountId -account $line.Counterparty -name "ING BANK N.V.")[1]
                    $destination_id   = (get-accountId -account $line.Account -name "ING BANK N.V.")[0]
                    $destination_name = (get-accountId -account $line.Account -name "ING BANK N.V.")[1]
                }
                elseif($line.'Debit/credit'.ToLower() -eq "debit") {  
                    $type             = "withdrawal"
                    $source_id        = (get-accountId -account $line.Account -name "ING BANK N.V.")[0]
                    $source_name      = (get-accountId -account $line.Account -name "ING BANK N.V.")[1]
                    $destination_id   = (get-accountId -account $line.Counterparty -name "ING BANK N.V.")[0]
                    $destination_name = (get-accountId -account $line.Counterparty -name "ING BANK N.V.")[1]
                }

                if(-not[string]::IsNullOrEmpty($source_id)){ $type = "transfer" }

                $transactionParams = @{
                    "type"               = $type
                    "date"               = $date
                    "amount"             = $amount
                    "description"        = $description
                    "source_id"          = $source_id
                    "source_name"        = $source_name
                    "destination_id"     = $destination_id
                    "destination_name"   = $destination_name
                    "tags"               = $tag
                }

                New-Transaction @transactionParams

            }
            catch{
                # Handle the error
                $exceptDetails = $_
                Write-Host -ForegroundColor Red "Savings Sub catch Error details: $_"

                # Added skipped/failed line to file
                $line | Add-Member -MemberType NoteProperty -Name "idy" -Value $idy -Force
                $line | Add-Member -MemberType NoteProperty -Name "psError" -Value $exceptDetails.Exception.Message -Force
                $line | Export-Csv -Path $newSkippedCsv -Append -NoTypeInformation -Delimiter ";"

                $skippedSav++
            }
            finally{
                Remove-Variable line, jsonPayload, destination_id, destination_name, source_id, source_name, type, exceptDetails, responseContent, `
                    date, amount, description, tag, response -ErrorAction SilentlyContinue

                # Update the progress bar
                $percentComplete = [math]::Round(($idy / $savingsImport.Count) * 100, 2)
                Write-Progress -Activity "Processing Savings Items" -Status "$percentComplete% Complete" -PercentComplete $percentComplete -CurrentOperation "Processing Item $item"
            }
        }
    }
    catch {
        $exceptDetails = $_
        Write-Host -ForegroundColor Red "Savings Main catch Error details: $_"
    }
    finally {
        # Complete the progress bar
        Write-Progress -Activity "Processing Savings Items" -Status "100% Complete" -PercentComplete 100 -Completed
        Write-Host "Done processing savings" -ForegroundColor Green
        Write-Host "Skipped $($SkippedSav) lines" -ForegroundColor Yellow
        Rename-FileWithDone -FilePath $savingsFile
    }
}
else{
    Write-Host "Either the given savings file does not exist or this run is disabled" -ForegroundColor Yellow
}
#endregion Savings Accounts

Write-Host "Done" -ForegroundColor Green
