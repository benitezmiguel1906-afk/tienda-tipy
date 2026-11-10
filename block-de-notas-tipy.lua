require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "java.io.*"
import "java.util.*"
import "com.androlua.LuaDialog"
import "android.os.Bundle"

local _b = "/storage/emulated/0/Administrador Tipy/"
local _c = _b .. "Backups/"
local _d = _b .. "Protegidos/"
local _e = _b .. "ofuscador.log"
local _f = nil
local _g = nil

local function _h(_i)
pcall(function() service.speak(tostring(_i)) end)
end



local function _j(_k)
if not _k then return nil end
local _l = false
local _m = false
pcall(function() _l = _k.isEditable() end)
pcall(function() _m = _k.isFocused() or _k.isAccessibilityFocused() end)
if _l and _m then return _k end

local _n = 0
pcall(function() _n = _k.getChildCount() end)
for _ua = 0, _n - 1 do
local _o = nil
pcall(function() _o = _k.getChild(_ua) end)
local _p = _j(_o)
if _p then return _p end
end
return nil
end

local function _q()
local _r = nil
pcall(function() _r = service.getRootInActiveWindow() end)
local _k = _j(_r)
if not _k then return false end
local _i = nil
pcall(function() _i = _k.getText() end)
if _i == nil then return false end
_g = tostring(_i)
_f = _k
return _g ~= ""
end

local function _s(_i)
if not _f then return false end
local _t = Bundle()
_t.putCharSequence("ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE", tostring(_i))
local action = 2097152
local _u = false
pcall(function() _u = _f.performAction(action, _t) end)
return _u == true
end

local function _v(_w)
local _x = File(_w)
if not _x.exists() then _x.mkdirs() end
return _x.exists()
end

local function _y(_w)
local _z = BufferedReader(FileReader(File(_w)))
local _aa = {}
local _ba = _z.readLine()
while _ba do
table.insert(_aa, _ba)
_ba = _z.readLine()
end
_z.close()
return table.concat(_aa, "\n")
end

local function _ca(_w, _da)
local _ea = FileWriter(File(_w))
_ea.write(_da)
_ea.close()
end

local function _fa(_w)
local _ga = File(_w)
return _ga.exists() and _ga.isFile() and _ga.canRead()
end

local function _ha(_w)
local _ia = _w:gsub("^.*[/\\\\]", "")
return _ia:gsub("%.lua$", "")
end

local function _ja(_ia)
_ia = tostring(_ia or ""):gsub("^%s+", ""):gsub("%s+$", "")
_ia = _ia:gsub("[\\\\/:*?\"<>|]", "_")
if _ia == "" or _ia == "." or _ia == ".." then _ia = "sin_nombre" end
return _ia
end

local function _ka(_la)
local _ma = _c .. _ja(_la) .. "/"
_v(_b)
_v(_c)
_v(_ma)
local _w = _ma .. "main.lua"
local _na = 1
while File(_w).exists() do
_w = _ma .. "main_" .. tostring(_na) .. ".lua"
_na = _na + 1
end
return _w
end

local _oa = {
["and"]=true,["break"]=true,["do"]=true,["else"]=true,["elseif"]=true,
["end"]=true,["false"]=true,["for"]=true,["function"]=true,["goto"]=true,
["if"]=true,["in"]=true,["local"]=true,["nil"]=true,["not"]=true,
["or"]=true,["repeat"]=true,["return"]=true,["then"]=true,["true"]=true,
["until"]=true,["while"]=true,

service=true,import=true,require=true,android=true,java=true,
File=true,FileReader=true,FileWriter=true,BufferedReader=true,
String=true,Intent=true,Button=true,EditText=true,TextView=true,
LinearLayout=true,ScrollView=true,ArrayAdapter=true,Handler=true,
Runnable=true,Uri=true,ContentValues=true,MediaStore=true,Environment=true,
LuaDialog=true,byte=true,pcall=true,xpcall=true,assert=true,error=true,
ipairs=true,pairs=true,next=true,type=true,tostring=true,tonumber=true,
table=true,string=true,math=true,os=true,io=true,coroutine=true,
print=true,

onClick=true,onLongClick=true,onTextChanged=true,afterTextChanged=true,
beforeTextChanged=true,run=true,action=true,listener=true
}

