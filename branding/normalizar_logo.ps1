# Normaliza un logo: convierte en transparencia SOLO el fondo blanco exterior (blanco
# conectado con el borde de la imagen) y recorta el margen dejando un área libre uniforme.
# Los blancos internos (rodeados por el diseño) no se tocan. Los píxeles de suavizado del
# contorno se separan del blanco (alfa parcial) para no dejar halo.
#
# Uso: powershell -File branding/normalizar_logo.ps1 -Origen <png> -Destino <png> [-Margen 0.04]
param(
  [Parameter(Mandatory)] [string]$Origen,
  [Parameter(Mandatory)] [string]$Destino,
  # Área libre alrededor del logo, como fracción del lado mayor del contenido.
  [double]$Margen = 0.04,
  # Un píxel es «fondo» si su canal más oscuro es >= Umbral y es casi neutro.
  [int]$Umbral = 236
)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class NormalizadorLogo {
  public static string Procesar(string origen, string destino, double margen, int umbral) {
    Bitmap fuente = new Bitmap(origen);
    int w = fuente.Width, h = fuente.Height;
    Bitmap bmp = fuente.Clone(new Rectangle(0, 0, w, h), PixelFormat.Format32bppArgb);
    fuente.Dispose();
    BitmapData d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    byte[] px = new byte[d.Stride * h];
    Marshal.Copy(d.Scan0, px, 0, px.Length);
    int s = d.Stride;
    Func<int, int, int> idx = (x, y) => y * s + x * 4;   // B, G, R, A

    // Si la imagen ya trae transparencia real (esquinas transparentes), su blanco opaco es
    // parte del diseño (p. ej. el contorno del visto del logo TEC): solo se recorta.
    bool yaTransparente = px[idx(0, 0) + 3] < 16 && px[idx(w - 1, h - 1) + 3] < 16;
    Func<int, bool> esFondo = i => {
      byte b = px[i], g = px[i + 1], r = px[i + 2], a = px[i + 3];
      if (a < 16) return true;                          // ya transparente
      if (yaTransparente) return false;
      int min = Math.Min(r, Math.Min(g, b)), max = Math.Max(r, Math.Max(g, b));
      return min >= umbral && max - min <= 20;          // blanco casi neutro
    };

    // 1) Relleno desde los bordes: solo el blanco conectado con el exterior.
    bool[] fuera = new bool[w * h];
    Queue<int> cola = new Queue<int>();
    for (int x = 0; x < w; x++) { cola.Enqueue(x); cola.Enqueue((h - 1) * w + x); }
    for (int y = 0; y < h; y++) { cola.Enqueue(y * w); cola.Enqueue(y * w + w - 1); }
    while (cola.Count > 0) {
      int p = cola.Dequeue();
      if (fuera[p]) continue;
      int x = p % w, y = p / w;
      if (!esFondo(idx(x, y))) continue;
      fuera[p] = true;
      if (x > 0) cola.Enqueue(p - 1);
      if (x < w - 1) cola.Enqueue(p + 1);
      if (y > 0) cola.Enqueue(p - w);
      if (y < h - 1) cola.Enqueue(p + w);
    }
    int quitados = 0;
    for (int p = 0; p < w * h; p++) {
      if (!fuera[p]) continue;
      int i = idx(p % w, p / w);
      if (px[i + 3] >= 16) quitados++;                   // solo cuenta blanco realmente quitado
      px[i] = px[i + 1] = px[i + 2] = 0; px[i + 3] = 0;
    }

    // 2) Contorno: píxeles del logo que tocan el fondo eliminado. Si son mezcla con blanco
    //    (suavizado), se separan: alfa = cuánto se alejan del blanco; color sin el blanco.
    int suavizados = 0;
    byte[] copia = (byte[])px.Clone();
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
      int p = y * w + x;
      if (fuera[p]) continue;
      bool borde = false;
      for (int dy = -1; dy <= 1 && !borde; dy++) for (int dx = -1; dx <= 1; dx++) {
        int nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        if (fuera[ny * w + nx]) { borde = true; break; }
      }
      if (!borde) continue;
      int i = idx(x, y);
      int a0 = copia[i + 3];
      if (a0 < 255 || yaTransparente) continue;          // contorno con alfa propio: intacto
      int b = copia[i], g = copia[i + 1], r = copia[i + 2];
      int min = Math.Min(r, Math.Min(g, b));
      if (min < 200) continue;                           // color pleno del diseño: intacto
      // «Color a alfa» respecto al blanco: un píxel de mezcla (canal mínimo entre 200 y
      // 255) recibe alfa proporcional a cuánto se aleja del blanco.
      double alfa = Math.Min(1.0, (255.0 - min) / (255.0 - 200.0));
      if (alfa <= 0.02) { px[i] = px[i + 1] = px[i + 2] = 0; px[i + 3] = 0; suavizados++; continue; }
      Func<int, byte> sinBlanco = c => (byte)Math.Max(0, Math.Min(255, Math.Round((c - 255.0 * (1 - alfa)) / alfa)));
      px[i] = sinBlanco(b); px[i + 1] = sinBlanco(g); px[i + 2] = sinBlanco(r);
      px[i + 3] = (byte)Math.Round(alfa * 255); suavizados++;
    }
    Marshal.Copy(px, 0, d.Scan0, px.Length);
    bmp.UnlockBits(d);

    // 3) Recorte al contenido visible + margen uniforme.
    int minX = w, minY = h, maxX = -1, maxY = -1;
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
      if (px[idx(x, y) + 3] > 8) {
        if (x < minX) minX = x; if (x > maxX) maxX = x;
        if (y < minY) minY = y; if (y > maxY) maxY = y;
      }
    }
    int cw = maxX - minX + 1, ch = maxY - minY + 1;
    int m = (int)Math.Round(Math.Max(cw, ch) * margen);
    Bitmap salida = new Bitmap(cw + 2 * m, ch + 2 * m, PixelFormat.Format32bppArgb);
    using (Graphics gr = Graphics.FromImage(salida)) {
      gr.Clear(Color.Transparent);
      gr.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
      gr.DrawImage(bmp, new Rectangle(m, m, cw, ch), new Rectangle(minX, minY, cw, ch), GraphicsUnit.Pixel);
    }
    bmp.Dispose();
    salida.Save(destino, ImageFormat.Png);
    string r2 = String.Format("{0}x{1} -> {2}x{3} | fondo quitado: {4} px | contorno suavizado: {5} px | contenido {6}x{7} en ({8},{9}) | margen {10} px",
      w, h, salida.Width, salida.Height, quitados, suavizados, cw, ch, minX, minY, m);
    salida.Dispose();
    return r2;
  }
}
'@
$Origen = (Resolve-Path $Origen).Path
if (-not [System.IO.Path]::IsPathRooted($Destino)) { $Destino = Join-Path (Get-Location).Path $Destino }
[NormalizadorLogo]::Procesar($Origen, $Destino, $Margen, $Umbral)
