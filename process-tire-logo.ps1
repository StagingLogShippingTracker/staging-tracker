Add-Type -AssemblyName System.Drawing

$src = "C:\Users\Brice\Downloads\1783831058524.png"
$dst = "C:\Users\Brice\Downloads\brand\staging-shipping-tire-logo.png"
$tmp = "C:\Users\Brice\Downloads\brand\staging-shipping-tire-logo.tmp.png"

if (-not (Test-Path $src)) { throw "Source logo not found: $src" }
if (-not (Test-Path (Split-Path $dst))) { New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null }

function New-RgbaBitmap([int]$width, [int]$height) {
  return New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Color-Distance([System.Drawing.Color]$a, [System.Drawing.Color]$b) {
  return [Math]::Abs($a.R - $b.R) + [Math]::Abs($a.G - $b.G) + [Math]::Abs($a.B - $b.B)
}

function Remove-Background([System.Drawing.Bitmap]$bitmap, [int]$tolerance = 48) {
  $w = $bitmap.Width
  $h = $bitmap.Height
  $refs = @(
    $bitmap.GetPixel(0, 0),
    $bitmap.GetPixel($w - 1, 0),
    $bitmap.GetPixel(0, $h - 1),
    $bitmap.GetPixel($w - 1, $h - 1)
  )

  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $p = $bitmap.GetPixel($x, $y)
      foreach ($bg in $refs) {
        if ((Color-Distance $p $bg) -le $tolerance) {
          $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $p.R, $p.G, $p.B)) | Out-Null
          break
        }
      }
    }
  }
}

function Get-ContentBounds([System.Drawing.Bitmap]$bitmap) {
  $w = $bitmap.Width
  $h = $bitmap.Height
  $minX = $w; $minY = $h; $maxX = -1; $maxY = -1

  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      if ($bitmap.GetPixel($x, $y).A -gt 12) {
        if ($x -lt $minX) { $minX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }

  if ($maxX -lt 0) { throw "No visible logo content found after background removal." }
  return [PSCustomObject]@{ Left = $minX; Top = $minY; Right = $maxX; Bottom = $maxY }
}

function Crop-Bitmap([System.Drawing.Bitmap]$bitmap, $bounds) {
  $width = $bounds.Right - $bounds.Left + 1
  $height = $bounds.Bottom - $bounds.Top + 1
  $cropped = New-RgbaBitmap $width $height
  $g = [System.Drawing.Graphics]::FromImage($cropped)
  $g.DrawImage(
    $bitmap,
    (New-Object System.Drawing.Rectangle 0, 0, $width, $height),
    (New-Object System.Drawing.Rectangle $bounds.Left, $bounds.Top, $width, $height),
    [System.Drawing.GraphicsUnit]::Pixel
  )
  $g.Dispose()
  return $cropped
}

function Square-CenterBitmap([System.Drawing.Bitmap]$bitmap) {
  $w = $bitmap.Width
  $h = $bitmap.Height
  $size = [Math]::Max($w, $h)
  $square = New-RgbaBitmap $size $size
  $g = [System.Drawing.Graphics]::FromImage($square)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $offsetX = [int][Math]::Floor(($size - $w) / 2)
  $offsetY = [int][Math]::Floor(($size - $h) / 2)
  $g.DrawImage($bitmap, $offsetX, $offsetY, $w, $h)
  $g.Dispose()
  return $square
}

function Fit-UniformToSquare([System.Drawing.Bitmap]$bitmap, [int]$outputSize = 512) {
  $w = $bitmap.Width
  $h = $bitmap.Height
  $scale = [Math]::Min($outputSize / $w, $outputSize / $h)
  $drawW = [int][Math]::Round($w * $scale)
  $drawH = [int][Math]::Round($h * $scale)
  $square = New-RgbaBitmap $outputSize $outputSize
  $g = [System.Drawing.Graphics]::FromImage($square)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $offsetX = [int][Math]::Floor(($outputSize - $drawW) / 2)
  $offsetY = [int][Math]::Floor(($outputSize - $drawH) / 2)
  $g.DrawImage($bitmap, $offsetX, $offsetY, $drawW, $drawH)
  $g.Dispose()
  return $square
}

$source = [System.Drawing.Bitmap]::FromFile($src)
$rgba = New-RgbaBitmap $source.Width $source.Height
$graphics = [System.Drawing.Graphics]::FromImage($rgba)
$graphics.DrawImage($source, 0, 0, $source.Width, $source.Height)
$graphics.Dispose()
$source.Dispose()

Remove-Background $rgba 52

$bounds = Get-ContentBounds $rgba
$content = Crop-Bitmap $rgba $bounds
$rgba.Dispose()

$square = Fit-UniformToSquare $content 512
$content.Dispose()

$square.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
$square.Dispose()

Move-Item -Force $tmp $dst

$verify = [System.Drawing.Bitmap]::FromFile($dst)
Write-Output "Wrote $dst ($($verify.Width)x$($verify.Height))"
$verify.Dispose()
