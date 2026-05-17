using System.Drawing;
using System.Drawing.Drawing2D;
using XLTD.Vpn.Windows.Controls;
using XLTD.Vpn.Windows.Models;
using XLTD.Vpn.Windows.Services;

namespace XLTD.Vpn.Windows;

internal sealed class MainForm : Form
{
    private readonly ProfileStore profileStore = new();
    private readonly CoreProcessManager core = new();
    private readonly WindowsTunnelManager tunnel = new();
    private readonly WindowsProxyManager proxy = new();
    private readonly List<Profile> profiles;

    private readonly ListBox profilesList = new();
    private readonly TextBox nameBox = new();
    private readonly TextBox linkBox = new();
    private readonly TextBox logBox = new();
    private readonly Label statusLabel = new();
    private readonly Label metaLabel = new();
    private readonly ComboBox routeModeBox = new();
    private readonly Button connectButton = new PillButton();
    private readonly Button saveButton = new PillButton();
    private readonly Button deleteButton = new PillButton();

    public MainForm()
    {
        profiles = profileStore.Load();
        Text = $"{AppInfo.ProductName} Windows {AppInfo.WindowsVersion}";
        MinimumSize = new Size(960, 660);
        Size = new Size(1080, 740);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(245, 246, 248);
        Font = new Font("Segoe UI", 10);

        BuildUi();
        WireEvents();
        RefreshProfiles();
        SetStatus("Ready. Add or select an olcRTC profile.");
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        tunnel.Dispose();
        proxy.Restore();
        core.Dispose();
        base.OnFormClosing(e);
    }

