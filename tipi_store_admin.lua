require "import"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.widget.Button"
import "android.widget.ScrollView"
import "android.content.Intent"
import "android.net.Uri"
import "android.graphics.Color"
import "android.os.Handler"
import "android.os.Looper"
import "android.os.Build"
import "android.os.Environment"
import "android.provider.Settings"
import "java.net.URL"
import "java.io.File"
import "java.io.ByteArrayOutputStream"
import "java.io.BufferedReader"
import "java.io.InputStreamReader"
import "com.androlua.LuaDialog"

local handler = Handler(Looper.getMainLooper())
local ctx = activity or service
local URL_CATALOGO = "https://raw.githubusercontent.com/benitezmiguel1906-afk/tienda-tipy/main/tienda-admin.json"
local BG = 0xFF0F172A
local CARD = 0xFF1E293B
local WHITE = 0xFFFFFFFF
local SECONDARY = 0xFF94A3B8
local BLUE = 0xFF0038A8
local GREEN = 0xFF2E7D32

local function speak(text)
  pcall(function()
    if service and service.asyncSpeak then service.asyncSpeak(tostring(text))
    elseif service and service.speak then service.speak(tostring(text)) end
  end)
end

local function get_json()
  local ok, lib = pcall(require, "cjson")
  if ok then return lib end
  ok, lib = pcall(require, "json")
  if ok then return lib end
  return nil
end

local json = get_json()

local function error_dialog(title, message)
  local d = LuaDialog(ctx)
  d.setTitle(title)
  d.setMessage(tostring(message))
  d.setPositiveButton("Cerrar", nil)
  d.show()
  speak(message)
end

local function http_get(url)
  local body, code, err = nil, nil, nil
  local ok, problem = pcall(function()
    local c = URL(url).openConnection()
    c.setRequestMethod("GET")
    c.setConnectTimeout(15000)
    c.setReadTimeout(15000)
    c.setInstanceFollowRedirects(true)
    c.setRequestProperty("User-Agent", "TIPI-Store-Administradores-v2")
    c.setRequestProperty("Accept-Encoding", "identity")
    code = c.getResponseCode()
    local stream
    if code >= 200 and code < 300 then stream = c.getInputStream() else stream = c.getErrorStream() end
    if stream then
      local bytes = ByteArrayOutputStream()
      local buffer = byte[4096]
      while true do
        local n = stream.read(buffer)
        if n == -1 then break end
        bytes.write(buffer, 0, n)
      end
      stream.close()
      body = tostring(bytes.toString("UTF-8"))
      bytes.close()
    end
    c.disconnect()
  end)
  if not ok then err = tostring(problem) end
  return body, code, err
end

local function permission_storage()
  if Build.VERSION.SDK_INT >= Build.VERSION_CODES.R then
    local ok, has = pcall(function() return Environment.isExternalStorageManager() end)
    if ok and has then return true end
    pcall(function()
      local intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
      intent.setData(Uri.parse("package:" .. ctx.getPackageName()))
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      ctx.startActivity(intent)
    end)
    speak("Debe permitir el acceso al almacenamiento y volver a abrir la tienda.")
    return false
  end
  return true
end

local function open_url(url, name)
  local ok = pcall(function()
    local i = Intent(Intent.ACTION_VIEW)
    i.setData(Uri.parse(tostring(url)))
    i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    ctx.startActivity(i)
  end)
  if ok then speak("Abriendo descarga de " .. name)
  else speak("No se pudo abrir la descarga") end
end

local function install_plugin(url, file_name, name)
  if not permission_storage() then return end
  local clean_name = tostring(file_name or "main.lua"):gsub("%.lua$", "")
  local folder = "/storage/emulated/0/解说/Plugins/" .. clean_name .. "/"
  local folder_file = File(folder)
  if not folder_file.exists() then folder_file.mkdirs() end
  local destination = folder .. "main.lua"
  speak("Descargando " .. name)
  Thread(Runnable{
    run = function()
      local body, code, err = http_get(url)
      handler.post(function()
        if err or code ~= 200 or not body or #body == 0 then
          error_dialog("Error", "No se pudo descargar el plugin. Codigo: " .. tostring(code))
          return
        end
        local output = io.open(destination, "wb")
        if not output then
          error_dialog("Error", "No se pudo guardar el plugin en el telefono.")
          return
        end
        output:write(body)
        output:close()
        error_dialog("Plugin descargado", "El plugin se guardo correctamente. Reinicie Jieshuo para activarlo.")
      end)
    end
  }).start()
end

local function plugin_url(item)
  if item.url and tostring(item.url) ~= "" then return tostring(item.url) end
  return tostring(item.url_base or "") .. tostring(item.archivo or "")
