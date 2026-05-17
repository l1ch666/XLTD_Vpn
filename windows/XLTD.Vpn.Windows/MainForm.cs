using System.Drawing;
using XLTD.Vpn.Windows.Models;
using XLTD.Vpn.Windows.Services;

namespace XLTD.Vpn.Windows;

internal sealed class MainForm : Form
{
    private readonly ProfileStore profileStore = new();
    private readonly CoreProcessManager core = new();
    private readonly WindowsProxyManager proxy = new();
    private readonly List<Profile> profiles;

    private readonly ListBox profilesList = new();
    private readonly TextBox nameBox = new();
    private readonly TextBox linkBox = new();
    private readonly TextBox logBox = new();
    private readonly Label statusLabel = new();
    private readonly Label metaLabel = new();
    private readonly CheckBox systemProxyBox = new();
    private readonly Button connectButton = new();
    private readonly Button saveButton = new();
    private readonly Button deleteButton = new();

    public MainForm()
    {
        profiles = profileStore.Load();
        Text = $"{AppInfo.ProductName} Windows {AppInfo.WindowsVersion}";
        MinimumSize = new Size(920, 640);
        Size = new Size(1040, 720);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(245, 246, 248);

        BuildUi();
        WireEvents();
        RefreshProfiles();
        SetStatus("Ready. Add or select an olcRTC profile.");
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
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
            Padding = new Padding(18),
            BackColor = BackColor
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 330));
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        Controls.Add(root);

        var left = PanelCard();
        left.Padding = new Padding(14);
        root.Controls.Add(left, 0, 0);

        var right = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3 };
        right.RowStyles.Add(new RowStyle(SizeType.Absolute, 250));
        right.RowStyles.Add(new RowStyle(SizeType.Absolute, 132));
        right.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.Controls.Add(right, 1, 0);

        var title = new Label
        {
            Text = "XLTD VPN",
            Dock = DockStyle.Top,
            Font = new Font("Segoe UI", 22, FontStyle.Bold),
            Height = 44
        };
        left.Controls.Add(title);

        var version = new Label
        {
            Text = "Windows beta " + AppInfo.WindowsVersion,
            Dock = DockStyle.Top,
            ForeColor = Color.FromArgb(95, 101, 112),
            Height = 28
        };
        left.Controls.Add(version);

        profilesList.Dock = DockStyle.Fill;
        profilesList.IntegralHeight = false;
        profilesList.Font = new Font("Segoe UI", 10);
        left.Controls.Add(profilesList);
        profilesList.BringToFront();

        var editor = PanelCard();
        editor.Padding = new Padding(16);
        right.Controls.Add(editor, 0, 0);

        var editorLayout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1 };
        editorLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));
        editorLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
        editorLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        editorLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 42));
        editor.Controls.Add(editorLayout);

        editorLayout.Controls.Add(SectionLabel("Profile"), 0, 0);
        nameBox.PlaceholderText = "Profile name";
        nameBox.Dock = DockStyle.Fill;
        editorLayout.Controls.Add(nameBox, 0, 1);
        linkBox.PlaceholderText = "olcrtc://carrier?transport<params>@room#64hexkey$comment";
        linkBox.Multiline = true;
        linkBox.ScrollBars = ScrollBars.Vertical;
        linkBox.Dock = DockStyle.Fill;
        editorLayout.Controls.Add(linkBox, 0, 2);

        var editorButtons = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.RightToLeft };
        saveButton.Text = "Save";
        saveButton.Width = 100;
        deleteButton.Text = "Delete";
        deleteButton.Width = 100;
        var newButton = new Button { Text = "New", Width = 100 };
        newButton.Click += (_, _) => ClearEditor();
        editorButtons.Controls.Add(saveButton);
        editorButtons.Controls.Add(deleteButton);
        editorButtons.Controls.Add(newButton);
        editorLayout.Controls.Add(editorButtons, 0, 3);

        var connection = PanelCard();
        connection.Padding = new Padding(16);
        right.Controls.Add(connection, 0, 1);

        var connectionLayout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 3 };
        connectionLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        connectionLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 160));
        connection.Controls.Add(connectionLayout);

        statusLabel.Text = "Disconnected";
        statusLabel.Font = new Font("Segoe UI", 12, FontStyle.Bold);
        statusLabel.Dock = DockStyle.Fill;
        connectionLayout.Controls.Add(statusLabel, 0, 0);

        connectButton.Text = "Connect";
        connectButton.Height = 38;
        connectButton.Dock = DockStyle.Fill;
        connectionLayout.Controls.Add(connectButton, 1, 0);

        metaLabel.Text = "Local SOCKS: 127.0.0.1:10808";
        metaLabel.ForeColor = Color.FromArgb(95, 101, 112);
        metaLabel.Dock = DockStyle.Fill;
        connectionLayout.Controls.Add(metaLabel, 0, 1);
        connectionLayout.SetColumnSpan(metaLabel, 2);

        systemProxyBox.Text = "Use Windows user proxy while connected (beta)";
        systemProxyBox.Dock = DockStyle.Fill;
        connectionLayout.Controls.Add(systemProxyBox, 0, 2);
        connectionLayout.SetColumnSpan(systemProxyBox, 2);

        var logs = PanelCard();
        logs.Padding = new Padding(16);
        right.Controls.Add(logs, 0, 2);

        var logsLayout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2 };
        logsLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));
        logsLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        logs.Controls.Add(logsLayout);
        logsLayout.Controls.Add(SectionLabel("Runtime log"), 0, 0);
        logBox.Dock = DockStyle.Fill;
        logBox.Multiline = true;
        logBox.ReadOnly = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.Font = new Font("Consolas", 9);
        logBox.BackColor = Color.White;
        logsLayout.Controls.Add(logBox, 0, 1);
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
        saveButton.Click += (_, _) => SaveProfile();
        deleteButton.Click += (_, _) => DeleteSelectedProfile();
        connectButton.Click += async (_, _) => await ToggleConnectionAsync();
        core.LogLine += line => Ui(() => AppendLog(line));
        core.Exited += code => Ui(() =>
        {
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
            }
            else
            {
                SetStatus("Connected. Local SOCKS is ready.");
                if (systemProxyBox.Checked)
                {
                    proxy.ApplySocksProxy(AppInfo.DefaultSocksHost, AppInfo.DefaultSocksPort);
                    SetStatus("Connected. Windows user proxy is enabled.");
                }
            }
        }
        catch (Exception ex)
        {
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

    private static Panel PanelCard()
    {
        return new Panel
        {
            Dock = DockStyle.Fill,
            BackColor = Color.White,
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
}
