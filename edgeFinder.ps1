
param (
    [string]$extension = "jpg",
    [float]$threshold = 0.1,
    [switch]$nodelete = $false,
    [switch]$nosource = $false,
    [switch]$help = $false,
    [string]$colour = "rgb(55,60,56)"
)

if ($help) {
    Write-Host No help for you!
    $host.exit
}

# Always need an output folder:
New-Item -ItemType directory -Path $PSScriptRoot/output -Force

if ($nosource) {
    $nodelete = $true
    Write-Host nosource switch set, skipping $extension files and using temp1 .txt files.
    Write-Host Skipping temp1 folder creation, because with nosource it must already exist.
    Write-Host "If you get errors that temp1\XYZ.txt cannot be found then temp1 .txt files do not exist"
    Write-Host and you need to run the script without the -nosource flag to create them.
}
else {
    Write-Host "Finding documents in scans in current folder with extension $extension."
    Write-Host "Creating temp1 folder."
    New-Item -ItemType directory -Path $PSScriptRoot/temp1 -Force
    New-Item -ItemType directory -Path $PSScriptRoot/temp2 -Force
    New-Item -ItemType directory -Path $PSScriptRoot/temp3 -Force
}
if ($nodelete) {
    Write-Host nodelete switch is true. Will not delete temp1 .txt files after use.
}
function rotator {
    $rotation = & magick temp1\$_ -background $colour -deskew 20% -print %[deskew:angle]\n null:
    Write-Host $rotation
    #Write-Host magick $_ -rotate $rotation temp2\$_
    & magick temp1\$_ -background "$colour" -rotate $rotation temp1\$_
    & magick $_ -background "$colour" -rotate $rotation temp2\$_
}
function cropper {
    # temp1late-1 top card (ID nums with remainder 2 when divided by 3) top left crop for 50px padding 47,61
    # temp1late-1 middle card (ID nums with remainder 1 when divided by 3) top left 26,104
    # temp1late-1 bottom card (ID nums with remainder 0 when divided by 3) top left 40,110
    $fileName = $gapInfo[0]
    Write-Host cropper thinks it`'s got a $gapInfo[1]
    if ($gapInfo[1] -match 'cols') {
        $padCorrect = 1.38
    }
    else {
        $padCorrect = 2.13
    }
    $gapPC1 = ([math]::Round((100 * $gapInfo[2] / $lineCounter), 2) - $padCorrect)
    $gapPC2 = ([math]::Round((100 * $gapInfo[4] / $lineCounter), 2) - $padCorrect)
    # Write-Host **********
    # Write-Host small $gapInfo[0] \t gap 1 is $gapInfo[1] lines long
    # Write-Host small $gapInfo[0] \t gap 1 is $gapPC1% of image long
    # Write-Host b i g $gapInfo[0] \t gap 1 is about (3600 * $gapInfo[1] / $lineCounter) lines long
    # Write-Host small $gapInfo[0] \t gap 2 is $gapInfo[3] lines long
    # Write-Host small $gapInfo[0] \t gap 2 is $gapPC2% of image long
    # Write-Host b i g $gapInfo[0] \t gap 2 is about (3600 * $gapInfo[3] / $lineCounter) lines long
    # Write-Host **********
    Write-Host The arraylist has $gapInfo.Count values.
    # The arraylist has one entry for the filename, and two for each gap, there is always 1 more
    # gap than there are cards. So starting with arraylist.Count (e.g. 9) take 1 off for the name (8)
    # and 2 off for the extra gap info (6), divide by two to get number of cards. 
    $numCards = ($gapInfo.Count - 4) / 2
    Write-Host That means the scan should have $numCards cards
    if ($numCards -le 1) {
        for ($i = 0; $i -lt (2 * $numCards); $i = $i + 2) {
            if ($gapInfo[1] -match 'cols') {
                [string]$bigFinale = ('temp2\{0}.jpg -chop {1}%x0 -gravity east -chop {2}%x0 temp3\{0}.jpg' -f $gapInfo[0], $gapPC1, $gapPC2)
            }
            else {
                [string]$bigFinale = ('temp3\{0}.jpg -chop 0x{1}% -gravity south -chop 0x{2}% output\{0}.jpg' -f $gapInfo[0], $gapPC1, $gapPC2)
            }
            cmd.exe /c "magick.exe $bigFinale" 
            if (!$nodelete) {
                #Remove-Item $PSScriptRoot\temp1\$fileName.txt
            }
            else {
                Write-Host Found more than one card, skipping. #for now, later try different standard deviations?
            }
        }
    }
}
function colDev {
    Get-ChildItem $PSScriptRoot -Filter *.$extension | 
        Foreach-Object {
        Write-Host ********************** Begin $_ ***************************
        $fName = $_.BaseName
        & magick $_ -resize 20% -fuzz 15% -fill $colour -opaque black temp1\$_
        rotator
        & magick temp1\$_ -gravity East -crop 1x +repage -format "%[fx:standard_deviation]\n" info: >$PSScriptRoot/temp1/$fName-cols.txt
        & magick temp1\$_ -gravity East -crop x1 +repage -format "%[fx:standard_deviation]\n" info: >$PSScriptRoot/temp1/$fName-rows.txt
        findGaps($fName)
        Write-Host ********************** End $_ ***************************
        
    }
}

function findGaps {
    foreach ($xy in ('cols', 'rows')) {
        Write-Host $xy
        [int]$j = 0 
        [int]$gapCount = 0
        [System.Collections.ArrayList]$gapInfo = @()
        $j = 0
        [int]$lineCounter = 0
        $gapCount = 0
        $gapInfo = @()
        $gapInfo += $_.BaseName
        $gapInfo += $xy
        $lines = [System.IO.File]::ReadLines( "$PSScriptRoot\temp1\$fName-$xy.txt" )
        foreach ( $line in $lines) {
            [float]$stDev = $line
            if ( $stDev -lt $threshold ) {
                $j++
            }
            elseif ($j -gt 9) {
                $gapCount++
                [int]$gapLength = (5 * $j)
                $gapEndLine = (5 * $lineCounter)
                $gapInfo += ($j, $lineCounter)
                $j = 0
            }
            else {
                $j = 0
            }
            $gapEndend = 0
            $lineCounter++
        }
        # last line is not recorded as a gap end because it probably does not have a high standard deviation
        # So we have to add the last line of the scan as a gap end.
        # We will assume it's a gap end and has a gapLength of at least 1.
        $gapEndend = 1
        $gapEndLine = (5 * $lineCounter)            
        $gapLength = (5 * $j)
        $gapInfo += ($j, $lineCounter)
        Write-Host findGaps thinks it`'s sending $gapInfo[1]
        cropper($gapInfo)
    }
}

    

if (!$nosource) {
    colDev
}
#findGaps

if (!$nodelete) {
    Remove-Item -path $PSScriptRoot\temp1 -recurse
}