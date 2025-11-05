#!/usr/bin/env lua
local the,help = {},[[
min.lua : multiple-objective active learning
(c) 2024, Tim Menzies <timm@ieee.org>, BSD-2.

USAGE:
  chmod +x min.lua
  ./min.lua [OPTIONS] [ARGS]

OPTIONS:
  -all            run test suite
  -b begin  int   initial samples   = 4
  -B Break  int   max samples       = 30
  -c cut    int   items to sort     = 100
  -C Cohen  float small effect      = .35
  -e elite  int   elite sample size = 4
  -h              show help            
  -k k      int   Bayes param       = 0
  -m m      int   Bayes param       = 3
  -r ranges int   max num of bins   = 10
  -s seed   int   random seed       = 1234567891
  -t train  str   csv file          = ../../../moot/optimize/misc/auto93.csv
  -T Top    float best set size     = .5]]

local NUM,SYM,COLS,DATA = {},{},{},{}
local big,coerce,csv,down,fmt,green,gt,keys,lt,median,new
local o,oo,pop,push,red,shuffle,sort,trim,up,yellow

BIG = 1e32
-- -----------------------------------------------------------------------------------
function SYM:new(  i,is) 
  return new(SYM, {n=0, i=i or 0, is=is or "", has={}, most=0, mode=nil}) end

function NUM:new(  i,is)
  return new(NUM, {n=0, i=i or 0, is=i or ""s, mu=0, sd=0, m2=0, lo=BIG, hi=-BIG,
                   goal = (is or ""):find"-$" and 0 or 1}) end

function COLS:new(names,     all,x,y,col)
  all,x,y = {},{},{}
  for i,is in pairs(names) do
    col = push(all, (is:find"^[A-Z]" and NUM or SYM):new(i,is))
    if not is:find"X$" then
      push(is:find"[!+-]$" and y or x, col) end end
  return new(COLS, {names=names, all=all, x=x, y=y}) end

function DATA:new() return new(DATA, {rows={}, cols=nil}) end

function DATA:clone(  rows) return DATA:new():from({self.cols.names}):from(rows) end

-- -----------------------------------------------------------------------------------
function DATA:csv(file) csv(file, function(n,row) self:add(row) end); return self end

function DATA:from(  rows) 
  for _,r in pairs(rows or {}) do self:add(r) end; return self end

function DATA:add(row) 
  if self.cols then push(self.rows, self.cols:add(row)) 
  else self.cols=COLS:new(row) end end

function COLS:add(row)
  for _,cols in pairs{self.x, self.y} do
    for _,col in pairs(cols) do col:add( row[col.i] ) end end
  return row end

function NUM:add(x,    d)
  if x ~= "?" then
    self.n  = self.n + 1
    d       = x - self.mu
    self.mu = self.mu + d / self.n
    self.m2 = self.m2 + d * (x - self.mu)
    self.sd = self.n < 2 and 0 or (self.m2/(self.n - 1))^.5 
    if x > self.hi then self.hi = x end
    if x < self.lo then self.lo = x end end end  

function SYM:add(x,  n)
  if x ~= "?" then
    n           = n or 1
    self.n      = n + self.n 
    self.has[x] = n + (self.has[x] or 0) 
    if self.has[x] > self.most then
      self.most, self.mode = self.has[x], x end end end

-- -----------------------------------------------------------------------------------
function NUM:norm(x)
  return x=="?" and x or (x - self.lo) / (self.hi - self.lo + 1/big) end

function NUM:pdf(x) 
  return math.exp(-.5*((x - self.mu)/self.sd)^2) / (self.sd*((2*math.pi)^0.5)) end

function NUM:cdf(x,     fun,z)
  fun = function(z) return 1 - 0.5 * math.exp(-0.717 * z - 0.416 * z * z) end
  z   = (x - self.mu) / self.sd
  return  z>=0 and fun(z) or 1 - fun(-z) end

function NUM:discretize(x) return self:cdf(x) * the.ranges // 1 end

