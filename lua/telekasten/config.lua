local filetype = require("plenary.filetype")
local Path = require("plenary.path")

local M = {}

---creates a default configuration for telekasten
---@param home string
local function defaultConfig(home)
    local cfg = {
        home = vim.fn.expand("~/zettelkasten"),

        -- if true, telekasten will be enabled when opening a note within the configured home
        take_over_my_home = true,

        -- auto-set telekasten filetype: if false, the telekasten filetype will not be used
        --                               and thus the telekasten syntax will not be loaded either
        auto_set_filetype = true,

        -- dir names for special notes (absolute path or subdir name)
        dailies = home .. "/" .. "daily",
        weeklies = home .. "/" .. "weekly",
        templates = home .. "/" .. "templates",

        -- image (sub)dir for pasting
        -- dir name (absolute path or subdir name)
        -- or nil if pasted images shouldn't go into a special subdir
        image_subdir = nil,

        -- markdown file extension
        extension = ".md",

        -- Generate note filenames. One of:
        -- "title" (default) - Use title if supplied, uuid otherwise
        -- "uuid" - Use uuid
        -- "uuid-title" - Prefix title by uuid
        -- "title-uuid" - Suffix title with uuid
        new_note_filename = "title",

        --[[ file UUID type
           - "rand"
           - string input for os.date()
           - or custom lua function that returns a string
        --]]
        uuid_type = "%Y%m%d%H%M",
        -- UUID separator
        uuid_sep = "-",

        -- if not nil, replaces any spaces in the title when it is used in filename generation
        filename_space_subst = nil,

        -- following a link to a non-existing note will create it
        follow_creates_nonexisting = true,
        dailies_create_nonexisting = true,
        weeklies_create_nonexisting = true,

        -- skip telescope prompt for goto_today and goto_thisweek
        journal_auto_open = false,

        -- templates for new notes
        template_new_note = home .. "/" .. "templates/new_note.md",
        template_new_daily = home .. "/" .. "templates/daily_tk.md",
        template_new_weekly = home .. "/" .. "templates/weekly_tk.md",

        -- image link style
        -- wiki:     ![[image name]]
        -- markdown: ![](image_subdir/xxxxx.png)
        image_link_style = "markdown",

        -- default sort option: 'filename', 'modified'
        sort = "filename",

        -- when linking to a note in subdir/, create a [[subdir/title]] link
        -- instead of a [[title only]] link
        subdirs_in_links = true,

        -- integrate with calendar-vim
        plug_into_calendar = true,
        calendar_opts = {
            -- calendar week display mode: 1 .. 'WK01', 2 .. 'WK 1', 3 .. 'KW01', 4 .. 'KW 1', 5 .. '1'
            weeknm = 4,
            -- use monday as first day of week: 1 .. true, 0 .. false
            calendar_monday = 1,
            -- calendar mark: where to put mark for marked days: 'left', 'right', 'left-fit'
            calendar_mark = "left-fit",
        },
        close_after_yanking = false,
        insert_after_inserting = true,

        -- tag notation: '#tag', ':tag:', 'yaml-bare'
        tag_notation = "#tag",

        -- command palette theme: dropdown (window) or ivy (bottom panel)
        command_palette_theme = "ivy",

        -- tag list theme:
        -- get_cursor: small tag list at cursor; ivy and dropdown like above
        show_tags_theme = "ivy",

        -- template_handling
        -- What to do when creating a new note via `new_note()` or `follow_link()`
        -- to a non-existing note
        -- - prefer_new_note: use `new_note` template
        -- - smart: if day or week is detected in title, use daily / weekly templates (default)
        -- - always_ask: always ask before creating a note
        template_handling = "smart",

        -- path handling:
        --   this applies to:
        --     - new_note()
        --     - new_templated_note()
        --     - follow_link() to non-existing note
        --
        --   it does NOT apply to:
        --     - goto_today()
        --     - goto_thisweek()
        --
        --   Valid options:
        --     - smart: put daily-looking notes in daily, weekly-looking ones in weekly,
        --              all other ones in home, except for notes/with/subdirs/in/title.
        --              (default)
        --
        --     - prefer_home: put all notes in home except for goto_today(), goto_thisweek()
        --                    except for notes/with/subdirs/in/title.
        --
        --     - same_as_current: put all new notes in the dir of the current note if
        --                        present or else in home
        --                        except for notes/with/subdirs/in/title.
        new_note_location = "smart",

        -- should all links be updated when a file is renamed
        rename_update_links = true,

        -- how to preview media files
        -- "telescope-media-files" if you have telescope-media-files.nvim installed
        -- "catimg-previewer" if you have catimg installed
        -- "viu-previewer" if you have viu installed
        media_previewer = "telescope-media-files",

        -- A customizable fallback handler for urls.
        follow_url_fallback = nil,
    }
    M.Cfg = cfg
    M.Cfg.note_type_templates = {
        normal = M.Cfg.template_new_note,
        daily = M.Cfg.template_new_daily,
        weekly = M.Cfg.template_new_weekly,
    }
end

local function make_config_path_absolute(path)
    local ret = path
    if not (Path:new(path):is_absolute()) and path ~= nil then
        ret = M.Cfg.home .. "/" .. path
    end
    return ret
end

