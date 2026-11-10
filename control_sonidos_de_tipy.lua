require "import"
import "android.content.Intent"
import "android.net.Uri"
import "android.os.Build"
import "android.provider.Settings"
import "android.media.AudioManager"
import "android.content.Context"
import "android.os.Vibrator"
import "android.app.AlertDialog"
import "android.view.WindowManager"
import "android.widget.LinearLayout"
import "android.widget.Button"
import "android.widget.TextView"

-- ============ CONTEXTO SEGURO ============
local ctx = activity
if ctx == nil then ctx = service end

local am = ctx.getSystemService(Context.AUDIO_SERVICE)

local function nuevoBuilder()
    local ok, builder = pcall(function()
        return AlertDialog.Builder(ctx)
    end)
    if ok and builder ~= nil then return builder end
    local ok2, b2 = pcall(function()
        return AlertDialog.Builder(ctx, android.R.style.Theme_DeviceDefault_Dialog_Alert)
    end)
    if ok2 then return b2 end
    return nil
end

local function mostrarDialogo(builder)
    local dlg = builder.create()
    if activity == nil then
        dlg.getWindow().setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
    end
    dlg.show()
    return dlg
end

-- ============ PERMISO NO MOLESTAR ============
function tienePermisoNoMolestar()
    if Build.VERSION.SDK_INT >= 23 then
        local nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE)
        return nm.isNotificationPolicyAccessGranted()
    end
    return true
end

function solicitarPermisoNoMolestar()
    local intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    service.startActivity(intent)
    service.asyncSpeak("Activa el acceso a No molestar para este plugin y vuelve a intentarlo.")
end

-- ============ STREAMS DE AUDIO ============
local streams = {
    {id = AudioManager.STREAM_MUSIC, nombre = "Multimedia"},
    {id = AudioManager.STREAM_VOICE_CALL, nombre = "Llamada"},
    {id = AudioManager.STREAM_RING, nombre = "Tono de llamada"},
    {id = AudioManager.STREAM_NOTIFICATION, nombre = "Notificaciones"},
    {id = AudioManager.STREAM_SYSTEM, nombre = "Sistema"},
    {id = AudioManager.STREAM_ALARM, nombre = "Alarmas"},
    {id = AudioManager.STREAM_ACCESSIBILITY, nombre = "Accesibilidad"},
}

-- ============ VARIABLES GLOBALES ============
local dialogoStreamActual = nil
local botonSubir = nil
local botonBajar = nil
local streamActivo = nil

-- ============ SUBIR / BAJAR VOLUMEN ============
function ajustarVolumen(streamId, direccion, nombreStream)
    local ok, err = pcall(function()
        am.adjustStreamVolume(streamId, direccion, AudioManager.FLAG_SHOW_UI)
    end)

    if ok then
        local volActual = am.getStreamVolume(streamId)
        local volMax = am.getStreamMaxVolume(streamId)
        local porcentaje = math.floor((volActual / volMax) * 100)
        service.asyncSpeak(nombreStream .. " al " .. porcentaje .. " por ciento")
        if botonSubir ~= nil and botonBajar ~= nil then
            botonSubir.setText("Subir volumen (actual: " .. porcentaje .. "%)")
            botonBajar.setText("Bajar volumen (actual: " .. porcentaje .. "%)")
        end
    else
        service.asyncSpeak("No se pudo ajustar el volumen: " .. tostring(err))
    end
end

-- ============ MENÚ DE VOLUMEN CON BOTONES ============
function menuVolumenStreamConBotones(stream)
    streamActivo = stream
    local volActual = am.getStreamVolume(stream.id)
    local volMax = am.getStreamMaxVolume(stream.id)
    local porcentaje = math.floor((volActual / volMax) * 100)

    local layout = LinearLayout(ctx)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(30, 30, 30, 30)

    local btnSubir = Button(ctx)
    btnSubir.setText("Subir volumen (actual: " .. porcentaje .. "%)")
    btnSubir.setOnClickListener(function()
        ajustarVolumen(stream.id, AudioManager.ADJUST_RAISE, stream.nombre)
    end)

    local btnBajar = Button(ctx)
    btnBajar.setText("Bajar volumen (actual: " .. porcentaje .. "%)")
    btnBajar.setOnClickListener(function()
        ajustarVolumen(stream.id, AudioManager.ADJUST_LOWER, stream.nombre)
    end)

    botonSubir = btnSubir
    botonBajar = btnBajar

    layout.addView(btnSubir)
    layout.addView(btnBajar)

    local b = nuevoBuilder()
    if not b then return end
    b.setTitle(stream.nombre)
    b.setView(layout)
    b.setNegativeButton("Volver", function()
        dialogoStreamActual = nil
        botonSubir = nil
        botonBajar = nil
        mostrarMenuVolumen()
    end)

    dialogoStreamActual = b.create()
    if activity == nil then
        dialogoStreamActual.getWindow().setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
    end
    dialogoStreamActual.show()

    service.asyncSpeak(stream.nombre .. ", " .. porcentaje .. " por ciento.")
end

-- ============ MENÚ DE SELECCIÓN DE STREAM ============
function mostrarMenuVolumen()
    local nombres = {}
    for _, s in ipairs(streams) do
        table.insert(nombres, s.nombre)
    end
    table.insert(nombres, "Volver al menú principal")

    local b = nuevoBuilder()
    if not b then
        service.asyncSpeak("No se pudo crear el menú.")
        return
    end
    b.setTitle("Control de volumen")
    b.setItems(nombres, function(d, which)
        if which == #streams then
            mostrarMenuPrincipal()
        else
            menuVolumenStreamConBotones(streams[which + 1])
        end
    end)
    b.setNegativeButton("Cerrar", nil)
    mostrarDialogo(b)
    service.asyncSpeak("Elige el tipo de volumen que quieres ajustar.")
