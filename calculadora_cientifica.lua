require "import"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.widget.Button"
import "android.widget.EditText"
import "android.widget.ScrollView"
import "com.androlua.LuaDialog"

-- Capturamos el contexto de forma segura para Jieshuo
local ctx = activity or service.getContext() or service

local function abrirCalculadora()
    -- Diseño de la ventana
    local layout = {
        LinearLayout,
        orientation = "vertical",
        layout_width = "match_parent",
        layout_height = "match_parent",
        padding = "16dp",
        {
            TextView,
            text = "Calculadora Científica Accesible",
            textSize = "20sp",
            layout_marginBottom = "16dp"
        },
        {
            EditText,
            id = "num1",
            hint = "Ingrese primer número",
            layout_width = "fill",
            layout_height = "wrap_content",
            inputType = "numberDecimal",
            layout_marginBottom = "8dp"
        },
        {
            EditText,
            id = "num2",
            hint = "Ingrese segundo número",
            layout_width = "fill",
            layout_height = "wrap_content",
            inputType = "numberDecimal",
            layout_marginBottom = "16dp"
        },
        {
            LinearLayout,
            orientation = "horizontal",
            layout_width = "fill",
            layout_height = "wrap_content",
            layout_marginBottom = "8dp",
            {
                Button,
                id = "btnSumar",
                text = "Sumar",
                layout_width = "0dp",
                layout_height = "wrap_content",
                layout_weight = 1
            },
            {
                Button,
                id = "btnRestar",
                text = "Restar",
                layout_width = "0dp",
                layout_height = "wrap_content",
                layout_weight = 1,
                layout_marginLeft = "8dp"
            },
            {
                Button,
                id = "btnMultiplicar",
                text = "Multiplicar",
                layout_width = "0dp",
                layout_height = "wrap_content",
                layout_weight = 1,
                layout_marginLeft = "8dp"
            }
        },
        {
            Button,
            id = "btnDividir",
            text = "Dividir",
            layout_width = "fill",
            layout_height = "wrap_content",
            layout_marginBottom = "16dp"
        }
    }

    -- Creamos el diálogo usando LuaDialog (compatible con Jieshuo)
    local d = LuaDialog(ctx)
    d.setTitle("Calculadora")
    d.setView(loadlayout(layout))
    d.setPositiveButton("Cerrar", function()
        d.dismiss()
    end)
    d.show()

    -- Lógica de los botones
    btnSumar.onClick = function()
        local n1 = tonumber(num1.text)
        local n2 = tonumber(num2.text)
        if n1 and n2 then
            local res = n1 + n2
            service.speak("El resultado de la suma es " .. res)
        else
            service.speak("Por favor ingrese números válidos")
        end
    end

    btnRestar.onClick = function()
        local n1 = tonumber(num1.text)
        local n2 = tonumber(num2.text)
        if n1 and n2 then
            local res = n1 - n2
            service.speak("El resultado de la resta es " .. res)
        else
            service.speak("Por favor ingrese números válidos")
        end
    end

    btnMultiplicar.onClick = function()
        local n1 = tonumber(num1.text)
        local n2 = tonumber(num2.text)
        if n1 and n2 then
            local res = n1 * n2
            service.speak("El resultado de la multiplicación es " .. res)
        else
            service.speak("Por favor ingrese números válidos")
        end
    end

    btnDividir.onClick = function()
        local n1 = tonumber(num1.text)
        local n2 = tonumber(num2.text)
        if n1 and n2 then
            if n2 == 0 then
                service.speak("No se puede dividir entre cero")
            else
                local res = n1 / n2
                service.speak("El resultado de la división es " .. res)
            end
        else
            service.speak("Por favor ingrese números válidos")
        end
    end
end

-- Llamamos a la función y avisamos por voz
abrirCalculadora()
service.speak("Calculadora cargada correctamente")

return true
