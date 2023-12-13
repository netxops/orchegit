-- 基础lib库，提供lua基础方法

utils = {}

function utils.file_exists(name)
    local f=io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

function utils.ubuntu_codename()
  local handle = io.popen("awk -F'=' '/UBUNTU_CODENAME/ {print $2}' /etc/os-release")
  local result = handle:read("*a")
  handle:close()
-- 原字符串包含回车，去除回车
  return string.sub(result, string.find(result, "[^%c]+"))
end

function utils.ubuntu_repo(mirror)
  lines = {}
  local codename = utils.ubuntu_codename()
  local suffix = "main restricted universe multivers"
  lines[#lines+1] = string.format("deb %s %s %s", mirror, codename, suffix)
  lines[#lines+1] = string.format("deb %s %s-security %s", mirror, codename, suffix)
  lines[#lines+1] = string.format("deb %s %s-updates %s", mirror, codename, suffix)
  lines[#lines+1] = string.format("deb %s %s-proposed %s", mirror, codename, suffix)
  lines[#lines+1] = string.format("deb-src %s %s %s", mirror, codename, suffix)
  lines[#lines+1] = string.format("deb-src %s %s-security %s", mirror, codename, suffix)
  lines[#lines+1] = string.format("deb-src %s %s-updates %s", mirror, codename, suffix)
  lines[#lines+1] = string.format("deb-src %s %s-proposed %s", mirror, codename, suffix)
  return lines
end


function utils.line_exists(name, target)
  for line in io.lines(name) do
    pattern = utils.escapePercent(target)
    if string.find(line, pattern) then
      return true
    end
  end
  return false
end

function utils.escapePercent(str)
  return str:gsub("%-", "%%-")
end

return module
