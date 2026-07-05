$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$src = 'assets/images/logo.png'
if (-not (Test-Path $src)) { Write-Error "Source not found: $src"; exit 1 }
$sizes = @(16,24,32,48,64,128,256)
$tempDir = "tooling\ico_parts"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }
$parts = @()

foreach ($s in $sizes) {
    $bmp = [System.Drawing.Bitmap]::FromFile($src)
    $resized = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($resized)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($bmp, 0, 0, $s, $s)
    $g.Dispose()
    $bmp.Dispose()

    $h = $resized.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($h)
    $tmp = Join-Path $tempDir ("part_$s.ico")
    $fs = [System.IO.File]::Open($tmp, [System.IO.FileMode]::Create)
    $icon.Save($fs)
    $fs.Close()
    $icon.Dispose()
    [System.Runtime.InteropServices.Marshal]::Release($h) | Out-Null
    $resized.Dispose()
    $parts += $tmp
}

# Merge ICO parts (each part is a 1-entry ICO)
$outPath = 'windows\runner\resources\app_icon.ico'
if (-not (Test-Path (Split-Path $outPath))) { New-Item -ItemType Directory -Path (Split-Path $outPath) | Out-Null }
$outs = New-Object System.IO.FileStream $outPath, ([System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter $outs

# ICONDIR header
$bw.Write([byte]0) # reserved
$bw.Write([byte]0)
$bw.Write([byte]1) # type
$bw.Write([byte]0)
$bw.Write([byte]($parts.Count % 256)) # count low
$bw.Write([byte]([int]($parts.Count / 256))) # count high (rarely used)

# placeholder for directory entries
$entryOffset = 6
$dirSize = 16 * $parts.Count
$currentImageOffset = $entryOffset + $dirSize
$imageDatas = @()

foreach ($p in $parts) {
    $bytes = [System.IO.File]::ReadAllBytes($p)
    # parse the single-entry ICO to extract its ICONDIRENTRY and image bytes
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $br = New-Object System.IO.BinaryReader($ms)
    $reserved = $br.ReadUInt16()
    $type = $br.ReadUInt16()
    $count = $br.ReadUInt16()
    if ($count -ne 1) { Write-Error ("Unexpected count in part {0}: {1}" -f $p, $count); exit 1 }
    # read entry
    $b = $br.ReadBytes(16)
    # width = b[0], height = b[1], colorcount b[2], reserved b[3]
    $width = $b[0]
    $height = $b[1]
    $colorCount = $b[2]
    $planes = [BitConverter]::ToUInt16($b,4)
    $bitCount = [BitConverter]::ToUInt16($b,6)
    $bytesInRes = [BitConverter]::ToInt32($b,8)
    $imgOffset = [BitConverter]::ToInt32($b,12)
    # image data bytes
    $ms.Seek($imgOffset, 'Begin') | Out-Null
    $imgData = $br.ReadBytes($bytesInRes)
    $imageDatas += @{ width=$width; height=$height; colorCount=$colorCount; planes=$planes; bitCount=$bitCount; bytesInRes=$bytesInRes; data=$imgData }
    $br.Close()
    $ms.Close()
}

# write directory entries now
foreach ($entry in $imageDatas) {
    # width and height 0 means 256
    $w = $entry.width
    $h = $entry.height
    $bw.Write([byte]$w)
    $bw.Write([byte]$h)
    $bw.Write([byte]$entry.colorCount)
    $bw.Write([byte]0) # reserved
    $bw.Write([uint16]$entry.planes)
    $bw.Write([uint16]$entry.bitCount)
    $bw.Write([int]$entry.data.Length)
    $bw.Write([int]$currentImageOffset)
    $currentImageOffset += $entry.data.Length
}

# write image data
foreach ($entry in $imageDatas) {
    $bw.Write($entry.data)
}

$bw.Flush()
$bw.Close()
$outs.Close()

Write-Output "Generated multi-size ICO: $outPath"

# cleanup temp
Remove-Item $tempDir -Recurse -Force
