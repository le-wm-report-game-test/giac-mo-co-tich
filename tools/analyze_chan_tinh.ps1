Add-Type -AssemblyName System.Drawing

$sheetsDir = "D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets"
$files = Get-ChildItem -Path $sheetsDir -Filter *.png

foreach ($file in $files) {
    $bmp = [System.Drawing.Bitmap]::new($file.FullName)
    Write-Output "File: $($file.Name)"
    Write-Output "  Dimensions: $($bmp.Width) x $($bmp.Height)"
    
    $corners = @(
        @{ Name = "top-left"; x = 0; y = 0 },
        @{ Name = "top-right"; x = $bmp.Width - 1; y = 0 },
        @{ Name = "bottom-left"; x = 0; y = $bmp.Height - 1 },
        @{ Name = "bottom-right"; x = $bmp.Width - 1; y = $bmp.Height - 1 },
        @{ Name = "mid-top"; x = [Math]::Floor($bmp.Width / 2); y = 0 }
    )
    
    Write-Output "  Corner colors:"
    foreach ($c in $corners) {
        $pixel = $bmp.GetPixel($c.x, $c.y)
        Write-Output "    $($c.Name): R=$($pixel.R), G=$($pixel.G), B=$($pixel.B), A=$($pixel.A)"
    }
    
    $bmp.Dispose()
    Write-Output ""
}
