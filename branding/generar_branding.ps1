# Genera las imágenes de icono y splash (branding/) desde el símbolo oficial
# assets/branding/logo_conpociiech.png. Uso, desde la raíz de la App:
#   powershell -File branding/generar_branding.ps1 -App .
# Luego: dart run flutter_launcher_icons ; dart run flutter_native_splash:create
param([string]$App = '.')
Add-Type -AssemblyName System.Drawing
# System.Drawing no conoce la ubicación de PowerShell: se usa la ruta absoluta.
$App = (Resolve-Path $App).Path

$simbolo = [System.Drawing.Bitmap]::FromFile("$App\assets\branding\logo_conpociiech.png")

# Lienzo cuadrado/rectangular con el símbolo centrado a un ancho dado.
function Componer([int]$ancho, [int]$alto, [int]$lado, [bool]$fondoBlanco, [string]$destino) {
  $lienzo = New-Object System.Drawing.Bitmap($ancho, $alto, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($lienzo)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  if ($fondoBlanco) { $g.Clear([System.Drawing.Color]::White) } else { $g.Clear([System.Drawing.Color]::Transparent) }
  # Mantiene la proporción del símbolo (466 x 463).
  $altoSimbolo = [int][Math]::Round($lado * $simbolo.Height / $simbolo.Width)
  $x = [int](($ancho - $lado) / 2); $y = [int](($alto - $altoSimbolo) / 2)
  $atributos = New-Object System.Drawing.Imaging.ImageAttributes
  $atributos.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)  # bordes sin halo
  $g.DrawImage($simbolo, (New-Object System.Drawing.Rectangle($x, $y, $lado, $altoSimbolo)),
    0, 0, $simbolo.Width, $simbolo.Height, [System.Drawing.GraphicsUnit]::Pixel, $atributos)
  $g.Dispose()
  $lienzo.Save($destino, [System.Drawing.Imaging.ImageFormat]::Png)
  $lienzo.Dispose()
  "{0}: {1}x{2}, simbolo {3}px" -f (Split-Path $destino -Leaf), $ancho, $alto, $lado
}

$b = "$App\branding"
# Icono clásico e iOS (sin transparencia): fondo blanco y margen del 12 %.
Componer 1024 1024 780 $true "$b\icono_conpociiech.png"
# Icono adaptativo Android 8+: el sistema recorta con su máscara; el símbolo queda dentro
# de la zona segura (66 de 108 dp, ~61 %).
Componer 1024 1024 600 $false "$b\icono_adaptativo_conpociiech.png"
# Splash (el generador lo trata como 4x): 1152 px = 288 dp; símbolo de 180 dp.
Componer 1152 1152 720 $false "$b\splash_conpociiech.png"
# Android 12+: icono dentro de un círculo de 2/3 del lienzo (640 px de 960).
Componer 960 960 560 $false "$b\splash_android12_conpociiech.png"
$simbolo.Dispose()
