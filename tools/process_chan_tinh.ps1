Add-Type -AssemblyName System.Drawing

$drawingAssemblyPath = [System.Drawing.Bitmap].Assembly.Location

$csharpCode = @"
using System;
using System.Drawing;
using System.Collections.Generic;

public struct IntPoint {
    public int X;
    public int Y;
    public IntPoint(int x, int y) {
        X = x;
        Y = y;
    }
}

public class SpriteProcessor {
    public static void RemoveBackgroundFloodFill(Bitmap bmp) {
        int w = bmp.Width;
        int h = bmp.Height;
        byte[] visited = new byte[w * h];
        Queue<IntPoint> queue = new Queue<IntPoint>();

        bool IsBackgroundPixel(Color col) {
            if (col.A == 0) return true;
            int min = Math.Min(col.R, Math.Min(col.G, col.B));
            int max = Math.Max(col.R, Math.Max(col.G, col.B));
            int spread = max - min;
            return (min >= 220 && spread <= 12);
        }

        void Enqueue(int x, int y) {
            if (x < 0 || x >= w || y < 0 || y >= h) return;
            int idx = y * w + x;
            if (visited[idx] == 1) return;
            Color pixel = bmp.GetPixel(x, y);
            if (IsBackgroundPixel(pixel)) {
                visited[idx] = 1;
                queue.Enqueue(new IntPoint(x, y));
            }
        }

        // Add border pixels
        for (int x = 0; x < w; x++) {
            Enqueue(x, 0);
            Enqueue(x, h - 1);
        }
        for (int y = 0; y < h; y++) {
            Enqueue(0, y);
            Enqueue(w - 1, y);
        }

        while (queue.Count > 0) {
            IntPoint p = queue.Dequeue();
            Enqueue(p.X - 1, p.Y);
            Enqueue(p.X + 1, p.Y);
            Enqueue(p.X, p.Y - 1);
            Enqueue(p.X, p.Y + 1);
        }

        Color transparent = Color.FromArgb(0, 0, 0, 0);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int idx = y * w + x;
                if (visited[idx] == 1) {
                    bmp.SetPixel(x, y, transparent);
                }
            }
        }

        // Anti-halo second pass
        for (int y = 1; y < h - 1; y++) {
            for (int x = 1; x < w - 1; x++) {
                Color pixel = bmp.GetPixel(x, y);
                if (pixel.A > 0) {
                    bool hasTransparentNeighbor = false;
                    for (int dy = -1; dy <= 1; dy++) {
                        for (int dx = -1; dx <= 1; dx++) {
                            if (dx == 0 && dy == 0) continue;
                            if (bmp.GetPixel(x + dx, y + dy).A == 0) {
                                hasTransparentNeighbor = true;
                                break;
                            }
                        }
                        if (hasTransparentNeighbor) break;
                    }

                    if (hasTransparentNeighbor) {
                        int min = Math.Min(pixel.R, Math.Min(pixel.G, pixel.B));
                        int max = Math.Max(pixel.R, Math.Max(pixel.G, pixel.B));
                        int spread = max - min;
                        if (min >= 180 && spread <= 15) {
                            bmp.SetPixel(x, y, transparent);
                        }
                    }
                }
            }
        }
    }
}
"@

Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies $drawingAssemblyPath

$sheetsDir = "D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets"
$outputDir = "D:\openclaw\giac-mo-co-tich\Assets\enemies\chan_tinh\movement_frames"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$directions = @(
    "down",       # Row 0
    "down_left",  # Row 1
    "left",       # Row 2
    "up_left",    # Row 3
    "up",         # Row 4
    "up_right",   # Row 5
    "right",      # Row 6
    "down_right"  # Row 7
)

$sheets = @(
    @{ Name = "chan_tinh_idle_8dir_3frames.png"; Action = "idle"; Cols = 3; Rows = 8 },
    @{ Name = "chan_tinh_walk_8dir_8frames.png"; Action = "walk"; Cols = 8; Rows = 8 },
    @{ Name = "chan_tinh_attack_8dir_4frames.png"; Action = "attack"; Cols = 4; Rows = 8 },
    @{ Name = "chan_tinh_hurt_8dir_4frames.png"; Action = "hurt"; Cols = 4; Rows = 8 },
    @{ Name = "chan_tinh_die_8dir_4frames.png"; Action = "die"; Cols = 4; Rows = 8 }
)

foreach ($sheet in $sheets) {
    $sheetPath = Join-Path $sheetsDir $sheet.Name
    if (-not (Test-Path $sheetPath)) {
        Write-Warning "File not found: $sheetPath"
        continue
    }

    Write-Output "Processing sheet: $($sheet.Name)"
    $srcBmp = [System.Drawing.Bitmap]::new($sheetPath)
    $sheet_w = $srcBmp.Width
    $sheet_h = $srcBmp.Height

    $cols = $sheet.Cols
    $rows = $sheet.Rows
    $action = $sheet.Action

    $cell_w = $sheet_w / $cols
    $cell_h = $sheet_h / $rows

    for ($r = 0; $r -lt $rows; $r++) {
        $direction = $directions[$r]
        for ($c = 0; $c -lt $cols; $c++) {
            $x_start = [Math]::Round($c * $cell_w)
            $x_end = [Math]::Round(($c + 1) * $cell_w)
            $y_start = [Math]::Round($r * $cell_h)
            $y_end = [Math]::Round(($r + 1) * $cell_h)

            $w_actual = $x_end - $x_start
            $h_actual = $y_end - $y_start

            if ($w_actual -le 0 -or $h_actual -le 0) { continue }

            $cropRect = [System.Drawing.Rectangle]::new($x_start, $y_start, $w_actual, $h_actual)
            $cellBmp = $srcBmp.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

            # Use C# static method for flood fill
            [SpriteProcessor]::RemoveBackgroundFloodFill($cellBmp)

            $destBmp = [System.Drawing.Bitmap]::new(256, 256, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($destBmp)
            $g.Clear([System.Drawing.Color]::Transparent)

            $paste_x = [Math]::Floor((256 - $w_actual) / 2)
            $paste_y = 256 - $h_actual

            $srcRect = [System.Drawing.Rectangle]::new(0, 0, $w_actual, $h_actual)
            $destRect = [System.Drawing.Rectangle]::new($paste_x, $paste_y, $w_actual, $h_actual)
            $g.DrawImage($cellBmp, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)

            $outFileName = "$($direction)_$($action)_$($c).png"
            $outPath = Join-Path $outputDir $outFileName
            $destBmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

            $g.Dispose()
            $destBmp.Dispose()
            $cellBmp.Dispose()
        }
    }
    $srcBmp.Dispose()
    Write-Output "Finished $($sheet.Name). Generated $($rows * $cols) frames."
}

Write-Output "All sprite sheets processed successfully!"
