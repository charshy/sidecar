--[[
ServiceProxy tenant library
]]

function get_target(service, default_version, version_selectors)
    local version = get_version(service, default_version, version_selectors)
    local path = string.sub(ngx.var.request_uri, string.len(service)+2)
    return "http://" .. service .. "_" .. version .. path
end

function get_version(service, default_version, version_selectors)
    local cookie_version = ngx.var.cookie_version -- check for cookie
    if cookie_version then
        if version_selectors and (version_selectors[cookie_version] or cookie_version == default_version) then
            -- ngx.log(ngx.DEBUG, "returning cookie_version: ", cookie_version)
            return cookie_version
        else
            add_cookie("version=; Path=/" .. service .. "; Expires=" .. ngx.cookie_time(0)) -- tell client to delete old cookie
        end
    end
    cookie_version = select_version(service, default_version, version_selectors)
    if version_selectors then
        add_cookie("version=" .. selected_version .. "; Path=/" .. service)
    end
    -- ngx.log(ngx.DEBUG, "returning: ", cookie_version)
    return cookie_version   
end

function select_version(service, default_version, version_selectors)
    selected_version = default_version
    if version_selectors then
        for version, selector in pairs(version_selectors) do -- TODO: how to get in selectors in specific order
            if selector.user and ngx.var.cookie_user and selector.user == ngx.var.cookie_user then
                selected_version = version
                break
            elseif selector.weight then
                if math.random() < selector.weight then
                    selected_version = version
                    break
                end
            elseif selector.pattern then
                -- TODO: match by domain name pattern
                break
            end
        end
    end
    -- ngx.log(ngx.DEBUG, "returning: ", selected_version)
    return selected_version
end

function add_cookie(cookie)
    local cookies = get_cookies()
    table.insert(cookies, cookie)
    ngx.header['Set-Cookie'] = cookies
end

function get_cookies()
    local cookies = ngx.header["Set-Cookie"] or {}

    if type(cookies) == "string" then
        cookies = {cookies}
    end

    return cookies
end

function remove_cookie(cookie_name)
    -- lookup if the cookie exists.
    local cookies, key, value = get_cookies()
 
    for key, value in ipairs(cookies) do
        local name = match(value, "(.-)=")
        if name == cookie_name then
            table.remove(cookies, key)
        end
    end
 
    ngx.header['Set-Cookie'] = cookies or {}
end

return {
  get_target = get_target,
  get_version = get_version
}
