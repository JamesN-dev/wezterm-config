-- Pull in the wezterm API
local wezterm = require("wezterm")

wezterm.log_info("Loading configuration file")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Helper function to save a value to a file
local function save_to_file(filename, value)
    local file = io.open(wezterm.home_dir .. "/.config/wezterm/" .. filename, "w")
    if file then
        file:write(value)
        file:close()
        return true
    end
    return false
end

-- Helper function to read a value from a file
local function read_from_file(filename)
    local file = io.open(wezterm.home_dir .. "/.config/wezterm/" .. filename, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content
    end
    return nil
end

-- Light & Dark mode
local function depending_on_appearance(arg)
    local appearance = wezterm.gui.get_appearance()
    if appearance:find 'Dark' then
        return arg.dark
    else
        return arg.light
    end
end

-- Resize pane function
local function resize_pane(key, direction)
    return {
        key = key,
        action = wezterm.action.AdjustPaneSize { direction, 5 }
    }
end

-- Load saved theme state
local is_random = read_from_file("theme_random")
local random_themes_enabled = is_random == nil or is_random == "true"

-- Load saved theme
local saved_theme = read_from_file("theme_current")
if saved_theme == nil then
    saved_theme = depending_on_appearance {
        light = 'AdventureTime',
        dark = 'Nord',
    }
end

-- Plugin Config
local scheme_names = {}
for name, _ in pairs(wezterm.color.get_builtin_schemes()) do
    table.insert(scheme_names, name)
end

-- Get index of current theme in scheme_names
local function get_theme_index(theme_name)
    for i, name in ipairs(scheme_names) do
        if name == theme_name then
            return i
        end
    end
    return 1
end

-- Keep track of the current color scheme
local current_scheme = saved_theme

-- Set initial color scheme
config.color_scheme = current_scheme

-- Random color scheme on window reload, only if enabled
wezterm.on('window-config-reloaded', function(window, pane)
    if window:get_config_overrides() then return end
    if random_themes_enabled then
        local scheme = scheme_names[math.random(#scheme_names)]
        current_scheme = scheme
        window:set_config_overrides { color_scheme = scheme }
        save_to_file("theme_current", scheme)
        wezterm.log_info("Your colour scheme is now: " .. scheme)
    else
        -- Apply the saved theme
        window:set_config_overrides { color_scheme = current_scheme }
    end
end)

-- Create a status bar with useful information
wezterm.on('update-status', function(window, pane)
    -- Get the current time - fixed format without seconds
    local date = wezterm.strftime('%a %b %-d %H:%M')

    -- Get CPU and RAM usage
    local success, stdout, stderr = wezterm.run_child_process({ "top", "-l", "1", "-n", "0", "-stats",
        "pid,command,cpu,mem", "-o", "cpu" })
    local cpu = "CPU: --    " -- Fixed width with padding
    local mem = "MEM: --    " -- Fixed width with padding

    if success then
        -- Try to parse CPU and memory info from top output
        local cpu_pattern = "CPU usage: ([%d%.]+)%%%s+user,"
        local mem_pattern = "PhysMem: ([%d%.]+)([MG]) used"

        for line in stdout:gmatch("[^\r\n]+") do
            local cpu_value = line:match(cpu_pattern)
            if cpu_value then
                -- Pad to fixed width
                cpu = string.format("CPU: %-6s", cpu_value .. "%")
            end

            local mem_value, unit = line:match(mem_pattern)
            if mem_value and unit then
                -- Pad to fixed width
                mem = string.format("MEM: %-6s", mem_value .. unit)
            end
        end
    end

    -- Get battery status with fixed width
    local battery_info = "BAT: --    " -- Fixed width with padding
    for _, b in ipairs(wezterm.battery_info()) do
        local charge = string.format("%.0f%%", b.state_of_charge * 100)
        if b.state == "Charging" then
            charge = charge .. "+"
        end
        -- Pad to fixed width
        battery_info = string.format("BAT: %-6s", charge)
    end

    -- Get current hostname
    local hostname = wezterm.hostname()

    -- Show whether random themes are enabled
    local theme_status = random_themes_enabled and "RANDOM" or "FIXED"

    -- Create the right status text with all our info (no DIR)
    local status_elements = {
        { Foreground = { Color = "#61afef" } },
        { Text = "SCHEME: " .. current_scheme .. " [" .. theme_status .. "] │ " },
        { Foreground = { Color = "#e5c07b" } },
        { Text = hostname .. " │ " },
        { Foreground = { Color = "#c678dd" } },
        { Text = cpu .. " │ " },
        { Foreground = { Color = "#56b6c2" } },
        { Text = mem .. " │ " },
        { Foreground = { Color = "#e06c75" } },
        { Text = battery_info .. " │ " },
        { Foreground = { Color = "#abb2bf" } },
        { Text = date },
    }

    -- Apply the right status
    window:set_right_status(wezterm.format(status_elements))
end)

-- Window settings
config.initial_rows = 32
config.initial_cols = 80
config.window_decorations = 'RESIZE'
config.window_frame = {
    font = wezterm.font({ family = 'Berkeley Mono', weight = 'Bold' }),
    font_size = 11,
}

-- Font settings
config.font = wezterm.font_with_fallback({
    "IosevkaTermSlab Nerd Font Mono",
    "Symbols Nerd Font Mono",
})
config.font_size = 15.4
config.line_height = 0.8
config.cell_width = 1.0

-- Tab bar and transparency
config.enable_tab_bar = true
config.tab_bar_at_bottom = true
config.window_background_opacity = 0.5
config.macos_window_background_blur = 44

-- Status update interval (in milliseconds)
config.status_update_interval = 1000

-- Set up leader key (CTRL+A with 500ms timeout for faster response)
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 500 }

-- Define ALL key bindings in a single table
-- Define ALL key bindings in a single table
config.keys = {
    -- Alt+Arrow for word jumping
    {
        key = 'LeftArrow',
        mods = 'OPT',
        action = wezterm.action.SendString '\x1bb',
    },
    {
        key = 'RightArrow',
        mods = 'OPT',
        action = wezterm.action.SendString '\x1bf',
    },

    -- Split panes (tmux-style with LEADER)
    -- LEADER (CTRL+A) followed by " to split horizontally
    {
        key = '"',
        mods = 'LEADER',
        action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },
    -- LEADER (CTRL+A) followed by % to split vertically
    {
        key = '%',
        mods = 'LEADER',
        action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
    },

    -- Direct resize with arrow keys (no mode needed)
    -- LEADER (CTRL+A) followed by arrow keys
    {
        key = 'LeftArrow',
        mods = 'LEADER',
        action = wezterm.action.AdjustPaneSize { 'Left', 5 },
    },
    {
        key = 'RightArrow',
        mods = 'LEADER',
        action = wezterm.action.AdjustPaneSize { 'Right', 5 },
    },
    {
        key = 'UpArrow',
        mods = 'LEADER',
        action = wezterm.action.AdjustPaneSize { 'Up', 5 },
    },
    {
        key = 'DownArrow',
        mods = 'LEADER',
        action = wezterm.action.AdjustPaneSize { 'Down', 5 },
    },

    -- Resize mode
    {
        key = 'r',
        mods = 'LEADER',
        action = wezterm.action.ActivateKeyTable {
            name = 'resize_panes',
            one_shot = false,
            timeout_milliseconds = 3000,
        }
    },

    -- LEADER + 'f' to fix/save the current theme (stop randomization)
    {
        key = 'f',
        mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            random_themes_enabled = false
            save_to_file("theme_random", "false")
            save_to_file("theme_current", current_scheme)
            window:toast_notification("WezTerm", "Theme fixed: " .. current_scheme, nil, 4000)
        end),
    },

    -- LEADER + 'R' to resume random themes
    {
        key = 'R',
        mods = 'LEADER|SHIFT',
        action = wezterm.action_callback(function(window, pane)
            random_themes_enabled = true
            save_to_file("theme_random", "true")
            window:toast_notification("WezTerm", "Random themes enabled", nil, 4000)
        end),
    },

    -- LEADER + 0 to cycle to next theme
    {
        key = '0',
        mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            local current_index = get_theme_index(current_scheme)
            local next_index = (current_index % #scheme_names) + 1
            local next_scheme = scheme_names[next_index]
            current_scheme = next_scheme
            window:set_config_overrides { color_scheme = next_scheme }
            save_to_file("theme_current", next_scheme)
            if random_themes_enabled then
                random_themes_enabled = false
                save_to_file("theme_random", "false")
                window:toast_notification("WezTerm", "Theme fixed: " .. next_scheme, nil, 4000)
            else
                window:toast_notification("WezTerm", "Theme: " .. next_scheme, nil, 4000)
            end
        end),
    },

    -- LEADER + 9 to cycle to previous theme
    {
        key = '9',
        mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            local current_index = get_theme_index(current_scheme)
            local prev_index = ((current_index - 2) % #scheme_names) + 1
            local prev_scheme = scheme_names[prev_index]
            current_scheme = prev_scheme
            window:set_config_overrides { color_scheme = prev_scheme }
            save_to_file("theme_current", prev_scheme)
            if random_themes_enabled then
                random_themes_enabled = false
                save_to_file("theme_random", "false")
                window:toast_notification("WezTerm", "Theme fixed: " .. prev_scheme, nil, 4000)
            else
                window:toast_notification("WezTerm", "Theme: " .. prev_scheme, nil, 4000)
            end
        end),
    },
    {
        key = ']',
        mods = 'CMD|SHIFT',
        action = wezterm.action.ToggleAlwaysOnTop,
    },
}
-- Keytables for specific modes
config.key_tables = {
    resize_panes = {
        -- Use arrow keys for more intuitive resizing (in addition to hjkl)
        { key = 'h',          action = wezterm.action.AdjustPaneSize { 'Left', 5 } },
        { key = 'j',          action = wezterm.action.AdjustPaneSize { 'Down', 5 } },
        { key = 'k',          action = wezterm.action.AdjustPaneSize { 'Up', 5 } },
        { key = 'l',          action = wezterm.action.AdjustPaneSize { 'Right', 5 } },
        { key = 'LeftArrow',  action = wezterm.action.AdjustPaneSize { 'Left', 5 } },
        { key = 'DownArrow',  action = wezterm.action.AdjustPaneSize { 'Down', 5 } },
        { key = 'UpArrow',    action = wezterm.action.AdjustPaneSize { 'Up', 5 } },
        { key = 'RightArrow', action = wezterm.action.AdjustPaneSize { 'Right', 5 } },

        -- Exit resize mode with Escape, q, or Enter
        { key = 'Escape',     action = wezterm.action.PopKeyTable },
        { key = 'q',          action = wezterm.action.PopKeyTable },
        { key = 'Enter',      action = wezterm.action.PopKeyTable },
    },
}


-- Return the configuration
return config
