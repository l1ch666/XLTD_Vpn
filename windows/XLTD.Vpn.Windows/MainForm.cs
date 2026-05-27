using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using XLTD.Vpn.Windows.Controls;
using XLTD.Vpn.Windows.Models;
using XLTD.Vpn.Windows.Services;

namespace XLTD.Vpn.Windows;

// Dark cockpit redesign (v2 — matches Android dark theme spec).
// Layout:
//   Left 220 px  — nav rail (logo + 5 nav items)
//   Right fill   — content pane that switches per active nav tab
internal sealed class MainForm : Form
{
    // ── Dark cockpit palette ──────────────────────────────────────────────
    private static readonly Color C_BG        = Color.FromArgb(0x13, 0x12, 0x1A);
    private static readonly Color C_SURFACE   = Color.FromArgb(0x1A, 0x19, 0x28);
    private static readonly Color C_SURFACE2  = Color.FromArgb(0x22, 0x20, 0x36);
    private static readonly Color C_BORDER    = Color.FromArgb(0x2A, 0x2A, 0x3E);
    private static readonly Color C_TEXT      = Color.FromArgb(0xF0, 0xF0, 0xF8);
    private static readonly Color C_TEXT_DIM  = Color.FromArgb(0x99, 0x99, 0xAF);
    private static readonly Color C_TEXT_MUT  = Color.FromArgb(0x55, 0x55, 0x6A);
    private static readonly Color C_PRIMARY   = Color.FromArgb(0x6C, 0x5C, 0xE7);
    private static readonly Color C_PRI_LT    = Color.FromArgb(0xA8, 0x9F, 0xF5);
    private static readonly Color C_PRI_DEEP  = Color.FromArgb(0x5B, 0x4F, 0xD6);
    private static readonly Color C_OK        = Color.FromArgb(0x00, 0xD2, 0xFF);
    private static readonly Color C_WARN      = Color.FromArgb(0xE1, 0x70, 0x55);

    // ── Nav tabs ──────────────────────────────────────────────────────────
    private const int TAB_HOME     = 0;
    private const int TAB_PROFILES = 1;
    private const int TAB_TRAFFIC  = 2;
    private const int TAB_SETTINGS = 3;
    private const int TAB_LOG      = 4;
    private int activeTab = TAB_HOME;

    // ── Services ──────────────────────────────────────────────────────────
    private readonly ProfileStore       profileStore = new();
    private readonly CoreProcessManager core         = new();
    private readonly WindowsTunnelManager tunnel     = new();
    private readonly WindowsProxyManager proxy       = new();
    private readonly List<Profile>      profiles;

    // ── Nav rail ──────────────────────────────────────────────────────────
    private readonly Panel navRail = new();
    private readonly NavRailItem[] navItems = new NavRailItem[5];

    // ── Status hero (Home) ────────────────────────────────────────────────
    private readonly Label heroStateLabel  = new();
    private readonly Label heroSpeedLabel  = new();
    private readonly Label heroCtxLabel    = new();
    private readonly Label heroPillLabel   = new();
    private readonly Button connectButton  = new PillButton();

    // ── Profiles (Home + Profiles tab) ────────────────────────────────────
    private readonly ListBox profilesList = new();
    private readonly TextBox nameBox      = new();
    private readonly TextBox linkBox      = new();
    private readonly Button  saveButton   = new PillButton();
    private readonly Button  deleteButton = new PillButton();

    // ── Traffic / Metrics (non-readonly: assigned in BuildMetricCard) ─────
    private Label rxLabel      = new();
    private Label txLabel      = new();
    private Label latLabel     = new();
    private Label uptimeLabel  = new();

    // ── Settings ──────────────────────────────────────────────────────────
    private readonly ComboBox routeModeBox = new();

    // ── Runtime log (Log tab + Home mini) ────────────────────────────────
    private readonly RichTextBox logBox   = new();
    private readonly RichTextBox miniLog  = new();

    // ── Active page container (swapped on nav change) ─────────────────────
    private Panel? pagePane;
    private bool isConnected;

    // ── DwmApi dark title bar ─────────────────────────────────────────────
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    private const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;

    public MainForm()
    {
        profiles = profileStore.Load();

        Text = $"{AppInfo.ProductName}  v{AppInfo.WindowsVersion} · WIN-X64";
        MinimumSize = new Size(980, 660);
        Size        = new Size(1160, 760);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor  = C_BG;
        ForeColor  = C_TEXT;
        Font       = new Font("Segoe UI", 10f);

        BuildUi();
        WireEvents();
        RefreshProfilesList();
        SetHeroState("Disconnected", "");
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        // Enable dark title bar on Windows 10 (19041+) / 11
        try
        {
            int dark = 1;
            DwmSetWindowAttribute(Handle, DWMWA_USE_IMMERSIVE_DARK_MODE, ref dark, sizeof(int));
        }
        catch { /* ignore on older Windows */ }
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        tunnel.Dispose();
        proxy.Restore();
        core.Dispose();
        base.OnFormClosing(e);
    }

    // ═════════════════════════════════════════════════════════════════════
    //  BUILD UI
    // ═════════════════════════════════════════════════════════════════════