---set up calendar integration: forward to our lua functions
---@param opts table
local function SetupCalendar(opts)
    local defaults = M.Cfg.calendar_opts
    opts = opts or defaults

    local cmd = [[
        function! MyCalSign(day, month, year)
            return luaeval('require("telekasten").CalendarSignDay(_A[1], _A[2], _A[3])', [a:day, a:month, a:year])
        endfunction

        function! MyCalAction(day, month, year, weekday, dir)
            " day : day
            " month : month
            " year year
            " weekday : day of week (monday=1)
            " dir : direction of calendar
            return luaeval('require("telekasten").CalendarAction(_A[1], _A[2], _A[3], _A[4], _A[5])',
                                                                 \ [a:day, a:month, a:year, a:weekday, a:dir])
        endfunction

        function! MyCalBegin()
            " too early, windown doesn't exist yet
            " cannot resize
        endfunction

        let g:calendar_sign = 'MyCalSign'
        let g:calendar_action = 'MyCalAction'
        " let g:calendar_begin = 'MyCalBegin'

        let g:calendar_mark = '{{calendar_mark}}'
        let g:calendar_weeknm = {{weeknm}}
    ]]

    for k, v in pairs(opts) do
        cmd = cmd:gsub("{{" .. k .. "}}", v)
    end
    vim.cmd(cmd)
    if opts.calendar_monday == 1 then
        vim.cmd("let g:calendar_monday = 1")
    end
end


---Overrides config with elements from cfg. See top of file for defaults.
---@param cfg table
function M.Setup(cfg)
    cfg = cfg or {}
    defaultConfig(cfg.home)
    local debug = cfg.debug
    for k, v in pairs(cfg) do
        -- merge everything but calendar opts
        -- they will be merged later
        if k ~= "calendar_opts" then
            if k == "home" then
                v = v
            end
            M.Cfg[k] = v
            if debug then
                print(
                    "Setup() setting `"
                        .. k
                        .. "`   ->   `"
                        .. tostring(v)
                        .. "`"
                )
            end
        end
    end
    -- TODO: this is obsolete:
    if vim.fn.executable("rg") == 1 then
        M.Cfg.find_command = { "rg", "--files", "--sortr", "created" }
    else
        M.Cfg.find_command = nil
    end

    -- this looks a little messy
    if M.Cfg.plug_into_calendar then
        cfg.calendar_opts = cfg.calendar_opts or {}
        M.Cfg.calendar_opts = M.Cfg.calendar_opts or {}
        M.Cfg.calendar_opts.weeknm = cfg.calendar_opts.weeknm
            or M.Cfg.calendar_opts.weeknm
            or 1
        M.Cfg.calendar_opts.calendar_monday = cfg.calendar_opts.calendar_monday
            or M.Cfg.calendar_opts.calendar_monday
            or 1
        M.Cfg.calendar_opts.calendar_mark = cfg.calendar_opts.calendar_mark
            or M.Cfg.calendar_opts.calendar_mark
            or "left-fit"
        SetupCalendar(M.Cfg.calendar_opts)
    end

    -- setup extensions to filter for
    M.Cfg.filter_extensions = cfg.filter_extensions or { M.Cfg.extension }

    -- provide fake filenames for template loading to fail silently if template is configured off
    M.Cfg.template_new_note = M.Cfg.template_new_note or "none"
    M.Cfg.template_new_daily = M.Cfg.template_new_daily or "none"
    M.Cfg.template_new_weekly = M.Cfg.template_new_weekly or "none"

    -- refresh templates
    M.Cfg.note_type_templates = {
        normal = M.Cfg.template_new_note,
        daily = M.Cfg.template_new_daily,
        weekly = M.Cfg.template_new_weekly,
    }

    -- for previewers to pick up our syntax, we need to tell plenary to override `.md` with our syntax
    if M.Cfg.auto_set_filetype then
        filetype.add_file("telekasten")
    end
    -- setting the syntax moved into plugin/telekasten.vim
    -- and does not work

    if M.Cfg.take_over_my_home == true then
        if M.Cfg.auto_set_filetype then
            vim.cmd(
                "au BufEnter "
                    .. M.Cfg.home
                    .. "/*"
                    .. M.Cfg.extension
                    .. " set ft=telekasten"
            )
        end
    end

    if debug then
        print("Resulting config:")
        print("-----------------")
        print(vim.inspect(M.Cfg))
    end

    -- Convert all directories in full path
    M.Cfg.image_subdir = make_config_path_absolute(M.Cfg.image_subdir)
    M.Cfg.dailies = make_config_path_absolute(M.Cfg.dailies)
    M.Cfg.weeklies = make_config_path_absolute(M.Cfg.weeklies)
    M.Cfg.templates = make_config_path_absolute(M.Cfg.templates)

    -- Check if ripgrep is compiled with --pcre
    -- ! This will need to be fixed when neovim moves to lua >=5.2 by the following:
    -- M.Cfg.rg_pcre = os.execute("echo 'hello' | rg --pcr2 hello &> /dev/null") or false

    M.Cfg.rg_pcre = false
    local has_pcre = os.execute("echo 'hello' | rg --pcre2 hello &> /dev/null")
    if has_pcre == 0 then
        M.Cfg.rg_pcre = true
    end
    M.Cfg.media_previewer = cfg.media_previewer
end

---wrapper around Setup that handles vault-specific configuration
---@param cfg table
function M._setup(cfg)
    if cfg.vaults ~= nil and cfg.default_vault ~= nil then
        M.vaults = cfg.vaults
        cfg.vaults = nil
        M.Setup(cfg.vaults[cfg.default_vault])
    elseif cfg.vaults ~= nil and cfg.vaults["default"] ~= nil then
        M.vaults = cfg.vaults
        cfg.vaults = nil
        M.Setup(cfg.vaults["default"])
    elseif cfg.home ~= nil then
        M.vaults = cfg.vaults or {}
        cfg.vaults = nil
        M.vaults["default"] = cfg
        M.Setup(cfg)
    end

    return M.Cfg
end

return M