local function _pa(_qa)
return _qa and _qa:match("[A-Za-z_]") ~= nil
end

local function _ra(_qa)
return _qa and _qa:match("[A-Za-z0-9_]") ~= nil
end

local function _sa(_ta, _ua)
if _ta:sub(_ua, _ua) ~= "[" then return nil end
local _va = _ua + 1
while _ta:sub(_va, _va) == "=" do _va = _va + 1 end
if _ta:sub(_va, _va) ~= "[" then return nil end
local _wa = _ta:sub(_ua + 1, _va - 1)
local _xa = "]" .. _wa .. "]"
local _ya = _ta:find(_xa, _va + 1, true)
if not _ya then return #_ta + 1 end
return _ya + #_xa
end


local function _za(_ta)
local _ab = {}
local _ua = 1
local _bb = #_ta
local _cb = nil

local function _db(_eb, _fb)
local _gb = {_eb=_eb, _fb=_fb, previous=_cb}
table.insert(_ab, _gb)
if _eb ~= "space" and _eb ~= "comment" then
_cb = _gb
end
end

while _ua <= _bb do
local _qa = _ta:sub(_ua, _ua)
local _hb = _ta:sub(_ua, _ua + 1)

if _qa:match("%s") then
local _va = _ua + 1
while _va <= _bb and _ta:sub(_va,_va):match("%s") do _va = _va + 1 end
_db("space", _ta:sub(_ua, _va - 1))
_ua = _va

elseif _hb == "--" then
local _ib = _sa(_ta, _ua + 2)
if _ib then
_db("comment", _ta:sub(_ua, _ib - 1))
_ua = _ib
else
local _va = _ta:find("\n", _ua + 2, true) or (_bb + 1)
_db("comment", _ta:sub(_ua, _va - 1))
_ua = _va
end

elseif _qa == '"' or _qa == "'" then
local _jb = _qa
local _va = _ua + 1
while _va <= _bb do
local _kb = _ta:sub(_va,_va)
if _kb == "\\" then
_va = _va + 2
elseif _kb == _jb then
_va = _va + 1
break
else
_va = _va + 1
end
end
_db("string", _ta:sub(_ua, _va - 1))
_ua = _va

elseif _qa == "[" then
local _ib = _sa(_ta, _ua)
if _ib then
_db("string", _ta:sub(_ua, _ib - 1))
_ua = _ib
else
_db("symbol", _qa)
_ua = _ua + 1
end

elseif _pa(_qa) then
local _va = _ua + 1
while _va <= _bb and _ra(_ta:sub(_va,_va)) do _va = _va + 1 end
_db("identifier", _ta:sub(_ua, _va - 1))
_ua = _va

elseif _qa:match("%d") then
local _va = _ua + 1
while _va <= _bb and _ta:sub(_va,_va):match("[%w%.]") do _va = _va + 1 end
_db("number", _ta:sub(_ua, _va - 1))
_ua = _va

else
local _lb = _ta:sub(_ua, _ua + 2)
if _lb == "..." then
_db("symbol", _lb)
_ua = _ua + 3
elseif _hb == "==" or _hb == "~=" or _hb == "<=" or _hb == ">=" or
_hb == ".." or _hb == "//" or _hb == "<<" or _hb == ">>" then
_db("symbol", _hb)
_ua = _ua + 2
else
_db("symbol", _qa)
_ua = _ua + 1
end
end
end
return _ab
end

local function _mb(_ab, _nb)
local _ua = _nb + 1
while _ab[_ua] and (_ab[_ua].kind == "space" or _ab[_ua].kind == "comment") do _ua = _ua + 1 end
return _ua <= #_ab and _ua or nil
end

local function _cb(_ab, _nb)
local _ua = _nb - 1
while _ua >= 1 and (_ab[_ua].kind == "space" or _ab[_ua].kind == "comment") do _ua = _ua - 1 end
return _ua >= 1 and _ua or nil
end

local function _ob(_nb)
local _pb = "abcdefghijklmnopqrstuvwxyz"
local _qb = "_"
local _rb = _nb
repeat
_qb = _qb .. _pb:sub((_rb % 26) + 1, (_rb % 26) + 1)
_rb = math.floor(_rb / 26) - 1
until _rb < 0
return _qb
end

