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
local VERSION_ACTUAL_APP = "2.0-publicador"
local CATALOGO_ADMIN = "tienda-admin.json"
local CATALOGO_MIEMBROS = "tienda-miembros.json"

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
-- L脫GICA DE SUBIDA A GITHUB Y ACTUALIZACI脫N AUTOM脕TICA DEL JSON
-- =====================================================================
local function subirPluginCompleto(user, repo, token, nombre_json, nombre_archivo, nombre_visible, desc_visible, codigo_lua)
    service.speak("Subiendo plugin y actualizando cat谩logo...")
    
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
                        contenido_json_actual = tostring(luajava.newInstance("java.lang.String", Base64.decode(base64_raw, Base64.DEFAULT), "UTF-8"))
                    end
                end
                connGetJson.disconnect()

                -- Parsear el JSON actual y conservar su estructura.
                contenido_json_actual = tostring(contenido_json_actual or "")
                local okCatalogo, catalogo = pcall(function()
                    return json.decode(contenido_json_actual)
                end)
                if not okCatalogo or type(catalogo) ~= "table" then
                    catalogo = { version = 1, plugins = {}, aplicaciones = {} }
                end

                local lista_plugins
                if catalogo.plugins and type(catalogo.plugins) == "table" then
                    lista_plugins = catalogo.plugins
                else
                    -- Compatibilidad con cat谩logos antiguos que eran una lista directa.
                    lista_plugins = catalogo
                    catalogo = { version = 1, plugins = lista_plugins, aplicaciones = {} }
                end

                local url_base = "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/main/"

                table.insert(lista_plugins, {
                    nombre = nombre_visible,
                    archivo = nombre_archivo,
                    version = "1.0",
                    autor = user,
                    descripcion = desc_visible,
                    url_base = url_base
                })
                catalogo.plugins = lista_plugins
                if type(catalogo.aplicaciones) ~= "table" then catalogo.aplicaciones = {} end
                if not catalogo.version then catalogo.version = 1 end

                local nuevo_json_string = json.encode(catalogo)
                local base64_json = Base64.encodeToString(luajava.newInstance("java.lang.String", nuevo_json_string).getBytes("UTF-8"), Base64.NO_WRAP)

                local dataJson = { message = "Actualizando cat谩logo con " .. nombre_visible, content = base64_json }
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
                    service.speak("隆Plugin y cat谩logo actualizados con 茅xito!")
                    mostrarError("脡xito Total", "El plugin " .. nombre_visible .. " se subi贸 y se agreg贸 al cat谩logo autom谩ticamente.\n\nYa puedes entrar a la tienda para verlo.")
                elseif exito_lua and not exito_json then
                    service.speak("Plugin subido, pero fall贸 el cat谩logo.")
                    mostrarError("Aviso", "El archivo .lua se subi贸, pero no se pudo actualizar el JSON autom谩ticamente.\n\nDetalle: " .. errorMsg)
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
                TextView, text = "Publicador TIPI para GitHub", textSize = "20sp", textColor = COLOR_TEXTO, layout_marginBottom = "15dp"
            },
            -- Datos de la cuenta
            { TextView, text = "Tu usuario de GitHub:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_user", text = "benitezmiguel1906-afk", textColor = COLOR_TEXTO, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Nombre del repositorio:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_repo", text = "tienda-tipy", textColor = COLOR_TEXTO, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Token de GitHub:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_token", hint = "Pega tu token aqu铆", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Cat谩logo de destino:", textColor = COLOR_TEXTO_SEC },
            { Button, id = "btn_catalogo", text = "Tienda de administradores", layout_width = "fill", layout_marginBottom = "15dp" },
            
            -- Datos del plugin
            { TextView, text = "Nombre del plugin (visible en tienda):", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_nombre_visible", hint = "Ej: Chat Boot", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Nombre del archivo .lua:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_archivo", hint = "Ej: chat_boot.lua", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_marginBottom = "10dp" },
            
            { TextView, text = "Descripci贸n corta:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_desc", hint = "Ej: Un bot de chat inteligente", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_marginBottom = "15dp" },
            
            { TextView, text = "C贸digo Lua completo:", textColor = COLOR_TEXTO_SEC },
            { EditText, id = "input_codigo", hint = "Pega aqu铆 el c贸digo...", textColor = COLOR_TEXTO, hintTextColor = COLOR_TEXTO_SEC, layout_width = "fill", layout_height = "150dp", gravity = "top", layout_marginBottom = "15dp" },
            
            { Button, id = "btn_subir", text = "PUBLICAR PLUGIN Y ACTUALIZAR CAT脕LOGO", layout_width = "fill", layout_marginBottom = "8dp" },
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

    local catalogoSeleccionado = CATALOGO_ADMIN
    btn_catalogo.onClick = function()
        if catalogoSeleccionado == CATALOGO_ADMIN then
            catalogoSeleccionado = CATALOGO_MIEMBROS
            btn_catalogo.setText("Tienda de miembros")
            service.speak("Tienda de miembros seleccionada")
        else
            catalogoSeleccionado = CATALOGO_ADMIN
            btn_catalogo.setText("Tienda de administradores")
            service.speak("Tienda de administradores seleccionada")
        end
    end
    
    btn_subir.onClick = function()
        local user = input_user.getText().toString()
        local repo = input_repo.getText().toString()
        local token = input_token.getText().toString()
        local nombre_json = catalogoSeleccionado
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
        service.speak("Publicando en " .. (nombre_json == CATALOGO_ADMIN and "la tienda de administradores" or "la tienda de miembros"))
        subirPluginCompleto(user, repo, token, nombre_json, archivo, nombre_visible, desc, codigo)
    end
end

-- =====================================================================
-- T脡RMINOS Y PERFILES
-- =====================================================================
local function mostrarTerminos()
    local dlg = LuaDialog(ctx)
    dlg.setTitle("T茅rminos y Condiciones")
    
    local scroll = ScrollView(ctx)
    local layout = LinearLayout(ctx)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(30, 30, 30, 30)
    layout.setBackgroundColor(COLOR_FONDO)
    
    local texto = [[
Bienvenido a TIPI Store y Publicador Colaborativo (Tecnolog铆a Inclusiva Paraguay).

1. Proyecto Colaborativo
Esta tienda es un esfuerzo conjunto de los miembros de TIPI. Los administradores y creadores (Sara Gonz谩lez, Miguel, Alejandro, Samuel y N茅stor) trabajan para ofrecer herramientas accesibles.

2. Respeto a la Propiedad Intelectual
Cada creador gestiona su propio cat谩logo. Est谩 prohibido copiar plugins de otros repositorios y subirlos aqu铆 sin permiso.

3. Uso Correcto
Los complementos aqu铆 publicados son gratuitos y para uso personal. No se permite su venta.

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
    dlg.setTitle("Equipo TIP