    private void BuildUi()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 1,
            Padding = new Padding(20),
            BackColor = BackColor
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 350));
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        Controls.Add(root);

        var left = PanelCard();
        left.Padding = new Padding(18);
        root.Controls.Add(left, 0, 0);

        var title = new Label
        {
            Text = "XLTD VPN",
            Dock = DockStyle.Top,
            Font = new Font("Segoe UI", 26, FontStyle.Bold),
            ForeColor = Color.FromArgb(17, 17, 17),
            Height = 54
        };
        left.Controls.Add(title);

        var version = new Label
        {
            Text = "Windows beta " + AppInfo.WindowsVersion,
            Dock = DockStyle.Top,
            ForeColor = Color.FromArgb(95, 101, 112),
            Height = 30
        };
        left.Controls.Add(version);

        profilesList.Dock = DockStyle.Fill;
        profilesList.IntegralHeight = false;
        profilesList.BorderStyle = BorderStyle.None;
        profilesList.BackColor = Color.White;
        profilesList.DrawMode = DrawMode.OwnerDrawFixed;
        profilesList.ItemHeight = 70;
        profilesList.Font = new Font("Segoe UI", 10);
        left.Controls.Add(profilesList);
        profilesList.BringToFront();

        var right = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3 };
        right.RowStyles.Add(new RowStyle(SizeType.Absolute, 250));
        right.RowStyles.Add(new RowStyle(SizeType.Absolute, 168));
        right.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.Controls.Add(right, 1, 0);

        BuildEditor(right);
        BuildConnection(right);
        BuildLogs(right);
    }

    private void BuildEditor(TableLayoutPanel right)
    {
        var editor = PanelCard();
        editor.Padding = new Padding(18);
        right.Controls.Add(editor, 0, 0);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1 };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));
        editor.Controls.Add(layout);

        layout.Controls.Add(SectionLabel("Profile"), 0, 0);
        nameBox.PlaceholderText = "Profile name";
        StyleTextBox(nameBox);
        layout.Controls.Add(nameBox, 0, 1);

        linkBox.PlaceholderText = "olcrtc://carrier?transport<params>@room#64hexkey$comment";
        linkBox.Multiline = true;
        linkBox.ScrollBars = ScrollBars.Vertical;
        StyleTextBox(linkBox);
        layout.Controls.Add(linkBox, 0, 2);

        var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.RightToLeft };
        saveButton.Text = "Save";
        saveButton.Width = 108;
        StylePrimary(saveButton);
        deleteButton.Text = "Delete";
        deleteButton.Width = 108;
        StyleSecondary(deleteButton);
        var newButton = new PillButton { Text = "New", Width = 108 };
        StyleSecondary(newButton);
        newButton.Click += (_, _) => ClearEditor();
        buttons.Controls.Add(saveButton);
        buttons.Controls.Add(deleteButton);
        buttons.Controls.Add(newButton);
        layout.Controls.Add(buttons, 0, 3);
    }

    private void BuildConnection(TableLayoutPanel right)
    {
        var connection = PanelCard();
        connection.Padding = new Padding(18);
        right.Controls.Add(connection, 0, 1);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 4 };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 168));
        connection.Controls.Add(layout);

        statusLabel.Text = "Disconnected";
        statusLabel.Font = new Font("Segoe UI", 13, FontStyle.Bold);
        statusLabel.ForeColor = Color.FromArgb(17, 17, 17);
        statusLabel.Dock = DockStyle.Fill;
        layout.Controls.Add(statusLabel, 0, 0);

        connectButton.Text = "Connect";
        connectButton.Dock = DockStyle.Fill;
        StylePrimary(connectButton);
        layout.Controls.Add(connectButton, 1, 0);

        metaLabel.Text = $"Local SOCKS: {AppInfo.DefaultSocksHost}:{AppInfo.DefaultSocksPort}";
        metaLabel.ForeColor = Color.FromArgb(95, 101, 112);
        metaLabel.Dock = DockStyle.Fill;
        layout.Controls.Add(metaLabel, 0, 1);
        layout.SetColumnSpan(metaLabel, 2);

        routeModeBox.Dock = DockStyle.Fill;
        routeModeBox.DropDownStyle = ComboBoxStyle.DropDownList;
        routeModeBox.Items.AddRange(new object[]
        {
            "Local SOCKS only",
            "Windows user proxy (beta)",
            "Full tunnel / Wintun (admin beta)"
        });
        routeModeBox.SelectedIndex = 0;
        layout.Controls.Add(routeModeBox, 0, 2);
        layout.SetColumnSpan(routeModeBox, 2);

        var hint = new Label
        {
            Text = WindowsTunnelManager.IsAdministrator()
                ? "Full tunnel is available in this elevated session."
                : "Full tunnel requires launching the app as Administrator.",
            ForeColor = Color.FromArgb(120, 126, 136),
            Dock = DockStyle.Fill
        };
        layout.Controls.Add(hint, 0, 3);
        layout.SetColumnSpan(hint, 2);
    }

    private void BuildLogs(TableLayoutPanel right)
    {
        var logs = PanelCard();
        logs.Padding = new Padding(18);
        right.Controls.Add(logs, 0, 2);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2 };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        logs.Controls.Add(layout);
        layout.Controls.Add(SectionLabel("Runtime log"), 0, 0);

        logBox.Dock = DockStyle.Fill;
        logBox.Multiline = true;
        logBox.ReadOnly = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.Font = new Font("Consolas", 9);
        logBox.BackColor = Color.White;
        logBox.BorderStyle = BorderStyle.None;
        layout.Controls.Add(logBox, 0, 1);
    }

    private void WireEvents()
    {
        profilesList.SelectedIndexChanged += (_, _) =>
        {
            if (profilesList.SelectedItem is Profile profile)
            {
                nameBox.Text = profile.Name;
                linkBox.Text = profile.Link;
                metaLabel.Text = $"{profile.Carrier} / {profile.Transport} - SOCKS {AppInfo.DefaultSocksHost}:{AppInfo.DefaultSocksPort}";
            }
        };
        profilesList.DrawItem += DrawProfileItem;
        saveButton.Click += (_, _) => SaveProfile();
        deleteButton.Click += (_, _) => DeleteSelectedProfile();
        connectButton.Click += async (_, _) => await ToggleConnectionAsync();
        core.LogLine += line => Ui(() => AppendLog(line));
        tunnel.LogLine += line => Ui(() => AppendLog("[tunnel] " + line));
        core.Exited += code => Ui(() =>
        {
            tunnel.Stop();
            proxy.Restore();
            connectButton.Text = "Connect";
            SetStatus(code.HasValue ? $"Core exited with code {code}" : "Core stopped");
        });
    }

    private void SaveProfile()
    {
        try
        {
            var link = linkBox.Text.Trim();
            var config = OlcUriParser.Parse(link);
            var selected = profilesList.SelectedItem as Profile;
            var profile = selected ?? new Profile { Id = "p" + DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() };
            profile.Link = link;
            profile.Name = string.IsNullOrWhiteSpace(nameBox.Text) ? BuildProfileName(config) : nameBox.Text.Trim();
            profile.Carrier = config.Carrier;
            profile.Transport = config.Transport;

            if (selected == null) profiles.Add(profile);
            profileStore.Save(profiles);
            RefreshProfiles(profile);
            SetStatus("Profile saved: " + profile.Name);
        }
        catch (Exception ex)
        {
            SetStatus("Profile error: " + ex.Message);
        }
    }

    private async Task ToggleConnectionAsync()
    {
        if (core.IsRunning)
        {
            tunnel.Stop();
            proxy.Restore();
            core.Stop();
            connectButton.Text = "Connect";
            SetStatus("Disconnected");
            return;
        }

        try
        {
            var config = OlcUriParser.Parse(linkBox.Text.Trim());
            SaveProfile();
            connectButton.Enabled = false;
            SetStatus("Starting olcRTC core...");
            core.Start(config, AppInfo.DefaultSocksPort);
            connectButton.Text = "Stop";

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(24));
            var ready = await core.WaitForSocksAsync(AppInfo.DefaultSocksPort, TimeSpan.FromSeconds(22), cts.Token);
            if (!ready)
            {
                SetStatus("Core started, SOCKS is not ready yet. Watch log.");
                return;
            }

            SetStatus("Connected. Local SOCKS is ready.");
            if (routeModeBox.SelectedIndex == 1)
            {
                proxy.ApplySocksProxy(AppInfo.DefaultSocksHost, AppInfo.DefaultSocksPort);
                SetStatus("Connected. Windows user proxy is enabled.");
            }
            else if (routeModeBox.SelectedIndex == 2)
            {
                tunnel.Start(AppInfo.DefaultSocksPort, ResolveMtu(config));
                SetStatus("Connected. Full tunnel is enabled.");
            }
        }
        catch (Exception ex)
        {
            tunnel.Stop();
            proxy.Restore();
            core.Stop();
            connectButton.Text = "Connect";
            SetStatus("Connection error: " + ex.Message);
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
        RefreshProfiles();
        ClearEditor();
        SetStatus("Profile deleted");
    }

    private void RefreshProfiles(Profile? select = null)
    {
        profilesList.BeginUpdate();
        profilesList.Items.Clear();
        foreach (var profile in profiles)
        {
            profilesList.Items.Add(profile);
        }
        profilesList.EndUpdate();

        if (select != null) profilesList.SelectedItem = select;
        else if (profiles.Count > 0 && profilesList.SelectedIndex < 0) profilesList.SelectedIndex = 0;
    }

    private void ClearEditor()
    {
        profilesList.ClearSelected();
        nameBox.Clear();
        linkBox.Clear();
        metaLabel.Text = $"Local SOCKS: {AppInfo.DefaultSocksHost}:{AppInfo.DefaultSocksPort}";
    }

    private static string BuildProfileName(OlcConfig config)
    {
        if (!string.IsNullOrWhiteSpace(config.Comment) && !config.Comment.Equals("direct", StringComparison.OrdinalIgnoreCase))
        {
            return config.Comment.Trim();
        }

        return config.ClientId.Equals("default", StringComparison.OrdinalIgnoreCase)
            ? $"{config.Carrier} | {config.Transport}"
            : $"{config.Carrier} | {config.Transport} | {config.ClientId}";
    }

    private void SetStatus(string text)
    {
        statusLabel.Text = text;
        AppendLog("[status] " + text);
    }

    private void AppendLog(string text)
    {
        logBox.AppendText(DateTime.Now.ToString("HH:mm:ss") + " " + text + Environment.NewLine);
    }

    private void Ui(Action action)
    {
        if (IsDisposed) return;
        if (InvokeRequired) BeginInvoke(action);
        else action();
    }

    private void DrawProfileItem(object? sender, DrawItemEventArgs e)
    {
        if (e.Index < 0 || e.Index >= profilesList.Items.Count) return;
        e.DrawBackground();
        var profile = (Profile)profilesList.Items[e.Index];
        var selected = (e.State & DrawItemState.Selected) == DrawItemState.Selected;
        var rect = new Rectangle(e.Bounds.X + 4, e.Bounds.Y + 6, e.Bounds.Width - 8, e.Bounds.Height - 10);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using var path = UiShapes.RoundedRect(rect, 18);
        using var fill = new SolidBrush(selected ? Color.FromArgb(17, 17, 17) : Color.FromArgb(245, 246, 248));
        e.Graphics.FillPath(fill, path);

        var titleColor = selected ? Color.White : Color.FromArgb(17, 17, 17);
        var metaColor = selected ? Color.FromArgb(215, 219, 226) : Color.FromArgb(95, 101, 112);
        TextRenderer.DrawText(
            e.Graphics,
            string.IsNullOrWhiteSpace(profile.Name) ? "olcRTC profile" : profile.Name,
            new Font("Segoe UI", 10, FontStyle.Bold),
            new Rectangle(rect.X + 14, rect.Y + 11, rect.Width - 28, 20),
            titleColor,
            TextFormatFlags.EndEllipsis);
        TextRenderer.DrawText(
            e.Graphics,
            $"{profile.Carrier} / {profile.Transport}",
            new Font("Segoe UI", 8),
            new Rectangle(rect.X + 14, rect.Y + 36, rect.Width - 28, 18),
            metaColor,
            TextFormatFlags.EndEllipsis);
    }

    private static Panel PanelCard()
    {
        return new RoundedPanel
        {
            Dock = DockStyle.Fill,
            FillColor = Color.White,
            BorderColor = Color.FromArgb(232, 234, 238),
            Radius = 26,
            Margin = new Padding(8)
        };
    }

    private static Label SectionLabel(string text)
    {
        return new Label
        {
            Text = text,
            Dock = DockStyle.Fill,
            ForeColor = Color.FromArgb(95, 101, 112),
            Font = new Font("Segoe UI", 10, FontStyle.Bold)
        };
    }

    private static void StyleTextBox(TextBox box)
    {
        box.Dock = DockStyle.Fill;
        box.BorderStyle = BorderStyle.FixedSingle;
        box.BackColor = Color.FromArgb(245, 246, 248);
        box.ForeColor = Color.FromArgb(17, 17, 17);
    }

    private static void StylePrimary(Button button)
    {
        if (button is PillButton pill)
        {
            pill.FillColor = Color.FromArgb(17, 17, 17);
            pill.HoverColor = Color.FromArgb(35, 35, 35);
            pill.PressedColor = Color.Black;
            pill.TextColor = Color.White;
        }
    }

    private static void StyleSecondary(Button button)
    {
        if (button is PillButton pill)
        {
            pill.FillColor = Color.FromArgb(240, 242, 245);
            pill.HoverColor = Color.FromArgb(226, 229, 235);
            pill.PressedColor = Color.FromArgb(214, 218, 225);
            pill.TextColor = Color.FromArgb(17, 17, 17);
        }
    }

    private static int ResolveMtu(OlcConfig config)
    {
        var visual = config.Transport is OlcUriParser.TransportVp8 or OlcUriParser.TransportSei or OlcUriParser.TransportVideo;
        var fallback = visual ? 1040 : 1500;
        var requested = config.IntParam("mtu", fallback);
        return Math.Max(900, Math.Min(1500, requested));
    }
}
