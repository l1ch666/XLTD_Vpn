using System.Drawing.Drawing2D;

namespace XLTD.Vpn.Windows.Controls;

internal sealed class RoundedPanel : Panel
{
    public int Radius { get; set; } = 22;
    public Color FillColor { get; set; } = Color.White;
    public Color BorderColor { get; set; } = Color.FromArgb(233, 235, 239);

    public RoundedPanel()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        Margin = new Padding(8);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using var path = UiShapes.RoundedRect(ClientRectangle, Radius);
        using var fill = new SolidBrush(FillColor);
        using var border = new Pen(BorderColor);
        e.Graphics.FillPath(fill, path);
        e.Graphics.DrawPath(border, path);
    }
}
