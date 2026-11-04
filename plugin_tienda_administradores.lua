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
import "java.net.URL"
import "java.io.BufferedReader"
import "java.io.InputStreamReader"
import "java.lang.StringBuilder"
import "com.androlua.LuaDialog"

-- TIPI Store: tienda exclusiva para administradores.
-- No contiene tokens ni contraseñas.
-- Consulta plugins y APK desde tienda-admin.json.

local handler = Handler(Looper.getMainLooper())
local ctx = activity or service

local URL_CATALOGO = "https://raw.githubusercontent.com/benitezmiguel1906-afk/tienda-tipy/main/tienda-admin.json"

local COLOR_FONDO = 0xFF0F172A
local COLOR_TARJETA = 0xFF1E293B
local COLOR_TEXTO = 0xFFFFFFFF
local COLOR_SECUNDARIO = 0xFF94A3B8
local COLOR_AZUL = 0xFF0038A8
local COLOR_ROJO = 0xFFD52B1E
local COLOR_VERDE = 0xFF2E7D32

local function hablar(texto)
    pcall(function()
        if service and service.asyncSpeak then
            service.asyncSpeak(tostring(texto))
        elseif service and service.speak then
            service.speak(tostring(texto))
        end
    end)
end

local function obtener_json()
    local ok, lib = pcall(require, "cjson")
    if ok then return lib end
    ok, lib = pcall(require, "json")
    if ok then return lib end
    return nil
end

local json = obtener_json()

local function descargar_texto(url)
    local cuerpo, codigo, error_texto = nil, nil, nil
    local ok, err = pcall(function()
        local conexion = URL(url).openConnection()
        conexion.setRequestMethod("GET")
        conexion.setConnectTimeout(15000)
        conexion.setReadTimeout(15000)
        conexion.setInstanceFollowRedirects(true)
        conexion.setRequestProperty("User-Agent", "TIPI-Store-Administradores")
        conexion.setRequestProperty("Accept-Encoding", "identity")
        codigo = conexion.getResponseCode()

        local entrada = conexion.getInputStream()
        local lector = BufferedReader(InputStreamReader(entrada, "UTF-8"))
        local texto = StringBuilder()
        while true do
            local linea = lector.readLine()
            if linea == nil then break end
            texto.append(linea)
        end
        lector.close()
        entrada.close()
        conexion.disconnect()
        cuerpo = texto.toString()
    end)
    if not ok then error_texto = tostring(err) end
    return cuerpo, codigo, error_texto
end

local function mostrar_error(titulo, mensaje)
    local dialogo = LuaDialog(ctx)
    dialogo.setTitle(titulo)
    dialogo.setMessage(tostring(mensaje))
    dialogo.setPositiveButton("Cerrar", nil)
    dialogo.show()
    hablar(tostring(mensaje))
end

local function abrir_enlace(url, nombre)
    local ok = pcall(function()
        local intent = Intent(Intent.ACTION_VIEW)
        intent.setData(Uri.parse(tostring(url)))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(intent)
    end)
    if ok then
        hablar("Abriendo descarga de " .. nombre)
    else
        hablar("No se pudo abrir la descarga de " .. nombre)
    end
end

local function tarjeta_base()
    local tarjeta = LinearLayout(ctx)
    tarjeta.setOrientation(LinearLayout.VERTICAL)
    tarjeta.setPadding(18, 18, 18, 18)
    tarjeta.setBackgroundColor(COLOR_TARJETA)
    return tarjeta
end

local function agregar_titulo(tarjeta, nombre, subtitulo)
    local titulo = TextView(ctx)
    titulo.setText(nombre)
    titulo.setTextColor(COLOR_TEXTO)
    titulo.setTextSize(19)
    titulo.setContentDescription(nombre)
    tarjeta.addView(titulo)

    local detalle = TextView(ctx)
    detalle.setText(subtitulo)
    detalle.setTextColor(COLOR_SECUNDARIO)
    detalle.setTextSize(15)
    detalle.setPadding(0, 8, 0, 8)
    tarjeta.addView(detalle)
end

local function agregar_separador(lista)
    local separador = TextView(ctx)
    separador.setText(" ")
    lista.addView(separador)
end

