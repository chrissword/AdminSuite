AS = AS or {}
AS.Theme = {}

--=====================================================
--  COLOR PALETTES
--=====================================================

AS.Theme = {
    dark = {
        bg = "#1D2022",
        panel = "#24272A",
        text = "#FFFFFF",
        accent = "#DF5702",
        accentBright = "#FA8903",
    },

    light = {
        bg = "#F4E9D7",
        panel = "#F4E9D7",
        text = "#181713",
        accent = "#DF5702",
        accentBright = "#FA8903",
    }
}


--=====================================================
--  TYPOGRAPHY & SPACING TOKENS
--=====================================================

AS.Theme.Spacing = {
    xs = 2,
    sm = 4,
    md = 8,
    lg = 12,
    xl = 16,
}

AS.Theme.FontSizes = {
    xs      = 10,
    sm      = 12,
    md      = 14,
    lg      = 18,
    xl      = 22,
    display = 28,
}

AS.Theme.Radii = {
    sm = 2,
    md = 4,
    lg = 8,
    xl = 12,
    pill = 999, -- for pill-style buttons/badges
}

--=====================================================
--  SURFACES (PANELS / HEADER / FOOTER / CARDS)
--=====================================================

AS.Theme.Surfaces = {
    Dark = {
        AppBg      = '#181B1E',
        Panel      = '#212528',
        PanelAlt   = '#262A2E',
        Header     = '#151719',
        Nav        = '#181B1E',
        Footer     = '#181B1E',
        Card       = '#262A2E',
        InputBg    = '#1C1F22',
        InputBorder= '#33373B',
        TagBg      = '#2F3438',
        TagText    = '#FFFFFF',
    },
    Light = {
        AppBg      = '#EFE1CC',
        Panel      = '#F9F0E2',
        PanelAlt   = '#F3E5D2',
        Header     = '#E3D3BD',
        Nav        = '#E6D7C3',
        Footer     = '#E3D3BD',
        Card       = '#F9F0E2',
        InputBg    = '#FFFFFF',
        InputBorder= '#D1C3AB',
        TagBg      = '#E0CFB6',
        TagText    = '#181713',
    },
}

--=====================================================
--  BUTTON TOKENS (PRIMARY / SECONDARY / GHOST / DANGER)
--=====================================================

AS.Theme.Buttons = {
    Dark = {
        Primary = {
            Bg       = '#DF5702',
            BgHover  = '#FA8903',
            BgActive = '#C44800',
            Text     = '#FFFFFF',
            Border   = 'transparent',
        },
        Secondary = {
            Bg       = 'transparent',
            BgHover  = 'rgba(250, 137, 3, 0.12)',
            BgActive = 'rgba(250, 137, 3, 0.20)',
            Text     = '#FA8903',
            Border   = 'rgba(250, 137, 3, 0.35)',
        },
        Ghost = {
            Bg       = 'transparent',
            BgHover  = 'rgba(255, 255, 255, 0.06)',
            BgActive = 'rgba(255, 255, 255, 0.12)',
            Text     = '#FFFFFF',
            Border   = 'transparent',
        },
        Danger = {
            Bg       = '#ff4d4d',
            BgHover  = '#ff6666',
            BgActive = '#e63b3b',
            Text     = '#FFFFFF',
            Border   = 'transparent',
        },
    },
    Light = {
        Primary = {
            Bg       = '#181713',
            BgHover  = '#2A2720',
            BgActive = '#12100D',
            Text     = '#F4E9D7',
            Border   = 'transparent',
        },
        Secondary = {
            Bg       = 'transparent',
            BgHover  = 'rgba(24, 23, 19, 0.06)',
            BgActive = 'rgba(24, 23, 19, 0.12)',
            Text     = '#181713',
            Border   = 'rgba(24, 23, 19, 0.25)',
        },
        Ghost = {
            Bg       = 'transparent',
            BgHover  = 'rgba(24, 23, 19, 0.04)',
            BgActive = 'rgba(24, 23, 19, 0.08)',
            Text     = '#181713',
            Border   = 'transparent',
        },
        Danger = {
            Bg       = '#d9534f',
            BgHover  = '#e26a66',
            BgActive = '#c74440',
            Text     = '#FFFFFF',
            Border   = 'transparent',
        },
    },
}

--=====================================================
--  REPORTS UI (ALWAYS DARK WITH ≥7:1 HEADER CONTRAST)
--=====================================================

AS.Theme.Reports = {
    Background   = '#1D2022',
    HeaderBg     = '#000000',
    HeaderText   = '#FFFFFF',
    Accent       = '#DF5702',
    BodyText     = '#FFFFFF',
    RowHover     = '#25292B',
    BadgeBg      = '#DF5702',
    BadgeText    = '#FFFFFF',
}

--=====================================================
--  HELPERS
--=====================================================

-- Existing helper: returns the core palette for a mode
function AS.Theme.Get(mode)
    if mode == 'light' then
        return AS.Theme.Light
    end
    return AS.Theme.Dark
end

-- New helper: returns component-level tokens for a mode
function AS.Theme.GetTokens(mode)
    local isLight = (mode == 'light')
    return {
        Base     = AS.Theme.Get(mode),
        Spacing  = AS.Theme.Spacing,
        Fonts    = AS.Theme.FontSizes,
        Radii    = AS.Theme.Radii,
        Surfaces = isLight and AS.Theme.Surfaces.Light or AS.Theme.Surfaces.Dark,
        Buttons  = isLight and AS.Theme.Buttons.Light   or AS.Theme.Buttons.Dark,
        Reports  = AS.Theme.Reports,
    }
end
