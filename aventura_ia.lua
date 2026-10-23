require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.os.Handler"
import "android.os.Looper"
import "com.androlua.Http"
import "com.androlua.LuaDialog"
import "cjson"
import "java.io.File"

local handler = Handler(Looper.getMainLooper())

-- Poner en false para desactivar la precarga de escenas
local PRECARGAR = true

local STRINGS = {
    dialog_title = "Aventura Mágica con IA",
    dlg_config_title = "Gestionar Clave API de Gemini",
    hint_api_key = "Pega aquí tu clave API de Google AI Studio...",
    btn_save_key = "Guardar y Volver",
    btn_config = "⚙️ Gestionar Clave API",
    btn_exit = "Salir del juego",
    msg_loading = "Generando la siguiente escena.",
    msg_key_saved = "¡Clave API actualizada!"
}

local rutaArchivoConfig = service.getLuaDir() .. "/gemini_api_key.txt"

local function limpiarClave(texto)
    local limpia = texto:gsub("%s+", "")
    limpia = limpia:gsub('"', "")
    limpia = limpia:gsub("'", "")
    return limpia
end

local function cargarApiKeyLocal()
    local archivo = io.open(rutaArchivoConfig, "r")
    if archivo then
        local clave = archivo:read("*all")
        archivo:close()
        clave = limpiarClave(clave)
        if clave ~= "" then return clave end
    end
    return nil
end

local function guardarApiKeyLocal(clave)
    local claveLimpia = limpiarClave(clave)
    local archivo = io.open(rutaArchivoConfig, "w")
    if archivo then
        archivo:write(claveLimpia)
        archivo:close()
        return true
    end
    return false
end

local API_KEY = cargarApiKeyLocal() or ""

-- Modelos con rotación automática, del más rápido al más lento
local modelos_disponibles = {
    { nombre = "gemini-3.5-flash-lite", thinking = { thinkingLevel = "minimal" } },
    { nombre = "gemini-3.8-flash",      thinking = { thinkingLevel = "minimal" } },
    { nombre = "gemini-3.6-flash",      thinking = { thinkingLevel = "minimal" } },
    { nombre = "gemini-2.5-flash",      thinking = { thinkingBudget = 0 } }
}

local estadoHistoriaActual = "Te despiertas en una mazmorra húmeda. Una antorcha parpadea y hay una puerta al frente."
local opcionesActuales = {
    "1. Forzar la puerta.",
    "2. Inspeccionar la antorcha.",
    "3. Gritar pidiendo auxilio.",
    "4. Buscar bajo la cama."
}

local mostrarEscenaIA
local mostrarVentanaConfiguracion
local mostrarVentanaErrorCopiable
local dlgActual = nil

-- Precarga de escenas
local cacheActual = {}
local cacheEstado = nil

mostrarVentanaErrorCopiable = function(textoError)
    if dlgActual then pcall(function() dlgActual.dismiss() end) dlgActual = nil end
    service.speak("Ocurrió un error.")

    local layoutError = {
        LinearLayout, orientation="vertical", padding="20dp", layout_width="fill", layout_height="wrap",
        { TextView, text="Detalle del Error (Copia y envía esto al desarrollador)", textSize="18sp", layout_marginBottom="10dp" },
        { EditText, text=textoError, layout_width="fill", layout_height="150dp", gravity="top", textIsSelectable=true, layout_marginBottom="15dp" },
        { Button, id="btnVolver", text="Volver al Juego", layout_width="fill", layout_marginBottom="8dp" },
        { Button, id="btnConfigErr", text=STRINGS.btn_config, layout_width="fill" }
    }

    local view = loadlayout(layoutError)
    dlgActual = LuaDialog(service)
    dlgActual.setView(view)

    btnVolver.onClick = function() dlgActual.dismiss() mostrarEscenaIA() end
    btnConfigErr.onClick = function() dlgActual.dismiss() mostrarVentanaConfiguracion() end
    dlgActual.show()
end

mostrarVentanaConfiguracion = function()
    if dlgActual then pcall(function() dlgActual.dismiss() end) dlgActual = nil end
    service.speak("Pantalla de configuración. Introduce tu clave API.")

    local layoutConfig = {
        LinearLayout, orientation="vertical", padding="20dp", layout_width="fill", layout_height="wrap",
        { TextView, text=STRINGS.dlg_config_title, textSize="18sp", layout_marginBottom="10dp" },
        { EditText, id="campoClave", hint=STRINGS.hint_api_key, text=API_KEY, layout_width="fill", layout_height="wrap", layout_marginBottom="15dp" },
        { Button, id="btnGuardar", text=STRINGS.btn_save_key, layout_width="fill", layout_marginBottom="8dp" },
        { Button, id="btnCancelar", text="Cancelar / Volver al Juego", layout_width="fill" }
    }

    local view = loadlayout(layoutConfig)
    dlgActual = LuaDialog(service)
    dlgActual.setView(view)

    btnGuardar.onClick = function()
        local textoIngresado = tostring(campoClave.getText().toString())
        local nuevaClave = limpiarClave(textoIngresado)
        if nuevaClave ~= "" then
            if guardarApiKeyLocal(nuevaClave) then
                API_KEY = nuevaClave
                service.speak(STRINGS.msg_key_saved)
                dlgActual.dismiss()
                mostrarEscenaIA()
            else
                service.speak("Error al guardar la clave.")
            end
        else
            service.speak("La clave no puede estar vacía.")
        end
    end

    btnCancelar.onClick = function() dlgActual.dismiss() mostrarEscenaIA() end
    dlgActual.show()