end

local function add_heading(list, text)
  local t = TextView(ctx)
  t.setText(text)
  t.setTextColor(WHITE)
  t.setTextSize(20)
  t.setPadding(0, 14, 0, 8)
  list.addView(t)
end

local function add_item(list, name, version, description, url, button_text, color, is_plugin, file_name)
  local card = LinearLayout(ctx)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setPadding(18, 18, 18, 18)
  card.setBackgroundColor(CARD)

  local title = TextView(ctx)
  title.setText(name .. " - version " .. version)
  title.setTextColor(WHITE)
  title.setTextSize(18)
  title.setContentDescription(name .. ", version " .. version)
  card.addView(title)

  local detail = TextView(ctx)
  detail.setText(description)
  detail.setTextColor(SECONDARY)
  detail.setTextSize(15)
  detail.setPadding(0, 8, 0, 8)
  card.addView(detail)

  local b = Button(ctx)
  b.setText(button_text)
  b.setTextColor(WHITE)
  b.setBackgroundColor(color)
  b.setContentDescription(button_text)
  b.setOnClickListener(function()
    if not url or tostring(url) == "" then
      speak("No hay enlace de descarga para " .. name)
      return
    end
    if is_plugin then install_plugin(url, file_name or "main.lua", name)
    else open_url(url, name) end
  end)
  card.addView(b)
  list.addView(card)
  local space = TextView(ctx)
  space.setText(" ")
  list.addView(space)
end

local function show_catalog(data)
  local d = LuaDialog(ctx)
  d.setTitle("TIPI Store - Administradores")
  local scroll = ScrollView(ctx)
  local list = LinearLayout(ctx)
  list.setOrientation(LinearLayout.VERTICAL)
  list.setPadding(20, 20, 20, 20)
  list.setBackgroundColor(BG)
  scroll.addView(list)

  local intro = TextView(ctx)
  intro.setText("Catalogo exclusivo para administradores")
  intro.setTextColor(WHITE)
  intro.setTextSize(18)
  intro.setContentDescription("Catalogo exclusivo para administradores")
  list.addView(intro)

  local plugins = data.plugins or {}
  local apps = data.aplicaciones or {}
  local total = 0

  add_heading(list, "Plugins Lua")
  if type(plugins) == "table" and #plugins > 0 then
    for _, p in ipairs(plugins) do
      total = total + 1
      local name = tostring(p.nombre or "Plugin sin nombre")
      local version = tostring(p.version or p.versionName or "Sin version")
      local description = tostring(p.descripcion or "Plugin para administradores")
      local url = plugin_url(p)
      add_item(list, name, version, description, url, "INSTALAR PLUGIN " .. name, BLUE, true, p.archivo or "main.lua")
    end
  else
    local empty = TextView(ctx)
    empty.setText("No hay plugins para administradores.")
    empty.setTextColor(SECONDARY)
    empty.setTextSize(16)
    list.addView(empty)
  end

  add_heading(list, "Aplicaciones APK")
  if type(apps) == "table" and #apps > 0 then
    for _, a in ipairs(apps) do
      total = total + 1
      local name = tostring(a.nombre or "Aplicacion sin nombre")
      local version = tostring(a.versionName or a.version or "Sin version")
      local description = tostring(a.descripcion or "Aplicacion para administradores")
      local url = a.url or a.apkUrl
      add_item(list, name, version, description, url, "DESCARGAR APK " .. name, GREEN, false, nil)
    end
  else
    local empty = TextView(ctx)
    empty.setText("No hay aplicaciones APK para administradores.")
    empty.setTextColor(SECONDARY)
    empty.setTextSize(16)
    list.addView(empty)
  end

  d.setView(scroll)
  d.setNegativeButton("Cerrar", function() d.dismiss() end)
  d.show()
  pcall(function() d.getWindow().setLayout(-1, -1) end)
  speak("Tienda de administradores. Hay " .. tostring(total) .. " elementos disponibles")
end

local function load_catalog()
  if not json then
    error_dialog("Error", "No se encontro una libreria JSON compatible.")
    return
  end
  speak("Cargando tienda de administradores")
  Thread(Runnable{
    run = function()
      local body, code, err = http_get(URL_CATALOGO)
      handler.post(function()
        if err or code ~= 200 or not body then
          error_dialog("Error de conexion", "No se pudo cargar tienda-admin.json. Codigo: " .. tostring(code))
          return
        end
        local ok, data = pcall(function() return json.decode(body) end)
        if not ok or type(data) ~= "table" then
          error_dialog("Error del catalogo", "tienda-admin.json no contiene un JSON valido.")
          return
        end
        show_catalog(data)
      end)
    end
  }).start()
end

load_catalog()
return true
