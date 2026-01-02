# --- Configuration ---
$apiKey = "YOUR_ACOUSTID_API_KEY" # Get one at https://acoustid.org/applications
$musicFolder = "C:\Path\To\Your\Music"
$secondsBetweenRequests = 1 # Recommended delay to be a "good citizen"

if ($apiKey -eq "YOUR_ACOUSTID_API_KEY") {
    Write-Error "Please set your AcoustID API Key in the script."
    return
}

$files = Get-ChildItem -Path $musicFolder -Filter *.mp3

foreach ($file in $files) {
    Write-Host "`n--- Processing: $($file.Name) ---" -ForegroundColor Cyan

    # 1. Get Fingerprint and Duration
    $fpData = & fpcalc -json "$($file.FullName)" | ConvertFrom-Json
    
    if (-not $fpData.fingerprint) {
        Write-Warning "Could not generate fingerprint for $($file.Name). Skipping."
        continue
    }

    # 2. Query AcoustID API using curl.exe
    $apiUrl = "https://api.acoustid.org/v2/lookup"
    $response = curl.exe -s -G $apiUrl `
        --data-urlencode "client=$apiKey" `
        --data-urlencode "meta=recordings" `
        --data-urlencode "duration=$($fpData.duration)" `
        --data-urlencode "fingerprint=$($fpData.fingerprint)"

    $jsonResponse = $response | ConvertFrom-Json

    # 3. Extract Metadata and Write with FFmpeg
    if ($jsonResponse.status -eq "ok" -and $jsonResponse.results.Count -gt 0) {
        $bestMatch = $jsonResponse.results[0].recordings[0]
        $title = $bestMatch.title
        $artist = $bestMatch.artists[0].name

        Write-Host "Match Found: $artist - $title" -ForegroundColor Green

        $tempFile = "$($file.DirectoryName)\temp_$($file.Name)"
        
        # -y overwrites temp file if it exists, -map_metadata 0 preserves other existing tags
        & ffmpeg -y -i "$($file.FullName)" `
                 -metadata title="$title" `
                 -metadata artist="$artist" `
                 -codec copy -loglevel error "$tempFile"

        if (Test-Path $tempFile) {
            Remove-Item "$($file.FullName)"
            Rename-Item -Path $tempFile -NewName "$($file.Name)"
        }
    } else {
        Write-Warning "No match found in AcoustID database."
    }

    # 4. Sleep to respect API rate limits
    Write-Host "Waiting $secondsBetweenRequests second(s)..." -ForegroundColor DarkGray
    Start-Sleep -Seconds $secondsBetweenRequests
}

Write-Host "`nProcessing Complete!" -ForegroundColor Yellow
