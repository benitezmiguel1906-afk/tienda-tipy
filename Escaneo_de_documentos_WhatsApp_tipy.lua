require "import"

-- 1. Bienvenida por voz
service.speak("Bienvenido al plugin Escanear Documentos, del grupo Tecnología Inclusiva Paraguay. Colaboradores: Samuel López, Alejandro Romero, Miguel Benítez, Néstor Ayala. Sara González, creadora del grupo Tecnología Inclusiva Paraguay.")

-- 2. Primera ventana: botón para escuchar instrucciones y continuar
local dlgBienvenida = LuaDialog()
.setTitle("Escanear Documentos")
.setItems({"Escuchar instrucciones y escanear"})
.show()

dlgBienvenida.onItemClick = function(l, v, p, i)
    dlgBienvenida.dismiss()
    
    -- 3. Se lee la instrucción por voz (esto empieza a sonar)
    service.speak("Instrucciones. Abre el chat del contacto o grupo donde quieres enviar el documento. Luego el plugin ejecutará automáticamente los pasos para escanear. Al entrar en la cámara de escaneo, la pestaña Automático estará activada. Desliza hacia la derecha al lado del botón de capturar y selecciona la pestaña Manual. Después enfoca la hoja y captura la imagen. Cuando termines, el PDF se guarda en la carpeta WhatsApp Document.")
    
    -- 4. INMEDIATAMENTE se muestra la segunda ventana con el botón de escanear.
    -- La voz de instrucciones seguirá sonando mientras esta ventana está visible.
    local dlgAccion = LuaDialog()
    .setTitle("Listo para escanear")
    .setItems({"Empezar a escanear documentos"})
    .show()
    
    dlgAccion.onItemClick = function(l2, v2, p2, i2)
        dlgAccion.dismiss()
        
        -- 5. SOLO al pulsar este botón se ejecuta el clic automático en WhatsApp
        if service.click({
            {"Adjuntar>5$500",
            "%[Deslizar a la derecha (toque directo)]",
            "Documento>5$500",
            "%[Deslizar a la derecha (toque directo)]",
            "Escanear documento>5$500",
            }
        })
            return true
        end
    end
    
    return true
end

return true