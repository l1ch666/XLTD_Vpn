using System.Drawing.Drawing2D;

namespace XLTD.Vpn.Windows.Controls;

internal static class UiShapes
{
    public static GraphicsPath RoundedRect(Rectangle bounds, int radius)
    {
        var path = new GraphicsPath();
        var r = Math.Max(1, Math.Min(radius, Math.Min(bounds.Width, bounds.Height)));
        var d = r * 2;
        var rect = new Rectangle(bounds.X, bounds.Y, bounds.Width - 1, bounds.Height - 1);

        path.AddArc(rect.X, rect.Y, d, d, 180, 90);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }
}