    private void BuildUi()
    {
        var root = new TableLayoutPanel
        {
            Dock        = DockStyle.Fill,
            ColumnCount = 2,
            RowCount    = 1,
            BackColor   = C_BG,
            Padding     = Padding.Empty,
            Margin      = Padding.Empty,
            CellBorderStyle = TableLayoutPanelCellBorderStyle.None
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 220));
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,  100));
        Controls.Add(root);

        // ── Left: nav rail ───────────────────────────────────────────────
        BuildNavRail();
        root.Controls.Add(navRail, 0, 0);

        // ── Right: page area ─────────────────────────────────────────────
        var rightHost = new Panel { Dock = DockStyle.Fill, BackColor = C_BG };
        rightHost.Padding = new Padding(0, 0, 16, 16);
        root.Controls.Add(rightHost, 1, 0);
        pagePane = new Panel { Dock = DockStyle.Fill, BackColor = C_BG };
        rightHost.Controls.Add(pagePane);
        RenderPage();
    }

    private void BuildNavRail()
    {
        navRail.Dock      = DockStyle.Fill;
        navRail.BackColor = C_SURFACE;
        navRail.Padding   = new Padding(0, 8, 0, 8);

        // App logo row
        var logoPanel = new Panel { Height = 56, Dock = DockStyle.Top, BackColor = C_SURFACE };
        var logo = new Label
        {
            Text      = "◉  XLTD VPN",
            Font      = new Font("Segoe UI", 13f, FontStyle.Bold),
            ForeColor = C_TEXT,
            TextAlign = ContentAlignment.MiddleLeft,
            Dock      = DockStyle.Fill,
            Padding   = new Padding(18, 0, 0, 0)
        };
        var ver = new Label
        {
            Text      = AppInfo.WindowsVersion,
            ForeColor = C_TEXT_MUT,
            Font      = new Font("Segoe UI", 8f),
            TextAlign = ContentAlignment.BottomLeft,
            Dock      = DockStyle.Bottom,
            Height    = 18,
            Padding   = new Padding(22, 0, 0, 4)
        };
        logoPanel.Controls.Add(logo);
        logoPanel.Controls.Add(ver);
        navRail.Controls.Add(logoPanel);

        // Divider
        var divider = new Panel { Height = 1, Dock = DockStyle.Top, BackColor = C_BORDER };
        navRail.Controls.Add(divider);

        // Nav items
        string[] labels  = { "Главная", "Профили", "Трафик", "Настройки", "Лог" };
        int[]    icons   = { NavRailItem.ICON_HOME, NavRailItem.ICON_PROFILES,
                              NavRailItem.ICON_TRAFFIC, NavRailItem.ICON_SETTINGS, NavRailItem.ICON_LOG };
        int[]    tabs    = { TAB_HOME, TAB_PROFILES, TAB_TRAFFIC, TAB_SETTINGS, TAB_LOG };

        for (int i = 0; i < 5; i++)
        {
            var item = new NavRailItem(labels[i], icons[i], tabs[i] == activeTab);
            int tabCopy = tabs[i];
            item.Click += (_, _) => SwitchTab(tabCopy);
            navItems[i] = item;
            navRail.Controls.Add(item);
        }
    }

    private void RenderPage()
    {
        if (pagePane == null) return;
        pagePane.Controls.Clear();

        switch (activeTab)
        {
            case TAB_HOME:     BuildHomePage();     break;
            case TAB_PROFILES: BuildProfilesPage(); break;
            case TAB_TRAFFIC:  BuildTrafficPage();  break;
            case TAB_SETTINGS: BuildSettingsPage(); break;
            case TAB_LOG:      BuildLogPage();      break;
        }

        RefreshDynamicUi();
    }

    private void SwitchTab(int tab)
    {
        activeTab = tab;
        for (int i = 0; i < navItems.Length; i++)
            navItems[i].SetActive(i == tab);
        RenderPage();
    }

    // ── Home page ─────────────────────────────────────────────────────────

    private void BuildHomePage()
    {
        var outer = new TableLayoutPanel
        {
            Dock       = DockStyle.Fill,
            ColumnCount = 1,
            RowCount   = 3,
            BackColor  = C_BG,
            Padding    = new Padding(16, 12, 0, 0)
        };
        outer.RowStyles.Add(new RowStyle(SizeType.Absolute, 160));  // hero
        outer.RowStyles.Add(new RowStyle(SizeType.Percent,  100));  // profiles + log
        outer.RowStyles.Add(new RowStyle(SizeType.Absolute, 70));   // route + connect
        pagePane!.Controls.Add(outer);

        outer.Controls.Add(BuildHeroPanel(), 0, 0);
        outer.Controls.Add(BuildTwoColPanel(), 0, 1);
        outer.Controls.Add(BuildRoutePanel(), 0, 2);
    }

    private Panel BuildHeroPanel()
    {
        var hero = DarkCard();
        hero.Padding = new Padding(20, 14, 20, 14);

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, BackColor = Color.Transparent
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 160));
        hero.Controls.Add(layout);

        // Left: badge + speed + context
        var left = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent };

        heroStateLabel.Dock      = DockStyle.Top;
        heroStateLabel.Height    = 26;
        heroStateLabel.Font      = new Font("Segoe UI", 10f, FontStyle.Bold);
        heroStateLabel.ForeColor = C_TEXT_MUT;
        left.Controls.Add(heroStateLabel);

        heroSpeedLabel.Dock      = DockStyle.Top;
        heroSpeedLabel.Height    = 52;
        heroSpeedLabel.Font      = new Font("Segoe UI Semibold", 30f, FontStyle.Bold);
        heroSpeedLabel.ForeColor = C_TEXT;
        left.Controls.Add(heroSpeedLabel);

        heroCtxLabel.Dock      = DockStyle.Top;
        heroCtxLabel.Height    = 22;
        heroCtxLabel.Font      = new Font("Segoe UI", 9f);
        heroCtxLabel.ForeColor = C_TEXT_DIM;
        left.Controls.Add(heroCtxLabel);

        heroPillLabel.Dock      = DockStyle.Top;
        heroPillLabel.Height    = 20;
        heroPillLabel.Font      = new Font("Segoe UI", 8.5f);
        heroPillLabel.ForeColor = C_TEXT_MUT;
        left.Controls.Add(heroPillLabel);

        layout.Controls.Add(left, 0, 0);

        // Right: connect button
        var right = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent, Padding = new Padding(12, 8, 0, 8) };
        connectButton.Text = "Connect";
        connectButton.Dock = DockStyle.Fill;
        StylePrimary(connectButton);
        right.Controls.Add(connectButton);
        layout.Controls.Add(right, 1, 0);
        return hero;
    }

    private TableLayoutPanel BuildTwoColPanel()
    {
        var twoCol = new TableLayoutPanel
        {
            Dock        = DockStyle.Fill,
            ColumnCount = 2,
            RowCount    = 1,
            BackColor   = C_BG,
            Padding     = new Padding(0, 8, 0, 8),
            Margin      = Padding.Empty
        };
        twoCol.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 48));
        twoCol.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 52));

        // Profiles mini-panel
        var profPanel = DarkCard();
        profPanel.Padding = new Padding(14, 10, 14, 10);
        var profHeader = SectionRow("ПРОФИЛИ", "+ добавить", () => SwitchTab(TAB_PROFILES));
        profPanel.Controls.Add(profHeader);
        profilesList.Dock          = DockStyle.Fill;
        profilesList.IntegralHeight = false;
        profilesList.BorderStyle   = BorderStyle.None;
        profilesList.BackColor     = Color.Transparent;
        profilesList.ForeColor     = C_TEXT;
        profilesList.DrawMode      = DrawMode.OwnerDrawFixed;
        profilesList.ItemHeight    = 52;
        profilesList.Font          = new Font("Segoe UI", 9.5f);
        profPanel.Controls.Add(profilesList);
        profilesList.BringToFront();
        twoCol.Controls.Add(profPanel, 0, 0);

        // Mini event log panel
        var logPanel = DarkCard();
        logPanel.Padding = new Padding(14, 10, 14, 10);
        var logHeader = SectionRow("СОБЫТИЯ", "все →", () => SwitchTab(TAB_LOG));
        logPanel.Controls.Add(logHeader);
        miniLog.Dock      = DockStyle.Fill;
        miniLog.ReadOnly  = true;
        miniLog.BorderStyle = BorderStyle.None;
        miniLog.BackColor = Color.Transparent;
        miniLog.ForeColor = C_TEXT_DIM;
        miniLog.Font      = new Font("Consolas", 8.5f);
        miniLog.ScrollBars = RichTextBoxScrollBars.Vertical;
        logPanel.Controls.Add(miniLog);
        miniLog.BringToFront();
        twoCol.Controls.Add(logPanel, 1, 0);
        return twoCol;
    }

    private Panel BuildRoutePanel()
    {
        var panel = DarkCard();
        panel.Padding = new Padding(16, 8, 16, 8);

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, BackColor = Color.Transparent
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 180));
        panel.Controls.Add(layout);

        routeModeBox.Dock         = DockStyle.Fill;
        routeModeBox.DropDownStyle = ComboBoxStyle.DropDownList;
        routeModeBox.BackColor    = C_SURFACE2;
        routeModeBox.ForeColor    = C_TEXT;
        routeModeBox.FlatStyle    = FlatStyle.Flat;
        routeModeBox.Font         = new Font("Segoe UI", 9.5f);
        routeModeBox.Items.AddRange(new object[]
        {
            "Local SOCKS only",
            "Windows user proxy (beta)",
            "Full tunnel / Wintun (admin beta)"
        });
        routeModeBox.SelectedIndex = 0;
        layout.Controls.Add(routeModeBox, 0, 0);

        var hint = new Label
        {
            Text      = WindowsTunnelManager.IsAdministrator()
                ? "Full tunnel available (elevated session)"
                : "Full tunnel requires admin elevation",
            ForeColor = C_TEXT_MUT,
            Font      = new Font("Segoe UI", 8.5f),
            Dock      = DockStyle.Right,
            AutoSize  = true,
            TextAlign = ContentAlignment.MiddleRight
        };
        layout.Controls.Add(hint, 1, 0);
        return panel;
    }

    // ── Profiles page ─────────────────────────────────────────────────────

    private void BuildProfilesPage()
    {
        var outer = new TableLayoutPanel
        {
            Dock        = DockStyle.Fill,
            ColumnCount = 1,
            RowCount    = 2,
            BackColor   = C_BG,
            Padding     = new Padding(16, 12, 0, 0)
        };
        outer.RowStyles.Add(new RowStyle(SizeType.Percent, 45));
        outer.RowStyles.Add(new RowStyle(SizeType.Percent, 55));
        pagePane!.Controls.Add(outer);

        // Profiles list card
        var profCard = DarkCard();
        profCard.Padding = new Padding(14, 10, 14, 10);
        var profHeader = SectionRow("ПРОФИЛИ", null, null);
        profCard.Controls.Add(profHeader);
        var profList2 = profilesList;
        profList2.Dock = DockStyle.Fill;
        profCard.Controls.Add(profList2);
        profList2.BringToFront();
        outer.Controls.Add(profCard, 0, 0);

        // Editor card
        outer.Controls.Add(BuildEditorCard(), 0, 1);
    }

    private Panel BuildEditorCard()
    {
        var card = DarkCard();
        card.Padding = new Padding(16, 12, 16, 12);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 5, ColumnCount = 1, BackColor = Color.Transparent };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 26));  // section label
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));  // name
        layout.RowStyles.Add(new RowStyle(SizeType.Percent,  100)); // link
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 46));  // buttons
        card.Controls.Add(layout);

        layout.Controls.Add(DarkSectionLabel("РЕДАКТОР ПРОФИЛЯ"), 0, 0);

        nameBox.PlaceholderText = "Название профиля";
        StyleTextBox(nameBox);
        layout.Controls.Add(nameBox, 0, 1);

        linkBox.PlaceholderText = "olcrtc://carrier?transport<params>@room#64hexkey$comment";
        linkBox.Multiline  = true;
        linkBox.ScrollBars = ScrollBars.Vertical;
        StyleTextBox(linkBox);
        layout.Controls.Add(linkBox, 0, 2);

        var buttons = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill, FlowDirection = FlowDirection.RightToLeft,
            Padding = new Padding(0, 4, 0, 0), WrapContents = false, BackColor = Color.Transparent
        };
        saveButton.Text   = "Сохранить"; saveButton.Width   = 120; StylePrimary(saveButton);
        deleteButton.Text = "Удалить";   deleteButton.Width = 110; StyleDanger(deleteButton);
        var newBtn = new PillButton { Text = "Новый", Width = 100 };
        StyleSecondary(newBtn);
        newBtn.Click += (_, _) => ClearEditor();
        buttons.Controls.Add(saveButton);
        buttons.Controls.Add(deleteButton);
        buttons.Controls.Add(newBtn);
        layout.Controls.Add(buttons, 0, 3);
        return card;
    }

    // ── Traffic page ──────────────────────────────────────────────────────

    private void BuildTrafficPage()
    {
        var outer = new TableLayoutPanel
        {
            Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2,
            BackColor = C_BG, Padding = new Padding(16, 12, 0, 0)
        };
        outer.RowStyles.Add(new RowStyle(SizeType.Absolute, 140));
        outer.RowStyles.Add(new RowStyle(SizeType.Percent,  100));
        pagePane!.Controls.Add(outer);

        // 4-wide metrics grid
        var metrics = new TableLayoutPanel
        {
            Dock = DockStyle.Fill, ColumnCount = 4, RowCount = 1, BackColor = C_BG, Margin = Padding.Empty
        };
        for (int i = 0; i < 4; i++)
            metrics.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 25));
        outer.Controls.Add(metrics, 0, 0);

        rxLabel     = BuildMetricCard(metrics, "↓ ВХОДЯЩИЙ", 0);
        txLabel     = BuildMetricCard(metrics, "↑ ИСХОДЯЩИЙ", 1);
        latLabel    = BuildMetricCard(metrics, "ЗАДЕРЖКА", 2);
        uptimeLabel = BuildMetricCard(metrics, "АПТАЙМ", 3);

        // Full log below metrics
        var logCard = DarkCard();
        logCard.Padding = new Padding(14, 10, 14, 10);
        logCard.Controls.Add(DarkSectionLabel("RUNTIME LOG"));
        logBox.Dock       = DockStyle.Fill;
        logBox.ReadOnly   = true;
        logBox.BorderStyle = BorderStyle.None;
        logBox.BackColor  = Color.Transparent;
        logBox.ForeColor  = C_TEXT_DIM;
        logBox.Font       = new Font("Consolas", 9f);
        logBox.ScrollBars = RichTextBoxScrollBars.Vertical;
        logCard.Controls.Add(logBox);
        logBox.BringToFront();
        outer.Controls.Add(logCard, 0, 1);
    }

    private Label BuildMetricCard(TableLayoutPanel grid, string title, int col)
    {
        var card = DarkCard();
        card.Padding = new Padding(14, 12, 14, 12);
        card.Controls.Add(new Label
        {
            Text = title, Dock = DockStyle.Top, Height = 18,
            Font = new Font("Segoe UI", 7.5f, FontStyle.Bold),
            ForeColor = C_TEXT_MUT
        });
        var value = new Label
        {
            Text = "—", Dock = DockStyle.Top, Height = 36,
            Font = new Font("Cascadia Code", 18f),
            ForeColor = C_TEXT
        };
        card.Controls.Add(value);
        value.BringToFront();
        grid.Controls.Add(card, col, 0);
        return value;
    }

    // ── Settings page ─────────────────────────────────────────────────────

    private void BuildSettingsPage()
    {
        var card = DarkCard();
        card.Dock    = DockStyle.Fill;
        card.Padding = new Padding(20, 16, 20, 16);
        pagePane!.Controls.Add(card);
        var t = pagePane.Padding;
        pagePane.Padding = new Padding(16, 12, 0, 0);

        card.Controls.Add(DarkSectionLabel("НАСТРОЙКИ"));

        var hint = new Label
        {
            Text = "Маршрутизация (выбрать до подключения):",
            Dock = DockStyle.Top, Height = 24,
            ForeColor = C_TEXT_DIM, Font = new Font("Segoe UI", 9.5f)
        };
        card.Controls.Add(hint);

        var routeLabel = DarkSectionLabel("ROUTE MODE");
        card.Controls.Add(routeLabel);

        var rc = new TableLayoutPanel { Dock = DockStyle.Top, Height = 44, ColumnCount = 3, RowCount = 1, BackColor = Color.Transparent };
        rc.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33));
        rc.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33));
        rc.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 34));

        string[] modes = { "SOCKS Only", "User Proxy (β)", "Full Tunnel (β)" };
        for (int i = 0; i < 3; i++)
        {
            int idx = i;
            var btn = new PillButton { Text = modes[i], Dock = DockStyle.Fill, Radius = 12 };
            if (i == routeModeBox.SelectedIndex) StylePrimary(btn);
            else StyleSecondary(btn);
            btn.Click += (_, _) =>
            {
                routeModeBox.SelectedIndex = idx;
                BuildSettingsPage(); // re-render
            };
            rc.Controls.Add(btn, i, 0);
        }
        card.Controls.Add(rc);

        var adminHint = new Label
        {
            Text = WindowsTunnelManager.IsAdministrator()
                ? "✓ Запущено с правами администратора — Full Tunnel доступен."
                : "⚠ Full Tunnel требует прав администратора.",
            ForeColor = WindowsTunnelManager.IsAdministrator() ? C_OK : C_WARN,
            Font      = new Font("Segoe UI", 9f),
            Dock      = DockStyle.Top, Height = 24
        };
        card.Controls.Add(adminHint);
    }

    // ── Log page ──────────────────────────────────────────────────────────

    private void BuildLogPage()
    {
        var card = DarkCard();
        card.Dock    = DockStyle.Fill;
        card.Padding = new Padding(14, 10, 14, 10);
        card.Controls.Add(DarkSectionLabel("RUNTIME LOG"));
        logBox.Dock       = DockStyle.Fill;
        logBox.ReadOnly   = true;
        logBox.BorderStyle = BorderStyle.None;
        logBox.BackColor  = Color.Transparent;
        logBox.ForeColor  = C_TEXT_DIM;
        logBox.Font       = new Font("Consolas", 9f);
        logBox.ScrollBars = RichTextBoxScrollBars.Vertical;
        card.Controls.Add(logBox);
        logBox.BringToFront();
        pagePane!.Padding = new Padding(16, 12, 0, 0);
        pagePane.Controls.Add(card);
    }

    // ═════════════════════════════════════════════════════════════════════
    //  EVENTS & LOGIC
    // ═════════════════════════════════════════════════════════════════════

    private void WireEvents()
    {
        profilesList.SelectedIndexChanged += (_, _) =>
        {
            if (profilesList.SelectedItem is Profile profile)
            {
                nameBox.Text = profile.Name;
                linkBox.Text = profile.Link;
            }
        };
        profilesList.DrawItem += DrawProfileItem;
        saveButton.Click   += (_, _) => SaveProfile();
        deleteButton.Click += (_, _) => DeleteSelectedProfile();
        connectButton.Click += async (_, _) => await ToggleConnectionAsync();

        core.LogLine += line => Ui(() => HandleCoreLogLine(line));
        tunnel.LogLine += line => Ui(() => AppendLog("[tunnel] " + line));
        core.Exited += code => Ui(() =>
        {
            isConnected = false;
            tunnel.Stop();
            proxy.Restore();
            connectButton.Text = "Connect";
            SetHeroState($"Core exited ({code})", "");
        });
    }

    private void SaveProfile()
    {
        try
        {
            var link   = linkBox.Text.Trim();
            var config = OlcUriParser.Parse(link);
            var selected = profilesList.SelectedItem as Profile;
            var profile  = selected ?? new Profile { Id = "p" + DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() };
            profile.Link      = link;
            profile.Name      = string.IsNullOrWhiteSpace(nameBox.Text) ? BuildProfileName(config) : nameBox.Text.Trim();
            profile.Carrier   = config.Carrier;
            profile.Transport = config.Transport;

            if (selected == null) profiles.Add(profile);
            profileStore.Save(profiles);
            RefreshProfilesList(profile);
            AppendLog("[status] Profile saved: " + profile.Name);
        }
        catch (Exception ex)
        {
            AppendLog("[error] Profile error: " + ex.Message);
        }
    }

    private async Task ToggleConnectionAsync()
    {
        if (core.IsRunning)
        {
            tunnel.Stop();
            proxy.Restore();
            core.Stop();
            isConnected = false;
            connectButton.Text = "Connect";
            StylePrimary(connectButton);
            SetHeroState("Disconnected", "");
            return;
        }

        try
        {
            var config = OlcUriParser.Parse(linkBox.Text.Trim());
            SaveProfile();
            connectButton.Enabled = false;
            SetHeroState("Connecting...", $"{config.Carrier} · {config.Transport}");

            core.Start(config, AppInfo.DefaultSocksPort);
            connectButton.Text = "Stop";
            StyleDanger(connectButton);

            using var cts  = new CancellationTokenSource(TimeSpan.FromSeconds(70));
            var ready = await core.WaitForSocksAsync(AppInfo.DefaultSocksPort, TimeSpan.FromSeconds(68), cts.Token);
            if (!ready)
            {
                SetHeroState(core.IsRunning ? "Waiting for SOCKS..." : "Core stopped early", "");
                return;
            }

            isConnected = true;
            SetHeroState("Connected", BuildContextLine(config));

            if (routeModeBox.SelectedIndex == 1)
            {
                proxy.ApplySocksProxy(AppInfo.DefaultSocksHost, AppInfo.DefaultSocksPort);
                AppendLog("[status] Windows user proxy enabled");
            }
            else if (routeModeBox.SelectedIndex == 2)
            {
                tunnel.Start(AppInfo.DefaultSocksPort, ResolveMtu(config));
                AppendLog("[status] Full tunnel enabled");
            }
        }
        catch (Exception ex)
        {
            tunnel.Stop();
            proxy.Restore();
            core.Stop();
            isConnected = false;
            connectButton.Text = "Connect";
            StylePrimary(connectButton);
            SetHeroState("Error: " + ex.Message, "");
        }
        finally
        {
            connectButton.Enabled = true;
        }
    }

    private void DeleteSelectedProfile()
    {
        if (profilesList.SelectedItem is not Profile profile) return;
        profiles.Remove(profile);
        profileStore.Save(profiles);
        RefreshProfilesList();
        ClearEditor();
        AppendLog("[status] Profile deleted");
    }

    private void RefreshProfilesList(Profile? select = null)
    {
        profilesList.BeginUpdate();
        profilesList.Items.Clear();
        foreach (var p in profiles) profilesList.Items.Add(p);
        profilesList.EndUpdate();
        if (select != null) profilesList.SelectedItem = select;
        else if (profiles.Count > 0 && profilesList.SelectedIndex < 0)
            profilesList.SelectedIndex = 0;
    }

    private void ClearEditor()
    {
        profilesList.ClearSelected();
        nameBox.Clear();
        linkBox.Clear();
    }

    // ═════════════════════════════════════════════════════════════════════
    //  DYNAMIC UI REFRESH
    // ═════════════════════════════════════════════════════════════════════

    private void SetHeroState(string state, string context)
    {
        heroStateLabel.Text    = state;
        heroStateLabel.ForeColor = isConnected ? C_OK : C_TEXT_MUT;
        heroCtxLabel.Text      = context;
        heroPillLabel.Text     = "SOCKS 127.0.0.1:" + AppInfo.DefaultSocksPort;
        heroSpeedLabel.Text    = isConnected ? "↓ — MB/s" : "—";
        heroSpeedLabel.ForeColor = isConnected ? C_TEXT : C_TEXT_DIM;
    }

    private void RefreshDynamicUi()
    {
        // Metrics cards (Traffic tab)
        rxLabel.Text     = "—";
        txLabel.Text     = "—";
        latLabel.Text    = "—";
        uptimeLabel.Text = "—";
    }

    private void HandleCoreLogLine(string line)
    {
        if (ShouldHideNoisyCoreLine(line)) return;
        AppendLog(line);
        var lower = line.ToLowerInvariant();
        if (lower.Contains("socks5 server listening"))
            SetHeroState(heroStateLabel.Text, heroCtxLabel.Text);
        else if (lower.Contains("ice connection state changed: connected"))
            SetHeroState("Carrier connected — waiting for handshake...", heroCtxLabel.Text);
        else if (lower.Contains("handshake client: read welcome") || lower.Contains("remote not ready"))
            SetHeroState("Handshake timeout — check room/key/server", "");
    }

    private void AppendLog(string text)
    {
        var ts  = DateTime.Now.ToString("HH:mm:ss");
        var msg = ts + "  " + text + Environment.NewLine;
        if (!logBox.IsDisposed)  logBox.AppendText(msg);
        if (!miniLog.IsDisposed) { miniLog.AppendText(msg); }
    }

    private static bool ShouldHideNoisyCoreLine(string line)
    {
        if (string.IsNullOrWhiteSpace(line)) return true;
        return line.Contains("[ice] TRACE:")
            || line.Contains("[dtls] TRACE:")
            || line.Contains("[sctp] TRACE:")
            || line.Contains("[sctp] DEBUG:")
            || line.Contains("Failed to ping without candidate pairs")
            || line.Contains("wsasendto: A socket operation was attempted")
            || line.Contains("wsasendto: The requested address is not valid");
    }

    private void DrawProfileItem(object? sender, DrawItemEventArgs e)
    {
        if (e.Index < 0 || e.Index >= profilesList.Items.Count) return;
        var profile  = (Profile)profilesList.Items[e.Index];
        var selected = (e.State & DrawItemState.Selected) == DrawItemState.Selected;

        using var bgBrush = new SolidBrush(selected ? C_SURFACE2 : C_SURFACE);
        e.Graphics.FillRectangle(bgBrush, e.Bounds);

        var rect = new Rectangle(e.Bounds.X + 4, e.Bounds.Y + 4, e.Bounds.Width - 8, e.Bounds.Height - 6);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using var path = UiShapes.RoundedRect(rect, 14);
        using var fill = new SolidBrush(selected ? Color.FromArgb(0x26, 0x24, 0x44) : Color.FromArgb(0x1E, 0x1D, 0x30));
        e.Graphics.FillPath(fill, path);

        // Purple left indicator strip
        using var strip = new SolidBrush(selected ? C_PRIMARY : Color.Transparent);
        e.Graphics.FillRectangle(strip, new Rectangle(rect.X, rect.Y, 3, rect.Height));

        TextRenderer.DrawText(e.Graphics,
            string.IsNullOrWhiteSpace(profile.Name) ? "olcRTC profile" : profile.Name,
            new Font("Segoe UI", 9.5f, FontStyle.Bold),
            new Rectangle(rect.X + 14, rect.Y + 8, rect.Width - 28, 18),
            selected ? C_TEXT : C_TEXT,
            TextFormatFlags.EndEllipsis);
        TextRenderer.DrawText(e.Graphics,
            $"{profile.Carrier}  ·  {profile.Transport}",
            new Font("Segoe UI", 8f),
            new Rectangle(rect.X + 14, rect.Y + 28, rect.Width - 28, 16),
            C_TEXT_DIM,
            TextFormatFlags.EndEllipsis);
    }

    private void Ui(Action action)
    {
        if (IsDisposed) return;
        if (InvokeRequired) BeginInvoke(action);
        else action();
    }

    // ═════════════════════════════════════════════════════════════════════
    //  HELPERS
    // ═════════════════════════════════════════════════════════════════════

    private static string BuildProfileName(OlcConfig config)
    {
        if (!string.IsNullOrWhiteSpace(config.Comment) &&
            !config.Comment.Equals("direct", StringComparison.OrdinalIgnoreCase))
            return config.Comment.Trim();
        return config.ClientId.Equals("default", StringComparison.OrdinalIgnoreCase)
            ? $"{config.Carrier} | {config.Transport}"
            : $"{config.Carrier} | {config.Transport} | {config.ClientId}";
    }

    private static string BuildContextLine(OlcConfig config)
    {
        var lanes = config.IntParam("mc-lanes", 1);
        return lanes > 1
            ? $"{config.Carrier} · {config.Transport} · {lanes} lanes"
            : $"{config.Carrier} · {config.Transport}";
    }

    // SEI is a data-channel transport and can handle full-size frames (1500 MTU).
    // Only real video transports (VP8 / video codec) need the reduced MTU.
    private static int ResolveMtu(OlcConfig config)
    {
        bool needsReducedMtu = config.Transport is OlcUriParser.TransportVp8 or OlcUriParser.TransportVideo;
        int fallback = needsReducedMtu ? 1040 : 1500;
        int requested = config.IntParam("mtu", fallback);
        return Math.Max(900, Math.Min(1500, requested));
    }

    private RoundedPanel DarkCard()
    {
        return new RoundedPanel
        {
            Dock        = DockStyle.Fill,
            FillColor   = C_SURFACE,
            BorderColor = C_BORDER,
            Radius      = 20,
            Margin      = new Padding(6, 4, 6, 4)
        };
    }

    private static Label DarkSectionLabel(string text)
    {
        return new Label
        {
            Text      = text,
            Dock      = DockStyle.Top,
            Height    = 24,
            Font      = new Font("Segoe UI", 8f, FontStyle.Bold),
            ForeColor = Color.FromArgb(0x55, 0x55, 0x6A)
        };
    }

    /// <summary>Header row with left title and optional right action link.</summary>
    private static Panel SectionRow(string title, string? action, Action? onAction)
    {
        var row = new Panel { Dock = DockStyle.Top, Height = 28, BackColor = Color.Transparent };
        var lbl = new Label
        {
            Text = title, Dock = DockStyle.Left, AutoSize = true,
            Font = new Font("Segoe UI", 8f, FontStyle.Bold),
            ForeColor = Color.FromArgb(0x55, 0x55, 0x6A),
            TextAlign = ContentAlignment.MiddleLeft
        };
        row.Controls.Add(lbl);
        if (action != null && onAction != null)
        {
            var link = new Label
            {
                Text = action, Dock = DockStyle.Right, AutoSize = true,
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = Color.FromArgb(0x6C, 0x5C, 0xE7),
                TextAlign = ContentAlignment.MiddleRight,
                Cursor = Cursors.Hand
            };
            link.Click += (_, _) => onAction();
            row.Controls.Add(link);
        }
        return row;
    }

    private void StyleTextBox(TextBox box)
    {
        box.Dock        = DockStyle.Fill;
        box.BorderStyle = BorderStyle.FixedSingle;
        box.BackColor   = C_SURFACE2;
        box.ForeColor   = C_TEXT;
        box.Font        = new Font("Segoe UI", 9.5f);
    }

    private static void StylePrimary(Button button)
    {
        if (button is PillButton pill)
        {
            pill.FillColor   = Color.FromArgb(0x6C, 0x5C, 0xE7);
            pill.HoverColor  = Color.FromArgb(0x7D, 0x6E, 0xF8);
            pill.PressedColor = Color.FromArgb(0x5B, 0x4F, 0xD6);
            pill.TextColor   = Color.White;
        }
    }

    private static void StyleSecondary(Button button)
    {
        if (button is PillButton pill)
        {
            pill.FillColor   = Color.FromArgb(0x22, 0x20, 0x36);
            pill.HoverColor  = Color.FromArgb(0x2E, 0x2C, 0x46);
            pill.PressedColor = Color.FromArgb(0x1A, 0x19, 0x28);
            pill.TextColor   = Color.FromArgb(0xA8, 0x9F, 0xF5);
        }
    }

    private static void StyleDanger(Button button)
    {
        if (button is PillButton pill)
        {
            pill.FillColor   = Color.FromArgb(0x2A, 0x15, 0x15);
            pill.HoverColor  = Color.FromArgb(0x3A, 0x20, 0x20);
            pill.PressedColor = Color.FromArgb(0x1E, 0x10, 0x10);
            pill.TextColor   = Color.FromArgb(0xE1, 0x70, 0x55);
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    //  NAV RAIL ITEM — canvas-drawn SVG-style icons (design v2)
    // ═════════════════════════════════════════════════════════════════════

    private sealed class NavRailItem : Panel
    {
        public const int ICON_HOME     = 0;
        public const int ICON_PROFILES = 1;
        public const int ICON_TRAFFIC  = 2;
        public const int ICON_SETTINGS = 3;
        public const int ICON_LOG      = 4;

        private readonly int    iconType;
        private readonly Label  textLabel;
        private bool active;

        public NavRailItem(string label, int iconType, bool active)
        {
            this.iconType = iconType;
            this.active   = active;
            Height  = 50;
            Dock    = DockStyle.Top;
            Cursor  = Cursors.Hand;
            BackColor = Color.Transparent;
            Padding = new Padding(0);

            textLabel = new Label
            {
                Text      = label,
                Font      = new Font("Segoe UI", 9f),
                ForeColor = active ? Color.FromArgb(0x6C, 0x5C, 0xE7) : Color.FromArgb(0x55, 0x55, 0x6A),
                AutoSize  = false,
                TextAlign = ContentAlignment.MiddleLeft
            };

            SetStyle(ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.UserPaint |
                     ControlStyles.OptimizedDoubleBuffer, true);
        }

        public void SetActive(bool value)
        {
            active = value;
            textLabel.ForeColor = value
                ? Color.FromArgb(0x6C, 0x5C, 0xE7)
                : Color.FromArgb(0x55, 0x55, 0x6A);
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            // Active indicator: purple left strip
            if (active)
            {
                using var strip = new SolidBrush(Color.FromArgb(0x6C, 0x5C, 0xE7));
                g.FillRectangle(strip, 0, 8, 3, Height - 16);
                using var bg = new SolidBrush(Color.FromArgb(20, 108, 92, 231));
                g.FillRectangle(bg, 3, 4, Width - 6, Height - 8);
            }

            // Icon
            var iconColor = active
                ? Color.FromArgb(0x6C, 0x5C, 0xE7)
                : Color.FromArgb(0x55, 0x55, 0x6A);
            using var pen = new Pen(iconColor, 1.5f) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };

            int ix = 18, iy = (Height - 20) / 2, is_ = 20;
            DrawIcon(g, pen, iconType, new RectangleF(ix, iy, is_, is_));

            // Label
            var labelX = ix + is_ + 10;
            TextRenderer.DrawText(g, textLabel.Text, textLabel.Font,
                new Rectangle(labelX, 0, Width - labelX - 8, Height),
                active ? Color.FromArgb(0xA8, 0x9F, 0xF5) : Color.FromArgb(0x66, 0x66, 0x7A),
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left);
        }

        private static void DrawIcon(System.Drawing.Graphics g, Pen pen, int type, RectangleF r)
        {
            float cx = r.X + r.Width / 2f, cy = r.Y + r.Height / 2f;
            float l = r.X, t = r.Top, ri = r.Right, b = r.Bottom;
            switch (type)
            {
                case ICON_HOME:
                {
                    float rBase = t + r.Height * 0.46f;
                    float bL = l + r.Width * 0.13f, bR = ri - r.Width * 0.13f;
                    g.DrawLines(pen, new[] { new PointF(l, rBase), new PointF(cx, t), new PointF(ri, rBase) });
                    g.DrawLines(pen, new[] { new PointF(bL, rBase), new PointF(bL, b), new PointF(bR, b), new PointF(bR, rBase) });
                    float dw = r.Width * 0.16f, dTop = b - r.Height * 0.46f;
                    g.DrawLines(pen, new[] { new PointF(cx - dw, b), new PointF(cx - dw, dTop), new PointF(cx + dw, dTop), new PointF(cx + dw, b) });
                    break;
                }
                case ICON_PROFILES:
                {
                    float gap = r.Height * 0.27f;
                    g.DrawLine(pen, l, cy - gap, ri, cy - gap);
                    g.DrawLine(pen, l, cy,       ri - r.Width * 0.22f, cy);
                    g.DrawLine(pen, l, cy + gap, ri - r.Width * 0.44f, cy + gap);
                    break;
                }
                case ICON_TRAFFIC:
                {
                    float cxL = l + r.Width * 0.30f, cxR = l + r.Width * 0.70f;
                    float ah = r.Height * 0.55f, hw = r.Width * 0.14f, hh = ah * 0.36f;
                    float top2 = cy - ah / 2f, bot2 = cy + ah / 2f;
                    g.DrawLine(pen, cxL, bot2, cxL, top2);
                    g.DrawLine(pen, cxL, top2, cxL - hw, top2 + hh);
                    g.DrawLine(pen, cxL, top2, cxL + hw, top2 + hh);
                    g.DrawLine(pen, cxR, top2, cxR, bot2);
                    g.DrawLine(pen, cxR, bot2, cxR - hw, bot2 - hh);
                    g.DrawLine(pen, cxR, bot2, cxR + hw, bot2 - hh);
                    break;
                }
                case ICON_SETTINGS:
                {
                    float gap = r.Height * 0.26f;
                    float kr = r.Height * 0.13f;
                    float k1x = l + r.Width * 0.65f, k2x = l + r.Width * 0.32f;
                    g.DrawLine(pen, l, cy - gap, k1x - kr, cy - gap);
                    g.DrawLine(pen, k1x + kr, cy - gap, ri, cy - gap);
                    using var fill = new SolidBrush(pen.Color);
                    g.FillEllipse(fill, k1x - kr, cy - gap - kr, kr * 2, kr * 2);
                    g.DrawLine(pen, l, cy + gap, k2x - kr, cy + gap);
                    g.DrawLine(pen, k2x + kr, cy + gap, ri, cy + gap);
                    g.FillEllipse(fill, k2x - kr, cy + gap - kr, kr * 2, kr * 2);
                    break;
                }
                case ICON_LOG:
                {
                    // Three lines with dots: console/log icon
                    float gap = r.Height * 0.25f;
                    g.DrawLine(pen, l + r.Width * 0.12f, cy - gap, ri, cy - gap);
                    g.DrawLine(pen, l + r.Width * 0.12f, cy,       ri - r.Width * 0.15f, cy);
                    g.DrawLine(pen, l + r.Width * 0.12f, cy + gap, ri - r.Width * 0.30f, cy + gap);
                    // Cursor dot
                    float dotR = r.Width * 0.06f;
                    using var fill = new SolidBrush(pen.Color);
                    g.FillEllipse(fill, l, cy + gap - dotR, dotR * 2, dotR * 2);
                    break;
                }
            }
        }

    }
}
