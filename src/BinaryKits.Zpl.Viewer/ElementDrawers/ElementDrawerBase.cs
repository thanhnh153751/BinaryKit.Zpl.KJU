using BinaryKits.Zpl.Label;
using BinaryKits.Zpl.Label.Elements;

using System.Drawing; // Replaces using SkiaSharp;

namespace BinaryKits.Zpl.Viewer.ElementDrawers
{
    // The interface IElementDrawer will also need its SKPoint and SKCanvas references updated to System.Drawing.PointF and System.Drawing.Graphics.

    public abstract class ElementDrawerBase : IElementDrawer
    {
        internal IPrinterStorage printerStorage;
        // Replaced SKCanvas with System.Drawing.Graphics
        internal Graphics graphicsCanvas;

        ///<inheritdoc/>
        public void Prepare(
            IPrinterStorage printerStorage,
            // Replaced SKCanvas with System.Drawing.Graphics
            Graphics graphicsCanvas)
        {
            this.printerStorage = printerStorage;
            this.graphicsCanvas = graphicsCanvas;
        }

        ///<inheritdoc/>
        public abstract bool CanDraw(ZplElementBase element);

        ///<inheritdoc/>
        public virtual bool IsReverseDraw(ZplElementBase element)
        {
            return false;
        }

        ///<inheritdoc/>
        public virtual bool IsWhiteDraw(ZplElementBase element)
        {
            return false;
        }

        ///<inheritdoc/>
        public virtual bool ForceBitmapDraw(ZplElementBase element)
        {
            return false;
        }

        ///<inheritdoc/>
        // Replaced SKPoint with System.Drawing.PointF
        public virtual PointF Draw(ZplElementBase element, DrawerOptions options, PointF currentPosition)
        {
            return currentPosition;
        }

        ///<inheritdoc/>
        // Replaced SKPoint with System.Drawing.PointF
        public virtual PointF Draw(ZplElementBase element, DrawerOptions options, PointF currentPosition, InternationalFont internationalFont)
        {
            return this.Draw(element, options, currentPosition);
        }

        ///<inheritdoc/>
        // Replaced SKPoint with System.Drawing.PointF
        public virtual PointF Draw(ZplElementBase element, DrawerOptions options, PointF currentPosition, InternationalFont internationalFont, int printDensityDpmm)
        {
            return this.Draw(element, options, currentPosition, internationalFont);
        }

        // Replaced SKPoint with System.Drawing.PointF
        protected virtual PointF CalculateNextDefaultPosition(float x, float y, float elementWidth, float elementHeight, bool useFieldOrigin, Label.FieldOrientation fieldOrientation, PointF currentPosition)
        {
            if (useFieldOrigin)
            {
                switch (fieldOrientation)
                {
                    case Label.FieldOrientation.Normal:
                        return new PointF(x + elementWidth, y + elementHeight);
                    case Label.FieldOrientation.Rotated90:
                        return new PointF(x, y + elementHeight);
                    case Label.FieldOrientation.Rotated180:
                        return new PointF(x - elementWidth, y);
                    case Label.FieldOrientation.Rotated270:
                        return new PointF(x, y - elementHeight);
                }
            }
            else
            {
                switch (fieldOrientation)
                {
                    case Label.FieldOrientation.Normal:
                        return new PointF(x + elementWidth, y);
                    case Label.FieldOrientation.Rotated90:
                        return new PointF(x, y + elementWidth);
                    case Label.FieldOrientation.Rotated180:
                        return new PointF(x - elementWidth, y);
                    case Label.FieldOrientation.Rotated270:
                        return new PointF(x, y - elementWidth);
                }
            }

            return currentPosition;
        }

    }
}
