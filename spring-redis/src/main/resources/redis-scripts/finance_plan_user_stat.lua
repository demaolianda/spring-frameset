--
-- 
-- User: yandi
-- Date: 2015/7/7
-- Time: 18:47
-- To change this template use File | Settings | File Templates.
-- jedis.eval(cad, 1, key, needUpdate);
--
-- 10_APPEND_0.0,15_APPEND_0.0


local function Split(szFullString, szSeparator)
    local nFindStartIndex = 1
    local nSplitIndex = 1
    local nSplitArray = {}
    while true do
        local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
        if not nFindLastIndex then
            nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
            break
        end
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
        nFindStartIndex = nFindLastIndex + string.len(szSeparator)
        nSplitIndex = nSplitIndex + 1
    end
    return nSplitArray
end

-- 四舍五入保留两位小数
local function getRounding(a)
    local r1, r2 = math.modf(a * 100, 1)
    r2 = r2 >= 0.5 and 1 or 0
    return (r1 + r2) / 100
end


local current = redis.call("get", KEYS[1])
local updateList = Split(tostring(ARGV[1]), ";") -- needUpdate 格式 10_0.0_APPEND;15_0.0_APPEND
local currentlist = Split(tostring(current), ",") -- 将redis中字符串转化成数组

for i = 1, #updateList do
--[[    local updateValue = string.format("index %d: value = %s", i, updateList[i]);
    print(updateValue);]]
    local updateStr = tostring(updateList[i])
    local needUpdateList = Split(tostring(updateStr), "_") -- 10_0.0_APPEND 转化为数组

    if "null" == tostring(needUpdateList[1]) then
        -- 有个principalAndInterest 每次都重新计算加权平均收益率rate
        local values = Split(tostring(needUpdateList[2]), ",")
        local p = tonumber(values[1])
        local ir = tonumber(values[2])
        local tp = tonumber(currentlist[16]) -- lua数组类型是从1开始   total
        local ar = tonumber(currentlist[17]) -- rate

        local tpNext = tonumber(tp) + tonumber(p)
        if tpNext > 0 then
            local ti = tonumber(tp) * tonumber(ar)
            local i = tonumber(p) * tonumber(ir)
            local tiNext = tonumber(ti) + tonumber(i)
            local tiNextTmp = getRounding(tonumber(tiNext))
            local tiNextDivide = tonumber(tiNextTmp) / tonumber(tpNext)
            currentlist[17] = getRounding(tonumber(tiNextDivide))
        else
            currentlist[17] = tonumber(0);
        end

    else
        -- 获得第几个字段坐标
        local index = tonumber(needUpdateList[1]) + 1 -- lua数组类型是从1开始
        if "null" ~= tostring(needUpdateList[2]) then
            currentlist[index] = getRounding(tonumber(needUpdateList[2]) + tonumber(currentlist[index]))
        end
    end
end

-- 将数组转化为逗号分隔的字符串
local tostore = "";
for i = 1, #currentlist do
    tostore = tostore..tostring(currentlist[i])..",";
end

tostore = string.sub(tostring(tostore), 0, string.len(tostring(tostore)) - 1)
redis.call("set", KEYS[1], tostring(tostore))
return tostore


