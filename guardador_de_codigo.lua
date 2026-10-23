require "import"

import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.os.Environment"
import "android.graphics.*"
import "android.graphics.pdf.PdfDocument"
import "java.io.*"
import "com.androlua.LuaDialog"

local ctx = service

-- ===== CARPETA PRINCIPAL =====
local rutaBase = tostring(Environment.getExternalStorageDirectory())
  .. "/Documents/Jieshuo_Guardador/"

local dir = File(rutaBase)
if not dir.exists() then
  dir.mkdirs()
end

-- ===== FUNCIONES DE GUARDADO =====

local function guardarPDF(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  local pdf = PdfDocument()
  local paint = Paint()
  paint.setTextSize(12)
  paint.setColor(0xFF000000)

  local ancho, alto = 595, 842
  local margen = 40
  local x = margen
  local y = margen
  local lineHeight = 18
  local pagina = 1

  local info = PdfDocument.PageInfo.Builder(ancho, alto, pagina).create()
  local page = pdf.startPage(info)
  local canvas = page.getCanvas()

  for linea in texto:gmatch("[^\n]+") do
    if y > alto - margen then
      pdf.finishPage(page)
      pagina = pagina + 1
      info = PdfDocument.PageInfo.Builder(ancho, alto, pagina).create()
      page = pdf.startPage(info)
      canvas = page.getCanvas()
      y = margen
    end

    canvas.drawText(linea, x, y, paint)
    y = y + lineHeight
  end

  if y > margen then
    pdf.finishPage(page)
  end

  local archivo = File(rutaBase .. nombre .. ".pdf")
  local ok = pcall(function()
    local fos = FileOutputStream(archivo)
    pdf.writeTo(fos)
    fos.close()
    pdf.close()
  end)

  if ok then
    return true, "PDF guardado en: " .. rutaBase
  else
    return false, "Error al crear PDF"
  end
end

local function guardarTXT(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  local archivo = File(rutaBase .. nombre .. ".txt")
  local ok = pcall(function()
    local writer = FileWriter(archivo)
    writer.write(texto)
    writer.close()
  end)

  if ok then
    return true, "TXT guardado en: " .. rutaBase
  else
    return false, "Error al crear TXT"
  end
end

local function guardarHTML(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  local htmlContent = [[<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>]] .. nombre .. [[</title>
  <style>
    body {
      font-family: 'Courier New', monospace;
      background-color: #1e1e1e;
      color: #d4d4d4;
      padding: 20px;
      line-height: 1.6;
      max-width: 1200px;
      margin: 0 auto;
    }
    pre {
      background-color: #252526;
      border: 1px solid #3e3e42;
      border-radius: 4px;
      padding: 15px;
      overflow-x: auto;
    }
    code {
      font-family: 'Courier New', monospace;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <h1>]] .. nombre .. [[</h1>
  <pre><code>]] .. tostring(texto):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;") .. [[</code></pre>
</body>
</html>]]

  local archivo = File(rutaBase .. nombre .. ".html")
  local ok = pcall(function()
    local writer = FileWriter(archivo)
    writer.write(htmlContent)
    writer.close()
  end)

  if ok then
    return true, "HTML guardado en: " .. rutaBase
  else
    return false, "Error al crear HTML"
  end
end

local function guardarMD(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  local mdContent = "# " .. nombre .. "\n\n```\n" .. texto .. "\n```\n"

  local archivo = File(rutaBase .. nombre .. ".md")
  local ok = pcall(function()
    local writer = FileWriter(archivo)
    writer.write(mdContent)
    writer.close()
  end)

  if ok then
    return true, "Markdown guardado en: " .. rutaBase
  else
    return false, "Error al crear Markdown"
  end
end

local function guardarJSON(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  -- Limpiar extensiones duplicadas si el usuario las escribe por error
  nombre = nombre:gsub("%.json$", ""):gsub("%.js$", "")

  local archivo = File(rutaBase .. nombre .. ".json")
  local ok, err = pcall(function()
    local writer = FileWriter(archivo)
    writer.write(texto)
    writer.close()
  end)

  if ok then
    return true, "JSON guardado en: " .. rutaBase
  else
    return false, "Error al crear JSON: " .. tostring(err)
  end
end

local function guardarJS(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  nombre = nombre:gsub("%.js$", "")

  local archivo = File(rutaBase .. nombre .. ".js")
  local ok = pcall(function()
    local writer = FileWriter(archivo)
    writer.write(texto)
    writer.close()
  end)

  if ok then
    return true, "JavaScript guardado en: " .. rutaBase
  else
    return false, "Error al crear JS"
  end
end

local function guardarCSS(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  nombre = nombre:gsub("%.css$", "")

  local archivo = File(rutaBase .. nombre .. ".css")
  local ok = pcall(function()
    local writer = FileWriter(archivo)
    writer.write(texto)
    writer.close()
  end)

  if ok then
    return true, "CSS guardado en: " .. rutaBase
  else
    return false, "Error al crear CSS"
  end
end

local function guardarXML(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  nombre = nombre:gsub("%.xml$", "")

  local archivo = File(rutaBase .. nombre .. ".xml")
  local ok = pcall(function()
    local writer = FileWriter(archivo)
    writer.write(texto)
    writer.close()
  end)

  if ok then
    return true, "XML guardado en: " .. rutaBase
  else
    return false, "Error al crear XML"
  end
end

local function guardarPY(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  nombre = nombre:gsub("%.py$", "")

  local archivo = File(rutaBase .. nombre .. ".py")
  local ok = pcall(function()
    local writer = FileWriter(archivo)
    writer.write(texto)
    writer.close()
  end)

  if ok then
    return true, "Python guardado en: " .. rutaBase
  else
    return false, "Error al crear PY"
  end
end

local function guardarLUA(texto, nombre)
  if texto == "" or nombre == "" then
    return false, "Faltan datos"
  end

  nombre = nombre:gsub("%.lua$", "")

  local archivo = File(rutaBase .. nombre .. ".lua")
  local ok = pcall(function()
    local writer = FileWriter(archivo)
    writer.write(texto)
    writer.close()
  end)

  if ok then
    return true, "Lua guardado en: " .. rutaBase
  else
    return false, "Error al crear LUA"
  end
end

-- ===== DIÁLOGO DE SELECCIÓN DE FORMATO =====

local function mostrarSelectorFormato(nombre, texto, dlgPrincipal)
  if nombre == "" or texto == "" then
    service.speak("Completa nombre y código primero")
    return
  end

  local dlg = LuaDialog(ctx)
  dlg.setTitle("Guardar como:")
  
  local scroll = ScrollView(ctx)
  scroll.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    800))

  local layout = LinearLayout(ctx)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(40, 20, 40, 20)
  scroll.addView(layout)

  local formatos = {
    {etiqueta = "PDF", funcion = guardarPDF},
    {etiqueta = "TXT (Texto plano)", funcion = guardarTXT},
    {etiqueta = "HTML", funcion = guardarHTML},
    {etiqueta = "Markdown", funcion = guardarMD},
    {etiqueta = "JSON", funcion = guardarJSON},
    {etiqueta = "JavaScript (.js)", funcion = guardarJS},
    {etiqueta = "CSS (.css)", funcion = guardarCSS},
    {etiqueta = "XML (.xml)", funcion = guardarXML},
    {etiqueta = "Python (.py)", funcion = guardarPY},
    {etiqueta = "Lua (.lua)", funcion = guardarLUA}
  }

  for _, fmt in ipairs(formatos) do
    local btn = Button(ctx)
    btn.setText(fmt.etiqueta)
    btn.setLayoutParams(LinearLayout.LayoutParams(
      LinearLayout.LayoutParams.MATCH_PARENT,
      LinearLayout.LayoutParams.WRAP_CONTENT))
    btn.setPadding(0, 15, 0, 15)

    btn.onClick = function()
      local exito, msg = fmt.funcion(texto, nombre)
      if exito then
        service.speak(msg)
        dlg.dismiss()
        dlgPrincipal.dismiss()
      else
        service.speak("Error: " .. msg)
      end
    end

    layout.addView(btn)
  end

  local btnCancelar = Button(ctx)
  btnCancelar.setText("Cancelar")
  btnCancelar.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    LinearLayout.LayoutParams.WRAP_CONTENT))
  btnCancelar.setPadding(0, 15, 0, 15)
  btnCancelar.setBackgroundColor(0xFF9E9E9E)
  btnCancelar.setTextColor(0xFFFFFFFF)
  btnCancelar.onClick = function() dlg.dismiss() end

  layout.addView(btnCancelar)
  dlg.setView(scroll)
  dlg.show()
end

-- ===== INTERFAZ PRINCIPAL =====

function mostrarInterfaz()
  local dlg = LuaDialog(ctx)
  dlg.setTitle("Guardador de Código")

  local layoutPrincipal = LinearLayout(ctx)
  layoutPrincipal.setOrientation(LinearLayout.VERTICAL)
  layoutPrincipal.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    LinearLayout.LayoutParams.MATCH_PARENT))

  local scroll = ScrollView(ctx)
  scroll.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    0,
    1))

  local layoutContenido = LinearLayout(ctx)
  layoutContenido.setOrientation(LinearLayout.VERTICAL)
  layoutContenido.setPadding(20, 20, 20, 20)
  scroll.addView(layoutContenido)

  local lblNombre = TextView(ctx)
  lblNombre.setText("Nombre del archivo:")
  lblNombre.setTextSize(14)
  layoutContenido.addView(lblNombre)

  local edtNombre = EditText(ctx)
  edtNombre.setHint("Escribe el nombre (sin extensión)")
  edtNombre.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    LinearLayout.LayoutParams.WRAP_CONTENT))
  layoutContenido.addView(edtNombre)

  local espacio1 = TextView(ctx)
  espacio1.setText("")
  espacio1.setHeight(10)
  layoutContenido.addView(espacio1)

  local lblCodigo = TextView(ctx)
  lblCodigo.setText("Pega aquí tu código:")
  lblCodigo.setTextSize(14)
  layoutContenido.addView(lblCodigo)

  local edtTexto = EditText(ctx)
  edtTexto.setHint("Código, texto, o lo que necesites guardar")
  edtTexto.setMinLines(10)
  edtTexto.setGravity(Gravity.TOP + Gravity.LEFT)
  edtTexto.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    LinearLayout.LayoutParams.WRAP_CONTENT))
  layoutContenido.addView(edtTexto)

  local espacio2 = TextView(ctx)
  espacio2.setText("")
  espacio2.setHeight(20)
  layoutContenido.addView(espacio2)

  layoutPrincipal.addView(scroll)

  local separator = View(ctx)
  separator.setBackgroundColor(0xFFCCCCCC)
  separator.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    2))
  layoutPrincipal.addView(separator)

  local layoutBotones = LinearLayout(ctx)
  layoutBotones.setOrientation(LinearLayout.HORIZONTAL)
  layoutBotones.setPadding(10, 10, 10, 10)
  layoutBotones.setGravity(Gravity.RIGHT)
  layoutBotones.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    LinearLayout.LayoutParams.WRAP_CONTENT))

  local btnGuardar = Button(ctx)
  btnGuardar.setText("Guardar")
  btnGuardar.setBackgroundColor(0xFF4CAF50)
  btnGuardar.setTextColor(0xFFFFFFFF)
  btnGuardar.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.WRAP_CONTENT,
    LinearLayout.LayoutParams.WRAP_CONTENT))
  btnGuardar.setPadding(20, 10, 20, 10)

  btnGuardar.onClick = function()
    local nombre = edtNombre.getText().toString()
    local texto = edtTexto.getText().toString()
    mostrarSelectorFormato(nombre, texto, dlg)
  end

  local btnCerrar = Button(ctx)
  btnCerrar.setText("Cerrar")
  btnCerrar.setBackgroundColor(0xFF9E9E9E)
  btnCerrar.setTextColor(0xFFFFFFFF)
  btnCerrar.setLayoutParams(LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.WRAP_CONTENT,
    LinearLayout.LayoutParams.WRAP_CONTENT))
  btnCerrar.setPadding(20, 10, 20, 10)

  btnCerrar.onClick = function()
    dlg.dismiss()
  end

  layoutBotones.addView(btnCerrar)
  layoutBotones.addView(btnGuardar)

  layoutPrincipal.addView(layoutBotones)

  dlg.setView(layoutPrincipal)
  dlg.setCancelable(true)
  dlg.show()
end

mostrarInterfaz()
