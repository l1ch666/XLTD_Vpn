using System.Drawing.Drawing2D;

namespace XLTD.Vpn.Windows.Controls;

internal sealed class PillButton : Button
{
    private bool hovered;
    private bool pressed;

    public Color FillColor { get; set; } = Color.FromArgb(17, 17, 17);
    public Color HoverColor { get; set; } = Color.FromArgb(35, 35, 35);
    public Color PressedColor { get; set; } = Color.Black;
    public Color TextColor { get; set; } = Color.White;
    public int Radius { get; set; } = 18;

    public PillButton()
    {
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        Cursor = Cursors.Hand;
        Font = new Font("Segoe UI", 10, FontStyle.Bold);
        Height = 40;
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw, true);
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        hovered = true;
        Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        hovered = false;
        pressed = false;
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs mevent)
    {
        pressed = true;
        Invalidate();
        base.OnMouseDown(mevent);
    }

    protected override void OnMouseUp(MouseEventArgs mevent)
    {
        pressed = false;
        Invalidate();
        base.OnMouseUp(mevent);
    }

    protected override void OnPaint(PaintEventArgs pevent)
    {
        pevent.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        var color = pressed ? PressedColor : hovered ? HoverColor : FillColor;
        using var path = UiShapes.RoundedRect(ClientRectangle, Radius);
        using var fill = new SolidBrush(Enabled ? color : Color.FromArgb(210, 213, 219));
        using var text = new SolidBrush(Enabled ? TextColor : Color.FromArgb(120, 126, 136));
        pevent.Graphics.FillPath(fill, path);
        TextRenderer.DrawText(
            pevent.Graphics,
            Text,
            Font,
            ClientRectangle,
            Enabled ? TextColor : Color.FromArgb(120, 126, 136),
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
    }
}
