require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.net.Uri"
import "android.graphics.Color"
import "com.androlua.*"
import "cjson"
import "com.androlua.Http"

-- 1. CONFIGURACION Y PREFERENCIAS
local ctx = activity or service or this
local pref = ctx.getSharedPreferences("mixtral_plus_prefs", 0)

local function guardar(clave, valor)
  pref.edit().putString(clave, tostring(valor)).apply()
end

local function leer(clave, defecto)
  return pref.getString(clave, defecto)
end

local current_api_key = leer("api_key", "")
local API_URL = "https://api.mistral.ai/v1/chat/completions"
local MODELS_URL = "https://api.mistral.ai/v1/models"
local URL_CLAVES = "https://console.mistral.ai/api-keys/"

local model_list = {"open-mixtral-8x7b", "mistral-small-latest", "mistral-medium-latest"}
local selected_model = leer("modelo", model_list[1])

local temp_list = {"0.2", "0.5", "0.7", "1.0"}
local tokens_list = {"256", "512", "1024", "2048"}
local temp_idx = tonumber(leer("temp_idx", "3")) or 3
local tokens_idx = tonumber(leer("tokens_idx", "3")) or 3

local SISTEMA = "Respondé siempre en español, de forma breve y clara, sin tablas ni formato visual."
local lectura_auto = leer("lectura_auto", "1") == "1"
local total_tokens = math.floor(tonumber(leer("total_tokens", "0")) or 0)

local historial = {}
local ultima_respuesta = ""
local ocupado = false
local MAX_HISTORIAL = 20

-- 2. FUNCIONES AUXILIARES
local function hablar(texto)
  if service and service.asyncSpeak then
    service.asyncSpeak(texto)
  end
end

local function pintar(boton, colorHex)
  boton.setBackgroundColor(Color.parseColor(colorHex))
  boton.setTextColor(Color.WHITE)
end

local function abrirNavegador(url)
  local ok, err = pcall(function()
    local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    ctx.startActivity(intent)
  end)
  if ok then
    hablar("Abriendo la página de Mistral")
  else
    hablar("No se pudo abrir el navegador")
    print("Error al abrir navegador: " .. tostring(err))
  end
end

local function describirError(code)
  code = tonumber(code) or 0
  if code == 401 then
    return "Clave de API inválida. Usá el botón Configurar clave."
  elseif code == 429 then
    return "Límite de uso alcanzado. Esperá un momento e intentá de nuevo."
  elseif code == 400 then
    return "Solicitud incorrecta. Revisá el modelo o el mensaje."
  elseif code >= 500 then
    return "El servidor de Mistral tiene problemas. Probá más tarde."
  elseif code <= 0 then
    return "Sin conexión a internet."
  end
  return "Error " .. code
end

local function actualizarContador(ultimo)
  local texto = "Total acumulado: " .. total_tokens .. " tokens."
  if ultimo then
    texto = "Último gasto: " .. math.floor(ultimo) .. " tokens. " .. texto
  end
  txtTokens.setText(texto)
end

local function mostrarRespuesta(texto)
  txtResponse.setText(texto)
  scrollResp.post(function()
    scrollResp.fullScroll(View.FOCUS_UP)
  end)
end

local function copiarAlPortapapeles(texto)
  local cm = ctx.getSystemService("clipboard")
  cm.setPrimaryClip(ClipData.newPlainText("Respuesta", texto))
end

local function leerPortapapeles()
  local cm = ctx.getSystemService("clipboard")
  local clip = cm.getPrimaryClip()
  if clip and clip.getItemCount() > 0 then
    local item = clip.getItemAt(0)
    local t = item.getText()
    if t then return tostring(t) end
  end
  return ""
end

local function updateSpinner(spinner, list)
  local adapter = ArrayAdapter(ctx, android.R.layout.simple_spinner_item, list)
  adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  spinner.setAdapter(adapter)
  local encontrado = false
  for i, nombre in ipairs(list) do
    if nombre == selected_model then
      spinner.setSelection(i - 1)
      encontrado = true
    end
  end
  if not encontrado and #list > 0 then
    selected_model = list[1]
    spinner.setSelection(0)
  end
end

local function reloadModels(spinner)
  if current_api_key == "" then return end
  local headers = { ["Authorization"] = "Bearer " .. current_api_key }
  Http.get(MODELS_URL, "", "UTF-8", headers, function(code, body)
    if code == 200 then
      local ok, data = pcall(cjson.decode, body)
      if ok and data.data then
        local nuevos = {}
        for _, m in ipairs(data.data) do
          if m.id and (m.id:find("mistral") or m.id:find("mixtral")) then
            table.insert(nuevos, m.id)
          end
        end
        if #nuevos > 0 then
          table.sort(nuevos)
          model_list = nuevos
          updateSpinner(spinner, model_list)
          hablar("Lista de modelos actualizada")
        end
      end
    else
      hablar(describirError(code))
    end
  end)
