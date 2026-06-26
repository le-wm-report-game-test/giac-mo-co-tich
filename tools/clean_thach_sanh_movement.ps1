Add-Type -AssemblyName System.Drawing

$sheetPath = Join-Path $PSScriptRoot "..\Assets\player\thach_sanh\thanh_sach_movement.png"
$sheetPath = [System.IO.Path]::GetFullPath($sheetPath)

$rowBounds = @(
    @(35, 134),
    @(167, 266),
    @(302, 401),
    @(434, 524),
    @(556, 646),
    @(679, 766),
    @(799, 887),
    @(922, 1009)
)

$idleStartX = 298
$idleWidth = 304
$idleFrames = 3
$walkStartX = 603
$walkWidth = 394
$walkFrames = 4

function Test-BackgroundLike {
    param(
        [System.Drawing.Color]$Color
    )

    if ($Color.A -eq 0) {
        return $true
    }

    $minChannel = [Math]::Min($Color.R, [Math]::Min($Color.G, $Color.B))
    $maxChannel = [Math]::Max($Color.R, [Math]::Max($Color.G, $Color.B))
    $spread = $maxChannel - $minChannel
    $brightness = ($Color.R + $Color.G + $Color.B) / 3.0

    return ($brightness -ge 105 -and $spread -le 55)
}

function Clear-FrameBackground {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Left,
        [int]$Top,
        [int]$Width,
        [int]$Height
    )

    for ($x = 0; $x -lt $Width; $x++) {
        for ($y = 0; $y -lt $Height; $y++) {
            $pixel = $Bitmap.GetPixel($Left + $X, $Top + $Y)
            if (-not (Test-BackgroundLike $pixel)) {
                continue
            }
            $Bitmap.SetPixel($Left + $X, $Top + $Y, [System.Drawing.Color]::FromArgb(0, $pixel.R, $pixel.G, $pixel.B))
        }
    }
}

function Process-Group {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$RowTop,
        [int]$RowBottom,
        [int]$StartX,
        [int]$TotalWidth,
        [int]$FrameCount
    )

    $frameWidth = [Math]::Floor($TotalWidth / $FrameCount)
    $rowHeight = $RowBottom - $RowTop + 1

    for ($frameIndex = 0; $frameIndex -lt $FrameCount; $frameIndex++) {
        $left = $StartX + ($frameIndex * $frameWidth)
        Clear-FrameBackground -Bitmap $Bitmap -Left $left -Top $RowTop -Width $frameWidth -Height $rowHeight
    }
}

$sourceBitmap = [System.Drawing.Bitmap]::new($sheetPath)
$bitmap = [System.Drawing.Bitmap]::new($sourceBitmap.Width, $sourceBitmap.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.DrawImage($sourceBitmap, 0, 0, $sourceBitmap.Width, $sourceBitmap.Height)
$graphics.Dispose()
$sourceBitmap.Dispose()

foreach ($row in $rowBounds) {
    Process-Group -Bitmap $bitmap -RowTop $row[0] -RowBottom $row[1] -StartX $idleStartX -TotalWidth $idleWidth -FrameCount $idleFrames
    Process-Group -Bitmap $bitmap -RowTop $row[0] -RowBottom $row[1] -StartX $walkStartX -TotalWidth $walkWidth -FrameCount $walkFrames
}

$outputPath = [System.IO.Path]::ChangeExtension($sheetPath, ".cleaned.png")
$bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()

Move-Item -LiteralPath $outputPath -Destination $sheetPath -Force

Write-Output "Cleaned movement sheet: $sheetPath"
