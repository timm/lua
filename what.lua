#!/usr/bin/env lua
l=require"lib"
local \
     coerce,  csv,  kap,  map,  new,  o,  oo,  push,  sort,  trim =
   l.coerce,l.csv,l.kap,l.map,l.new,l.o,l.oo,l.push,l.sort,l.trim

-------------------------------------------------------------------------------
local NUM,SYM,COLS,DATA = {},{},{},{}
local Num,Sym,Cols,Data

function Sym(at,s) 
  return new(SYM, {txt=s, at=at or 0, n=0, has={}, mode=nil, most=0}) end

function Num(at,s,    goalp) 
  s = s or ""
  if s:find"-$" then goalp=0 end
  if s:find"+$" then goalp=1 end
  return new(NUM, {txt=s, at=at or 0, n=0, lo=1E32, hi= -1E32, 
                   mu=0, m2=0, sd=0, goalp=goalp}) end

function Cols(names,   x,y,col,cols)
  x,y,cols = {},{},{}
  for at,s in pairs(names) do
    col = push(cols, (s:find"^[A-Z]" and Num or Sym)(at,s)) 
    if not s:find"X$" then 
      push(s:find"[+-!]$" and y or x, col) end end
  return new(COLS,{x=x, y=y, all=cols, names=names} end

function Data() 
  return new(DATA, {rows={}, cols=nil}) end

-------------------------------------------------------------------------------
function DATA.add(i,row)
  if i.cols 
  then push(i.rows, i.cols:add(row))
  else i.cols = COLS:new(row) end end

function COLS.add(i,row)
  return map(i.cols.all, function(col) col:add(row[col.at]) end) end

function SYM.add(i,v)
  if v ~= "?" then
    i.n = i.n + 1
    i.has[v] = 1 + (i.has[v] or 0)
    if i.has[v] > i.most then 
      i.most, i.mode = i.has[v], v end end 
  return v end

function NUM.add(i,v,    d)
  if v ~= "?" then
    i.n  = i.n + 1
    d    = x - i.mu
    i.mu = i.mu + d / i.n
    i.m2 = i.m2 + d * (x - i.mu)
    i.sd = i.n < 2 and 0 or (i.m2/(i.n - 1))^.5 
    if x > i.hi then i.hi = x end
    if x < i.lo then i.lo = x end end 
  return v end 
