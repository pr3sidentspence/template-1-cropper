Param(
    [string]$colour = "rgb(55,60,56)"
)
New-Item -ItemType directory -Path $PSScriptRoot/temp1 -Force
New-Item -ItemType directory -Path $PSScriptRoot/temp2 -Force

function makeSmallGrey {
    Get-ChildItem $PSScriptRoot -Filter *.jpg | 
        Foreach-Object {
            magick $_ -resize 10% -fuzz 15% -fill $colour -opaque black temp1\$_
            findRotation
    }
}

function findRotation {
    $rotation = & magick temp1\$_ -background $colour -deskew 20% -print %[deskew:angle]\n null:
    Write-Host $rotation
    Write-Host magick $_ -rotate $rotation temp2\$_
    & magick $_ -rotate $rotation -verbose temp2\$_

}

makeSmallGrey
