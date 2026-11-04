require "import"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.widget.Button"
import "android.widget.EditText"
import "android.widget.ScrollView"
import "android.content.Context"
import "android.content.Intent"
import "android.net.Uri"
import "android.provider.Settings"
import "android.os.Build"
import "android.os.Environment"
import "android.os.Handler"
import "android.os.Looper"
import "java.io.File"
import "java.net.URL"
import "java.net.HttpURLConnection"
import "java.io.ByteArrayOutputStream"
import "java.io.OutputStreamWriter"
import "java.io.BufferedReader"
import "java.io.InputStreamReader"
import "java.lang.StringBuilder"
import "android.util.Base64"
import "com.androlua.LuaDialog"
import "android.graphics.drawable.GradientDrawable"
import "android.graphics.drawable.ColorDrawable"
import "android.graphics.Color"
import "android.view.View"
import "android.view.ViewGroup"

local handler = Handler(Looper.getMainLooper())
local HUB_JSON_URL = "https://raw.githubusercontent.com/benitezmiguel1906-afk/tienda-tipy/main/tienda.json"
local VERSION_ACTUAL_APP = "1.0"

local diagnosticos = {}
local mainDialog = nil
local logView = nil
local lista_tiendas = {}
local ctx = activity or service

-- PALETA DE COLORES: Bandera de Paraguay
local COLOR_FONDO = 0xFF0F172A
local COLOR_TARJETA = 0xFF1E293B
local COLOR_TEXTO = 0xFFFFFFFF
local COLOR_TEXTO_SEC = 0xFF94A3B8
local COLOR_BOTON_ROJO = 0xFFD52B1E
local COLOR_BOTON_AZUL = 0xFF0038A8
local COLOR_BLANCO = 0xFFFFFFFF

local function log(msg)
    msg = tostring(msg)
    table.insert(diagnosticos, msg)
    pcall(function() service.asyncSpeak(msg) end)
end

local function obtener_json()
    local ok, lib = pcall(require, "cjson")
    if ok then return lib end
    ok, lib = pcall(require, "json")
    if ok then return lib end
    return nil
end
local json = obtener_json()

local function verificarPermisoAlmacenamiento()
    if Build.VERSION.SDK_INT >= Build.VERSION_CODES.R then
        local ok, tiene = pcall(function() return Environment.isExternalStorageManager() end)
        if ok and tiene then return true end
        pcall(function()
            local intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
            local uri = Uri.fromParts("package", ctx.getPackageName(), nil)
            intent.setData(uri)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
        end)
        log("Debe otorgar permiso de almacenamiento.")
        return false
    end
    return true
end

local function descargarTextoHttp(url)
    local body, code, err = nil, nil, nil
    local ok, pcallErr = pcall(function()
        local urlObj = URL(url)
        local conn = urlObj.openConnection()
        conn.setRequestMethod("GET")
        conn.setConnectTimeout(15000)
        conn.setReadTimeout(15000)
        conn.setInstanceFollowRedirects(true)
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Android) TIPIStore")
        conn.setRequestProperty("Accept-Encoding", "identity")
        code = conn.getResponseCode()

        local stream
        if code >= 200 and code < 300 then stream = conn.getInputStream() else stream = conn.getErrorStream() end

        if stream then
            local baos = ByteArrayOutputStream()
            local buffer = byte[4096]
            while true do
                local n = stream.read(buffer)
                if n == -1 then break end
                baos.write(buffer, 0, n)
            end
            stream.close()
            body = baos.toString("UTF-8")
            baos.close()
        end
        conn.disconnect()
    end)
    if not ok then err = tostring(pcallErr) end
    return body, code, err
end

local function mostrarError(titulo, msj)
    local dlg = LuaDialog(ctx)
    dlg.setTitle(titulo)
    local txt = TextView(ctx)
    txt.setText(tostring(msj))
    txt.setTextColor(Color.BLACK)
    txt.setPadding(30,30,30,30)
    dlg.setView(txt)
    dlg.setPositiveButton("Cerrar", nil)
    dlg.show()
end