end

-- Une todas las partes de texto de la respuesta, ignorando las de razonamiento
local function extraerTexto(resultado)
    local candidato = resultado.candidates[1]
    if not candidato or not candidato.content or not candidato.content.parts then
        return nil
    end
    local textos = {}
    for _, parte in ipairs(candidato.content.parts) do
        if parte.text and not parte.thought then
            table.insert(textos, parte.text)
        end
    end
    if #textos == 0 then return nil end
    return table.concat(textos, "\n")
end

-- Convierte el texto de la IA en historia y cuatro opciones
local function parsearRespuesta(respuestaIA)
    local nuevaHistoria = string.match(respuestaIA, "HISTORIA:%s*(.-)%s*OPCION 1:")
    local op1 = string.match(respuestaIA, "OPCION 1:%s*(.-)%s*OPCION 2:")
    local op2 = string.match(respuestaIA, "OPCION 2:%s*(.-)%s*OPCION 3:")
    local op3 = string.match(respuestaIA, "OPCION 3:%s*(.-)%s*OPCION 4:")
    local op4 = string.match(respuestaIA, "OPCION 4:%s*(.*)")

    if nuevaHistoria and op1 and op2 and op3 and op4 then
        return nuevaHistoria, { "1. " .. op1, "2. " .. op2, "3. " .. op3, "4. " .. op4 }
    end
    return respuestaIA, { "1. Continuar.", "2. Retroceder.", "3. Mirar alrededor.", "4. Esperar." }
end

-- Pide una escena a Gemini con rotación de modelos.
-- alTerminar(ok, historia, opciones) si ok es true; alTerminar(false, textoError) si falla.
local function pedirEscena(historiaBase, eleccion, rondasMax, alTerminar, index_modelo, intento, ultimoError, ultimoCodigo)
    index_modelo = index_modelo or 1
    intento = intento or 1

    local config_modelo = modelos_disponibles[index_modelo]
    if not config_modelo then
        if (ultimoCodigo == 503 or ultimoCodigo == 429) and intento < rondasMax then
            handler.postDelayed(Runnable({
                run = function()
                    pedirEscena(historiaBase, eleccion, rondasMax, alTerminar, 1, intento + 1, ultimoError, ultimoCodigo)
                end
            }), 2000)
        else
            alTerminar(false, "Ningún modelo respondió.\n" .. tostring(ultimoError))
        end
        return
    end

    local modelo_actual = config_modelo.nombre
    local url_api = "https://generativelanguage.googleapis.com/v1beta/models/" .. modelo_actual .. ":generateContent?key=" .. API_KEY

    local promptCompleto = "Eres el narrador de una aventura. Situación actual: " .. historiaBase ..
                           "\nEl jugador eligió: " .. eleccion ..
                           "\nContinúa la historia en máximo 2 oraciones cortas. LUEGO, escribe exactamente 4 opciones cortas usando ESTRICTAMENTE este formato (sin asteriscos, sin negritas):\n" ..
                           "HISTORIA: (texto)\n" ..
                           "OPCION 1: (texto)\nOPCION 2: (texto)\nOPCION 3: (texto)\nOPCION 4: (texto)"

    local datosJson = cjson.encode({
        contents = { { parts = { { text = promptCompleto } } } },
        generationConfig = {
            maxOutputTokens = 400,
            thinkingConfig = config_modelo.thinking
        }
    })

    local headers = { ["Content-Type"] = "application/json" }

    Http.post(url_api, datosJson, headers, function(code, body)
        handler.post(function()
            if code == 200 then
                local success, resultado = pcall(cjson.decode, body)
                local respuestaIA = nil
                if success and resultado and resultado.candidates then
                    respuestaIA = extraerTexto(resultado)
                end

                if respuestaIA then
                    local historia, opciones = parsearRespuesta(respuestaIA)
                    alTerminar(true, historia, opciones)
                else
                    alTerminar(false, "Error al leer respuesta de Gemini.\nModelo: " .. modelo_actual .. "\n" .. tostring(body))
                end
            elseif code == 503 or code == 429 or code == 404 or code == 400 then
                local detalle = "Modelo: " .. modelo_actual .. "\nHTTP " .. tostring(code) .. "\n" .. tostring(body)
                pedirEscena(historiaBase, eleccion, rondasMax, alTerminar, index_modelo + 1, intento, detalle, code)
            else
                local msjError = "Fallo de conexión o red.\nModelo: " .. modelo_actual .. "\n"
                if not code then
                    msjError = msjError .. "El dispositivo no pudo conectar con los servidores de Google. Revisa tu conexión a internet o usa una VPN."
                else
                    msjError = msjError .. "HTTP " .. tostring(code) .. "\n" .. tostring(body)
                end
                alTerminar(false, msjError)
            end
        end)
    end)
