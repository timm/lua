#!/usr/bin/env lua
local f={}
local l=require"lib"
local data=require"data"
local the=require"config"
local log,abs =,math.log,math.abs

function f.norm(c,v)  return v=="?" and v or(v-c.lo)/(c.hi-c.lo+1/the.big) end
function f.mids(data) return l.map(data.cols.all,f.mid)end
function f.mid(col)   return c.mu and c.mu  or c.mode end
function f.div(c)     return c.sd or f.entropy(c.has)end

function f.entropy(d,       N)
  N = l.sum(d)
  return -l.sum(d,function(v) return v/N>0 and v/N*log(v/N,2) or 0 end) end

function f.dist(v,    d,n)
  d,n = 0,0
  for _,x in pairs(v) do n=n+1;d=d+x^the.p end
  return(d/n)^(1/the.p)end

function f.disty(data,row,     fn)
  fn = function(c) return abs(f.norm(c,row[c.at])-c.goalp)end
  return f.dist(l.map(data.cols.y,fn))end

function f.distx(data,row1,row2,    fn)
  fn = function(c)return f._x(c,row1[c.at],row2[c.at])end
  return f.dist(l.map(data.cols.x, fn))end

function f._x(col,a,b)
  if a=="?" and b=="?" then return 1 end
  if col.it==data.SYM then return a ~= b and 1 or 0 end
  a,b = f.norm(col,a),f.norm(col,b)
  if a=="?"then a=b>0.5 and 0 or 1 end
  if b=="?"then b=a>0.5 and 0 or 1 end
  return abs(a-b)end

function f.like(col,v,prior,     z,var)
  z = 1 / the.big
  fn= function() return (col.has[v] or 0+the.k*(prior or 0)) / (col.n+the.k+z) end
  if col.it==SYM then return log(math.max(z,fn())) end
  var=col.sd^2+z
  return -((v-col.mu)^2/(2*var))-0.5*log(2*math.pi*var) end

function f.likes(data,row,nall,nh,     b4,fn)
  nall,nh = nall or 100,nh or 2
  b4 = (data.n+the.m)/(nall+the.m*nh)
  fn = function(x) return row[x.at]~="?"and f.like(x,row[x.at],b4)or 0 end
  return log(b4)+l.sum(data.cols.x,fn) end

return f