-- =====================================================================
-- LÓGICA DE SUBIDA A GITHUB Y ACTUALIZACIÓN AUTOMÁTICA DEL JSON
-- =====================================================================
local function subirPluginCompleto(user, repo, token, nombre_json, nombre_archivo, nombre_visible, desc_visible, codigo_lua)
    service.speak("Subiendo plugin y actualizando catálogo...")
    
    Thread(Runnable({
        run = function()
            local exito_lua = false
            local exito_json = false
            local errorMsg = ""
            
            local ok, pcallErr = pcall(function()
                local token_limpio = tostring(token):gsub("%s+", "")
                local string_java = luajava.newInstance("java.lang.String", codigo_lua)
                local base64_lua = Base64.encodeToString(string_java.getBytes("UTF-8"), Base64.NO_WRAP)
                
                local url_lua = "https://api.github.com/repos/" .. user .. "/" .. repo .. "/contents/" .. nombre_archivo
                
                -- 1. SUBIR EL ARCHIVO .LUA
                local sha_lua = nil
                local connGetLua = URL(url_lua).openConnection()
                connGetLua.setRequestMethod("GET")
                connGetLua.setRequestProperty("Authorization", "token " .. token_limpio)
                connGetLua.setRequestProperty("User-Agent", "TIPI-Store-App")
                if connGetLua.getResponseCode() == 200 then
                    local reader = BufferedReader(InputStreamReader(connGetLua.getInputStream()))
                    local sb = StringBuilder()
                    local line
                    while true do
                        line = reader.readLine()
                        if line == nil then break end
                        sb.append(line)
                    end
                    reader.close()
                    local data = json.decode(sb.toString())
                    if data and data.sha then sha_lua = data.sha end
                end
                connGetLua.disconnect()

                local dataLua = { message = "Subiendo " .. nombre_archivo, content = base64_lua }
                if sha_lua then dataLua.sha = sha_lua end

                local connPutLua = URL(url_lua).openConnection()
                connPutLua.setRequestMethod("PUT")
                connPutLua.setRequestProperty("Authorization", "token " .. token_limpio)
                connPutLua.setRequestProperty("Accept", "application/vnd.github.v3+json")
                connPutLua.setRequestProperty("User-Agent", "TIPI-Store-App")
                connPutLua.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                connPutLua.setDoOutput(true)
                local os = connPutLua.getOutputStream()
                local writer = OutputStreamWriter(os, "UTF-8")
                writer.write(json.encode(dataLua))
                writer.flush()
                writer.close()
                
                local codeLua = connPutLua.getResponseCode()
                if codeLua == 201 or codeLua == 200 then
                    exito_lua = true
                else
                    errorMsg = "Error al subir .lua: HTTP " .. tostring(codeLua)
                    return
                end
                connPutLua.disconnect()

                -- 2. ACTUALIZAR EL ARCHIVO JSON
                local url_json = "https://api.github.com/repos/" .. user .. "/" .. repo .. "/contents/" .. nombre_json
                local sha_json = nil
                local contenido_json_actual = "[]"

                local connGetJson = URL(url_json).openConnection()
                connGetJson.setRequestMethod("GET")
                connGetJson.setRequestProperty("Authorization", "token " .. token_limpio)
                connGetJson.setRequestProperty("User-Agent", "TIPI-Store-App")
                if connGetJson.getResponseCode() == 200 then
                    local reader = BufferedReader(InputStreamReader(connGetJson.getInputStream()))
                    local sb = StringBuilder()
                    local line
                    while true do
                        line = reader.readLine()
                        if line == nil then break end
                        sb.append(line)
                    end
                    reader.close()
                    local data = json.decode(sb.toString())
                    if data then
                        sha_json = data.sha
                        -- Decodificar el Base64 que devuelve GitHub para leer el JSON real
                        local base64_raw = tostring(data.content):gsub("%s+", "")
                        contenido_json_actual = luajava.newInstance("java.lang.String", Base64.decode(base64_raw, Base64.DEFAULT), "UTF-8")
                    end
                end
                connGetJson.disconnect()

                -- Parsear el JSON actual, agregar el nuevo plugin y volver a codificar
                local lista_plugins = json.decode(contenido_json_actual) or {}
                local url_base = "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/main/"
                
                table.insert(lista_plugins, {
                    nombre = nombre_visible,
                    archivo = nombre_archivo,
                    version = "1.0",
                    autor = user,
                    descripcion = desc_visible,
                    url_base = url_base
                })
                
                local nuevo_json_string = json.encode(lista_plugins)
                local base64_json = Base64.encodeToString(luajava.newInstance("java.lang.String", nuevo_json_string).getBytes("UTF-8"), Base64.NO_WRAP)

                local dataJson = { message = "Actualizando catálogo con " .. nombre_visible, content = base64_json }
                if sha_json then dataJson.sha = sha_json end

                local connPutJson = URL(url_json).openConnection()
                connPutJson.setRequestMethod("PUT")
                connPutJson.setRequestProperty("Authorization", "token " .. token_limpio)
                connPutJson.setRequestProperty("Accept", "application/vnd.github.v3+json")
                connPutJson.setRequestProperty("User-Agent", "TIPI-Store-App")
                connPutJson.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                connPutJson.setDoOutput(true)
                local osJson = connPutJson.getOutputStream()
                local writerJson = OutputStreamWriter(osJson, "UTF-8")
                writerJson.write(json.encode(dataJson))
                writerJson.flush()
                writerJson.close()
                
                local codeJson = connPutJson.getResponseCode()
                if codeJson == 201 or codeJson == 200 then
                    exito_json = true
                else
                    errorMsg = errorMsg .. "\nError al actualizar JSON: HTTP " .. tostring(codeJson)
                end
                connPutJson.disconnect()
            end)
            
            if not ok then
                errorMsg = "Error interno: " .. tostring(pcallErr)
            end

            handler.post(function()
                if exito_lua and exito_json then
                    service.speak("¡Plugin y catálogo actualizados con éxito!")
                    mostrarError("Éxito Total", "El plugin " .. nombre_visible .. " se subió y se agregó al catálogo automáticamente.\n\nYa puedes entrar a la tienda para verlo.")
                elseif exito_lua and not exito_json then
                    service.speak("Plugin subido, pero falló el catálogo.")
                    mostrarError("Aviso", "El archivo .lua se subió, pero no se pudo actualizar el JSON automáticamente.\n\nDetalle: " .. errorMsg)
                else
                    service.speak("Error al subir.")
                    mostrarError("Error de GitHub", "No se pudo subir.\n\nDetalle:\n" .. errorMsg)
                end
            end)
        end
    })).start()