end

-- ============ MODO DE SONIDO ============
function cambiarModoSonido(modo, nombreModo)
    if not tienePermisoNoMolestar() then
        solicitarPermisoNoMolestar()
        return
    end
    local ok, err = pcall(function()
        am.setRingerMode(modo)
    end)
    if ok then
        service.asyncSpeak("Modo " .. nombreModo .. " activado.")
    else
        service.asyncSpeak("No se pudo cambiar el modo: " .. tostring(err))
    end
end

function mostrarMenuModoSonido()
    local modoActual = am.getRingerMode()
    local nombreActual = "Normal"
    if modoActual == AudioManager.RINGER_MODE_VIBRATE then
        nombreActual = "Vibración"
    elseif modoActual == AudioManager.RINGER_MODE_SILENT then
        nombreActual = "Silencio"
    end

    local opciones = {"Normal", "Vibración", "Silencio"}

    local b = nuevoBuilder()
    if not b then
        service.asyncSpeak("No se pudo crear el menú.")
        return
    end
    b.setTitle("Modo de sonido (actual: " .. nombreActual .. ")")
    b.setItems(opciones, function(d, which)
        if which == 0 then
            cambiarModoSonido(AudioManager.RINGER_MODE_NORMAL, "Normal")
        elseif which == 1 then
            cambiarModoSonido(AudioManager.RINGER_MODE_VIBRATE, "Vibración")
        else
            cambiarModoSonido(AudioManager.RINGER_MODE_SILENT, "Silencio")
        end
    end)
    b.setNegativeButton("Volver", function()
        mostrarMenuPrincipal()
    end)
    mostrarDialogo(b)
    service.asyncSpeak("Modo actual: " .. nombreActual .. ". Elige Normal, Vibración o Silencio.")
end

-- ============ INSTRUCCIONES ============
local TEXTO_INSTRUCCIONES = "Instrucciones del plugin Control de sonido: " ..
    "En el menú principal tienes dos opciones: Ajustar volumen y Modo de sonido. " ..
    "Ajustar volumen te permite elegir entre Multimedia, Llamada, Tono de llamada, Notificaciones, Sistema, Alarmas y Accesibilidad. " ..
    "Al entrar a un tipo de volumen verás dos botones: Subir volumen y Bajar volumen. Puedes tocar varias veces seguidas para ajustar paso a paso sin que el foco salga del botón. " ..
    "El porcentaje actual se verbaliza después de cada ajuste. " ..
    "Modo de sonido te permite cambiar entre Normal, Vibración y Silencio. Si el sistema pide permiso de No molestar, el plugin te llevará a activarlo. " ..
    "Toca Aceptar para volver al menú."

local function mostrarInstrucciones()
    local b = nuevoBuilder()
    if not b then
        service.asyncSpeak(TEXTO_INSTRUCCIONES)
        return
    end
    b.setTitle("Instrucciones")
    b.setMessage(TEXTO_INSTRUCCIONES)
    b.setPositiveButton("Aceptar", function()
        mostrarMenuPrincipal()
    end)
    mostrarDialogo(b)
    service.asyncSpeak(TEXTO_INSTRUCCIONES)
end

-- ============ ACERCA DE ============
local TEXTO_ACERCA_DE = "Configuración de sonido, versión 1.0. " ..
    "Desarrollado por la Administración de Tecnología Inclusiva Paraguay. " ..
    "Con la colaboración de los administradores: Miguel Benítez, Alejandro Romero, " ..
    "Samuel López, Néstor Ayala y Sara González, creadora del grupo Tecnología Inclusiva Paraguay. " ..
    "Este plugin permite ajustar el volumen de multimedia, llamada, notificaciones, sistema, alarmas y accesibilidad, " ..
    "y también cambiar entre modo Normal, Vibración y Silencio."

local function mostrarAcercaDe()
    local b = nuevoBuilder()
    if not b then
        service.asyncSpeak(TEXTO_ACERCA_DE)
        return
    end
    b.setTitle("Acerca de")
    b.setMessage(TEXTO_ACERCA_DE)
    b.setPositiveButton("Aceptar", function()
        mostrarMenuPrincipal()
    end)
    mostrarDialogo(b)
    service.asyncSpeak(TEXTO_ACERCA_DE)
end

-- ============ MENÚ PRINCIPAL ============
function mostrarMenuPrincipal()
    local opciones = {
        "Ajustar volumen",
        "Modo de sonido (Normal/Vibración/Silencio)",
        "Instrucciones",
        "Acerca de"
    }

    local b = nuevoBuilder()
    if not b then
        service.asyncSpeak("No se pudo crear el menú.")
        return
    end
    b.setTitle("Configuración de sonido")
    b.setItems(opciones, function(d, which)
        if which == 0 then
            mostrarMenuVolumen()
        elseif which == 1 then
            mostrarMenuModoSonido()
        elseif which == 2 then
            mostrarInstrucciones()
        else
            mostrarAcercaDe()
        end
    end)
    b.setNegativeButton("Cerrar", nil)
    mostrarDialogo(b)
    service.asyncSpeak("Configuración de sonido. Elige una opción.")
end

-- ============ EJECUCIÓN ============
mostrarMenuPrincipal()

-- Vibrar
local vibrator = ctx.getSystemService(Context.VIBRATOR_SERVICE)
if vibrator and vibrator.hasVibrator() then
    vibrator.vibrate(70)
end

return true