end

local mostrarDialogoClave

local function sendMessage(mensaje)
  if ocupado then
    hablar("Espere, hay una consulta en curso")
    return
  end
  if mensaje == nil or mensaje:match("^%s*$") then
    hablar("Escribí un mensaje primero")
    return
  end
  if current_api_key == "" then
    hablar("Falta la clave de API")
    mostrarDialogoClave()
    return
  end

  guardar("modelo", selected_model)

  table.insert(historial, {role = "user", content = mensaje})
  while #historial > MAX_HISTORIAL do
    table.remove(historial, 1)
  end

  local mensajes = {{role = "system", content = SISTEMA}}
  for _, m in ipairs(historial) do
    table.insert(mensajes, m)
  end

  local headers = {
    ["Authorization"] = "Bearer " .. current_api_key,
    ["Content-Type"] = "application/json"
  }

  local post_data = cjson.encode({
    model = selected_model,
    messages = mensajes,
    temperature = tonumber(temp_list[temp_idx]) or 0.7,
    max_tokens = tonumber(tokens_list[tokens_idx]) or 1024
  })

  ocupado = true
  editMsg.setText("")
  mostrarRespuesta("Pensando...")
  hablar("Enviando consulta. Esperando respuesta.")

  Http.post(API_URL, post_data, "UTF-8", headers, function(code, body)
    ocupado = false
    if code == 200 then
      local ok, res = pcall(cjson.decode, body)
      if ok and res.choices and res.choices[1] and res.choices[1].message then
        local respuesta = res.choices[1].message.content or ""
        local gastados = 0
        if res.usage and res.usage.total_tokens then
          gastados = math.floor(res.usage.total_tokens)
        end
        total_tokens = total_tokens + gastados
        guardar("total_tokens", total_tokens)
        ultima_respuesta = respuesta
        table.insert(historial, {role = "assistant", content = respuesta})
        mostrarRespuesta(respuesta)
        actualizarContador(gastados)
        if lectura_auto then
          hablar(respuesta)
        else
          hablar("Respuesta recibida")
        end
      else
        table.remove(historial)
        mostrarRespuesta("Error al procesar la respuesta.")
        hablar("Error al procesar la respuesta")
      end
    else
      table.remove(historial)
      local motivo = describirError(code)
      mostrarRespuesta(motivo)
      hablar(motivo)
    end
  end)
end

mostrarDialogoClave = function()
  local campo = EditText(ctx)
  campo.setHint("Pegá aquí tu clave de API de Mistral")
  campo.setText(current_api_key)
  local okd, errd = pcall(function()
    LuaDialog(ctx)
      .setTitle("Configurar clave de API")
      .setView(campo)
      .setButton("Guardar", function()
        local nueva = campo.getText().toString():gsub("%s+", "")
        current_api_key = nueva
        guardar("api_key", nueva)
        hablar("Clave guardada")
        if nueva ~= "" and modelSpinner then
          reloadModels(modelSpinner)
        end
      end)
      .show()
  end)
  if not okd then
    hablar("No se pudo abrir el diálogo de la clave")
    print("Error en diálogo de clave: " .. tostring(errd))
  end
end