local function mostrar_catalogo(datos)
    local dialogo = LuaDialog(ctx)
    dialogo.setTitle("TIPI Store - Administradores")

    local desplazable = ScrollView(ctx)
    local lista = LinearLayout(ctx)
    lista.setOrientation(LinearLayout.VERTICAL)
    lista.setPadding(20, 20, 20, 20)
    lista.setBackgroundColor(COLOR_FONDO)
    desplazable.addView(lista)

    local encabezado = TextView(ctx)
    encabezado.setText("Catálogo exclusivo para administradores")
    encabezado.setTextColor(COLOR_TEXTO)
    encabezado.setTextSize(18)
    encabezado.setPadding(0, 0, 0, 18)
    encabezado.setContentDescription("Catálogo exclusivo para administradores")
    lista.addView(encabezado)

    local plugins = datos.plugins or {}
    local aplicaciones = datos.aplicaciones or {}
    local total = 0

    local titulo_plugins = TextView(ctx)
    titulo_plugins.setText("Plugins Lua")
    titulo_plugins.setTextColor(COLOR_TEXTO)
    titulo_plugins.setTextSize(20)
    lista.addView(titulo_plugins)

    if type(plugins) == "table" and #plugins > 0 then
        for _, plugin in ipairs(plugins) do
            total = total + 1
            local nombre = tostring(plugin.nombre or plugin.nombre_visible or "Plugin sin nombre")
            local version = tostring(plugin.version or plugin.versionName or "Sin versión")
            local descripcion = tostring(plugin.descripcion or "Plugin para administradores")
            local url = plugin.url or plugin.url_base or plugin.url_archivo

            local tarjeta = tarjeta_base()
            agregar_titulo(tarjeta, nombre .. " - versión " .. version, descripcion)

            local boton = Button(ctx)
            boton.setText("Descargar plugin " .. nombre)
            boton.setTextColor(COLOR_TEXTO)
            boton.setBackgroundColor(COLOR_AZUL)
            boton.setContentDescription("Descargar plugin " .. nombre .. ", versión " .. version)
            boton.setOnClickListener(function()
                if not url or tostring(url) == "" then
                    hablar("El plugin no tiene un enlace de descarga")
                    return
                end
                abrir_enlace(url, nombre)
            end)
            tarjeta.addView(boton)
            lista.addView(tarjeta)
            agregar_separador(lista)
        end
    else
        local vacio = TextView(ctx)
        vacio.setText("No hay plugins para administradores.")
        vacio.setTextColor(COLOR_SECUNDARIO)
        vacio.setTextSize(16)
        vacio.setPadding(0, 8, 0, 18)
        lista.addView(vacio)
    end

    local titulo_apps = TextView(ctx)
    titulo_apps.setText("Aplicaciones APK")
    titulo_apps.setTextColor(COLOR_TEXTO)
    titulo_apps.setTextSize(20)
    lista.addView(titulo_apps)

    if type(aplicaciones) == "table" and #aplicaciones > 0 then
        for _, aplicacion in ipairs(aplicaciones) do
            total = total + 1
            local nombre = tostring(aplicacion.nombre or "Aplicación sin nombre")
            local version = tostring(aplicacion.versionName or aplicacion.version or "Sin versión")
            local descripcion = tostring(aplicacion.descripcion or "Aplicación para administradores")
            local url = aplicacion.url or aplicacion.apkUrl

            local tarjeta = tarjeta_base()
            agregar_titulo(tarjeta, nombre .. " - versión " .. version, descripcion)

            local boton = Button(ctx)
            boton.setText("Descargar " .. nombre)
            boton.setTextColor(COLOR_TEXTO)
            boton.setBackgroundColor(COLOR_VERDE)
            boton.setContentDescription("Descargar aplicación " .. nombre .. ", versión " .. version)
            boton.setOnClickListener(function()
                if not url or tostring(url) == "" then
                    hablar("La aplicación no tiene un enlace de descarga")
                    return
                end
                abrir_enlace(url, nombre)
            end)
            tarjeta.addView(boton)
            lista.addView(tarjeta)
            agregar_separador(lista)
        end
    else
        local vacio = TextView(ctx)
        vacio.setText("No hay aplicaciones APK para administradores.")
        vacio.setTextColor(COLOR_SECUNDARIO)
        vacio.setTextSize(16)
        vacio.setPadding(0, 8, 0, 18)
        lista.addView(vacio)
    end

    dialogo.setView(desplazable)
    dialogo.setNegativeButton("Cerrar", function() dialogo.dismiss() end)
    dialogo.show()
    hablar("Tienda de administradores. Hay " .. tostring(total) .. " elementos disponibles")
end

local function cargar_catalogo()
    if not json then
        mostrar_error("Error", "No se encontró una librería JSON compatible.")
        return
    end

    hablar("Cargando tienda de administradores")
    Thread(Runnable{
        run = function()
            local cuerpo, codigo, err = descargar_texto(URL_CATALOGO)
            handler.post(function()
                if err or codigo ~= 200 or not cuerpo or cuerpo == "" then
                    mostrar_error("Error de conexión", "No se pudo cargar tienda-admin.json. Código: " .. tostring(codigo))
                    return
                end

                local ok, datos = pcall(function() return json.decode(cuerpo) end)
                if not ok or type(datos) ~= "table" then
                    mostrar_error("Error del catálogo", "tienda-admin.json no contiene un JSON válido.")
                    return
                end

                mostrar_catalogo(datos)
            end)
        end
    }).start()
end

cargar_catalogo()
return true
