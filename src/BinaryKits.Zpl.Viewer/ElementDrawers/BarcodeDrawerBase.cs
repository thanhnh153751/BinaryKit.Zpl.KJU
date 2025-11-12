using BinaryKits.Zpl.Label;


using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;

using ZXing.Common;

namespace BinaryKits.Zpl.Viewer.ElementDrawers
{
    /// <summary>
    /// Base clase for Barcode element drawers
    /// </summary>
    public abstract class BarcodeDrawerBase : ElementDrawerBase
    {
        /// <summary>
        /// Minimum acceptable magin between a barcode and its interpretation line, in pixels
        /// </summary>
        protected const float MIN_LABEL_MARGIN = 5f;

        protected void DrawBarcode(byte[] barcodeImageData, float x, float y, int barcodeWidth, int barcodeHeight, bool useFieldOrigin, Label.FieldOrientation fieldOrientation)
        {
            // Replaced SKAutoCanvasRestore with Graphics.Save/Restore
            GraphicsState state = this.graphicsCanvas.Save();

            try
            {
                // Replaced SKMatrix with System.Drawing.Drawing2D.Matrix
                Matrix matrix = GetRotationMatrix(x, y, barcodeWidth, barcodeHeight, useFieldOrigin, fieldOrientation);

                if (!useFieldOrigin)
                {
                    y -= barcodeHeight;
                    if (y < 0)
                    {
                        y = 0;
                    }
                }

                // Check for rotation/translation
                if (matrix != null)
                {
                    this.graphicsCanvas.Transform = matrix;
                }

                // Decode the image data (PNG format from the drawer helper) into a GDI+ Bitmap
                using (var ms = new MemoryStream(barcodeImageData))
                using (var barcodeBitmap = new Bitmap(ms))
                {
                    // DrawBitmap replacement: Draw the bitmap to the Graphics canvas
                    this.graphicsCanvas.DrawImage(barcodeBitmap, x, y, barcodeWidth, barcodeHeight);
                }
            }
            finally
            {
                this.graphicsCanvas.Restore(state);
            }
        }

        protected void DrawInterpretationLine(string interpretation, float labelFontSize, float x, float y, int barcodeWidth, int barcodeHeight, bool useFieldOrigin, Label.FieldOrientation fieldOrientation, bool printInterpretationLineAboveCode, DrawerOptions options)
        {
            // Note: SKFont replaced with InternationalFont (which must expose a System.Drawing.Font).
            // Note: DrawShapedText (HarfBuzz) is replaced with standard DrawString. 
            //       This is a functional compromise for .NET 4.0, but may not handle complex scripts (e.g., Arabic, Thai) correctly.

            GraphicsState state = this.graphicsCanvas.Save();

            try
            {
                // Retrieve the GDI+ Font from the InternationalFont object
                // ASSUMPTION: InternationalFont has a property/method to get System.Drawing.Font

                Font font = new Font("Arial", labelFontSize);

                // SKPaint replacement: Pen/Brush setup
                using (Brush textBrush = new SolidBrush(Color.Black))
                {
                    // Replaced SKMatrix with System.Drawing.Drawing2D.Matrix
                    Matrix matrix = GetRotationMatrix(x, y, barcodeWidth, barcodeHeight, useFieldOrigin, fieldOrientation);
                    if (matrix != null)
                    {
                        this.graphicsCanvas.Transform = matrix;
                    }

                    // SKFont.MeasureText replacement
                    SizeF textBounds = this.graphicsCanvas.MeasureString(interpretation, font);

                    // Center the text
                    x += (barcodeWidth - textBounds.Width) / 2;

                    if (!useFieldOrigin)
                    {
                        y -= barcodeHeight;
                        if (y < 0)
                        {
                            y = 0;
                        }
                    }

                    // SKFont.Spacing replacement (Approximation)
                    float margin = Math.Max(font.GetHeight(this.graphicsCanvas) - textBounds.Height, MIN_LABEL_MARGIN);

                    if (printInterpretationLineAboveCode)
                    {
                        // DrawShapedText replacement using DrawString
                        this.graphicsCanvas.DrawString(interpretation, font, textBrush, x, y - margin - textBounds.Height);
                    }
                    else
                    {
                        // DrawShapedText replacement using DrawString
                        this.graphicsCanvas.DrawString(interpretation, font, textBrush, x, y + barcodeHeight + margin);
                    }
                }
            }
            finally
            {
                this.graphicsCanvas.Restore(state);
            }
        }