-- 3. INTERFAZ PRINCIPAL
local mainLayout = {
  ScrollView,
  layout_width = "match_parent",
  layout_height = "wrap_content",
  {
    LinearLayout,
    orientation = "vertical",
    layout_width = "match_parent",
    layout_height = "wrap_content",
    padding = "16dp",
    {
      TextView,
      text = "Mixtral Bot con Medidor",
      textSize = "20sp",
      layout_gravity = "center",
      textColor = "#ff3d00"
    },
    {
      TextView,
      id = "txtTokens",
      text = "Total acumulado: 0 tokens.",
      textSize = "12sp"
    },
    {
      Button,
      id = "btnObtener",
      text = "Obtener clave en Mistral",
      layout_width = "match_parent"
    },
    {
      Button,
      id = "btnClave",
      text = "Configurar clave",
      layout_width = "match_parent"
    },
    {
      LinearLayout,
      layout_width = "match_parent",
      {
        Spinner,
        id = "modelSpinner",
        layout_weight = "1",
        contentDescription = "Modelo"
      },
      {
        Button,
        id = "btnActualizar",
        text = "Act"
      }
    },
    {
      TextView,
      text = "Temperatura",
      textSize = "14sp"
    },
    {
      Spinner,
      id = "tempSpinner",
      layout_width = "match_parent",
      contentDescription = "Temperatura"
    },
    {
      TextView,
      text = "Longitud máxima de respuesta en tokens",
      textSize = "14sp"
    },
    {
      Spinner,
      id = "tokensSpinner",
      layout_width = "match_parent",
      contentDescription = "Longitud máxima de respuesta"
    },
    {
      CheckBox,
      id = "chkAuto",
      text = "Leer respuesta automáticamente",
      layout_width = "match_parent"
    },
    {
      EditText,
      id = "editMsg",
      hint = "Escribe aquí...",
      layout_width = "match_parent"
    },
    {
      Button,
      id = "btnEnviar",
      text = "Enviar Consulta",
      layout_width = "match_parent"
    },
    {
      Button,
      id = "btnPegar",
      text = "Pegar y enviar",
      layout_width = "match_parent"
    },
    {
      Button,
      id = "btnCopiar",
      text = "Copiar respuesta",
      layout_width = "match_parent"
    },
    {
      Button,
      id = "btnLeer",
      text = "Leer de nuevo",
      layout_width = "match_parent"
    },
    {
      Button,
      id = "btnNueva",
      text = "Nueva conversación",
      layout_width = "match_parent"
    },
    {
      ScrollView,
      id = "scrollResp",
      layout_width = "match_parent",
      layout_height = "300dp",
      {
        TextView,
        id = "txtResponse",
        text = "Esperando...",
        textSize = "16sp",
        padding = "8dp",
        layout_width = "match_parent",
        layout_height = "wrap_content",
        textIsSelectable = true
      }
    }
  }
}

local dlg
local ok, err = pcall(function()
  dlg = LuaDialog(ctx)
    .setView(loadlayout(mainLayout))
    .setButton("Cerrar", nil)
    .show()
end)

if not ok then
  print("Error al abrir diálogo: " .. tostring(err))
  return false
end

-- 4. COLORES DE BOTONES
pintar(btnObtener, "#E65100")
pintar(btnClave, "#1565C0")
pintar(btnActualizar, "#455A64")
pintar(btnEnviar, "#2E7D32")
pintar(btnPegar, "#00897B")
pintar(btnCopiar, "#6A1B9A")
pintar(btnLeer, "#3949AB")
pintar(btnNueva, "#C62828")

-- 5. EVENTOS Y VALORES INICIALES
txtResponse.setTextIsSelectable(true)
chkAuto.setChecked(lectura_auto)
actualizarContador(nil)

updateSpinner(tempSpinner, temp_list)
tempSpinner.setSelection(temp_idx - 1)
updateSpinner(tokensSpinner, tokens_list)
tokensSpinner.setSelection(tokens_idx - 1)

modelSpinner.onItemSelected = function(p, v, pos, id)
  if model_list[pos + 1] then
    selected_model = model_list[pos + 1]
  end
end

tempSpinner.onItemSelected = function(p, v, pos, id)
  temp_idx = pos + 1
  guardar("temp_idx", temp_idx)
end

tokensSpinner.onItemSelected = function(p, v, pos, id)
  tokens_idx = pos + 1
  guardar("tokens_idx", tokens_idx)
end

chkAuto.onClick = function(v)
  lectura_auto = chkAuto.isChecked()
  guardar("lectura_auto", lectura_auto and "1" or "0")
  if lectura_auto then
    hablar("Lectura automática activada")
  else
    hablar("Lectura automática desactivada")
  end
end

btnObtener.onClick = function(v)
  abrirNavegador(URL_CLAVES)
end

btnClave.onClick = function(v)
  mostrarDialogoClave()
end

btnActualizar.onClick = function(v)
  if current_api_key == "" then
    hablar("Primero configurá la clave de API")
    return
  end
  reloadModels(modelSpinner)
end

btnEnviar.onClick = function(v)
  sendMessage(editMsg.getText().toString())
end

btnPegar.onClick = function(v)
  local texto = leerPortapapeles()
  if texto == "" then
    hablar("El portapapeles está vacío")
    return
  end
  editMsg.setText(texto)
  sendMessage(texto)
end

btnCopiar.onClick = function(v)
  if ultima_respuesta == "" then
    hablar("No hay respuesta para copiar")
    return
  end
  copiarAlPortapapeles(ultima_respuesta)
  hablar("Respuesta copiada")
end

btnLeer.onClick = function(v)
  if ultima_respuesta == "" then
    hablar("No hay respuesta para leer")
    return
  end
  hablar(ultima_respuesta)
end

btnNueva.onClick = function(v)
  historial = {}
  ultima_respuesta = ""
  mostrarRespuesta("Esperando...")
  editMsg.setText("")
  hablar("Nueva conversación iniciada")
end

if current_api_key == "" then
  hablar("Falta la clave de API. Usá el botón Obtener clave en Mistral o Configurar clave.")
else
  reloadModels(modelSpinner)
end

return true