function SYM:discretize(x) return x end

function SYM:entropy(x,      e) 
  e=0; for _,n in pairs(self.has) do e = e - n/self.n * math.log(n/self.n, 2) end
  return e end

-- -----------------------------------------------------------------------------------
function DATA:chebyshev(row,    tmp,d)
  d=0; for _,col in pairs(self.cols.y) do
         tmp = math.abs(col.goal - col:norm(row[col.i]))
         if tmp > d then d = tmp end end
  return d end

function DATA:shuffle()
  self.rows = shuffle(self.rows); return self end

function DATA:sort(    fun)
  fun = function(row) return self:chebyshev(row) end
  self.rows = sort(self.rows, function(a,b) return fun(a) < fun(b) end)
  return self end

function DATA:bestRest(top,      best,rest)
  self:sort()
  best,rest = self:clone(), self:clone()
  for i,row in pairs(self:sort().rows) do
    (i <= (#self.rows)^(top or the.Top) and best or rest):add(row) end
  return best,rest end

-- -----------------------------------------------------------------------------------
function SYM:like(x, prior)
  return ((self.has[x] or 0) + the.m*prior)/(self.n +the.m) end

function NUM:like(x,...)
  return self.sd==0 and  (x==self.mu and 1 or 1E-32) or math.min(1,self:pdf(x)) end

function DATA:like(row, n, nClasses,     col,prior,out,v,inc)
  prior = (#self.rows + the.k) / (n + the.k * nClasses)
  out   = math.log(prior)
  for _,col in pairs(self.cols.x) do
    v = row[col.i]
    if v ~= "?" then
      inc = col:like(v,prior)
      if inc > 0 then out = out + math.log(inc) end end end
  return out end

function DATA:acquire(score,rows,       todo,done,top)
  todo, done = {},{}
  for i,t in pairs(rows or {}) do push( done, t) end
  for i,t in pairs(self.rows)  do push(#done < the.begin and done or todo, t) end
  while #done < the.Break do
    top, todo = self:guess(todo, done, score or function(B,R) return B-R end)
    push(done, top) 
    done = self:clone(done):sort().rows end
  return done end

function DATA:guess(todo, done, score,      best,rest,fun,tmp,out,j,k)
  best,rest = self:clone(done):bestRest()
  fun = function(t) return score(best:like(t,#done,2), rest:like(t,#done,2)) end
  tmp, out = {},{}
  for i,t in pairs(todo) do push(tmp, {i <= the.cut and fun(t) or 0, t}) end
  for _,z in pairs(sort(tmp, lt(1))) do push(out, z[2]) end
  return self:demoteBadGusses(out) end

function DATA:demoteBadGusses(out,    half,saved)
  half,saved = the.cut//2,{}
  for i=half, the.cut        do push(saved,out[i]) end
  for i=the.cut+1, #out-half do out[i-half] = out[i] end
  for i,x in pairs(saved)    do out[#out-half + i ] = x end
  return pop(out), out end

-- -----------------------------------------------------------------------------------
-- ## Contrasts

local CONTRAST={}

function CONTRAST:new(goal,i,is,lo,hi,B,R)
  return new(CONTRAST,{goal=goal, i=i, is=is, lo=lo, hi=hi, 
                       n=0, bests=0, rests=0, B=B, R=R}) end

function CONTRAST:__tostring() return "12" end
function CONTRAST:add(x,y)
  if x < self.lo then self.lo=x end
  if x > self.hi then self.hi=x end 
  self.n = self.n + 1
  if y==self.goal then self.bests = self.bests+1 else self.rests = self.rests+1 end end

function CONTRAST:entropy(     p1,p2)
  p1, p2 = self.bests/self.n, self.rests/self.n
  return -p1*math.log(p1,2) - p2*math.log(p2,2) end 

function CONTRAST:score(    b,r)
  b,r = self.bests/self.B,self.rests/self.R
  return b>r and b^2/(b + r + 1E-32) or 0 end

function CONTRAST:combined(other,dull,small,      k,e0,e1,e2)
  k = self:combine(other)
  if math.abs(self.lo  - other.lo) < dull then return k end
  if self.n < small or other.n < small    then return k end
  e0, e1, e2 = k:entropy(), self:entropy(), other:entropy()
  if e0 <= (e1*self.n + e2*other.n) / k.n then return k end end

function CONTRAST.combine(i,j,      k)
  k = CONTRAST:new(i.goal, i.i, i.is, math.min(i.lo,j.lo), math.max(i.hi,j.hi),i.B,i.R)
  k.n     = i.n + j.n
  k.bests = i.bests + j.bests
  k.rests = i.rests + j.rests
  return k end 

function DATA:contrasts(other,both,      out)
  out = {}
  for i,col in pairs(both.cols.x) do
    for _,contrast in pairs(self:contrasts4col(col,other)) do 
        push(out, contrast) end end 
  return   sort(out, up(function(c) return c:score() end)) end

function DATA:contrasts4col(col,other,      x,b,out,index)
  out, index = {}, {}
  for klass,rows in pairs{best=self.rows, rest=other.rows} do
    for _,row in pairs(rows) do
      x = row[col.i]
      if x ~= "?" then
        b = col:discretize(x)
        index[b] = index[b] or 
                   push(out,CONTRAST:new("best",col.i,col.is,x,x,#self.rows,#other.rows))
        index[b]:add(x,klass) end end end
  return col:contrastsCombined(sort(out,lt"lo"), col.n / the.ranges) end

function SYM:contrastsCombined(contrasts,_) return contrasts end

function NUM:contrastsCombined(contrasts,small,    t,new,dull)
  dull = self.sd * the.Cohen
  t={contrasts[1]} 
  for i,contrast in pairs(contrasts) do
    if i > 1 then
      new = contrast:combined(t[#t], dull,small) 
      if new then t[#t] = new else push(t,contrast) end end end
  return t end

-- -----------------------------------------------------------------------------------
-- ## Lib

function adds(t, it)
  it = it or Num(); for _,x in pairs(t) do  it:add(x) end; return it; end

pop = table.remove

fmt = string.format

function new(klass,obj)
  klass.__index=klass; klass.__tostring=o; return setmetatable(obj,klass) end

function push(t,x)   t[1+#t]=x; return x end

function sort(t,  fun) table.sort(t,fun); return t end

function median(t) return sort(t)[.5*#t//1] end

function lt(key)   return function(a,b) return a[key] < b[key] end end
function gt(key)   return function(a,b) return a[key] > b[key] end end

function up(fun)   return function(a,b) return fun(a) > fun(b) end end
function down(fun) return function(a,b) return fun(a) < fun(b) end end

function keys(t,    u) 
  u={}; for k,_ in pairs(t) do push(u,k) end return sort(u) end   

function shuffle(t,    j)
  for i = #t, 2, -1 do j = math.random(i); t[i], t[j] = t[j], t[i] end
  return t end

function coerce(s,     fun)   
  fun = function(s) return s=="true" and true or s ~= "false" and s end
  return math.tointeger(s) or tonumber(s) or fun(trim(s)) end

function csv(file,fun,      src,s,cells,n)
  src = io.input(file)
  while true do
    s = io.read()
    if s then fun(cells(s)) else return io.close(src) end end end

function cells(s,    t)
  t={}; for s1 in s:gmatch"([^,]+)" do push(t,coerce(s1)) end; return t end

function trim(s)  return s:match"^%s*(.-)%s*$" end

-- (any) --> str
function o(x,     list,hash)
  list= function(t) for _,v in pairs(x) do push(t, o(v)) end; return t end
  hash= function(t) for _,k in pairs(keys(x)) do 
                      if   not o(k):find"^_" 
                      then push(t, fmt(":%s %s", k, o(x[k]))) end end 
                    return t end
  if type(x) == "number" then return fmt("%g",x) end
  if type(x) ~= "table"  then return tostring(x)   end
  return "{" .. table.concat(#x>0 and list{} or hash{}, " ") .. "}" end

-- (any) --> nil
function oo(x) print(o(x)) end

function yellow(s) return "\27[33m" .. s .. "\27[0m" end
function green(s)  return "\27[32m" .. s .. "\27[0m" end
function red(s)    return "\27[31m" .. s .. "\27[0m" end
-- -----------------------------------------------------------------------------------
-- ## Main

local go = {}

function go.h(_) print("\n" ..help) end

function go.the(_) oo(the) end

function go.all(_,     status,msg,fails,todos) 
  todos, fails = "sort csv data bayes cheb acq", 0
  for x in todos:gmatch"([^ ]+)" do
    print(yellow(x))
    math.randomseed(the.seed)
    status,msg = xpcall(go[x], debug.traceback, _)
    if status == false then 
      print(red("fail in "..x.." :"..msg)); fails = fails + 1
    else print(green("pass")) end end
  os.exit(fails) end 

function go.train(x) the.train = x end

function go.seed(x) the.seed = coerce(x); math.randomseed(the.seed) end

function go.sort(_,     t)
  t = sort({10,1,2,3,1,4,1,1,2,4,2,1}, function(a,b) return a>b end)
  assert(t[1]==10, "wrong sort") end

function go.csv(_,     fun) 
  fun = function(n,t) if (n % 60) == 0 then print(n, o(t)) end end
  csv(the.train, fun) end

function go.data(_,      d)
  d = DATA:new():csv(the.train):shuffle():sort()
  for n,row in pairs(d.rows) do 
    if n==1 or (n%30)==0 then print(n,o(row)) end end
  print""; for _,col in pairs(d.cols.y) do oo(col) end end

function go.bayes(_,      d,fun)
  d   = DATA:new():csv(the.train) 
  fun = function(t) return d:like(t,1000,2) end
  for n,t in pairs(sort(d.rows, down(fun))) do
    if n==1 or n==#d.rows or (n%30)==0 then print(n, t[#t], fun(t)) end end end

function go.cheb(_,      d,num)
  d   = DATA:new():csv(the.train) 
  num = NUM:new()
  for _,t in pairs(d.rows) do num:add(d:chebyshev(t)) end
  print(num.mu, num.sd) end

function go.acq(_,      d,toBe,t,asIs,repeats,start)
  d = DATA:new():csv(the.train) 
  asIs,toBe = {},{}
  for _,t in pairs(d.rows) do push(asIs, d:chebyshev(t)) end
  repeats = 20
  start = os.clock()
  for i=1,repeats do push(toBe, d:chebyshev(d:shuffle():acquire()[1])) end
  oo{secs = (os.clock() - start)/repeats, asIs=median(asIs), toBe=median(toBe)} end

function go.br(_,     both,best,rest)
  both = DATA:new():csv(the.train)
  best,rest = both:bestRest(.5)
  for i,c in pairs(best:contrasts(rest,both)) do 
    print(i, c, c:score(#best.rows, #rest.rows)) end end

function go.push(_) os.execute("git commit -am saving; git push; git status") end
function go.pdf(_)  os.execute("make -B ~/tmp/min.pdf; open ~/tmp/min.pdf") end
function go.doc(_)  os.execute(
  "pycco -d ~/tmp min.lua; echo 'p {text-align:right;}' >> ~/tmp/pycco.css") end

-- -----------------------------------------------------------------------------------
-- ## Start

help:gsub("\n%s+-%S%s(%S+)[^=]+=%s+(%S+)", function(k,v) the[k] = coerce(v) end)
math.randomseed(the.seed)

if arg[0]:find"min.lua" then
  for i,s in pairs(arg) do 
    s = s:sub(2)
    if go[s] then go[s]( arg[i+1] ) end end end

return {NUM=NUM,SYM=SYM,DATA=DATA,the=the,help=help} 