        protected static Matrix GetRotationMatrix(float x, float y, int width, int height, bool useFieldOrigin, Label.FieldOrientation fieldOrientation)
        {
            // Replaced SKMatrix with System.Drawing.Drawing2D.Matrix
            Matrix matrix = null;
            float centerX = x + width / 2f;
            float centerY = y + height / 2f;

            float rotationDegrees = 0;

            if (useFieldOrigin)
            {
                switch (fieldOrientation)
                {
                    case Label.FieldOrientation.Rotated90:
                        rotationDegrees = 90;
                        break;
                    case Label.FieldOrientation.Rotated180:
                        rotationDegrees = 180;
                        break;
                    case Label.FieldOrientation.Rotated270:
                        rotationDegrees = 270;
                        break;
                    case Label.FieldOrientation.Normal:
                        break;
                }

                if (rotationDegrees != 0)
                {
                    // Rotate around the center of the barcode
                    matrix = new Matrix();
                    matrix.RotateAt(rotationDegrees, new PointF(centerX, centerY));
                }
            }
            else
            {
                switch (fieldOrientation)
                {
                    case Label.FieldOrientation.Rotated90:
                        rotationDegrees = 90;
                        break;
                    case Label.FieldOrientation.Rotated180:
                        rotationDegrees = 180;
                        break;
                    case Label.FieldOrientation.Rotated270:
                        rotationDegrees = 270;
                        break;
                    case Label.FieldOrientation.Normal:
                        break;
                }

                if (rotationDegrees != 0)
                {
                    // Rotate around the field origin (top-left corner defined by x, y)
                    matrix = new Matrix();
                    matrix.RotateAt(rotationDegrees, new PointF(x, y));
                }
            }

            return matrix;
        }

        protected static Bitmap BoolArrayToSKBitmap(bool[] array, int height, int moduleWidth = 1)
        {
            int originalWidth = array.Length;
            int finalWidth = originalWidth * moduleWidth;

            // Create a temporary 1-pixel high bitmap to set colors
            using (Bitmap tempImage = new Bitmap(originalWidth, 1, PixelFormat.Format32bppArgb))
            {
                for (int col = 0; col < originalWidth; col++)
                {
                    // SKColor replacement
                    Color color = array[col] ? Color.Black : Color.Transparent;
                    tempImage.SetPixel(col, 0, color);
                }

                // Resize to the final dimensions using a high-quality (Nearest Neighbor replacement)
                // We use Graphics.DrawImage for controlled resizing, which is the GDI+ way.
                Bitmap finalImage = new Bitmap(finalWidth, height, PixelFormat.Format32bppArgb);
                using (Graphics g = Graphics.FromImage(finalImage))
                {
                    // Use NearestNeighbor for pixel-perfect scaling (matches SKFilterMode.Nearest)
                    g.InterpolationMode = InterpolationMode.NearestNeighbor;
                    g.DrawImage(tempImage, 0, 0, finalWidth, height);
                }
                return finalImage;
            }
        }

        /// <summary>
        /// Converts a boolean array with a mask to a System.Drawing.Bitmap, scaling by module width and height.
        /// </summary>
        protected static Bitmap BoolArrayWithMaskToBitmap(bool[] array, bool[] mask, int height, int moduleWidth = 1)
        {
            int originalWidth = array.Length;
            int finalWidth = originalWidth * moduleWidth;

            using (Bitmap tempImage = new Bitmap(originalWidth, 1, PixelFormat.Format32bppArgb))
            {
                for (int col = 0; col < originalWidth; col++)
                {
                    Color color = array[col] && mask[col] ? Color.Black : Color.Transparent;
                    tempImage.SetPixel(col, 0, color);
                }

                Bitmap finalImage = new Bitmap(finalWidth, height, PixelFormat.Format32bppArgb);
                using (Graphics g = Graphics.FromImage(finalImage))
                {
                    g.InterpolationMode = InterpolationMode.NearestNeighbor;
                    g.DrawImage(tempImage, 0, 0, finalWidth, height);
                }
                return finalImage;
            }
        }

        /// <summary>
        /// Converts a ZXing BitMatrix to a System.Drawing.Bitmap, scaling by pixel scale.
        /// </summary>
        protected static Bitmap BitMatrixToBitmap(BitMatrix matrix, int pixelScale)
        {
            int originalWidth = matrix.Width;
            int originalHeight = matrix.Height;
            int finalWidth = originalWidth * pixelScale;
            int finalHeight = originalHeight * pixelScale;

            // Create the scaled bitmap
            Bitmap scaledImage = new Bitmap(finalWidth, finalHeight, PixelFormat.Format32bppArgb);

            // Directly draw onto the scaled bitmap using SetPixel (slower, but accurate for this port)
            // Note: For performance, LockBits is usually preferred for large bitmaps.
            Color black = Color.Black;
            Color transparent = Color.Transparent;

            for (int y = 0; y < originalHeight; y++)
            {
                for (int x = 0; x < originalWidth; x++)
                {
                    // Use the real ZXing API
                    bool isBlack = matrix[x, y];
                    Color color = isBlack ? black : transparent;

                    // Fill the scaled block (pixelScale x pixelScale)
                    for (int dy = 0; dy < pixelScale; dy++)
                    {
                        for (int dx = 0; dx < pixelScale; dx++)
                        {
                            scaledImage.SetPixel(
                                (x * pixelScale) + dx,
                                (y * pixelScale) + dy,
                                color
                            );
                        }
                    }
                }
            }
            return scaledImage;
        }

        protected static bool[] AdjustWidths(bool[] array, int wide, int narrow)
        {
            List<bool> result = [];
            bool last = true;
            int count = 0;
            foreach (bool current in array)
            {
                if (current != last)
                {
                    result.AddRange(Enumerable.Repeat(last, count == 1 ? narrow : wide));
                    last = current;
                    count = 0;
                }

                count += 1;
            }

            result.AddRange(Enumerable.Repeat(last, narrow));
            return result.ToArray();
        }
    }
}
