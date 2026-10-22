-- Calculadora Científica Accesible
-- Plugin de prueba para validar la tienda

import "android.widget.*"
import "android.app.AlertDialog"

local function abrirCalculadora()
    local layout = {
        LinearLayout,
        orientation="vertical",
        layout_width="fill",
        layout_height="fill",
        padding="16dp",
        {
            TextView,
            text="Calculadora Científica Accesible",
            textSize="20sp",
            layout_marginBottom="16dp"
        },
        {
            EditText,
            id="num1",
            hint="Ingrese primer número",
            layout_width="fill",
            layout_height="wrap_content"
        },
        {
            EditText,
            id="num2",
            hint="Ingrese segundo número",
            layout_width="fill",
            layout_height="wrap_content"
        },
        {
            Button,
            text="Sumar",
            layout_width="fill",
            layout_height="wrap_content",
            onClick=function()
                local n1 = tonumber(num1.text)
                local n2 = tonumber(num2.text)
                if n1 and n2 then
                    local res = n1 + n2
                    service.speak("El resultado de la suma es " .. res)
                else
                    service.speak("Por favor ingrese números válidos")
                end
            end
        }
    }
    AlertDialog.Builder(activity)
    .setTitle("Calculadora")
    .setView(loadlayout(layout))
    .setPositiveButton("Cerrar", nil)
    .show()
end

-- Iniciar calculadora al cargar
abrirCalculadora()
service.speak("Calculadora Científica instalada y ejecutada correctamente")
return true
