Add-Type -AssemblyName System.Drawing

$sheetPath = Join-Path $PSScriptRoot "..\Assets\player\thach_sanh\thanh_sach_movement.png"
$sheetPath = [System.IO.Path]::GetFullPath($sheetPath)
$outputDir = Join-Path $PSScriptRoot "..\Assets\player\thach_sanh\movement_frames"
$outputDir = [System.IO.Path]::GetFullPath($outputDir)
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$rows = @(
    @{ Name = "down"; y = 35; height = 100 },
    @{ Name = "up"; y = 167; height = 100 },
    @{ Name = "right"; y = 302; height = 100 },
    @{ Name = "left"; y = 434; height = 91 },
    @{ Name = "down_right"; y = 556; height = 91 },
    @{ Name = "down_left"; y = 679; height = 88 },
    @{ Name = "up_right"; y = 799; height = 89 },
    @{ Name = "up_left"; y = 922; height = 88 }
)

$groups = @(
    @{ Name = "idle"; startX = 298; width = 304; frames = 3 },
    @{ Name = "walk"; startX = 603; width = 394; frames = 4 }
)

function Copy-ToArgbBitmap {
    param([string]$Path)
    $sourceBitmap = [System.Drawing.Bitmap]::new($Path)
    $bitmap = [System.Drawing.Bitmap]::new($sourceBitmap.Width, $sourceBitmap.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.DrawImage($sourceBitmap, 0, 0, $sourceBitmap.Width, $sourceBitmap.Height)
    $graphics.Dispose()
    $sourceBitmap.Dispose()
    return $bitmap
}

function Get-AlphaBounds {
    param([System.Drawing.Bitmap]$Bitmap)

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x, $y)
            if ($pixel.A -le 0) {
                continue
            }
            if (Test-IsLikelyBackdropPixel -Pixel $pixel) {
                continue
            }
            if ($x -lt $minX) { $minX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }

    if ($maxX -lt 0 -or $maxY -lt 0) {
        return $null
    }

    return @{
        x = $minX
        y = $minY
        width = $maxX - $minX + 1
        height = $maxY - $minY + 1
    }
}

function Test-IsLikelyBackdropPixel {
    param([System.Drawing.Color]$Pixel)

    if ($Pixel.A -le 0) {
        return $false
    }

    $rg = [Math]::Abs([int]$Pixel.R - [int]$Pixel.G)
    $gb = [Math]::Abs([int]$Pixel.G - [int]$Pixel.B)
    $rb = [Math]::Abs([int]$Pixel.R - [int]$Pixel.B)
    $maxChannel = [Math]::Max([int]$Pixel.R, [Math]::Max([int]$Pixel.G, [int]$Pixel.B))
    $minChannel = [Math]::Min([int]$Pixel.R, [Math]::Min([int]$Pixel.G, [int]$Pixel.B))

    return $rg -le 14 -and $gb -le 14 -and $rb -le 14 -and $maxChannel -ge 72 -and ($maxChannel - $minChannel) -le 16
}

function Remove-BackdropFringe {
    param([System.Drawing.Bitmap]$Bitmap)

    $width = $Bitmap.Width
    $height = $Bitmap.Height
    $transparent = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    $changed = $true

    while ($changed) {
        $changed = $false

        for ($x = 0; $x -lt $width; $x++) {
            foreach ($y in @(0, ($height - 1))) {
                if (Test-IsLikelyBackdropPixel -Pixel ($Bitmap.GetPixel($x, $y))) {
                    $Bitmap.SetPixel($x, $y, $transparent)
                    $changed = $true
                }
            }
        }

        for ($y = 1; $y -lt ($height - 1); $y++) {
            foreach ($x in @(0, ($width - 1))) {
                if (Test-IsLikelyBackdropPixel -Pixel ($Bitmap.GetPixel($x, $y))) {
                    $Bitmap.SetPixel($x, $y, $transparent)
                    $changed = $true
                }
            }
        }

        if (-not $changed) {
            break
        }
    }
}

$sheet = Copy-ToArgbBitmap -Path $sheetPath

foreach ($row in $rows) {
    foreach ($group in $groups) {
        $frameWidth = [Math]::Floor($group.width / $group.frames)
        for ($frameIndex = 0; $frameIndex -lt $group.frames; $frameIndex++) {
            $left = $group.startX + ($frameIndex * $frameWidth)
            $top = $row.y
            $frameRect = [System.Drawing.Rectangle]::new($left, $top, $frameWidth, $row.height)
            $workingBitmap = $sheet.Clone($frameRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

            for ($pass = 0; $pass -lt 3; $pass++) {
                Remove-BackdropFringe -Bitmap $workingBitmap

                $bounds = Get-AlphaBounds -Bitmap $workingBitmap
                if ($null -eq $bounds) {
                    break
                }

                $cropRect = [System.Drawing.Rectangle]::new($bounds.x, $bounds.y, $bounds.width, $bounds.height)
                $nextBitmap = $workingBitmap.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
                $workingBitmap.Dispose()
                $workingBitmap = $nextBitmap
            }

            if ($null -eq $workingBitmap) {
                continue
            }

            $fileName = "{0}_{1}_{2}.png" -f $row.Name, $group.Name, $frameIndex
            $outputPath = Join-Path $outputDir $fileName
            $workingBitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $workingBitmap.Dispose()
        }
    }
}

$sheet.Dispose()
Write-Output "Extracted cropped movement frames to: $outputDir"