end

-- =====================================================================
-- VENTANA DE ADMINISTRADOR
-- =====================================================================
local function abrirPanelAdmin()
    local layout = {
        ScrollView,
        layout_width = "fill",
        layout_height = "match_parent",
        {
            LinearLayout,
            orientation = "vertical",
            padding = "20dp",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = COLOR_FONDO,
            {
                TextView, text = "Panel de Administrador TIPI", textSize = "20sp", textColor = COLOR_TEXTO, layout_marginBottom = "15dp"
            },
            -- Datos de la cuenta
            { TextView, text = "Tu usuario de GitHub:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_user", text = "benitezmiguel1906-afk", textColor = COLOR_TEXTO, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Nombre del repositorio:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_repo", text = "tienda-tipy", textColor = COLOR_TEXTO, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Token de GitHub:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_token", hint = "Pega tu token aquí", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Archivo JSON a actualizar:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_json", text = "tienda_miguel.json", textColor = COLOR_TEXTO, layout_width = "fill", layout_marginBottom = "15dp" },
            
            -- Datos del plugin
            { TextView, text = "Nombre del plugin (visible en tienda):", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_nombre_visible", hint = "Ej: Chat Boot", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Nombre del archivo .lua:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_archivo", hint = "Ej: chat_boot.lua", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Descripción corta:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_desc", hint = "Ej: Un bot de chat inteligente", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_marginBottom = "15dp" },
            
            { TextView, text = "Código Lua completo:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_codigo", hint = "Pega aquí el código...", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_height = "150dp", gravity = "top", layout_marginBottom = "15dp" },
            
            { Button, id = "btn_subir", text = "SUBIR PLUGIN Y ACTUALIZAR TIENDA", layout_width = "fill", layout_marginBottom = "8dp" },
            { Button, id = "btn_cerrar_admin", text = "Cerrar", layout_width = "fill" }
        }
    }
    
    local view = loadlayout(layout)
    local dlg = LuaDialog(ctx)
    dlg.setView(view)
    dlg.show()
    
    local bgAzul = GradientDrawable()
    bgAzul.setColor(COLOR_BOTON_AZUL)
    bgAzul.setCornerRadius(20)
    btn_subir.setBackground(bgAzul)
    btn_subir.setTextColor(Color.WHITE)
    
    btn_cerrar_admin.onClick = function() dlg.dismiss() end
    
    btn_subir.onClick = function()
        local user = input_user.getText().toString()
        local repo = input_repo.getText().toString()
        local token = input_token.getText().toString()
        local nombre_json = input_json.getText().toString()
        local nombre_visible = input_nombre_visible.getText().toString()
        local archivo = input_archivo.getText().toString()
        local desc = input_desc.getText().toString()
        local codigo = input_codigo.getText().toString()
        
        if token == "" or archivo == "" or codigo == "" or nombre_visible == "" then
            service.speak("Por favor, completa los campos obligatorios.")
            return
        end
        
        if string.sub(archivo, -4) ~= ".lua" then
            archivo = archivo .. ".lua"
        end
        
        dlg.dismiss()
        subirPluginCompleto(user, repo, token, nombre_json, archivo, nombre_visible, desc, codigo)
    end
end

-- =====================================================================
-- TÉRMINOS Y PERFILES
-- =====================================================================
local function mostrarTerminos()
    local dlg = LuaDialog(ctx)
    dlg.setTitle("Términos y Condiciones")
    
    local scroll = ScrollView(ctx)
    local layout = LinearLayout(ctx)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(30, 30, 30, 30)
    layout.setBackgroundColor(COLOR_FONDO)
    
    local texto = [[
Bienvenido a TIPI Store Colaborativa (Tecnología Inclusiva Paraguay).

1. Proyecto Colaborativo
Esta tienda es un esfuerzo conjunto de los miembros de TIPI. Los administradores y creadores (Sara González, Miguel, Alejandro, Samuel y Néstor) trabajan para ofrecer herramientas accesibles.

2. Respeto a la Propiedad Intelectual
Cada creador gestiona su propio catálogo. Está prohibido copiar plugins de otros repositorios y subirlos aquí sin permiso.

3. Uso Correcto
Los complementos aquí publicados son gratuitos y para uso personal. No se permite su venta.

Al usar esta tienda, aceptas estas condiciones y apoyas el desarrollo inclusivo.
    ]]
    
    local txt = TextView(ctx)
    txt.setText(texto)
    txt.setTextColor(COLOR_TEXTO)
    txt.setTextSize(16)
    
    layout.addView(txt)
    scroll.addView(layout)
    
    dlg.setView(scroll)
    dlg.setPositiveButton("Aceptar", function() dlg.dismiss() end)
    dlg.show()
    pcall(function()
        dlg.getWindow().setBackgroundDrawable(ColorDrawable(COLOR_FONDO))
    end)
end

local function mostrarPerfiles()
    local dlg = LuaDialog(ctx)
    dlg.setTitle("Equipo TIPI")
    
    local layout = LinearLayout(ctx)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(30, 30, 30, 30)
    layout.setBackgroundColor(COLOR_FONDO)
    
    local perfiles = {
        "👤 Sara González\n   Creadora de TIPI",
        "👤 Miguel\n   Administrador y Desarrollador",
        "👤 Alejandro Romero\n   Colaborador",
        "👤 Samuel López\n   Colaborador",
        "👤 Néstor Ayala\n   Colaborador"
    }
    
    for _, nombre in ipairs(perfiles) do
        local t = TextView(ctx)
        t.setText(nombre)
        t.setTextColor(COLOR_TEXTO)
        t.setTextSize(16)
        t.setPadding(0, 20, 0, 20)
        layout.addView(t)
    end
    
    dlg.setView(layout)
    dlg.setNegativeButton("Cerrar", function() dlg.dismiss() end)
    dlg.show()
    pcall(function()
        dlg.getWindow().setBackgroundDrawable(ColorDrawable(COLOR_FONDO))
    end)
end

-- =====================================================================
-- TIENDA Y TARJETAS
-- =====================================================================
local function crearTarjetaStore(tienda)
    local card = LinearLayout(ctx)
    card.setOrientation(LinearLayout.VERTICAL)
    card.setPadding(40, 40, 40, 40)
    
    local bg = GradientDrawable()
    bg.setColor(COLOR_TARJETA)
    bg.setCornerRadius(40)
    bg.setStroke(2, COLOR_BLANCO)
    card.setBackground(bg)
    
    local titulo = TextView(ctx)
    titulo.setText(tienda.nombre or "Tienda sin nombre")
    titulo.setTextColor(COLOR_TEXTO)
    titulo.setTextSize(20)
    
    local subtitulo = TextView(ctx)
    subtitulo.setText(tienda.descripcion or "Sin descripción")
    subtitulo.setTextColor(COLOR_TEXTO_SEC)
    subtitulo.setTextSize(14)
    subtitulo.setPadding(0, 15, 0, 0)
    
    card.addView(titulo)
    card.addView(subtitulo)
    
    card.setOnClickListener(function()
        if not tienda.url_json or tienda.url_json == "" then
            service.speak("Esta tienda aún no tiene plugins disponibles, próximamente.")
        else
            service.speak("Abriendo " .. (tienda.nombre or "tienda"))
            cargarPluginsDeTienda(tienda.url_json)
        end
    end)
    
    return card
end

local function ejecutar_descarga(url_archivo, nombre_archivo, nombre_plugin)
    if not verificarPermisoAlmacenamiento() then return end
    local dir_plugins = "/storage/emulated/0/解说/Plugins/"
    local nombre_carpeta = string.gsub(nombre_archivo, "%.lua$", "")
    local dir_plugin_especifico = dir_plugins .. nombre_carpeta .. "/"
    local dir_obj = File(dir_plugin_especifico)
    if not dir_obj.exists() then dir_obj.mkdirs() end
    local ruta_destino = dir_plugin_especifico .. "main.lua"

    log("Descargando " .. nombre_plugin .. "...")
    service.speak("Descargando " .. nombre_plugin)

    Thread(Runnable{
        run = function()
            local body, code, err = descargarTextoHttp(url_archivo)
            handler.post(function()
                if err or code ~= 200 or not body or #body == 0 then
                    log("Error al descargar. Código: " .. tostring(code))
                    return
                end
                body = string.gsub(body, "^%s+", "")
                local archivo = io.open(ruta_destino, "wb")
                if archivo then
                    archivo:write(body)
                    archivo:close()
                    log("¡Instalado con éxito! Reinicie Jieshuo.")
                else
                    log("Error al escribir archivo.")
                end
            end)
        end
    }).start()
end

local function verificar_e_instalar(url_archivo, nombre_archivo, nombre_plugin)
    local nombre_carpeta = string.gsub(nombre_archivo, "%.lua$", "")
    local ruta_destino = "/storage/emulated/0/解说/Plugins/" .. nombre_carpeta .. "/main.lua"
    if File(ruta_destino).exists() then
        local alert = LuaDialog(ctx)
        alert.setTitle("Plugin existente")
        alert.setMessage("El complemento ya está instalado. ¿Desea sobrescribirlo?")
        alert.setPositiveButton("Sí", function()
            alert.dismiss()
            ejecutar_descarga(url_archivo, nombre_archivo, nombre_plugin)
        end)
        alert.setNegativeButton("No", function() alert.dismiss() end)
        alert.show()
    else
        ejecutar_descarga(url_archivo, nombre_archivo, nombre_plugin)
    end
end


local function abrirAPK(url_archivo, nombre)
    local ok = pcall(function()
        local intent = Intent(Intent.ACTION_VIEW)
        intent.setData(Uri.parse(tostring(url_archivo)))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(intent)
    end)
    if ok then
        service.speak("Abriendo descarga de " .. tostring(nombre))
    else
        service.speak("No se pudo abrir la descarga de " .. tostring(nombre))
    end
end

function cargarPluginsDeTienda(url_json_tienda)
    service.speak("Cargando catálogo...")
    Thread(Runnable{
        run = function()
            local body, code, err = descargarTextoHttp(url_json_tienda)
            handler.post(function()
                if code == 200 and body and body ~= "" then
                    local status, data = pcall(function() return json.decode(body) end)
                    if not status or type(data) ~= "table" then
                        log("Error: el catálogo no contiene JSON válido.")
                        service.speak("El catálogo tiene errores.")
                        return
                    end

                    -- Formato antiguo: una lista directa de plugins.
                    -- Formato nuevo: {plugins = [...], aplicaciones = [...]}
                    local lista = {}
                    if data.plugins or data.aplicaciones then
                        if type(data.plugins) == "table" then
                            for _, p in ipairs(data.plugins) do
                                table.insert(lista, {
                                    tipo = "plugin",
                                    nombre = p.nombre or "Plugin sin nombre",
                                    version = p.version or p.versionName or "1.0",
                                    descripcion = p.descripcion or "Sin descripción",
                                    archivo = p.archivo,
                                    url_base = p.url_base,
                                    url = p.url or p.url_archivo
                                })
                            end
                        end
                        if type(data.aplicaciones) == "table" then
                            for _, a in ipairs(data.aplicaciones) do
                                table.insert(lista, {
                                    tipo = "apk",
                                    nombre = a.nombre or "Aplicación sin nombre",
                                    version = a.versionName or a.version or "1.0",
                                    descripcion = a.descripcion or "Aplicación Android",
                                    url = a.url or a.apkUrl,
                                    apkUrl = a.url or a.apkUrl
                                })
                            end
                        end
                    else
                        lista = data
                    end

                    if #lista > 0 then
                        mostrarVentanaPlugins(lista)
                    else
                        log("El catálogo está vacío.")
                        service.speak("No hay elementos disponibles en esta tienda.")
                    end
                else
                    service.speak("Error al conectar con la tienda.")
                end
            end)
        end
    }).start()
end

function mostrarVentanaPlugins(plugins_table)
    local dlg = LuaDialog(ctx)
    dlg.setTitle("Seleccionar elemento")

    local scroll = ScrollView(ctx)
    local layout = LinearLayout(ctx)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(20, 20, 20, 20)
    layout.setBackgroundColor(COLOR_FONDO)
    scroll.addView(layout)

    for _, comp in ipairs(plugins_table) do
        local card = LinearLayout(ctx)
        card.setOrientation(LinearLayout.VERTICAL)
        card.setPadding(30, 30, 30, 30)

        local bg = GradientDrawable()
        bg.setColor(COLOR_TARJETA)
        bg.setCornerRadius(30)
        card.setBackground(bg)

        local nombre = tostring(comp.nombre or "Sin nombre")
        local version = tostring(comp.version or "1.0")
        local tipo = comp.tipo == "apk" and "Aplicación APK" or "Plugin Lua"

        local t1 = TextView(ctx)
        t1.setText(nombre .. " (v" .. version .. ")")
        t1.setTextColor(COLOR_TEXTO)
        t1.setTextSize(18)

        local t2 = TextView(ctx)
        t2.setText(tipo .. "\n" .. tostring(comp.descripcion or "Sin descripción"))
        t2.setTextColor(COLOR_TEXTO_SEC)
        t2.setTextSize(14)
        t2.setPadding(0, 10, 0, 20)

        local btn = Button(ctx)
        btn.setText(comp.tipo == "apk" and "DESCARGAR APK" or "INSTALAR PLUGIN")
        btn.setTextColor(Color.WHITE)

        local btnBg = GradientDrawable()
        btnBg.setColor(comp.tipo == "apk" and COLOR_BOTON_ROJO or COLOR_BOTON_AZUL)
        btnBg.setCornerRadius(20)
        btn.setBackground(btnBg)
        btn.setContentDescription(btn.getText())

        btn.setOnClickListener(function()
            dlg.dismiss()
            if comp.tipo == "apk" then
                if comp.url and tostring(comp.url) ~= "" then
                    abrirAPK(comp.url, nombre)
                else
                    service.speak("La aplicación no tiene enlace de descarga.")
                end
            else
                local url_descarga = comp.url
                if not url_descarga or tostring(url_descarga) == "" then
                    url_descarga = (comp.url_base or "") .. (comp.archivo or "")
                end
                verificar_e_instalar(url_descarga, comp.archivo or "main.lua", nombre)
            end
        end)

        card.addView(t1)
        card.addView(t2)
        card.addView(btn)
        local lp = LinearLayout.LayoutParams(-1, -2)
        lp.setMargins(0, 0, 0, 20)
        layout.addView(card, lp)
    end

    dlg.setView(scroll)
    dlg.setNegativeButton("Cerrar", function() dlg.dismiss() end)
    dlg.show()
    pcall(function() dlg.getWindow().setBackgroundDrawable(ColorDrawable(COLOR_FONDO)) end)
end

local function mostrarHub(tiendas)
    lista_tiendas = tiendas
    if mainDialog then mainDialog.dismiss() end
    mainDialog = LuaDialog(ctx)
    mainDialog.setTitle("TIPI Store Colaborativa")
    
    local root = LinearLayout(ctx)
    root.setOrientation(LinearLayout.VERTICAL)
    root.setBackgroundColor(COLOR_FONDO)
    root.setPadding(30, 30, 30, 30)
    root.setLayoutParams(LinearLayout.LayoutParams(-1, -1))
    
    local btnBar = LinearLayout(ctx)
    btnBar.setOrientation(LinearLayout.HORIZONTAL)
    local lpBar = LinearLayout.LayoutParams(-1, -2)
    lpBar.setMargins(0, 0, 0, 20)
    root.addView(btnBar, lpBar)
    
    local btnPerfiles = Button(ctx)
    btnPerfiles.setText("PERFILES")
    btnPerfiles.setTextColor(Color.WHITE)
    local bgPerfil = GradientDrawable()
    bgPerfil.setColor(COLOR_BOTON_ROJO)
    bgPerfil.setCornerRadius(20)
    btnPerfiles.setBackground(bgPerfil)
    local lpBtn1 = LinearLayout.LayoutParams(0, -2, 1)
    lpBtn1.setMargins(0, 0, 10, 0)
    btnBar.addView(btnPerfiles, lpBtn1)
    
    local btnTerminos = Button(ctx)
    btnTerminos.setText("TÉRMINOS")
    btnTerminos.setTextColor(Color.WHITE)
    local bgTerm = GradientDrawable()
    bgTerm.setColor(COLOR_BOTON_AZUL)
    bgTerm.setCornerRadius(20)
    btnTerminos.setBackground(bgTerm)
    local lpBtn2 = LinearLayout.LayoutParams(0, -2, 1)
    btnBar.addView(btnTerminos, lpBtn2)
    
    -- BOTÓN SECRETO DE ADMIN
    local btnAdmin = Button(ctx)
    btnAdmin.setText("🔒")
    btnAdmin.setTextColor(Color.WHITE)
    local bgAdmin = GradientDrawable()
    bgAdmin.setColor(0xFF333333)
    bgAdmin.setCornerRadius(20)
    btnAdmin.setBackground(bgAdmin)
    local lpBtn3 = LinearLayout.LayoutParams(-2, -2)
    btnBar.addView(btnAdmin, lpBtn3)
    
    btnPerfiles.onClick = function() mostrarPerfiles() end
    btnTerminos.onClick = function() mostrarTerminos() end
    btnAdmin.onClick = function() abrirPanelAdmin() end
    
    local buscador = EditText(ctx)
    buscador.setHint("Buscar tienda...")
    buscador.setTextColor(0xFF000000)
    buscador.setHintTextColor(0xFF666666)
    
    local searchBg = GradientDrawable()
    searchBg.setColor(COLOR_BLANCO)
    searchBg.setCornerRadius(30)
    buscador.setBackground(searchBg)
    buscador.setPadding(30, 30, 30, 30)
    
    local lpBus = LinearLayout.LayoutParams(-1, -2)
    lpBus.setMargins(0, 0, 0, 30)
    root.addView(buscador, lpBus)
    
    local scroll = ScrollView(ctx)
    local contenedor = LinearLayout(ctx)
    contenedor.setOrientation(LinearLayout.VERTICAL)
    scroll.addView(contenedor)
    local lpScroll = LinearLayout.LayoutParams(-1, 0)
    lpScroll.weight = 1
    root.addView(scroll, lpScroll)
    
    local barraInferior = LinearLayout(ctx)
    barraInferior.setOrientation(LinearLayout.HORIZONTAL)
    barraInferior.setPadding(0, 20, 0, 0)
    
    local btnCerrar = Button(ctx)
    btnCerrar.setText("Cerrar tienda")
    btnCerrar.setTextColor(COLOR_BOTON_ROJO)
    
    local closeBg = GradientDrawable()
    closeBg.setColor(Color.TRANSPARENT)
    closeBg.setStroke(2, COLOR_BOTON_ROJO)
    closeBg.setCornerRadius(30)
    btnCerrar.setBackground(closeBg)
    
    btnCerrar.setOnClickListener(function() mainDialog.dismiss() end)
    barraInferior.addView(btnCerrar, LinearLayout.LayoutParams(-1, -2))
    root.addView(barraInferior)
    
    mainDialog.setView(root)
    mainDialog.show()
    
    pcall(function()
        local window = mainDialog.getWindow()
        window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        window.setBackgroundDrawable(ColorDrawable(COLOR_FONDO))
    end)
    
    local function dibujar(lista)
        contenedor.removeAllViews()
        for _, tienda in ipairs(lista) do
            local card = crearTarjetaStore(tienda)
            local lp = LinearLayout.LayoutParams(-1, -2)
            lp.setMargins(0, 0, 0, 20)
            contenedor.addView(card, lp)
        end
    end
    
    dibujar(tiendas)
    
    buscador.addTextChangedListener({
        onTextChanged = function(s)
            local texto = string.lower(tostring(s))
            local filtrados = {}
            for _, t in ipairs(lista_tiendas) do
                if string.find(string.lower(t.nombre or ""), texto, 1, true) then
                    table.insert(filtrados, t)
                end
            end
            dibujar(filtrados)
        end
    })
end

local function verificarActualizacion(data)
    local prefs = ctx.getSharedPreferences("TIPIStorePrefs", 0)
    local versionGuardada = prefs.getString("version_aceptada", "0.0")
    local versionRemota = tonumber(data.version) or 0
    local versionLocal = tonumber(versionGuardada) or 0
    
    if versionRemota > versionLocal then
        local dlg = LuaDialog(ctx)
        dlg.setTitle("Tienda actualizada")
        dlg.setMessage("Versión: " .. data.version .. "\n\nCambios en esta versión:\n" .. (data.cambios or ""))
        dlg.setPositiveButton("ACEPTAR Y CONTINUAR", function() 
            prefs.edit().putString("version_aceptada", tostring(data.version)).apply()
            dlg.dismiss()
            mostrarHub(data.tiendas)
        end)
        dlg.show()
    else
        mostrarHub(data.tiendas)
    end
end

log("Conectando con TIPI Store...")

if not json then
    service.speak("Error: La librería JSON no está instalada.")
    return
end

Thread(Runnable{
    run = function()
        local body, code, err = descargarTextoHttp(HUB_JSON_URL)
        handler.post(function()
            if code == 200 and body and body ~= "" then
                local status, data = pcall(function() return json.decode(body) end)
                if status then
                    if data and data.tiendas then
                        verificarActualizacion(data)
                    else
                        service.speak("El JSON no contiene la lista de tiendas.")
                    end
                else
                    service.speak("El JSON tiene errores de escritura.")
                end
            else
                service.speak("Error de conexión. Código: " .. tostring(code))
            end
        end)
    end
}).start()

return true