end

-- Pide en segundo plano las cuatro escenas posibles de la escena actual
local function precargarEscenas()
    if not PRECARGAR or API_KEY == "" then return end
    if cacheEstado == estadoHistoriaActual then return end

    cacheEstado = estadoHistoriaActual
    local miCache = {}
    cacheActual = miCache

    local historiaBase = estadoHistoriaActual
    local opciones = opcionesActuales

    for i = 1, 4 do
        miCache[i] = { estado = "pendiente" }
        pedirEscena(historiaBase, opciones[i], 1, function(ok, a, b)
            local entrada = miCache[i]
            if ok then
                entrada.estado = "listo"
                entrada.datos = { historia = a, opciones = b }
            else
                entrada.estado = "error"
            end
            if entrada.alTerminar then
                local f = entrada.alTerminar
                entrada.alTerminar = nil
                f(ok, a, b)
            end
        end)
    end
end

local function aplicarEscena(historia, opciones)
    estadoHistoriaActual = historia
    opcionesActuales = opciones
    mostrarEscenaIA()
end

mostrarEscenaIA = function()
    if API_KEY == "" then mostrarVentanaConfiguracion() return end
    if dlgActual then pcall(function() dlgActual.dismiss() end) dlgActual = nil end

    service.speak(estadoHistoriaActual)

    local layoutJuego = {
        LinearLayout, orientation="vertical", padding="20dp", layout_width="fill", layout_height="match_parent",
        { TextView, text=STRINGS.dialog_title, textSize="18sp", layout_marginBottom="10dp" },
        {
            ScrollView, layout_width="fill", layout_height="0dp", layout_weight=1, layout_marginBottom="15dp",
            { TextView, id="txtHistoria", text=estadoHistoriaActual, textSize="16sp" }
        },
        { Button, id="btnOp1", text=opcionesActuales[1], layout_width="fill", layout_marginBottom="8dp" },
        { Button, id="btnOp2", text=opcionesActuales[2], layout_width="fill", layout_marginBottom="8dp" },
        { Button, id="btnOp3", text=opcionesActuales[3], layout_width="fill", layout_marginBottom="8dp" },
        { Button, id="btnOp4", text=opcionesActuales[4], layout_width="fill", layout_marginBottom="15dp" },
        { Button, id="btnConfig", text=STRINGS.btn_config, layout_width="fill", layout_marginBottom="8dp" },
        { Button, id="btnExit", text=STRINGS.btn_exit, layout_width="fill" }
    }

    local view = loadlayout(layoutJuego)
    dlgActual = LuaDialog(service)
    dlgActual.setView(view)
    dlgActual.show()

    precargarEscenas()

    local function elegirOpcion(index)
        dlgActual.dismiss()
        local entrada = cacheActual[index]

        if entrada and entrada.estado == "listo" then
            aplicarEscena(entrada.datos.historia, entrada.datos.opciones)
        elseif entrada and entrada.estado == "pendiente" then
            service.speak(STRINGS.msg_loading)
            entrada.alTerminar = function(ok, a, b)
                if ok then
                    aplicarEscena(a, b)
                else
                    mostrarVentanaErrorCopiable(tostring(a))
                end
            end
        else
            service.speak(STRINGS.msg_loading)
            pedirEscena(estadoHistoriaActual, opcionesActuales[index], 3, function(ok, a, b)
                if ok then
                    aplicarEscena(a, b)
                else
                    mostrarVentanaErrorCopiable(tostring(a))
                end
            end)
        end
    end

    btnOp1.onClick = function() elegirOpcion(1) end
    btnOp2.onClick = function() elegirOpcion(2) end
    btnOp3.onClick = function() elegirOpcion(3) end
    btnOp4.onClick = function() elegirOpcion(4) end
    btnConfig.onClick = function() dlgActual.dismiss() mostrarVentanaConfiguracion() end
    btnExit.onClick = function() dlgActual.dismiss() end
end

if API_KEY == "" then
    mostrarVentanaConfiguracion()
else
    mostrarEscenaIA()
end