local function _sb(_ia)
return _oa[_ia] == true or _ia:match("^_") ~= nil
end


local function _tb(_ab)
local _ub = {}
local _vb = {}
local function _wb(_ia)
if _ia and not _sb(_ia) and not _ub[_ia] then
_ub[_ia] = true
table.insert(_vb, _ia)
end
end

local _ua = 1
while _ua <= #_ab do
if _ab[_ua].kind == "identifier" and _ab[_ua].value == "local" then
local _va = _mb(_ab, _ua)
if _va and _ab[_va].kind == "identifier" and _ab[_va].value == "function" then
local _xb = _mb(_ab, _va)
if _xb and _ab[_xb].kind == "identifier" then
_wb(_ab[_xb].value)
_xb = _mb(_ab, _xb)
end
if _xb and _ab[_xb].value == "(" then
_xb = _mb(_ab, _xb)
while _xb and _ab[_xb].value ~= ")" do
if _ab[_xb].kind == "identifier" and _ab[_xb].value ~= "self" then _wb(_ab[_xb].value) end
_xb = _mb(_ab, _xb)
end
end
else
while _va and _ab[_va].value ~= "=" and _ab[_va].value ~= "do" and
_ab[_va].value ~= "in" and _ab[_va].value ~= ";" and
_ab[_va].value ~= "end" do
if _ab[_va].kind == "identifier" then _wb(_ab[_va].value) end
_va = _mb(_ab, _va)
end
end
elseif _ab[_ua].kind == "identifier" and _ab[_ua].value == "function" then
local _va = _mb(_ab, _ua)
if _va and _ab[_va].value == "(" then
_va = _mb(_ab, _va)
while _va and _ab[_va].value ~= ")" do
if _ab[_va].kind == "identifier" and _ab[_va].value ~= "self" then _wb(_ab[_va].value) end
_va = _mb(_ab, _va)
end
end
end
_ua = _ua + 1
end
return _vb
end

local function _yb(_zb)
local _ab = _za(_zb)
local _ac = _tb(_ab)
local _bc = {}
local _cc = {}
local _dc = 0

for _, _vc in ipairs(_ac) do
repeat
_dc = _dc + 1
_bc[_vc] = _ob(_dc)
until not _oa[_bc[_vc]] and not _cc[_bc[_vc]]
_cc[_bc[_vc]] = true
end

local _ec = {}
local _fc = 0
local _gc = 0
for _ua, token in ipairs(_ab) do
if token.kind == "comment" then
_fc = _fc + 1
elseif token.kind == "identifier" and _bc[token.value] then
local _hc = _cb(_ab, _ua)
local _ic = _hc and _ab[_hc].value or nil

if _ic ~= "." and _ic ~= ":" then
table.insert(_ec, _bc[token.value])
_gc = _gc + 1
else
table.insert(_ec, token.value)
end
else
table.insert(_ec, token.value)
end
end

local _qb = table.concat(_ec)


_qb = _qb:gsub("[ \t]+\n", "\n")
_qb = _qb:gsub("\n[ \t]+", "\n")
return _qb, {comments=_fc, _gc=_gc, locals=#_ac}
end

local function _jc(_kc)
_v(_b)
_v(_d)
local _ia = _ha(_kc)
local _w = _d .. _ia .. "_protegida.lua"
local _n = 1
while File(_w).exists() do
_w = _d .. _ia .. "_protegida_" .. tostring(_n) .. ".lua"
_n = _n + 1
end
return _w
end

local function _lc(_kc, _la)
if not _kc or _kc == "" then
_h("Debes indicar la ruta del archivo Lua")
return false
end
_kc = _kc:gsub("^%s+", ""):gsub("%s+$", "")
if not _fa(_kc) then
_h("No se encontro el archivo indicado")
return false
end

local _mc, _zb = pcall(_y, _kc)
if not _mc or not _zb then
_h("No se pudo leer el archivo Lua")
return false
end

_la = _ja(_la)
if _la == "sin_nombre" then _la = _ha(_kc) end
local _nc = _ka(_la)
local _oc = pcall(_ca, _nc, _zb)
if not _oc then
_h("No se pudo crear el respaldo. No se realizo la ofuscacion")
return false
end

local _pc, _qc = _yb(_zb)
local _rc = _jc(_kc)
local _sc, _tc = pcall(_ca, _rc, _pc)
if not _sc then
_h("No se pudo guardar el archivo protegido")
return false
end

_v(_b)
local _uc = os.date("%Y-%m-%d %H:%M:%S") ..
" | entrada=" .. _kc ..
" | respaldo=" .. _nc ..
" | salida=" .. _rc ..
" | locales=" .. _qc.locals ..
" | renombrados=" .. _qc.renamed ..
" | comentarios=" .. _qc.comments .. "\n"
pcall(function()
local _vc = ""
if File(_e).exists() then _vc = _y(_e) end
_ca(_e, _vc .. _uc)
end)

_h("Ofuscacion terminada. Variables renombradas: " .. _qc.renamed)
_h("Respaldo guardado en Backups, carpeta " .. _la)
_h("Archivo protegido guardado en la carpeta Protegidos")
return true
end

local function _wc(_la)
if not _g then
_h("No se encontro un cuadro de edicion activo de Jieshuo")
return false
end
_la = _ja(_la)
if _la == "sin_nombre" then
_h("Escribe el nombre de la extension")
return false
end

local _zb = _g
local _nc = _ka(_la)
if not pcall(_ca, _nc, _zb) then
_h("No se pudo crear el respaldo. No se realizo la ofuscacion")
return false
end

local _pc, _qc = _yb(_zb)
local _rc = _jc(_la .. ".lua")
if not pcall(_ca, _rc, _pc) then
_h("No se pudo guardar el archivo protegido")
return false
end

if not _s(_pc) then
_h("El codigo fue procesado, pero Jieshuo no permitio reemplazar el editor")
_h("El archivo protegido se guardo en Protegidos")
return false
end

local _uc = os.date("%Y-%m-%d %H:%M:%S") ..
" | extension=" .. _la ..
" | respaldo=" .. _nc ..
" | salida=" .. _rc ..
" | locales=" .. _qc.locals ..
" | renombrados=" .. _qc.renamed ..
" | comentarios=" .. _qc.comments .. "\n"
pcall(function()
local _vc = ""
if File(_e).exists() then _vc = _y(_e) end
_ca(_e, _vc .. _uc)
end)
_h("Codigo ofuscado y colocado en el editor de Jieshuo")
_h("Respaldo guardado en Backups, carpeta " .. _la)
return true
end

local function _xc()
_h("Abre primero el editor de una extension en Jieshuo. Escribe su nombre y pulsa Procesar. El original se respalda antes de reemplazarlo.")
end

local function _yc()
_v(_b)
_v(_d)

local _zc = LinearLayout(service)
_zc.setOrientation(LinearLayout.VERTICAL)
_zc.setPadding(32, 24, 32, 24)

local _ad = TextView(service)
_ad.setText("Ofuscador Lua para Jieshuo")
_ad.setTextSize(20)
_zc.addView(_ad)

local _bd = TextView(service)
local _cd = _g and "Codigo del editor detectado." or "No se detecto un editor activo."
_bd.setText(_cd .. " El original se respalda automaticamente en: " .. _c .. "<nombre>/main.lua")
_bd.setTextSize(14)
_zc.addView(_bd)

local _dd = EditText(service)
_dd.setHint("Nombre de la extension, por ejemplo responder")
_dd.setSingleLine(true)
_zc.addView(_dd)

local _ed = Button(service)
_ed.setText("Procesar y reemplazar en Jieshuo")
_ed.setOnClickListener({onClick=function()
_wc(_dd.getText().toString())
end})
_zc.addView(_ed)

local _fd = Button(service)
_fd.setText("Ayuda")
_fd.setOnClickListener({onClick=function() _xc() end})
_zc.addView(_fd)

local _gd = Button(service)
_gd.setText("Cerrar")
_zc.addView(_gd)

local _hd = LuaDialog(service)
_hd.setTitle("Ofuscador Lua")
_hd.setView(_zc)
_gd.setOnClickListener({onClick=function() _hd.dismiss() end})
_hd.show()
end


pcall(_q)
local _mc, _tc = pcall(_yc)
if not _mc then
_h("Error al iniciar el ofuscador")
pcall(function() print("Ofuscador Lua: " .. tostring(_tc)) end)
end